import 'dart:async';
import 'dart:math' as math;
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
      
      // 쿼리 빌더 시작
      var query = _client
          .from(tableName)
          .select('*')
          .order('date', ascending: false)
          .order('created_at', ascending: false);
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        query = query.filter('market_type', 'eq', marketType);
      }
      
      // 제한 개수 적용
      query = query.limit(limit);
      
      final response = await query;
      print('📊 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 조회된 데이터가 없습니다.');
        return [];
      }
      
      final result = response
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
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
      
      // 쿼리 빌더 (전체 시장 데이터만, ticker가 null인 데이터)
      var query = _client
          .from(tableName)
          .select('date, market_type, investor_type, sell_amount, buy_amount, net_amount')
          .gte('date', actualStartDate)
          .lte('date', actualEndDate)
          .filter('ticker', 'is', null)  // 전체 시장 데이터만
          .order('date', ascending: false);
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        query = query.filter('market_type', 'eq', marketType);
      }
      
      final response = await query;
      print('📊 일별 요약 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 일별 요약 데이터가 없습니다.');
        return [];
      }
      
      // 날짜별로 그룹화하여 집계
      final Map<String, Map<String, Map<String, int>>> grouped = {};
      
      for (final item in response) {
        final date = item['date'] as String;
        final market = item['market_type'] as String;
        final investorType = item['investor_type'] as String;
        
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
      
      // 쿼리 빌더 (개별 종목 데이터만, ticker가 null이 아닌 데이터)
      var query = _client
          .from(tableName)
          .select('*')
          .gte('date', startDate)
          .lte('date', queryDate)
          .filter('ticker', 'not.is', null)  // 개별 종목 데이터만
          .filter('investor_type', 'eq', '외국인')
          .filter('net_amount', 'gt', 0)  // 순매수만
          .order('net_amount', ascending: false);
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        query = query.filter('market_type', 'eq', marketType);
      }
      
      query = query.limit(limit);
      
      final response = await query;
      print('📊 상위 종목 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 상위 종목 데이터가 없습니다.');
        return [];
      }
      
      final result = response
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
      print('✅ 상위 종목 데이터 ${result.length}개 반환');
      return result;
      
    } catch (e) {
      print('외국인 순매수 상위 종목 조회 실패: $e');
      return [];
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
      
      // 쿼리 빌더 (개별 종목 데이터만, ticker가 null이 아닌 데이터)
      var query = _client
          .from(tableName)
          .select('*')
          .gte('date', startDate)
          .lte('date', queryDate)
          .filter('ticker', 'not.is', null)  // 개별 종목 데이터만
          .filter('investor_type', 'eq', '외국인')
          .filter('net_amount', 'lt', 0)  // 순매도만
          .order('net_amount', ascending: true);  // 오름차순 (가장 많이 판 것부터)
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL') {
        query = query.filter('market_type', 'eq', marketType);
      }
      
      query = query.limit(limit);
      
      final response = await query;
      print('📊 순매도 상위 종목 DB 조회 결과: ${response.length}개 레코드');
      
      if (response.isEmpty) {
        print('⚠️ 순매도 상위 종목 데이터가 없습니다.');
        return [];
      }
      
      final result = response
          .map<ForeignInvestorData>((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
      print('✅ 순매도 상위 종목 데이터 ${result.length}개 반환');
      return result;
      
    } catch (e) {
      print('외국인 순매도 상위 종목 조회 실패: $e');
      return [];
    }
  }

  // 실시간 데이터 구독 시작 (더미 구현)
  void startRealtimeSubscription() {
    print('실시간 데이터 구독 시작 (더미 구현)');
    // 실제 구현에서는 Supabase realtime을 사용
  }

  // 리소스 정리
  void dispose() {
    _dataStreamController.close();
  }

  // 유틸리티 메서드들
  static String formatAmount(int amount) {
    if (amount == 0) return '0';
    
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    
    String formatted;
    if (absAmount >= 1000000000000) { // 1조 이상
      formatted = '${(absAmount / 1000000000000).toStringAsFixed(1)}조';
    } else if (absAmount >= 100000000) { // 1억 이상
      formatted = '${(absAmount / 100000000).toStringAsFixed(0)}억';
    } else if (absAmount >= 10000) { // 1만 이상
      formatted = '${(absAmount / 10000).toStringAsFixed(0)}만';
    } else {
      formatted = absAmount.toString();
    }
    
    return isNegative ? '-$formatted' : formatted;
  }

  static String formatDateForDisplay(String date) {
    try {
      if (date.length == 8) {
        final year = date.substring(0, 4);
        final month = date.substring(4, 6);
        final day = date.substring(6, 8);
        return '$year.$month.$day';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  static String getDaysAgoString(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return DateFormat('yyyyMMdd').format(date);
  }
}