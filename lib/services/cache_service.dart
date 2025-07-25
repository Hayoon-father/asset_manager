import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/foreign_investor_data.dart';

class CacheService {
  static const String _cachePrefix = 'foreign_investor_cache_';
  static const String _cacheTimestampPrefix = 'cache_timestamp_';
  static const Duration _cacheValidDuration = Duration(hours: 1); // 1시간 캐시 유효
  
  // 싱글톤 패턴
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // 캐시 키 생성
  String _generateCacheKey(String type, {String? date, String? market}) {
    final keyParts = [_cachePrefix, type];
    if (date != null) keyParts.add(date);
    if (market != null) keyParts.add(market);
    return keyParts.join('_');
  }

  // 타임스탬프 키 생성
  String _generateTimestampKey(String cacheKey) {
    return '$_cacheTimestampPrefix${cacheKey.replaceAll(_cachePrefix, '')}';
  }

  // 캐시 유효성 확인
  Future<bool> _isCacheValid(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampKey = _generateTimestampKey(cacheKey);
      final timestamp = prefs.getInt(timestampKey);
      
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      return now.difference(cacheTime) < _cacheValidDuration;
    } catch (e) {
      return false;
    }
  }

  // 데이터 캐시 저장
  Future<void> setCachedData(
    String type,
    List<ForeignInvestorData> data, {
    String? date,
    String? market,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(type, date: date, market: market);
      final timestampKey = _generateTimestampKey(cacheKey);
      
      // 데이터를 JSON으로 변환하여 저장
      final jsonList = data.map((item) => item.toJson()).toList();
      final jsonString = json.encode(jsonList);
      
      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('캐시 저장 완료: $cacheKey (${data.length}개 항목)');
    } catch (e) {
      print('캐시 저장 실패: $e');
    }
  }

  // 캐시된 데이터 조회
  Future<List<ForeignInvestorData>?> getCachedData(
    String type, {
    String? date,
    String? market,
  }) async {
    try {
      final cacheKey = _generateCacheKey(type, date: date, market: market);
      
      // 캐시 유효성 확인
      if (!await _isCacheValid(cacheKey)) {
        print('캐시 만료됨: $cacheKey');
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(cacheKey);
      
      if (jsonString == null) {
        print('캐시 데이터 없음: $cacheKey');
        return null;
      }
      
      final jsonList = json.decode(jsonString) as List<dynamic>;
      final data = jsonList
          .map((json) => ForeignInvestorData.fromJson(json))
          .toList();
      
      print('캐시에서 데이터 로드: $cacheKey (${data.length}개 항목)');
      return data;
    } catch (e) {
      print('캐시 조회 실패: $e');
      return null;
    }
  }

  // 최신 데이터 캐시 (기본)
  Future<void> setCachedLatestData(List<ForeignInvestorData> data) async {
    await setCachedData('latest', data);
  }

  Future<List<ForeignInvestorData>?> getCachedLatestData() async {
    return await getCachedData('latest');
  }

  // 일별 요약 데이터 캐시
  Future<void> setCachedDailySummary(
    List<dynamic> data,
    String? market,
  ) async {
    // DailyForeignSummary를 JSON으로 직렬화 가능하도록 변환
    final jsonData = data.map((summary) => {
      'date': summary.date,
      'market_type': summary.marketType,
      'foreign_net_amount': summary.foreignNetAmount,
      'other_foreign_net_amount': summary.otherForeignNetAmount,
      'total_foreign_net_amount': summary.totalForeignNetAmount,
      'foreign_buy_amount': summary.foreignBuyAmount,
      'foreign_sell_amount': summary.foreignSellAmount,
    }).toList();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey('daily_summary', market: market);
      final timestampKey = _generateTimestampKey(cacheKey);
      
      final jsonString = json.encode(jsonData);
      await prefs.setString(cacheKey, jsonString);
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('일별 요약 캐시 저장: $cacheKey (${data.length}개 항목)');
    } catch (e) {
      print('일별 요약 캐시 저장 실패: $e');
    }
  }

  Future<List<dynamic>?> getCachedDailySummary(String? market) async {
    try {
      final cacheKey = _generateCacheKey('daily_summary', market: market);
      
      if (!await _isCacheValid(cacheKey)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(cacheKey);
      
      if (jsonString == null) return null;
      
      final jsonList = json.decode(jsonString) as List<dynamic>;
      final data = jsonList; // DailyForeignSummary 객체 생성은 호출하는 곳에서 처리
      
      print('일별 요약 캐시 로드: $cacheKey (${data.length}개 항목)');
      return data;
    } catch (e) {
      print('일별 요약 캐시 조회 실패: $e');
      return null;
    }
  }

  // 상위 종목 데이터 캐시
  Future<void> setCachedTopStocks(
    String type, // 'buy' 또는 'sell'
    List<ForeignInvestorData> data,
    String? market,
  ) async {
    await setCachedData('top_$type', data, market: market);
  }

  Future<List<ForeignInvestorData>?> getCachedTopStocks(
    String type,
    String? market,
  ) async {
    return await getCachedData('top_$type', market: market);
  }

  // 특정 캐시 삭제
  Future<void> clearCache(String type, {String? date, String? market}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(type, date: date, market: market);
      final timestampKey = _generateTimestampKey(cacheKey);
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
      
      print('캐시 삭제: $cacheKey');
    } catch (e) {
      print('캐시 삭제 실패: $e');
    }
  }

  // 전체 캐시 삭제
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (key) => key.startsWith(_cachePrefix) || key.startsWith(_cacheTimestampPrefix)
      ).toList();
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      print('전체 캐시 삭제 완료 (${keys.length}개 항목)');
    } catch (e) {
      print('전체 캐시 삭제 실패: $e');
    }
  }

  // 캐시 통계 조회
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys = prefs.getKeys().where(
        (key) => key.startsWith(_cachePrefix)
      ).toList();
      
      final stats = <String, dynamic>{
        'total_cached_items': cacheKeys.length,
        'cache_items': <Map<String, dynamic>>[],
      };
      
      for (final key in cacheKeys) {
        final timestampKey = _generateTimestampKey(key);
        final timestamp = prefs.getInt(timestampKey);
        final isValid = await _isCacheValid(key);
        
        stats['cache_items'].add({
          'key': key,
          'timestamp': timestamp != null 
              ? DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()
              : null,
          'is_valid': isValid,
        });
      }
      
      return stats;
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

