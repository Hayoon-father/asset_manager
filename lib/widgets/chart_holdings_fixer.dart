import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/foreign_investor_data.dart';

/// 차트 데이터의 actualHoldingsValue를 직접 수정하는 유틸리티
class ChartHoldingsFixer {
  static final SupabaseClient _client = Supabase.instance.client;
  static Map<String, Map<String, int>>? _cachedHoldingsMap;
  static DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// 차트 데이터의 actualHoldingsValue를 실제 DB 데이터로 수정
  static Future<bool> fixActualHoldingsValues(List<DailyForeignSummary> chartData) async {
    if (chartData.isEmpty) {
      print('🔧 ChartHoldingsFixer: 차트 데이터가 비어있음');
      return false;
    }

    print('🔧 ChartHoldingsFixer: ${chartData.length}개 차트 데이터 보유액 수정 시작');

    try {
      // 1. 보유액 데이터 로드 (캐시 우선)
      final holdingsMap = await _getHoldingsMap();
      
      if (holdingsMap.isEmpty) {
        print('🔧 ChartHoldingsFixer: 보유액 데이터가 없어서 수정 불가');
        return false;
      }

      print('🔧 ChartHoldingsFixer: ${holdingsMap.keys.length}일의 보유액 데이터 로드됨');

      // 2. 각 차트 데이터의 actualHoldingsValue 수정
      int fixedCount = 0;
      int fallbackCount = 0;
      
      // 최신 보유액 값 (폴백용)
      final latestKospiValue = _getLatestValue(holdingsMap, 'KOSPI');
      final latestKosdaqValue = _getLatestValue(holdingsMap, 'KOSDAQ');
      
      for (final data in chartData) {
        final originalValue = data.actualHoldingsValue;
        
        if (holdingsMap.containsKey(data.date)) {
          final marketHoldings = holdingsMap[data.date]!;
          
          if (data.marketType == 'ALL') {
            final kospiValue = marketHoldings['KOSPI'] ?? 0;
            final kosdaqValue = marketHoldings['KOSDAQ'] ?? 0;
            data.actualHoldingsValue = kospiValue + kosdaqValue;
          } else {
            data.actualHoldingsValue = marketHoldings[data.marketType] ?? 0;
          }
          
          if (data.actualHoldingsValue > 0) {
            fixedCount++;
          }
        } else {
          // 날짜 매칭 실패 시 최신 데이터로 폴백
          if (data.marketType == 'ALL') {
            data.actualHoldingsValue = latestKospiValue + latestKosdaqValue;
          } else if (data.marketType == 'KOSPI') {
            data.actualHoldingsValue = latestKospiValue;
          } else if (data.marketType == 'KOSDAQ') {
            data.actualHoldingsValue = latestKosdaqValue;
          }
          
          if (data.actualHoldingsValue > 0) {
            fallbackCount++;
          }
        }
        
        if (originalValue != data.actualHoldingsValue) {
          final trillion = data.actualHoldingsValue / 1000000000000;
          print('🔧 수정: [${data.date}] ${data.marketType}: $originalValue → ${data.actualHoldingsValue} (${trillion.toStringAsFixed(1)}조원)');
        }
      }

      // 3. 결과 확인
      final zeroCount = chartData.where((d) => d.actualHoldingsValue == 0).length;
      final nonZeroCount = chartData.length - zeroCount;
      
      print('🔧 ChartHoldingsFixer 완료:');
      print('   - 정확매칭: ${fixedCount}개');
      print('   - 폴백적용: ${fallbackCount}개');
      print('   - 0인 값: ${zeroCount}개');
      print('   - 0이 아닌 값: ${nonZeroCount}개');
      print('   - 전체: ${chartData.length}개');

      // 수정이 실제로 발생했는지 반환
      return nonZeroCount > 0;

    } catch (e) {
      print('🔧 ChartHoldingsFixer 오류: $e');
      return false;
    }
  }

  /// 보유액 데이터 맵 가져오기 (캐시 포함)
  static Future<Map<String, Map<String, int>>> _getHoldingsMap() async {
    // 캐시 확인
    if (_cachedHoldingsMap != null && 
        _lastCacheTime != null && 
        DateTime.now().difference(_lastCacheTime!) < _cacheExpiry) {
      print('🔧 보유액 데이터 캐시 사용');
      return _cachedHoldingsMap!;
    }

    print('🔧 Supabase에서 보유액 데이터 직접 로드');
    
    try {
      // 최근 90일 데이터 로드
      final now = DateTime.now();
      final fromDate = now.subtract(const Duration(days: 90));
      final fromDateStr = '${fromDate.year}${fromDate.month.toString().padLeft(2, '0')}${fromDate.day.toString().padLeft(2, '0')}';
      final toDateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      final response = await _client
          .from('foreign_holdings_value')
          .select('date, market_type, total_holdings_value')
          .gte('date', fromDateStr)
          .lte('date', toDateStr)
          .order('date', ascending: false);

      print('🔧 Supabase 응답: ${response.length}개 레코드');

      // 날짜별, 시장별로 그룹화
      final Map<String, Map<String, int>> holdingsMap = {};
      
      for (final item in response) {
        final date = item['date'] as String;
        final marketType = item['market_type'] as String;
        final totalValue = item['total_holdings_value'] as int;
        
        if (!holdingsMap.containsKey(date)) {
          holdingsMap[date] = {};
        }
        holdingsMap[date]![marketType] = totalValue;
      }

      // 캐시 저장
      _cachedHoldingsMap = holdingsMap;
      _lastCacheTime = DateTime.now();

      print('🔧 보유액 맵 생성 완료: ${holdingsMap.keys.length}일, 캐시 저장됨');
      
      // 최신 3일 데이터 샘플 출력
      final sortedDates = holdingsMap.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final date in sortedDates.take(3)) {
        final markets = holdingsMap[date]!;
        final kospiValue = markets['KOSPI'] ?? 0;
        final kosdaqValue = markets['KOSDAQ'] ?? 0;
        print('🔧 샘플: $date - KOSPI: ${kospiValue ~/ 1000000000000}조, KOSDAQ: ${kosdaqValue ~/ 1000000000000}조');
      }

      return holdingsMap;

    } catch (e) {
      print('🔧 보유액 데이터 로드 실패: $e');
      return {};
    }
  }

  /// 특정 시장의 최신 보유액 값 가져오기
  static int _getLatestValue(Map<String, Map<String, int>> holdingsMap, String marketType) {
    final sortedDates = holdingsMap.keys.toList()..sort((a, b) => b.compareTo(a));
    
    for (final date in sortedDates) {
      final value = holdingsMap[date]![marketType];
      if (value != null && value > 0) {
        return value;
      }
    }
    
    return 0;
  }

  /// 캐시 클리어
  static void clearCache() {
    _cachedHoldingsMap = null;
    _lastCacheTime = null;
    print('🔧 ChartHoldingsFixer 캐시 클리어됨');
  }
}