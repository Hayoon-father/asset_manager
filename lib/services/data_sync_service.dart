import 'package:intl/intl.dart';
import '../config/supabase_config.dart';
import '../models/foreign_investor_data.dart';
import 'pykrx_data_service.dart';

class DataSyncService {
  final PykrxDataService _pykrxService = PykrxDataService();
  
  // 싱글톤 패턴
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  // 데이터베이스에서 최신 데이터 날짜 조회 (시장별, 투자자별로 세분화)
  Future<String?> getLatestDateInDB() async {
    try {
      final response = await SupabaseConfig.client
          .from('foreign_investor_data')
          .select('date')
          .order('date', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final latestDate = response.first['date'] as String;
        return latestDate;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 특정 날짜의 완전한 데이터가 모두 존재하는지 확인
  Future<bool> isCompleteDailyDataExists(String date) async {
    try {
      // 해당 날짜에 필요한 모든 데이터 조합이 있는지 확인
      // KOSPI, KOSDAQ 각각에 대해 외국인, 기타외국인 데이터가 있어야 함
      final requiredCombinations = [
        {'market': 'KOSPI', 'investor': '외국인'},
        {'market': 'KOSPI', 'investor': '기타외국인'},
        {'market': 'KOSDAQ', 'investor': '외국인'},
        {'market': 'KOSDAQ', 'investor': '기타외국인'},
      ];

      for (final combo in requiredCombinations) {
        final response = await SupabaseConfig.client
            .from('foreign_investor_data')
            .select('id')
            .eq('date', date)
            .eq('market_type', combo['market']!)
            .eq('investor_type', combo['investor']!)
            .filter('ticker', 'is', null) // 전체 시장 데이터만 확인
            .limit(1);

        if (response.isEmpty) {
          return false; // 하나라도 없으면 불완전한 데이터
        }
      }
      
      return true; // 모든 필수 데이터가 존재
    } catch (e) {
      return false;
    }
  }

  // 특정 날짜의 데이터가 DB에 존재하는지 확인
  Future<bool> isDataExistsInDB(String date) async {
    try {
      final response = await SupabaseConfig.client
          .from('foreign_investor_data')
          .select('id')
          .eq('date', date)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // DB에서 누락된 날짜들을 찾기
  Future<List<String>> getMissingDatesInDB(String fromDate, String toDate) async {
    try {
      final missingDates = <String>[];
      
      // 날짜 범위 내의 모든 날짜 생성
      final startDate = DateFormat('yyyyMMdd').parse(fromDate);
      final endDate = DateFormat('yyyyMMdd').parse(toDate);
      
      for (var date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final dateString = DateFormat('yyyyMMdd').format(date);
        
        // 완전한 일일 데이터가 존재하는지 확인
        final hasCompleteData = await isCompleteDailyDataExists(dateString);
        if (!hasCompleteData) {
          missingDates.add(dateString);
        }
      }
      
      return missingDates;
    } catch (e) {
      return [];
    }
  }

  // 새로운 데이터를 DB에 저장 (개선된 배치 처리)
  Future<bool> saveDataToDB(List<ForeignInvestorData> dataList) async {
    if (dataList.isEmpty) return true;

    try {
      final jsonDataList = dataList.map((data) => data.toJson()).toList();
      
      // 대용량 데이터를 위한 배치 처리 (100개씩 나누어 저장)
      const batchSize = 100;
      for (int i = 0; i < jsonDataList.length; i += batchSize) {
        final batch = jsonDataList.skip(i).take(batchSize).toList();
        
        // upsert로 중복 시 업데이트, 없으면 삽입
        await SupabaseConfig.client
            .from('foreign_investor_data')
            .upsert(
              batch, 
              onConflict: 'date,market_type,investor_type,ticker',
              ignoreDuplicates: false,  // 중복 시에도 업데이트
            );
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // 최신 데이터 동기화 (앱 초기화 시 호출) - 개선된 버전
  Future<DataSyncResult> syncLatestData() async {
    try {
      // 1. pykrx API 서버 상태 확인 (재시도 로직 적용)
      final isApiHealthy = await _pykrxService.checkServerWithRetry(maxRetries: 3);
      if (!isApiHealthy) {
        return DataSyncResult(
          success: false,
          message: 'pykrx API 서버 연결 실패 (3회 재시도 후)',
          newDataCount: 0,
        );
      }

      // 2. pykrx에서 최신 거래일 조회
      final latestTradingDate = await _pykrxService.getLatestTradingDate();
      
      // 3. DB에서 최신 데이터 날짜 조회
      final latestDateInDB = await getLatestDateInDB();
      
      // 4. 완전한 최신 데이터가 있는지 정밀 검증
      if (latestDateInDB != null && latestDateInDB == latestTradingDate) {
        final hasCompleteLatestData = await isCompleteDailyDataExists(latestDateInDB);
        if (hasCompleteLatestData) {
          return DataSyncResult(
            success: true,
            message: '이미 완전한 최신 데이터 보유',
            newDataCount: 0,
          );
        }
      }

      // 5. 동기화할 날짜 범위 결정
      final String fromDate = latestDateInDB != null 
          ? latestDateInDB  // 최신 날짜부터 다시 확인 (누락 데이터 보완)
          : _getDaysAgo(30); // DB가 비어있으면 최근 30일 가져오기
      
      // 6. 누락된 날짜들 찾기
      final missingDates = await getMissingDatesInDB(fromDate, latestTradingDate);
      
      if (missingDates.isEmpty) {
        return DataSyncResult(
          success: true,
          message: '누락된 데이터 없음',
          newDataCount: 0,
        );
      }

      // 7. 누락된 데이터만 선별적으로 가져오기
      final newDataList = <ForeignInvestorData>[];
      
      for (final missingDate in missingDates) {
        final dailyData = await _pykrxService.getForeignInvestorDataByDateRange(
          fromDate: missingDate,
          toDate: missingDate,
          markets: ['KOSPI', 'KOSDAQ'],
        );
        newDataList.addAll(dailyData);
      }

      if (newDataList.isEmpty) {
        return DataSyncResult(
          success: true,
          message: 'pykrx에서 새로운 데이터 없음',
          newDataCount: 0,
        );
      }

      // 8. 정밀한 중복 검증 후 저장
      final uniqueDataList = await _filterDuplicateDataPrecise(newDataList);
      
      if (uniqueDataList.isEmpty) {
        return DataSyncResult(
          success: true,
          message: '모든 데이터가 이미 존재함',
          newDataCount: 0,
        );
      }

      // 9. DB에 저장
      final saveSuccess = await saveDataToDB(uniqueDataList);
      
      if (saveSuccess) {
        return DataSyncResult(
          success: true,
          message: '데이터 동기화 완료 (누락 데이터: ${missingDates.length}일)',
          newDataCount: uniqueDataList.length,
        );
      } else {
        return DataSyncResult(
          success: false,
          message: 'DB 저장 실패',
          newDataCount: 0,
        );
      }

    } catch (e) {
      return DataSyncResult(
        success: false,
        message: '데이터 동기화 실패: $e',
        newDataCount: 0,
      );
    }
  }

  // 중복 데이터 필터링 (기본 버전)
  Future<List<ForeignInvestorData>> _filterDuplicateData(List<ForeignInvestorData> dataList) async {
    final uniqueDataList = <ForeignInvestorData>[];
    
    for (final data in dataList) {
      final exists = await _isDataDuplicate(data);
      if (!exists) {
        uniqueDataList.add(data);
      }
    }
    
    return uniqueDataList;
  }

  // 정밀한 중복 데이터 필터링 (개선된 버전)
  Future<List<ForeignInvestorData>> _filterDuplicateDataPrecise(List<ForeignInvestorData> dataList) async {
    final uniqueDataList = <ForeignInvestorData>[];
    final checkedKeys = <String>{};
    
    // 먼저 메모리에서 중복 제거 (같은 요청 내 중복)
    for (final data in dataList) {
      final key = '${data.date}_${data.marketType}_${data.investorType}_${data.ticker ?? 'ALL'}';
      if (checkedKeys.contains(key)) {
        continue; // 이미 처리한 데이터는 건너뛰기
      }
      checkedKeys.add(key);
      
      // DB에서 중복 확인
      final exists = await _isDataDuplicatePrecise(data);
      if (!exists) {
        uniqueDataList.add(data);
      }
    }
    
    return uniqueDataList;
  }

  // 특정 데이터가 DB에 중복으로 존재하는지 확인 (기본 버전)
  Future<bool> _isDataDuplicate(ForeignInvestorData data) async {
    try {
      final response = await SupabaseConfig.client
          .from('foreign_investor_data')
          .select('id')
          .eq('date', data.date)
          .eq('market_type', data.marketType)
          .eq('investor_type', data.investorType)
          .eq('ticker', data.ticker ?? '')
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 정밀한 중복 검사 (null 값 처리 개선)
  Future<bool> _isDataDuplicatePrecise(ForeignInvestorData data) async {
    try {
      var query = SupabaseConfig.client
          .from('foreign_investor_data')
          .select('id, buy_amount, sell_amount, net_amount')
          .eq('date', data.date)
          .eq('market_type', data.marketType)
          .eq('investor_type', data.investorType);
      
      // ticker null 처리 개선
      if (data.ticker == null) {
        query = query.filter('ticker', 'is', null);
      } else {
        query = query.eq('ticker', data.ticker!);
      }
      
      final response = await query.limit(1);
      
      if (response.isEmpty) {
        return false; // 중복 아님
      }
      
      // 데이터 값까지 비교하여 정확히 같은 데이터인지 확인
      final existingData = response.first;
      final existingBuyAmount = existingData['buy_amount'] as int? ?? 0;
      final existingSellAmount = existingData['sell_amount'] as int? ?? 0;
      final existingNetAmount = existingData['net_amount'] as int? ?? 0;
      
      return existingBuyAmount == data.buyAmount && 
             existingSellAmount == data.sellAmount && 
             existingNetAmount == data.netAmount;
             
    } catch (e) {
      return false; // 오류 시 중복이 아닌 것으로 간주하여 안전하게 저장
    }
  }

  // 다음 날짜 계산 (YYYYMMDD 형식)
  String _getNextDate(String dateString) {
    try {
      final date = DateFormat('yyyyMMdd').parse(dateString);
      final nextDate = date.add(const Duration(days: 1));
      return DateFormat('yyyyMMdd').format(nextDate);
    } catch (e) {
      return dateString;
    }
  }

  // N일 전 날짜 계산 (YYYYMMDD 형식)
  String _getDaysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return DateFormat('yyyyMMdd').format(date);
  }
}

// 데이터 동기화 결과 모델 (개선된 버전)
class DataSyncResult {
  final bool success;
  final String message;
  final int newDataCount;
  final List<String>? syncedDates;  // 동기화된 날짜들
  final DateTime syncTime;  // 동기화 시각

  DataSyncResult({
    required this.success,
    required this.message,
    required this.newDataCount,
    this.syncedDates,
    DateTime? syncTime,
  }) : syncTime = syncTime ?? DateTime.now();

  @override
  String toString() {
    return 'DataSyncResult{success: $success, message: $message, newDataCount: $newDataCount, syncTime: $syncTime}';
  }

  // 성공적인 동기화 여부
  bool get isSuccessfulSync => success && newDataCount > 0;
  
  // 최신 데이터 보유 여부
  bool get hasLatestData => success && newDataCount == 0 && message.contains('최신');
}