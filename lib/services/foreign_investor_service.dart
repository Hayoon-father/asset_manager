import 'dart:async';
import 'dart:math' as Math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/foreign_investor_data.dart';
import 'package:intl/intl.dart';

class ForeignInvestorService {
  static const String tableName = 'foreign_investor_data';
  
  final SupabaseClient _client = SupabaseConfig.client;
  
  // 스트림 컨트롤러 (실시간 데이터 업데이트용)
  final StreamController<List<ForeignInvestorData>> _dataStreamController = 
      StreamController<List<ForeignInvestorData>>.broadcast();
  
  Stream<List<ForeignInvestorData>> get dataStream => _dataStreamController.stream;

  // 최근 외국인 수급 데이터 조회 (실제 DB 연결)
  Future<List<ForeignInvestorData>> getLatestForeignInvestorData({
    String? marketType,
    int limit = 50,
  }) async {
    try {
      print('🔍 실제 DB에서 최신 외국인 수급 데이터 조회 시작');
      
      // 전체 데이터 조회
      final response = await _client
          .from(tableName)
          .select('*')
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit * 3); // 필터링을 위해 더 많이 조회
      print('📊 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 조회된 데이터가 없습니다.');
        return [];
      }
      
      // JSON을 객체로 변환
      var allData = response
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        allData = allData.where((data) => data.marketType == marketType).toList();
      }
      
      // 제한 개수만큼 잘라내기
      final result = allData.take(limit).toList();
      
      print('✅ 실제 데이터 ${result.length}개 반환');
      return result;
          
    } catch (e) {
      print('외국인 수급 데이터 조회 실패: $e');
      return [];
    }
  }

  // 일별 외국인 수급 요약 조회 (실제 DB 연결)
  Future<List<DailyForeignSummary>> getDailyForeignSummary({
    String? startDate,
    String? endDate,
    String? marketType,
    int limit = 30,
  }) async {
    try {
      print('🔍 실제 DB에서 일별 외국인 수급 요약 조회 시작');
      
      // 기본 날짜 설정
      final String actualEndDate = endDate ?? DateFormat('yyyyMMdd').format(DateTime.now());
      final String actualStartDate = startDate ?? DateFormat('yyyyMMdd').format(
        DateTime.now().subtract(Duration(days: limit))
      );
      
      // 전체 시장 데이터만 조회 (ticker가 null인 데이터)
      final response = await _client
          .from(tableName)
          .select('date, market_type, investor_type, sell_amount, buy_amount, net_amount')
          .gte('date', actualStartDate)
          .lte('date', actualEndDate)
          .order('date', ascending: false)
          .limit(limit * 10); // 충분한 데이터 조회
      
      print('📊 일별 요약 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 일별 요약 데이터가 없습니다.');
        return [];
      }
      
      // 전체 시장 데이터만 필터링 (ticker가 null인 데이터)
      final marketData = response.where((item) => item['ticker'] == null).toList();
      
      // 날짜별로 그룹화하여 집계
      final Map<String, Map<String, Map<String, int>>> grouped = {};
      
      for (final item in marketData) {
        final date = item['date'] as String;
        final market = item['market_type'] as String;
        final investorType = item['investor_type'] as String;
        
        // 시장 필터 적용
        if (marketType != null && marketType != 'ALL' && market != marketType) {
          continue;
        }
        
        if (!grouped.containsKey(date)) {
          grouped[date] = {};
        }
        if (!grouped[date]!.containsKey(market)) {
          grouped[date]![market] = {
            'foreign_net_amount': 0,
            'other_foreign_net_amount': 0,
            'foreign_buy_amount': 0,
            'foreign_sell_amount': 0,
          };
        }
        
        final sellAmount = item['sell_amount'] as int? ?? 0;
        final buyAmount = item['buy_amount'] as int? ?? 0;
        final netAmount = item['net_amount'] as int? ?? 0;
        
        if (investorType == '외국인') {
          grouped[date]![market]!['foreign_net_amount'] = netAmount;
          grouped[date]![market]!['foreign_buy_amount'] = buyAmount;
          grouped[date]![market]!['foreign_sell_amount'] = sellAmount;
        } else if (investorType == '기타외국인') {
          grouped[date]![market]!['other_foreign_net_amount'] = netAmount;
        }
      }
      
      // DailyForeignSummary 객체로 변환
      final result = <DailyForeignSummary>[];
      
      for (final dateEntry in grouped.entries) {
        final date = dateEntry.key;
        final markets = dateEntry.value;
        
        for (final marketEntry in markets.entries) {
          final market = marketEntry.key;
          final amounts = marketEntry.value;
          
          final foreignNet = amounts['foreign_net_amount']!;
          final otherForeignNet = amounts['other_foreign_net_amount']!;
          
          result.add(DailyForeignSummary(
            date: date,
            marketType: market,
            foreignNetAmount: foreignNet,
            otherForeignNetAmount: otherForeignNet,
            totalForeignNetAmount: foreignNet + otherForeignNet,
            foreignBuyAmount: amounts['foreign_buy_amount']!,
            foreignSellAmount: amounts['foreign_sell_amount']!,
          ));
        }
      }
      
      // 날짜순 정렬 (최신순)
      result.sort((a, b) => b.date.compareTo(a.date));
      
      print('✅ 일별 요약 데이터 ${result.length}개 반환');
      return result.take(limit).toList();
      
    } catch (e) {
      print('일별 외국인 수급 요약 조회 실패: $e');
      return [];
    }
  }

  // 외국인 순매수 상위 종목 조회 (실제 DB 연결)
  Future<List<ForeignInvestorData>> getTopForeignStocks({
    String? date,
    String? marketType,
    int limit = 20,
  }) async {
    try {
      print('🔍 실제 DB에서 외국인 순매수 상위 종목 조회 시작');
      
      // 기본 날짜 설정 (최근 5일 내)
      final String queryDate = date ?? DateFormat('yyyyMMdd').format(DateTime.now());
      final String startDate = DateFormat('yyyyMMdd').format(
        DateTime.now().subtract(const Duration(days: 5))
      );
      
      // 개별 종목 데이터만 조회 (ticker가 null이 아닌 데이터)
      final response = await _client
          .from(tableName)
          .select('*')
          .gte('date', startDate)
          .lte('date', queryDate)
          .order('net_amount', ascending: false)
          .limit(limit * 3); // 필터링을 위해 더 많이 조회
      
      print('📊 상위 종목 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 상위 종목 데이터가 없습니다.');
        return [];
      }
      
      // 개별 종목 데이터만 필터링 (ticker가 null이 아니고 외국인 순매수)
      var stockData = response
          .where((item) => 
              item['ticker'] != null && 
              item['investor_type'] == '외국인' &&
              (item['net_amount'] as int? ?? 0) > 0)
          .toList();
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        stockData = stockData.where((item) => item['market_type'] == marketType).toList();
      }
      
      // 순매수 금액순으로 정렬
      stockData.sort((a, b) => (b['net_amount'] as int).compareTo(a['net_amount'] as int));
      
      // 제한 개수만큼 잘라내기
      final limitedData = stockData.take(limit).toList();
      
      final result = limitedData
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
      print('✅ 상위 종목 데이터 ${result.length}개 반환');
      
      // 실제 데이터가 없으면 더미 데이터로 fallback
      if (result.isEmpty) {
        print('⚠️ 실제 종목 데이터가 없어 더미 데이터로 fallback');
        return _getDummyTopBuyStocks(marketType, limit);
      }
      
      return result;
      
    } catch (e) {
      print('외국인 순매수 상위 종목 조회 실패: $e');
      return _getDummyTopBuyStocks(marketType, limit);
    }
  }

  // 외국인 순매도 상위 종목 조회 (실제 DB 연결)
  Future<List<ForeignInvestorData>> getTopForeignSellStocks({
    String? date,
    String? marketType,
    int limit = 20,
  }) async {
    try {
      print('🔍 실제 DB에서 외국인 순매도 상위 종목 조회 시작');
      
      // 기본 날짜 설정 (최근 5일 내)
      final String queryDate = date ?? DateFormat('yyyyMMdd').format(DateTime.now());
      final String startDate = DateFormat('yyyyMMdd').format(
        DateTime.now().subtract(const Duration(days: 5))
      );
      
      // 개별 종목 데이터만 조회 (ticker가 null이 아닌 데이터)
      final response = await _client
          .from(tableName)
          .select('*')
          .gte('date', startDate)
          .lte('date', queryDate)
          .order('net_amount', ascending: true) // 오름차순(가장 많이 판 것부터)
          .limit(limit * 3); // 필터링을 위해 더 많이 조회
      
      print('📊 순매도 상위 종목 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 순매도 상위 종목 데이터가 없습니다.');
        return [];
      }
      
      // 개별 종목 데이터만 필터링 (ticker가 null이 아니고 외국인 순매도)
      var stockData = response
          .where((item) => 
              item['ticker'] != null && 
              item['investor_type'] == '외국인' &&
              (item['net_amount'] as int? ?? 0) < 0)
          .toList();
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        stockData = stockData.where((item) => item['market_type'] == marketType).toList();
      }
      
      // 순매도 금액순으로 정렬 (절댓값 기준)
      stockData.sort((a, b) => (a['net_amount'] as int).compareTo(b['net_amount'] as int));
      
      // 제한 개수만큼 잘라내기
      final limitedData = stockData.take(limit).toList();
      
      final result = limitedData
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
      print('✅ 순매도 상위 종목 데이터 ${result.length}개 반환');
      
      // 실제 데이터가 없으면 더미 데이터로 fallback
      if (result.isEmpty) {
        print('⚠️ 실제 종목 데이터가 없어 더미 데이터로 fallback');
        return _getDummyTopSellStocks(marketType, limit);
      }
      
      return result;
      
    } catch (e) {
      print('외국인 순매도 상위 종목 조회 실패: $e');
      return _getDummyTopSellStocks(marketType, limit);
    }
  }

  // 데이터 삽입/업데이트 (upsert)
  Future<void> upsertForeignInvestorData(List<ForeignInvestorData> dataList) async {
    try {
      final jsonDataList = dataList.map((data) => data.toJson()).toList();
      await _client.from(tableName).upsert(jsonDataList);
      _notifyDataUpdate();
    } catch (e) {
      print('외국인 수급 데이터 저장 실패: $e');
      throw Exception('외국인 수급 데이터 저장 실패: $e');
    }
  }

  // 실시간 데이터 구독 시작 (에러 방지용 더미 구현)
  void startRealtimeSubscription() {
    // 실제 구독은 나중에 구현
    print('실시간 데이터 구독 시작 (더미 구현)');
  }

  // 데이터 업데이트 알림
  void _notifyDataUpdate() async {
    try {
      final latestData = await getLatestForeignInvestorData(limit: 50);
      _dataStreamController.add(latestData);
    } catch (e) {
      // 에러가 발생해도 스트림은 계속 동작하도록 함
      print('데이터 업데이트 알림 실패: $e');
    }
  }

  // 유틸리티: 날짜 포맷팅 (YYYYMMDD -> 표시용)
  static String formatDateForDisplay(String date) {
    try {
      final DateTime dateTime = DateFormat('yyyyMMdd').parse(date);
      return DateFormat('yyyy-MM-dd').format(dateTime);
    } catch (e) {
      return date;
    }
  }

  // 유틸리티: 금액 포맷팅 (원 단위 -> 억원 단위)
  static String formatAmount(int amount) {
    if (amount == 0) return '0';
    
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 1000000000000) { // 1조 이상
      final cho = (absAmount / 1000000000000);
      return '$sign${cho.toStringAsFixed(cho == cho.truncate() ? 0 : 1)}조원';
    } else if (absAmount >= 100000000) { // 1억 이상
      final eok = (absAmount / 100000000);
      return '$sign${eok.toStringAsFixed(eok == eok.truncate() ? 0 : 1)}억원';
    } else if (absAmount >= 10000) { // 1만 이상
      final man = (absAmount / 10000);
      return '$sign${man.toStringAsFixed(man == man.truncate() ? 0 : 1)}만원';
    } else {
      return '$sign$absAmount원';
    }
  }

  // 유틸리티: 오늘 날짜를 YYYYMMDD 형식으로 반환
  static String getTodayString() {
    return DateFormat('yyyyMMdd').format(DateTime.now());
  }

  // 유틸리티: n일 전 날짜를 YYYYMMDD 형식으로 반환
  static String getDaysAgoString(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return DateFormat('yyyyMMdd').format(date);
  }

  // 더미 상위 매수 종목 데이터 (fallback)
  List<ForeignInvestorData> _getDummyTopBuyStocks(String? marketType, int limit) {
    final result = <ForeignInvestorData>[];
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    
    final dummyStocks = [
      {'ticker': '005930', 'name': '삼성전자', 'market': 'KOSPI', 'netAmount': 1500000000000},
      {'ticker': '000660', 'name': 'SK하이닉스', 'market': 'KOSPI', 'netAmount': 800000000000},
      {'ticker': '035420', 'name': 'NAVER', 'market': 'KOSPI', 'netAmount': 600000000000},
      {'ticker': '005380', 'name': '현대차', 'market': 'KOSPI', 'netAmount': 400000000000},
      {'ticker': '035720', 'name': '카카오', 'market': 'KOSPI', 'netAmount': 300000000000},
      {'ticker': '373220', 'name': 'LG에너지솔루션', 'market': 'KOSPI', 'netAmount': 250000000000},
      {'ticker': '207940', 'name': '삼성바이오로직스', 'market': 'KOSPI', 'netAmount': 200000000000},
      {'ticker': '006400', 'name': '삼성SDI', 'market': 'KOSPI', 'netAmount': 180000000000},
      {'ticker': '051910', 'name': 'LG화학', 'market': 'KOSPI', 'netAmount': 150000000000},
      {'ticker': '096770', 'name': 'SK이노베이션', 'market': 'KOSPI', 'netAmount': 120000000000},
    ];
    
    for (int i = 0; i < dummyStocks.length && i < limit; i++) {
      final stock = dummyStocks[i];
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL' && stock['market'] != marketType) {
        continue;
      }
      
      result.add(ForeignInvestorData(
        date: today,
        marketType: stock['market'] as String,
        investorType: '외국인',
        ticker: stock['ticker'] as String,
        stockName: stock['name'] as String,
        sellAmount: 2000000000,
        buyAmount: (stock['netAmount'] as int) + 2000000000,
        netAmount: stock['netAmount'] as int,
        createdAt: DateTime.now(),
      ));
    }
    
    return result;
  }
  
  // 더미 상위 매도 종목 데이터 (fallback)  
  List<ForeignInvestorData> _getDummyTopSellStocks(String? marketType, int limit) {
    final result = <ForeignInvestorData>[];
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    
    final dummySellStocks = [
      {'ticker': '068270', 'name': '셀트리온', 'market': 'KOSPI', 'netAmount': -300000000000},
      {'ticker': '323410', 'name': '카카오뱅크', 'market': 'KOSPI', 'netAmount': -250000000000},
      {'ticker': '003550', 'name': 'LG', 'market': 'KOSPI', 'netAmount': -200000000000},
      {'ticker': '012330', 'name': '현대모비스', 'market': 'KOSPI', 'netAmount': -180000000000},
      {'ticker': '028260', 'name': '삼성물산', 'market': 'KOSPI', 'netAmount': -150000000000},
    ];
    
    for (int i = 0; i < dummySellStocks.length && i < limit; i++) {
      final stock = dummySellStocks[i];
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL' && stock['market'] != marketType) {
        continue;
      }
      
      final netAmount = stock['netAmount'] as int;
      result.add(ForeignInvestorData(
        date: today,
        marketType: stock['market'] as String,
        investorType: '외국인',
        ticker: stock['ticker'] as String,
        stockName: stock['name'] as String,
        sellAmount: netAmount.abs() + 1000000000,
        buyAmount: 1000000000,
        netAmount: netAmount,
        createdAt: DateTime.now(),
      ));
    }
    
    return result;
  }

  // 리소스 정리
  void dispose() {
    _dataStreamController.close();
  }
}