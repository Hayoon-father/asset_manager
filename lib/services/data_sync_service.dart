import 'package:intl/intl.dart';
import '../config/supabase_config.dart';
import '../models/foreign_investor_data.dart';
import 'pykrx_data_service.dart';
import 'foreign_investor_service.dart';

class DataSyncService {
  final PykrxDataService _pykrxService = PykrxDataService();
  
  // 싱글톤 패턴
  static final DataSyncService _instance = DataSyncService._internal();
  factory DataSyncService() => _instance;
  DataSyncService._internal();

  // 데이터베이스에서 최신 데이터 날짜 조회
  Future<String?> getLatestDateInDB() async {
    try {
      print('🔍 DB에서 최신 데이터 날짜 조회 중...');
      
      final response = await SupabaseConfig.client
          .from('foreign_investor_data')
          .select('date')
          .order('date', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final latestDate = response.first['date'] as String;
        print('📅 DB 최신 데이터 날짜: $latestDate');
        return latestDate;
      } else {
        print('📅 DB에 데이터가 없습니다');
        return null;
      }
    } catch (e) {
      print('❌ DB 최신 날짜 조회 실패: $e');
      return null;
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
      print('❌ DB 데이터 존재 확인 실패: $e');
      return false;
    }
  }

  // 새로운 데이터를 DB에 저장
  Future<bool> saveDataToDB(List<ForeignInvestorData> dataList) async {
    if (dataList.isEmpty) return true;

    try {
      print('💾 DB에 ${dataList.length}개 데이터 저장 중...');
      
      final jsonDataList = dataList.map((data) => data.toJson()).toList();
      
      // 배치로 저장 (중복 데이터는 무시)
      await SupabaseConfig.client
          .from('foreign_investor_data')
          .upsert(jsonDataList, onConflict: 'date,market_type,investor_type,ticker');

      print('✅ DB에 데이터 저장 완료');
      return true;
    } catch (e) {
      print('❌ DB 데이터 저장 실패: $e');
      return false;
    }
  }

  // 최신 데이터 동기화 (앱 초기화 시 호출)
  Future<DataSyncResult> syncLatestData() async {
    try {
      print('🔄 데이터 동기화 시작...');
      
      // 1. pykrx API 서버 상태 확인
      final isApiHealthy = await _pykrxService.checkApiHealth();
      if (!isApiHealthy) {
        print('⚠️ pykrx API 서버에 연결할 수 없습니다. 기존 DB 데이터를 사용합니다.');
        return DataSyncResult(
          success: false,
          message: 'pykrx API 서버 연결 실패',
          newDataCount: 0,
        );
      }

      // 2. DB에서 최신 데이터 날짜 조회
      final latestDateInDB = await getLatestDateInDB();
      
      // 3. pykrx에서 최신 거래일 조회
      final latestTradingDate = await _pykrxService.getLatestTradingDate();
      
      print('📊 데이터 비교:');
      print('  - DB 최신 날짜: ${latestDateInDB ?? "없음"}');
      print('  - pykrx 최신 거래일: $latestTradingDate');

      // 4. 새로운 데이터가 있는지 확인
      if (latestDateInDB != null && latestDateInDB == latestTradingDate) {
        print('✅ 이미 최신 데이터를 보유하고 있습니다.');
        return DataSyncResult(
          success: true,
          message: '이미 최신 데이터 보유',
          newDataCount: 0,
        );
      }

      // 5. 새로운 데이터 가져오기
      final String fromDate = latestDateInDB != null 
          ? _getNextDate(latestDateInDB)
          : _getDaysAgo(30); // DB가 비어있으면 최근 30일 가져오기
      
      print('📥 새로운 데이터 조회: $fromDate ~ $latestTradingDate');
      
      final newDataList = await _pykrxService.getForeignInvestorDataByDateRange(
        fromDate: fromDate,
        toDate: latestTradingDate,
        markets: ['KOSPI', 'KOSDAQ'],
      );

      if (newDataList.isEmpty) {
        print('📭 새로운 데이터가 없습니다.');
        return DataSyncResult(
          success: true,
          message: '새로운 데이터 없음',
          newDataCount: 0,
        );
      }

      // 6. 중복 데이터 필터링
      final uniqueDataList = await _filterDuplicateData(newDataList);
      
      if (uniqueDataList.isEmpty) {
        print('📭 모든 데이터가 이미 존재합니다.');
        return DataSyncResult(
          success: true,
          message: '모든 데이터 중복',
          newDataCount: 0,
        );
      }

      // 7. DB에 저장
      final saveSuccess = await saveDataToDB(uniqueDataList);
      
      if (saveSuccess) {
        print('🎉 데이터 동기화 완료: ${uniqueDataList.length}개 신규 데이터 추가');
        return DataSyncResult(
          success: true,
          message: '데이터 동기화 완료',
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
      print('❌ 데이터 동기화 실패: $e');
      return DataSyncResult(
        success: false,
        message: '데이터 동기화 실패: $e',
        newDataCount: 0,
      );
    }
  }

  // 중복 데이터 필터링
  Future<List<ForeignInvestorData>> _filterDuplicateData(List<ForeignInvestorData> dataList) async {
    final uniqueDataList = <ForeignInvestorData>[];
    
    for (final data in dataList) {
      final exists = await _isDataDuplicate(data);
      if (!exists) {
        uniqueDataList.add(data);
      }
    }
    
    print('🔍 중복 필터링 결과: ${dataList.length}개 → ${uniqueDataList.length}개');
    return uniqueDataList;
  }

  // 특정 데이터가 DB에 중복으로 존재하는지 확인
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
      print('❌ 중복 확인 실패: $e');
      return false;
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

// 데이터 동기화 결과 모델
class DataSyncResult {
  final bool success;
  final String message;
  final int newDataCount;

  DataSyncResult({
    required this.success,
    required this.message,
    required this.newDataCount,
  });

  @override
  String toString() {
    return 'DataSyncResult{success: $success, message: $message, newDataCount: $newDataCount}';
  }
}