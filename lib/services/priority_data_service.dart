import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/foreign_investor_data.dart';
import 'pykrx_data_service.dart';
import 'foreign_investor_service.dart';
import 'cache_service.dart';
import 'data_sync_service.dart';

class PriorityDataService {
  final PykrxDataService _pykrxService = PykrxDataService();
  final ForeignInvestorService _dbService = ForeignInvestorService();
  final CacheService _cacheService = CacheService();
  final DataSyncService _syncService = DataSyncService();
  
  // 백그라운드 재시도 관련
  Timer? _backgroundRetryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  static const Duration _retryInterval = Duration(minutes: 2);
  
  // 백그라운드 DB 동기화 관련
  bool _isBackgroundSyncRunning = false;
  final StreamController<DataSyncStatus> _syncStatusController = 
      StreamController<DataSyncStatus>.broadcast();
  
  Stream<DataSyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  // 싱글톤 패턴
  static final PriorityDataService _instance = PriorityDataService._internal();
  factory PriorityDataService() => _instance;
  PriorityDataService._internal();

  /// 메인 데이터 로드 로직 - 우선순위에 따른 처리
  Future<PriorityDataResult> loadLatestDataWithPriority({
    String? marketType,
    int limit = 50,
  }) async {
    print('🚀 우선순위 데이터 로드 시작...');
    
    try {
      // 1단계: API 호출 시도
      print('1️⃣ API 호출 시도 중...');
      final apiResult = await _tryApiCall(marketType: marketType, limit: limit);
      
      if (apiResult.success) {
        print('✅ API 호출 성공!');
        return await _handleApiSuccess(apiResult, marketType, limit);
      } else {
        print('❌ API 호출 실패, fallback 모드로 전환...');
        return await _handleApiFailure(marketType, limit);
      }
      
    } catch (e) {
      print('❌ 우선순위 데이터 로드 전체 실패: $e');
      return await _handleApiFailure(marketType, limit);
    }
  }

  /// API 호출 시도
  Future<ApiCallResult> _tryApiCall({
    String? marketType,
    int limit = 50,
  }) async {
    try {
      // 서버 상태 먼저 확인
      final isServerHealthy = await _pykrxService.checkServerWithRetry(maxRetries: 2);
      if (!isServerHealthy) {
        return ApiCallResult(success: false, error: 'pykrx 서버 연결 실패');
      }
      
      // 최신 데이터 조회
      final data = await _pykrxService.getLatestForeignInvestorData(
        markets: marketType != null && marketType != 'ALL' 
            ? [marketType] 
            : ['KOSPI', 'KOSDAQ'],
      );
      
      if (data.isNotEmpty) {
        return ApiCallResult(success: true, data: data);
      } else {
        return ApiCallResult(success: false, error: '응답 데이터 없음');
      }
      
    } catch (e) {
      return ApiCallResult(success: false, error: e.toString());
    }
  }

  /// API 성공 시 처리: 캐시 저장 → 최신 데이터 표시 → 백그라운드 DB 동기화
  Future<PriorityDataResult> _handleApiSuccess(
    ApiCallResult apiResult, 
    String? marketType, 
    int limit,
  ) async {
    final data = apiResult.data!;
    
    try {
      // 1) 캐시에 즉시 저장
      print('💾 캐시에 데이터 저장 중...');
      await _cacheService.setCachedData('latest_priority', data, market: marketType);
      
      // 2) 최신 날짜 정보 확인
      final latestDate = data.isNotEmpty ? data.first.date : null;
      final displayMessage = latestDate != null 
          ? '현재 ${_formatDateForDisplay(latestDate)}가 최신 정보입니다'
          : '최신 정보를 확인할 수 없습니다';
      
      print('📅 $displayMessage');
      
      // 3) 백그라운드에서 DB 동기화 시작
      _startBackgroundDbSync(data);
      
      // 4) 재시도 카운터 리셋
      _resetRetryCounter();
      
      return PriorityDataResult(
        success: true,
        data: data.take(limit).toList(),
        source: DataSource.api,
        latestDate: latestDate,
        message: displayMessage,
      );
      
    } catch (e) {
      print('❌ API 성공 처리 중 오류: $e');
      // API는 성공했지만 캐시 저장 실패 시에도 데이터는 반환
      return PriorityDataResult(
        success: true,
        data: data.take(limit).toList(),
        source: DataSource.api,
        latestDate: data.isNotEmpty ? data.first.date : null,
        message: 'API 데이터 로드 완료 (캐시 저장 실패)',
      );
    }
  }

  /// API 실패 시 처리: DB 최신 데이터 → 캐시 저장 → 백그라운드 재시도
  Future<PriorityDataResult> _handleApiFailure(
    String? marketType, 
    int limit,
  ) async {
    try {
      // 1) DB에서 최신 데이터 조회
      print('🗄️ DB에서 최신 데이터 조회 중...');
      final dbData = await _dbService.getLatestForeignInvestorData(
        marketType: marketType,
        limit: limit,
      );
      
      if (dbData.isNotEmpty) {
        // 2) DB 데이터를 캐시에 저장
        print('💾 DB 데이터를 캐시에 저장 중...');
        await _cacheService.setCachedData('latest_fallback', dbData, market: marketType);
        
        // 3) 백그라운드 API 재시도 시작
        _startBackgroundApiRetry(marketType, limit);
        
        final latestDate = dbData.first.date;
        final displayMessage = '현재 ${_formatDateForDisplay(latestDate)}가 최신 정보입니다 (DB)';
        
        return PriorityDataResult(
          success: true,
          data: dbData,
          source: DataSource.database,
          latestDate: latestDate,
          message: displayMessage,
        );
        
      } else {
        // 4) DB에도 데이터가 없으면 캐시 확인
        print('💾 캐시에서 데이터 조회 중...');
        final cachedData = await _cacheService.getCachedData('latest_priority', market: marketType) ??
                          await _cacheService.getCachedData('latest_fallback', market: marketType);
        
        if (cachedData != null && cachedData.isNotEmpty) {
          _startBackgroundApiRetry(marketType, limit);
          
          return PriorityDataResult(
            success: true,
            data: cachedData.take(limit).toList(),
            source: DataSource.cache,
            latestDate: cachedData.first.date,
            message: '캐시된 데이터를 사용 중입니다',
          );
        } else {
          // 5) 모든 소스에서 데이터를 찾을 수 없음
          return PriorityDataResult(
            success: false,
            data: [],
            source: DataSource.none,
            latestDate: null,
            message: '데이터를 찾을 수 없습니다',
          );
        }
      }
      
    } catch (e) {
      print('❌ API 실패 처리 중 오류: $e');
      return PriorityDataResult(
        success: false,
        data: [],
        source: DataSource.none,
        latestDate: null,
        message: '데이터 로드 실패: $e',
      );
    }
  }

  /// 백그라운드 DB 동기화 시작
  void _startBackgroundDbSync(List<ForeignInvestorData> data) {
    if (_isBackgroundSyncRunning) {
      print('⚠️ 이미 백그라운드 동기화가 실행 중입니다.');
      return;
    }
    
    print('🔄 백그라운드 DB 동기화 시작...');
    _isBackgroundSyncRunning = true;
    _syncStatusController.add(DataSyncStatus.syncing);
    
    // 백그라운드에서 실행
    Future.microtask(() async {
      try {
        // 전체 동기화 실행
        final syncResult = await _syncService.syncLatestData();
        
        if (syncResult.success) {
          print('✅ 백그라운드 DB 동기화 완료: ${syncResult.newDataCount}개 신규 데이터');
          _syncStatusController.add(DataSyncStatus.completed);
        } else {
          print('❌ 백그라운드 DB 동기화 실패: ${syncResult.message}');
          _syncStatusController.add(DataSyncStatus.failed);
        }
        
      } catch (e) {
        print('❌ 백그라운드 DB 동기화 중 오류: $e');
        _syncStatusController.add(DataSyncStatus.failed);
      } finally {
        _isBackgroundSyncRunning = false;
      }
    });
  }

  /// 백그라운드 API 재시도 시작
  void _startBackgroundApiRetry(String? marketType, int limit) {
    if (_backgroundRetryTimer != null && _backgroundRetryTimer!.isActive) {
      print('⚠️ 이미 백그라운드 재시도가 실행 중입니다.');
      return;
    }
    
    if (_retryCount >= _maxRetries) {
      print('⚠️ 최대 재시도 횟수에 도달했습니다.');
      return;
    }
    
    print('🔄 백그라운드 API 재시도 시작... (${_retryCount + 1}/$_maxRetries)');
    
    _backgroundRetryTimer = Timer(_retryInterval, () async {
      _retryCount++;
      
      try {
        final apiResult = await _tryApiCall(marketType: marketType, limit: limit);
        
        if (apiResult.success) {
          print('✅ 백그라운드 API 재시도 성공!');
          await _handleApiSuccess(apiResult, marketType, limit);
          _resetRetryCounter();
        } else {
          print('❌ 백그라운드 API 재시도 실패: ${apiResult.error}');
          
          if (_retryCount < _maxRetries) {
            _startBackgroundApiRetry(marketType, limit); // 다음 재시도 스케줄링
          } else {
            print('❌ 모든 재시도 실패');
          }
        }
        
      } catch (e) {
        print('❌ 백그라운드 재시도 중 오류: $e');
        
        if (_retryCount < _maxRetries) {
          _startBackgroundApiRetry(marketType, limit);
        }
      }
    });
  }

  /// 재시도 카운터 리셋
  void _resetRetryCounter() {
    _retryCount = 0;
    _backgroundRetryTimer?.cancel();
    _backgroundRetryTimer = null;
  }

  /// 날짜 포맷팅
  String _formatDateForDisplay(String date) {
    try {
      if (date.length == 8) {
        return '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  /// 서비스 종료
  void dispose() {
    _backgroundRetryTimer?.cancel();
    _syncStatusController.close();
  }
}

/// API 호출 결과
class ApiCallResult {
  final bool success;
  final List<ForeignInvestorData>? data;
  final String? error;

  ApiCallResult({
    required this.success,
    this.data,
    this.error,
  });
}

/// 우선순위 데이터 결과
class PriorityDataResult {
  final bool success;
  final List<ForeignInvestorData> data;
  final DataSource source;
  final String? latestDate;
  final String message;

  PriorityDataResult({
    required this.success,
    required this.data,
    required this.source,
    required this.latestDate,
    required this.message,
  });
}

/// 데이터 소스 타입
enum DataSource {
  api,        // pykrx API에서 직접 조회
  database,   // Supabase DB에서 조회
  cache,      // 로컬 캐시에서 조회
  none,       // 데이터 없음
}

/// 동기화 상태
enum DataSyncStatus {
  idle,       // 대기 중
  syncing,    // 동기화 중
  completed,  // 완료
  failed,     // 실패
}