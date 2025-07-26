import 'package:flutter/foundation.dart';
import '../providers/foreign_investor_provider.dart';
import '../services/enhanced_foreign_investor_service.dart';

/// 향상된 외국인 투자자 Provider (pykrx 서버 자동 관리 포함)
class EnhancedForeignInvestorProvider extends ForeignInvestorProvider {
  late final EnhancedForeignInvestorService _enhancedService;
  
  // pykrx 서버 상태
  bool _isPykrxServerHealthy = false;
  bool _isPykrxServerRecovering = false;
  String _pykrxServerMessage = 'pykrx 서버 상태 확인 중...';
  String _pykrxRecoveryMessage = '';
  
  // 자동 복구 설정
  bool _autoRecoveryEnabled = true;
  int _recoveryAttempts = 0;
  static const int _maxRecoveryAttempts = 3;
  
  @override
  void initState() {
    super.initState();
    _setupEnhancedService();
  }
  
  /// 향상된 서비스 설정
  void _setupEnhancedService() {
    _enhancedService = EnhancedForeignInvestorService();
    
    // 서버 상태 변경 콜백 설정
    _enhancedService.onStatusUpdate = (message, isError) {
      _pykrxServerMessage = message;
      _isPykrxServerHealthy = !isError;
      
      if (isError && _autoRecoveryEnabled && _recoveryAttempts < _maxRecoveryAttempts) {
        _recoveryAttempts++;
        // 자동 복구는 서비스에서 처리됨
      }
      
      notifyListeners();
    };
    
    // 복구 진행 상황 콜백 설정
    _enhancedService.onRecoveryProgress = (message) {
      _pykrxRecoveryMessage = message;
      _isPykrxServerRecovering = message.isNotEmpty && !message.contains('완료') && !message.contains('실패');
      notifyListeners();
    };
    
    // 서비스 시작 (헬스 모니터링 포함)
    _enhancedService.startService();
  }
  
  // Getters
  bool get isPykrxServerHealthy => _isPykrxServerHealthy;
  bool get isPykrxServerRecovering => _isPykrxServerRecovering;
  String get pykrxServerMessage => _pykrxServerMessage;
  String get pykrxRecoveryMessage => _pykrxRecoveryMessage;
  bool get autoRecoveryEnabled => _autoRecoveryEnabled;
  int get recoveryAttempts => _recoveryAttempts;
  Map<String, dynamic> get pykrxServerStatus => _enhancedService.getServerStatus();
  
  /// 자동 복구 활성화/비활성화
  void setAutoRecoveryEnabled(bool enabled) {
    _autoRecoveryEnabled = enabled;
    notifyListeners();
  }
  
  /// 수동 서버 복구 시도
  Future<bool> manualServerRecovery() async {
    _isPykrxServerRecovering = true;
    _pykrxRecoveryMessage = '수동 복구를 시작합니다...';
    notifyListeners();
    
    try {
      final success = await _enhancedService.manualServerRecovery();
      
      if (success) {
        _recoveryAttempts = 0; // 성공 시 복구 시도 횟수 리셋
        _pykrxRecoveryMessage = '서버 복구가 완료되었습니다.';
      } else {
        _pykrxRecoveryMessage = '서버 복구에 실패했습니다.';
      }
      
      _isPykrxServerRecovering = false;
      notifyListeners();
      
      return success;
    } catch (e) {
      _isPykrxServerRecovering = false;
      _pykrxRecoveryMessage = '복구 중 오류 발생: $e';
      notifyListeners();
      return false;
    }
  }
  
  /// 서버 상태 수동 확인
  Future<void> checkServerHealth() async {
    _pykrxServerMessage = '서버 상태를 확인하고 있습니다...';
    notifyListeners();
    
    try {
      final isHealthy = await _enhancedService.checkServerHealth();
      _isPykrxServerHealthy = isHealthy;
      
      if (isHealthy) {
        _pykrxServerMessage = 'pykrx 서버가 정상적으로 실행 중입니다.';
        _recoveryAttempts = 0;
      } else {
        _pykrxServerMessage = 'pykrx 서버에 연결할 수 없습니다.';
      }
    } catch (e) {
      _isPykrxServerHealthy = false;
      _pykrxServerMessage = '서버 상태 확인 실패: $e';
    }
    
    notifyListeners();
  }
  
  /// 향상된 데이터 로드 (자동 복구 포함)
  @override
  Future<void> loadLatestData() async {
    setLoading(true);
    
    try {
      // 향상된 서비스로 데이터 로드 시도
      final data = await _enhancedService.getLatestForeignInvestorDataWithRetry(
        marketType: selectedMarket == 'ALL' ? null : selectedMarket,
        limit: 50,
      );
      
      if (data.isNotEmpty) {
        // 성공적으로 데이터를 받았으면 기존 로직 사용
        await super.loadLatestData();
      } else {
        // 데이터가 없으면 기존 서비스 폴백
        await super.loadLatestData();
      }
    } catch (e) {
      // 오류 시 기존 서비스 폴백
      print('⚠️ 향상된 서비스 실패, 기존 서비스로 폴백: $e');
      await super.loadLatestData();
    } finally {
      setLoading(false);
    }
  }
  
  /// 향상된 일별 요약 데이터 로드 (자동 복구 포함)
  @override
  Future<void> loadDailySummary() async {
    try {
      final dateRange = getCurrentDateRange();
      final startDate = dateRange['fromDateFormatted'] ?? '';
      final endDate = dateRange['toDateFormatted'] ?? '';
      
      if (startDate.isEmpty || endDate.isEmpty) {
        await super.loadDailySummary();
        return;
      }
      
      // 향상된 서비스로 데이터 로드 시도
      final data = await _enhancedService.getDailyForeignSummaryWithRetry(
        startDate: startDate,
        endDate: endDate,
        marketType: selectedMarket,
        limit: 100,
      );
      
      if (data.isNotEmpty) {
        // 성공적으로 데이터를 받았으면 기존 로직 사용
        await super.loadDailySummary();
      } else {
        // 데이터가 없으면 기존 서비스 폴백
        await super.loadDailySummary();
      }
    } catch (e) {
      // 오류 시 기존 서비스 폴백
      print('⚠️ 향상된 일별 요약 서비스 실패, 기존 서비스로 폴백: $e');
      await super.loadDailySummary();
    }
  }
  
  /// 복구 시도 횟수 리셋
  void resetRecoveryAttempts() {
    _recoveryAttempts = 0;
    notifyListeners();
  }
  
  /// pykrx 서버 메시지 클리어
  void clearPykrxMessages() {
    _pykrxServerMessage = '';
    _pykrxRecoveryMessage = '';
    notifyListeners();
  }
  
  /// 헬스 모니터링 재시작
  void restartHealthMonitoring() {
    _enhancedService.stopService();
    _enhancedService.startService();
  }
  
  @override
  void dispose() {
    _enhancedService.stopService();
    _enhancedService.dispose();
    super.dispose();
  }
}