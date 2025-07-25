import 'dart:async';
import 'package:flutter/foundation.dart';
import 'data_sync_service.dart';

/// 자동 데이터 동기화 스케줄러
/// 앱 실행 중 정기적으로 최신 데이터를 확인하고 동기화
class AutoSyncScheduler {
  final DataSyncService _syncService = DataSyncService();
  Timer? _periodicTimer;
  Timer? _initialDelayTimer;
  
  // 싱글톤 패턴
  static final AutoSyncScheduler _instance = AutoSyncScheduler._internal();
  factory AutoSyncScheduler() => _instance;
  AutoSyncScheduler._internal();

  bool _isRunning = false;
  DateTime? _lastSyncTime;
  VoidCallback? _onSyncComplete;

  bool get isRunning => _isRunning;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 자동 동기화 시작
  /// [intervalMinutes] 동기화 간격 (분 단위, 기본값: 30분)
  /// [initialDelayMinutes] 앱 시작 후 첫 동기화까지 대기 시간 (분 단위, 기본값: 2분)
  /// [onSyncComplete] 동기화 완료 시 호출할 콜백
  void startAutoSync({
    int intervalMinutes = 30,
    int initialDelayMinutes = 2,
    VoidCallback? onSyncComplete,
  }) {
    if (_isRunning) {
      if (kDebugMode) {
        debugPrint('AutoSync: 이미 실행 중입니다.');
      }
      return;
    }

    _isRunning = true;
    _onSyncComplete = onSyncComplete;

    if (kDebugMode) {
      debugPrint('AutoSync: 자동 동기화 시작 (간격: $intervalMinutes분, 초기 지연: $initialDelayMinutes분)');
    }

    // 초기 지연 후 첫 번째 동기화 실행
    _initialDelayTimer = Timer(Duration(minutes: initialDelayMinutes), () {
      _performSync();
    });

    // 정기적인 동기화 스케줄링
    _periodicTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      _performSync();
    });
  }

  /// 자동 동기화 중지
  void stopAutoSync() {
    if (!_isRunning) return;

    _initialDelayTimer?.cancel();
    _periodicTimer?.cancel();
    _initialDelayTimer = null;
    _periodicTimer = null;
    _isRunning = false;

    if (kDebugMode) {
      debugPrint('AutoSync: 자동 동기화 중지됨');
    }
  }

  /// 즉시 수동 동기화 실행
  Future<DataSyncResult> syncNow() async {
    if (kDebugMode) {
      debugPrint('AutoSync: 수동 동기화 요청');
    }
    return await _performSync();
  }

  /// 다음 동기화까지 남은 시간 (분 단위)
  int? getMinutesUntilNextSync() {
    if (!_isRunning || _periodicTimer == null) return null;
    
    // Timer의 남은 시간은 직접 접근할 수 없으므로, 마지막 동기화 시간 기준으로 계산
    if (_lastSyncTime == null) return null;
    
    const intervalMinutes = 30; // 기본 간격
    final nextSyncTime = _lastSyncTime!.add(const Duration(minutes: intervalMinutes));
    final remainingMinutes = nextSyncTime.difference(DateTime.now()).inMinutes;
    
    return remainingMinutes > 0 ? remainingMinutes : 0;
  }

  /// 동기화 수행
  Future<DataSyncResult> _performSync() async {
    if (kDebugMode) {
      debugPrint('AutoSync: 자동 동기화 시작...');
    }

    try {
      final syncResult = await _syncService.syncLatestData();
      _lastSyncTime = DateTime.now();

      if (kDebugMode) {
        debugPrint('AutoSync: 동기화 완료 - ${syncResult.message}');
      }

      // 콜백 실행
      _onSyncComplete?.call();

      return syncResult;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AutoSync: 동기화 실패 - $e');
      }
      
      return DataSyncResult(
        success: false,
        message: '자동 동기화 실패: $e',
        newDataCount: 0,
      );
    }
  }

  /// 마지막 동기화로부터 경과 시간 (분 단위)
  int? getMinutesSinceLastSync() {
    if (_lastSyncTime == null) return null;
    return DateTime.now().difference(_lastSyncTime!).inMinutes;
  }

  /// 동기화 상태 정보
  Map<String, dynamic> getStatus() {
    return {
      'isRunning': _isRunning,
      'lastSyncTime': _lastSyncTime?.toString(),
      'minutesSinceLastSync': getMinutesSinceLastSync(),
      'minutesUntilNextSync': getMinutesUntilNextSync(),
    };
  }

  /// 앱 종료 시 리소스 정리
  void dispose() {
    stopAutoSync();
  }
}

/// 거래일 기준 스마트 동기화 스케줄러
/// 주말과 공휴일에는 동기화하지 않고, 장 마감 후에만 동기화
class SmartSyncScheduler extends AutoSyncScheduler {
  SmartSyncScheduler() : super._internal();
  /// 거래일인지 확인 (간단한 주말 체크, 실제로는 공휴일 API 연동 필요)
  bool _isTradingDay(DateTime date) {
    final weekday = date.weekday;
    return weekday >= 1 && weekday <= 5; // 월~금요일만
  }

  /// 거래 시간인지 확인 (9:00~15:30)
  bool _isTradingHours(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final totalMinutes = hour * 60 + minute;
    
    const marketOpen = 9 * 60; // 9:00
    const marketClose = 15 * 60 + 30; // 15:30
    
    return totalMinutes >= marketOpen && totalMinutes <= marketClose;
  }

  /// 장 마감 후인지 확인 (15:30 이후)
  bool _isAfterMarketClose(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final totalMinutes = hour * 60 + minute;
    
    const marketClose = 15 * 60 + 30; // 15:30
    return totalMinutes > marketClose;
  }

  @override
  Future<DataSyncResult> _performSync() async {
    final now = DateTime.now();
    
    // 거래일이 아니면 동기화 건너뛰기
    if (!_isTradingDay(now)) {
      if (kDebugMode) {
        debugPrint('SmartSync: 비거래일로 동기화 건너뛰기');
      }
      return DataSyncResult(
        success: true,
        message: '비거래일 - 동기화 건너뛰기',
        newDataCount: 0,
      );
    }

    // 거래 시간 중에는 동기화 건너뛰기 (서버 부하 방지)
    if (_isTradingHours(now)) {
      if (kDebugMode) {
        debugPrint('SmartSync: 거래 시간 중 동기화 건너뛰기');
      }
      return DataSyncResult(
        success: true,
        message: '거래 시간 중 - 동기화 건너뛰기',
        newDataCount: 0,
      );
    }

    // 장 마감 후에만 실제 동기화 수행
    if (_isAfterMarketClose(now)) {
      if (kDebugMode) {
        debugPrint('SmartSync: 장 마감 후 동기화 수행');
      }
      return await super._performSync();
    }

    // 장 시작 전에는 전날 데이터 확인
    if (kDebugMode) {
      debugPrint('SmartSync: 장 시작 전 전날 데이터 확인');
    }
    return await super._performSync();
  }
}