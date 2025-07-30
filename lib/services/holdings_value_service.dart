import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 보유액 데이터 모델
class HoldingsValueData {
  final String date;
  final String marketType;
  final int totalHoldingsValue;
  final int calculatedStocks;
  final String dataSource;
  final bool isEstimated;
  final DateTime createdAt;
  final DateTime updatedAt;

  HoldingsValueData({
    required this.date,
    required this.marketType,
    required this.totalHoldingsValue,
    required this.calculatedStocks,
    this.dataSource = 'pykrx',
    this.isEstimated = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HoldingsValueData.fromJson(Map<String, dynamic> json) {
    return HoldingsValueData(
      date: json['date'] ?? '',
      marketType: json['market_type'] ?? '',
      totalHoldingsValue: _parseIntSafely(json['total_holdings_value']),
      calculatedStocks: json['calculated_stocks'] ?? 0,
      dataSource: json['data_source'] ?? 'pykrx',
      isEstimated: json['is_estimated'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'market_type': marketType,
      'total_holdings_value': totalHoldingsValue,
      'calculated_stocks': calculatedStocks,
      'data_source': dataSource,
      'is_estimated': isEstimated,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// pykrx API 응답에서 생성
  factory HoldingsValueData.fromPykrxApiResponse(Map<String, dynamic> json) {
    return HoldingsValueData(
      date: json['date'] ?? '',
      marketType: json['market_type'] ?? '',
      totalHoldingsValue: _parseIntSafely(json['total_holdings_value']),
      calculatedStocks: json['calculated_stocks'] ?? 0,
      dataSource: 'pykrx',
      isEstimated: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// API 연결 실패 정보
class ApiFailureInfo {
  final String reason;
  final DateTime failureTime;
  final int attemptCount;
  final Duration retryDelay;
  final Map<String, dynamic> diagnostics;

  ApiFailureInfo({
    required this.reason,
    required this.failureTime,
    required this.attemptCount,
    required this.retryDelay,
    this.diagnostics = const {},
  });
}

/// 외국인 실제 보유액 데이터 관리 서비스 (개선된 버전)
/// 우선순위: DB/캐시 즉시 출력 → 증분 데이터 백그라운드 업데이트 → API 실패 분석 및 재시도
class HoldingsValueService {
  static const String _cacheKeyPrefix = 'holdings_value_';
  static const String _lastUpdateKey = 'holdings_last_update';
  static const String _lastDataDateKey = 'holdings_last_data_date';
  static const Duration _cacheExpiry = Duration(hours: 6);
  static const int _dataRetentionDays = 90;
  static const int _maxRetryAttempts = 5;
  
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _pykrxApiUrl = 'http://127.0.0.1:8000'; // PyKRX API 서버
  
  // API 재시도 관리
  ApiFailureInfo? _lastFailure;
  Timer? _backgroundUpdateTimer;
  bool _isBackgroundUpdateRunning = false;

  /// 우선순위 1: DB/캐시에서 최신 데이터 즉시 출력
  Future<List<HoldingsValueData>> getImmediateData({
    int days = 60,
    List<String>? markets,
  }) async {
    print('🚀 [우선순위 1] DB/캐시에서 즉시 데이터 로드 시작');
    
    markets ??= ['KOSPI', 'KOSDAQ'];
    final toDate = DateTime.now();
    final fromDate = toDate.subtract(Duration(days: days));
    
    // 1-1. DB에서 먼저 조회
    try {
      final dbData = await _loadFromDatabase(
        fromDate: _formatDate(fromDate),
        toDate: _formatDate(toDate),
        markets: markets,
      );
      
      if (dbData.isNotEmpty) {
        print('✅ [우선순위 1] DB에서 ${dbData.length}개 데이터 즉시 반환');
        print('   첫 번째 DB 데이터: ${dbData.first.date} ${dbData.first.marketType} ${dbData.first.totalHoldingsValue}');
        print('   마지막 DB 데이터: ${dbData.last.date} ${dbData.last.marketType} ${dbData.last.totalHoldingsValue}');
        // 백그라운드 증분 업데이트 시작
        _startIncrementalUpdate(markets: markets);
        return dbData;
      }
    } catch (e) {
      print('⚠️ [우선순위 1] DB 조회 실패: $e');
    }
    
    // 1-2. 캐시에서 조회
    try {
      final cacheData = await _loadFromCache(
        fromDate: _formatDate(fromDate),
        toDate: _formatDate(toDate),
        markets: markets,
      );
      
      if (cacheData.isNotEmpty) {
        print('✅ [우선순위 1] 캐시에서 ${cacheData.length}개 데이터 즉시 반환');
        // 백그라운드 증분 업데이트 시작
        _startIncrementalUpdate(markets: markets);
        return cacheData;
      }
    } catch (e) {
      print('⚠️ [우선순위 1] 캐시 조회 실패: $e');
    }
    
    print('📭 [우선순위 1] DB/캐시에 데이터 없음 - 빈 리스트 반환');
    // 백그라운드에서 전체 데이터 로드 시작
    _startFullDataLoad(markets: markets);
    return [];
  }

  /// 우선순위 2: 증분 데이터 업데이트 (백그라운드)
  void _startIncrementalUpdate({List<String>? markets}) {
    if (_isBackgroundUpdateRunning) {
      print('🔄 [우선순위 2] 이미 백그라운드 업데이트 실행 중 - 건너뜀');
      return;
    }
    
    _isBackgroundUpdateRunning = true;
    print('🔄 [우선순위 2] 증분 백그라운드 업데이트 시작');
    
    // 2초 후 백그라운드에서 실행
    Timer(const Duration(seconds: 2), () async {
      try {
        await _performIncrementalUpdate(markets: markets ?? ['KOSPI', 'KOSDAQ']);
      } finally {
        _isBackgroundUpdateRunning = false;
      }
    });
  }
  
  /// 증분 업데이트 실행
  Future<void> _performIncrementalUpdate({required List<String> markets}) async {
    try {
      // 2-1. DB에서 최신 데이터 날짜 조회
      final latestDataDate = await _getLatestDataDate();
      final today = DateTime.now();
      final todayStr = _formatDate(today);
      
      print('📅 [우선순위 2] DB 최신 데이터: $latestDataDate, 오늘: $todayStr');
      
      if (latestDataDate != null && latestDataDate.compareTo(todayStr) >= 0) {
        print('✅ [우선순위 2] 데이터가 최신임 - 업데이트 불필요');
        return;
      }
      
      // 2-2. 최신 날짜 이후 데이터 API에서 조회
      final fromDate = latestDataDate != null ? 
          _getNextDate(latestDataDate) : _formatDate(today.subtract(const Duration(days: 30)));
      
      print('🔍 [우선순위 2] 증분 데이터 조회: $fromDate ~ $todayStr');
      
      final incrementalData = await _loadFromPykrxApiWithRetry(
        fromDate: fromDate,
        toDate: todayStr,
        markets: markets,
      );
      
      if (incrementalData.isNotEmpty) {
        // 2-3. 새 데이터를 DB와 캐시에 저장
        await _saveToDatabase(incrementalData);
        await _saveToCache(incrementalData);
        await _updateLastDataDate(todayStr);
        
        print('✅ [우선순위 2] 증분 업데이트 완료: ${incrementalData.length}개 데이터 저장');
      } else {
        print('📭 [우선순위 2] 새로운 데이터 없음');
      }
      
    } catch (e) {
      print('❌ [우선순위 2] 증분 업데이트 실패: $e');
      // 우선순위 3: API 실패 분석 및 재시도
      await _handleApiFailureAndRetry(e, markets: markets);
    }
  }

  /// 우선순위 3: API 실패 분석 및 보완된 재시도 (백그라운드)
  Future<void> _handleApiFailureAndRetry(dynamic error, {required List<String> markets}) async {
    print('🔍 [우선순위 3] API 실패 분석 시작: $error');
    
    // 3-1. 실패 원인 분석
    final failureInfo = _analyzeApiFailure(error);
    _lastFailure = failureInfo;
    
    print('📊 [우선순위 3] 실패 분석 결과:');
    print('   - 원인: ${failureInfo.reason}');
    print('   - 시도 횟수: ${failureInfo.attemptCount}');
    print('   - 재시도 지연: ${failureInfo.retryDelay}');
    print('   - 진단: ${failureInfo.diagnostics}');
    
    // 3-2. 최대 재시도 횟수 확인
    if (failureInfo.attemptCount >= _maxRetryAttempts) {
      print('❌ [우선순위 3] 최대 재시도 횟수 초과 (${_maxRetryAttempts}회)');
      return;
    }
    
    // 3-3. 백그라운드에서 보완된 재시도
    _backgroundUpdateTimer?.cancel();
    _backgroundUpdateTimer = Timer(failureInfo.retryDelay, () async {
      print('🔄 [우선순위 3] 보완된 재시도 시작 (시도 ${failureInfo.attemptCount + 1}/${_maxRetryAttempts})');
      
      try {
        // 실패 원인에 따른 보완 조치 적용
        await _applyFailureCompensation(failureInfo);
        
        // 재시도 실행
        await _performIncrementalUpdate(markets: markets);
        
        // 성공 시 실패 정보 초기화
        _lastFailure = null;
        print('✅ [우선순위 3] 보완된 재시도 성공!');
        
      } catch (retryError) {
        print('❌ [우선순위 3] 재시도 실패: $retryError');
        // 재귀적으로 다시 재시도 처리
        await _handleApiFailureAndRetry(retryError, markets: markets);
      }
    });
  }
  
  /// API 실패 원인 분석
  ApiFailureInfo _analyzeApiFailure(dynamic error) {
    final errorString = error.toString().toLowerCase();
    final currentAttempt = (_lastFailure?.attemptCount ?? 0) + 1;
    Map<String, dynamic> diagnostics = {};
    String reason = '알 수 없는 오류';
    Duration retryDelay = Duration(seconds: 30);
    
    if (errorString.contains('timeout') || errorString.contains('시간 초과')) {
      reason = 'API 응답 시간 초과';
      retryDelay = Duration(seconds: 60 * currentAttempt); // 점진적 증가
      diagnostics = {'timeout_duration': '30초', 'suggested_timeout': '60초'};
      
    } else if (errorString.contains('connection') || errorString.contains('연결')) {
      reason = '서버 연결 실패';
      retryDelay = Duration(seconds: 30 * currentAttempt);
      diagnostics = {'server_url': _pykrxApiUrl, 'connection_type': 'HTTP'};
      
    } else if (errorString.contains('404') || errorString.contains('not found')) {
      reason = 'API 엔드포인트 없음';
      retryDelay = Duration(minutes: 5); // 긴 지연
      diagnostics = {'missing_endpoint': '/foreign_holdings_value_range'};
      
    } else if (errorString.contains('500') || errorString.contains('internal server')) {
      reason = '서버 내부 오류';
      retryDelay = Duration(minutes: 2 * currentAttempt);
      diagnostics = {'server_error': true, 'suggest': '서버 재시작 필요'};
      
    } else if (errorString.contains('403') || errorString.contains('forbidden')) {
      reason = '접근 권한 없음';
      retryDelay = Duration(minutes: 10); // 매우 긴 지연
      diagnostics = {'auth_required': true};
    }
    
    return ApiFailureInfo(
      reason: reason,
      failureTime: DateTime.now(),
      attemptCount: currentAttempt,
      retryDelay: retryDelay,
      diagnostics: diagnostics,
    );
  }
  
  /// 실패 원인에 따른 보완 조치 적용
  Future<void> _applyFailureCompensation(ApiFailureInfo failureInfo) async {
    print('🔧 [우선순위 3] 보완 조치 적용: ${failureInfo.reason}');
    
    switch (failureInfo.reason) {
      case 'API 응답 시간 초과':
        // 타임아웃 시간 연장은 _loadFromPykrxApiWithRetry에서 처리
        print('   - 타임아웃 시간을 60초로 연장');
        break;
        
      case '서버 연결 실패':
        // 서버 상태 확인
        print('   - 서버 연결 상태 사전 확인');
        await _checkServerHealth();
        break;
        
      case 'API 엔드포인트 없음':
        print('   - 대체 엔드포인트 사용 시도');
        // 필요시 대체 API 엔드포인트 로직 추가
        break;
        
      case '서버 내부 오류':
        print('   - 서버 복구 대기 중...');
        break;
        
      default:
        print('   - 기본 보완 조치: 재시도 지연 시간 적용');
    }
  }

  /// 2. DB에서 데이터 조회
  Future<List<HoldingsValueData>> _loadFromDatabase({
    String? fromDate,
    String? toDate,
    List<String>? markets,
  }) async {
    try {
      var query = _supabase
          .from('foreign_holdings_value')
          .select('*');

      // 날짜 범위 필터
      if (fromDate != null) {
        query = query.gte('date', fromDate);
      }
      if (toDate != null) {
        query = query.lte('date', toDate);
      }

      // 시장 필터
      if (markets != null && markets.isNotEmpty) {
        query = query.inFilter('market_type', markets);
      }

      final response = await query
          .order('date', ascending: false)
          .order('market_type', ascending: true);

      return response
          .map<HoldingsValueData>((json) => HoldingsValueData.fromJson(json))
          .toList();

    } catch (e) {
      print('❌ DB에서 보유액 데이터 조회 실패: $e');
      return [];
    }
  }

  /// 3. pykrx API에서 데이터 조회
  Future<List<HoldingsValueData>> _loadFromPykrxApi({
    String? fromDate,
    String? toDate,
    List<String>? markets,
  }) async {
    try {
      final uri = Uri.parse('$_pykrxApiUrl/foreign_holdings_value_range')
          .replace(queryParameters: {
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        'markets': markets?.join(',') ?? 'KOSPI,KOSDAQ',
      });

      print('🔍 pykrx API 호출: $uri');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('pykrx API 호출 시간 초과 (30초)');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> dataList = data['data'] ?? [];

        return dataList
            .map<HoldingsValueData>((json) => 
                HoldingsValueData.fromPykrxApiResponse(json))
            .toList();

      } else {
        throw Exception('pykrx API 호출 실패: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ pykrx API에서 보유액 데이터 조회 실패: $e');
      return [];
    }
  }

  /// 4. DB에 데이터 저장 (UPSERT)
  Future<void> _saveToDatabase(List<HoldingsValueData> dataList) async {
    if (dataList.isEmpty) return;

    try {
      for (final data in dataList) {
        await _supabase
            .from('foreign_holdings_value')
            .upsert({
              'date': data.date,
              'market_type': data.marketType,
              'total_holdings_value': data.totalHoldingsValue,
              'calculated_stocks': data.calculatedStocks,
              'data_source': data.dataSource,
              'is_estimated': data.isEstimated,
            }, onConflict: 'date,market_type');
      }

      print('✅ DB에 ${dataList.length}개 보유액 데이터 저장 완료');

    } catch (e) {
      print('❌ DB 저장 실패: $e');
      throw e;
    }
  }

  /// 5. 캐시에 저장
  Future<void> _saveToCache(List<HoldingsValueData> dataList) async {
    if (dataList.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = <String, dynamic>{};

      for (final data in dataList) {
        final key = '${data.date}_${data.marketType}';
        cacheData[key] = data.toJson();
      }

      await prefs.setString(
        '$_cacheKeyPrefix${DateTime.now().millisecondsSinceEpoch}',
        json.encode(cacheData),
      );

      await prefs.setString(
        _lastUpdateKey,
        DateTime.now().toIso8601String(),
      );

      print('✅ 캐시에 ${dataList.length}개 보유액 데이터 저장 완료');

    } catch (e) {
      print('❌ 캐시 저장 실패: $e');
    }
  }

  /// 6. 캐시에서 데이터 조회
  Future<List<HoldingsValueData>> _loadFromCache({
    String? fromDate,
    String? toDate,
    List<String>? markets,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((key) => key.startsWith(_cacheKeyPrefix))
          .toList();

      if (keys.isEmpty) return [];

      // 최신 캐시 키 찾기
      keys.sort((a, b) => b.compareTo(a));
      final latestKey = keys.first;

      final cacheDataStr = prefs.getString(latestKey);
      if (cacheDataStr == null) return [];

      final cacheData = json.decode(cacheDataStr) as Map<String, dynamic>;
      final result = <HoldingsValueData>[];

      for (final entry in cacheData.entries) {
        final data = HoldingsValueData.fromJson(entry.value);
        
        // 필터 적용
        if (fromDate != null && data.date.compareTo(fromDate) < 0) continue;
        if (toDate != null && data.date.compareTo(toDate) > 0) continue;
        if (markets != null && markets.isNotEmpty && !markets.contains(data.marketType)) continue;

        result.add(data);
      }

      print('💾 캐시에서 ${result.length}개 보유액 데이터 로드됨');
      return result;

    } catch (e) {
      print('❌ 캐시에서 데이터 조회 실패: $e');
      return [];
    }
  }

  /// 7. 백그라운드 데이터 업데이트
  Future<void> _updateDataInBackground({
    String? fromDate,
    String? toDate,
    List<String>? markets,
  }) async {
    // 백그라운드에서 실행 (Fire and forget)
    Timer(const Duration(seconds: 2), () async {
      try {
        print('🔄 백그라운드 보유액 데이터 업데이트 시작');
        
        final apiData = await _loadFromPykrxApi(
          fromDate: fromDate,
          toDate: toDate,
          markets: markets,
        );

        if (apiData.isNotEmpty) {
          await _saveToDatabase(apiData);
          await _saveToCache(apiData);
          print('✅ 백그라운드 보유액 데이터 업데이트 완료: ${apiData.length}개');
        }

      } catch (e) {
        print('⚠️ 백그라운드 보유액 데이터 업데이트 실패: $e');
      }
    });
  }

  /// 8. 최근 30일 데이터 가져오기 (주요 메서드) - 개선된 버전
  Future<List<HoldingsValueData>> getRecentHoldingsData({
    int days = 30,
    List<String>? markets,
  }) async {
    // 새로운 우선순위 시스템 사용
    return await getImmediateData(
      days: days,
      markets: markets ?? ['KOSPI', 'KOSDAQ'],
    );
  }

  /// 9. 특정 날짜의 보유액 데이터 가져오기
  Future<Map<String, int>> getHoldingsValueByDate(String date) async {
    final data = await getImmediateData(
      days: 1, // 특정 날짜만
      markets: ['KOSPI', 'KOSDAQ'],
    );
    
    // 특정 날짜 필터링
    final filteredData = data.where((item) => item.date == date).toList();

    final result = <String, int>{};
    for (final item in filteredData) {
      result[item.marketType] = item.totalHoldingsValue;
    }

    return result;
  }

  /// 10. 캐시 정리
  Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys()
          .where((key) => key.startsWith(_cacheKeyPrefix))
          .toList();

      final cutoffTime = DateTime.now().subtract(_cacheExpiry);
      
      for (final key in keys) {
        final timestampStr = key.replaceFirst(_cacheKeyPrefix, '');
        final timestamp = int.tryParse(timestampStr);
        
        if (timestamp != null) {
          final keyTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          if (keyTime.isBefore(cutoffTime)) {
            await prefs.remove(key);
          }
        }
      }

      print('✅ 만료된 보유액 캐시 정리 완료');

    } catch (e) {
      print('❌ 캐시 정리 실패: $e');
    }
  }

  /// 11. 데이터 상태 확인
  Future<Map<String, dynamic>> getDataStatus() async {
    try {
      final response = await _supabase
          .from('holdings_data_status')
          .select('*')
          .single();

      return response;

    } catch (e) {
      print('❌ 데이터 상태 확인 실패: $e');
      return {};
    }
  }

  /// 헬퍼 메서드: 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// 헬퍼 메서드들 (개선된 시스템용)
  Future<String?> _getLatestDataDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastDataDateKey);
    } catch (e) {
      print('❌ 최신 데이터 날짜 조회 실패: $e');
      return null;
    }
  }
  
  Future<void> _updateLastDataDate(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDataDateKey, dateStr);
    } catch (e) {
      print('❌ 최신 데이터 날짜 업데이트 실패: $e');
    }
  }
  
  String _getNextDate(String dateStr) {
    try {
      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      final date = DateTime(year, month, day);
      final nextDate = date.add(const Duration(days: 1));
      return _formatDate(nextDate);
    } catch (e) {
      return _formatDate(DateTime.now());
    }
  }
  
  void _startFullDataLoad({required List<String> markets}) {
    print('🔄 [백그라운드] 전체 데이터 로드 시작');
    Timer(const Duration(seconds: 5), () async {
      try {
        final today = DateTime.now();
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        
        final fullData = await _loadFromPykrxApiWithRetry(
          fromDate: _formatDate(thirtyDaysAgo),
          toDate: _formatDate(today),
          markets: markets,
        );
        
        if (fullData.isNotEmpty) {
          await _saveToDatabase(fullData);
          await _saveToCache(fullData);
          await _updateLastDataDate(_formatDate(today));
          print('✅ [백그라운드] 전체 데이터 로드 완료: ${fullData.length}개');
        }
      } catch (e) {
        print('❌ [백그라운드] 전체 데이터 로드 실패: $e');
      }
    });
  }
  
  Future<List<HoldingsValueData>> _loadFromPykrxApiWithRetry({
    String? fromDate,
    String? toDate,
    List<String>? markets,
  }) async {
    // 실패 분석을 기반으로 타임아웃 조정
    final timeoutDuration = _lastFailure?.reason == 'API 응답 시간 초과' 
        ? const Duration(seconds: 60) 
        : const Duration(seconds: 30);
    
    try {
      final uri = Uri.parse('$_pykrxApiUrl/foreign_holdings_value_range')
          .replace(queryParameters: {
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        'markets': markets?.join(',') ?? 'KOSPI,KOSDAQ',
      });

      print('🔍 [API] 보완된 호출: $uri (timeout: ${timeoutDuration.inSeconds}초)');

      final response = await http.get(uri).timeout(
        timeoutDuration,
        onTimeout: () {
          throw Exception('pykrx API 호출 시간 초과 (${timeoutDuration.inSeconds}초)');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> dataList = data['data'] ?? [];

        return dataList
            .map<HoldingsValueData>((json) => 
                HoldingsValueData.fromPykrxApiResponse(json))
            .toList();

      } else {
        throw Exception('pykrx API 호출 실패: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ [API] 보완된 호출 실패: $e');
      throw e;
    }
  }
  
  Future<void> _checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_pykrxApiUrl/health'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ [서버 상태] 정상');
      } else {
        print('⚠️ [서버 상태] 비정상: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [서버 상태] 확인 실패: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    _backgroundUpdateTimer?.cancel();
    // 필요시 타이머나 기타 리소스 정리
  }
}