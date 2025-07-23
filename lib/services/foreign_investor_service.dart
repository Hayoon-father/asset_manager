import 'dart:async';
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

  // 최근 외국인 수급 데이터 조회 (간단한 버전)
  Future<List<ForeignInvestorData>> getLatestForeignInvestorData({
    String? marketType,
    int limit = 50,
  }) async {
    try {
      // 기본 쿼리
      var query = _client
          .from(tableName)
          .select()
          .order('date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<Map<String, dynamic>> response = await query;
      
      // 시장 타입 필터링 (클라이언트에서 처리)
      List<Map<String, dynamic>> filteredResponse = response;
      if (marketType != null) {
        filteredResponse = response
            .where((item) => item['market_type'] == marketType)
            .toList();
      }
      
      return filteredResponse
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
          
    } catch (e) {
      // 데이터가 없는 경우 빈 리스트 반환 (테이블이 없을 수도 있음)
      print('외국인 수급 데이터 조회 실패: $e');
      return [];
    }
  }

  // 일별 외국인 수급 요약 조회 (더미 데이터로 시작)
  Future<List<DailyForeignSummary>> getDailyForeignSummary({
    String? startDate,
    String? endDate,
    String? marketType,
    int limit = 30,
  }) async {
    try {
      // 실제 구현 전에 더미 데이터로 UI 테스트
      final result = <DailyForeignSummary>[];
      
      // 요청된 일수만큼 더미 데이터 생성 (최대 60일)
      final daysToGenerate = limit > 60 ? 60 : limit;
      for (int i = 0; i < daysToGenerate; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateString = DateFormat('yyyyMMdd').format(date);
        
        // KOSPI 더미 데이터
        if (marketType == null || marketType == 'ALL' || marketType == 'KOSPI') {
          result.add(DailyForeignSummary(
            date: dateString,
            marketType: 'KOSPI',
            foreignNetAmount: (i % 2 == 0 ? 1 : -1) * (1000000000 + i * 100000000),
            otherForeignNetAmount: (i % 3 == 0 ? 1 : -1) * (50000000 + i * 10000000),
            totalForeignNetAmount: (i % 2 == 0 ? 1 : -1) * (1050000000 + i * 110000000),
            foreignBuyAmount: 5000000000 + i * 100000000,
            foreignSellAmount: 4000000000 + i * 50000000,
          ));
        }
        
        // KOSDAQ 더미 데이터
        if (marketType == null || marketType == 'ALL' || marketType == 'KOSDAQ') {
          result.add(DailyForeignSummary(
            date: dateString,
            marketType: 'KOSDAQ',
            foreignNetAmount: (i % 2 == 1 ? 1 : -1) * (500000000 + i * 50000000),
            otherForeignNetAmount: (i % 3 == 1 ? 1 : -1) * (25000000 + i * 5000000),
            totalForeignNetAmount: (i % 2 == 1 ? 1 : -1) * (525000000 + i * 55000000),
            foreignBuyAmount: 2500000000 + i * 50000000,
            foreignSellAmount: 2000000000 + i * 25000000,
          ));
        }
      }
      
      return result.take(limit).toList();
      
    } catch (e) {
      print('일별 외국인 수급 요약 조회 실패: $e');
      return [];
    }
  }

  // 외국인 순매수 상위 종목 조회 (더미 데이터)
  Future<List<ForeignInvestorData>> getTopForeignStocks({
    String? date,
    String? marketType,
    int limit = 20,
  }) async {
    try {
      // 더미 상위 종목 데이터
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
      
    } catch (e) {
      print('외국인 순매수 상위 종목 조회 실패: $e');
      return [];
    }
  }

  // 외국인 순매도 상위 종목 조회 (더미 데이터)
  Future<List<ForeignInvestorData>> getTopForeignSellStocks({
    String? date,
    String? marketType,
    int limit = 20,
  }) async {
    try {
      // 더미 순매도 종목 데이터
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
      
    } catch (e) {
      print('외국인 순매도 상위 종목 조회 실패: $e');
      return [];
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

  // 리소스 정리
  void dispose() {
    _dataStreamController.close();
  }
}