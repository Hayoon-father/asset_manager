import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// pykrx 서버 자동 관리 및 복구 서비스
class PykrxServerManager {
  static const String _serverUrl = 'http://127.0.0.1:8000';
  static const String _healthEndpoint = '$_serverUrl/health';
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  
  Timer? _healthCheckTimer;
  bool _isHealthy = false;
  bool _isRecovering = false;
  DateTime? _lastHealthCheck;
  
  // 상태 변경 콜백
  Function(bool isHealthy, String message)? onStatusChanged;
  Function(String message)? onRecoveryProgress;
  
  /// 서버 상태 모니터링 시작
  void startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
    
    // 즉시 한 번 체크
    _performHealthCheck();
  }
  
  /// 서버 상태 모니터링 중지
  void stopHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }
  
  /// 서버 상태 확인
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse(_healthEndpoint),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_connectionTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isHealthy = data['status'] == 'healthy';
        _lastHealthCheck = DateTime.now();
        
        if (_isHealthy && onStatusChanged != null) {
          onStatusChanged!(_isHealthy, 'pykrx 서버가 정상적으로 실행 중입니다.');
        }
        
        return _isHealthy;
      }
    } catch (e) {
      print('❌ pykrx 서버 상태 확인 실패: $e');
    }
    
    _isHealthy = false;
    if (onStatusChanged != null) {
      onStatusChanged!(_isHealthy, 'pykrx 서버에 연결할 수 없습니다.');
    }
    
    return false;
  }
  
  /// 자동 서버 복구 시도
  Future<bool> attemptServerRecovery() async {
    if (_isRecovering) {
      print('🔄 이미 서버 복구가 진행 중입니다.');
      return false;
    }
    
    _isRecovering = true;
    
    try {
      if (onRecoveryProgress != null) {
        onRecoveryProgress!('pykrx 서버 복구를 시도합니다...');
      }
      
      // 1단계: 기존 서버 프로세스 종료
      await _killExistingServerProcesses();
      
      if (onRecoveryProgress != null) {
        onRecoveryProgress!('기존 서버 프로세스를 종료했습니다.');
      }
      
      await Future.delayed(const Duration(seconds: 2));
      
      // 2단계: 서버 재시작
      final startResult = await _startPykrxServer();
      
      if (startResult) {
        if (onRecoveryProgress != null) {
          onRecoveryProgress!('pykrx 서버를 재시작했습니다.');
        }
        
        // 3단계: 서버 상태 확인 (최대 30초 대기)
        bool isHealthy = false;
        for (int i = 0; i < 6; i++) {
          await Future.delayed(const Duration(seconds: 5));
          
          if (onRecoveryProgress != null) {
            onRecoveryProgress!('서버 상태 확인 중... (${i + 1}/6)');
          }
          
          isHealthy = await checkServerHealth();
          if (isHealthy) break;
        }
        
        if (isHealthy) {
          if (onRecoveryProgress != null) {
            onRecoveryProgress!('✅ pykrx 서버 복구가 완료되었습니다.');
          }
          return true;
        } else {
          if (onRecoveryProgress != null) {
            onRecoveryProgress!('❌ 서버 재시작 후에도 연결할 수 없습니다.');
          }
        }
      } else {
        if (onRecoveryProgress != null) {
          onRecoveryProgress!('❌ 서버 재시작에 실패했습니다.');
        }
      }
    } catch (e) {
      print('❌ 서버 복구 중 오류 발생: $e');
      if (onRecoveryProgress != null) {
        onRecoveryProgress!('❌ 서버 복구 중 오류가 발생했습니다: $e');
      }
    } finally {
      _isRecovering = false;
    }
    
    return false;
  }
  
  /// 재시도 로직이 포함된 API 호출
  Future<http.Response?> makeApiCallWithRetry(
    String endpoint, {
    Map<String, String>? queryParams,
    int maxRetries = _maxRetryAttempts,
  }) async {
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // URL 구성
        final uri = Uri.parse('$_serverUrl$endpoint');
        final finalUri = queryParams != null 
            ? uri.replace(queryParameters: queryParams)
            : uri;
        
        // API 호출
        final response = await http.get(
          finalUri,
          headers: {'Content-Type': 'application/json'},
        ).timeout(_connectionTimeout);
        
        if (response.statusCode == 200) {
          // 성공 시 서버 상태 업데이트
          _isHealthy = true;
          _lastHealthCheck = DateTime.now();
          return response;
        } else {
          throw HttpException('HTTP ${response.statusCode}: ${response.body}');
        }
        
      } catch (e) {
        print('❌ API 호출 시도 $attempt/$maxRetries 실패: $e');
        
        // 마지막 시도가 아니라면 복구 시도
        if (attempt < maxRetries) {
          if (onRecoveryProgress != null) {
            onRecoveryProgress!('API 호출 실패 - 서버 복구 시도 중... ($attempt/$maxRetries)');
          }
          
          // 서버 복구 시도
          final recoverySuccess = await attemptServerRecovery();
          
          if (recoverySuccess) {
            // 복구 성공 시 잠시 대기 후 다시 시도
            await Future.delayed(_retryDelay);
            continue;
          } else {
            // 복구 실패 시 대기 후 다시 시도
            if (attempt < maxRetries) {
              await Future.delayed(_retryDelay);
            }
          }
        }
      }
    }
    
    // 모든 시도 실패
    if (onStatusChanged != null) {
      onStatusChanged!(false, 'pykrx 서버에 $maxRetries번 시도했지만 연결할 수 없습니다.');
    }
    
    return null;
  }
  
  /// 기존 서버 프로세스 종료
  Future<void> _killExistingServerProcesses() async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        // 포트 8000을 사용하는 프로세스 종료
        await Process.run('bash', ['-c', 'lsof -ti:8000 | xargs kill -9 || true']);
        
        // pykrx 관련 프로세스 종료
        await Process.run('bash', ['-c', 'pkill -f "python.*main.py" || true']);
        await Process.run('bash', ['-c', 'pkill -f "uvicorn" || true']);
      }
    } catch (e) {
      print('⚠️ 기존 프로세스 종료 중 오류 (무시 가능): $e');
    }
  }
  
  /// pykrx 서버 시작
  Future<bool> _startPykrxServer() async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        // 프로젝트 루트에서 pykrx_server 디렉토리 찾기
        final currentDir = Directory.current.path;
        final serverDir = '$currentDir/pykrx_server';
        final serverDirAlt = '${currentDir.replaceAll('/lib', '')}/pykrx_server';
        
        String actualServerDir = serverDir;
        if (!Directory(serverDir).existsSync() && Directory(serverDirAlt).existsSync()) {
          actualServerDir = serverDirAlt;
        }
        
        if (!Directory(actualServerDir).existsSync()) {
          print('❌ pykrx_server 디렉토리를 찾을 수 없습니다: $actualServerDir');
          return false;
        }
        
        // 백그라운드에서 서버 시작
        final result = await Process.run('bash', [
          '-c',
          'cd "$actualServerDir" && source venv/bin/activate && nohup python main.py > server.log 2>&1 &'
        ]);
        
        print('🚀 pykrx 서버 시작 명령 실행: ${result.exitCode}');
        return result.exitCode == 0;
      }
    } catch (e) {
      print('❌ pykrx 서버 시작 실패: $e');
    }
    
    return false;
  }
  
  /// 정기적인 상태 확인
  void _performHealthCheck() async {
    if (_isRecovering) return; // 복구 중이면 스킵
    
    final isHealthy = await checkServerHealth();
    
    // 서버가 비정상이면 자동 복구 시도
    if (!isHealthy && !_isRecovering) {
      print('🔧 pykrx 서버 비정상 감지 - 자동 복구 시작');
      await attemptServerRecovery();
    }
  }
  
  /// 현재 서버 상태 정보
  Map<String, dynamic> getServerStatus() {
    return {
      'isHealthy': _isHealthy,
      'isRecovering': _isRecovering,
      'lastHealthCheck': _lastHealthCheck?.toIso8601String(),
      'serverUrl': _serverUrl,
    };
  }
  
  /// 리소스 정리
  void dispose() {
    stopHealthMonitoring();
    onStatusChanged = null;
    onRecoveryProgress = null;
  }
}