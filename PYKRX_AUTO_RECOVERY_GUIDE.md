# pykrx API 자동 복구 시스템 가이드

## 개요

pykrx API 연결 실패 시 자동으로 서버를 재시작하고 재시도하는 시스템을 구현했습니다. 이 시스템은 현재와 같은 서버 연결 문제가 발생했을 때 사용자 개입 없이 자동으로 복구를 시도합니다.

## 주요 기능

### 1. 자동 감지 및 복구
- **실시간 헬스 체크**: 30초마다 pykrx 서버 상태 모니터링
- **자동 서버 재시작**: 연결 실패 시 자동으로 서버 프로세스 종료 후 재시작
- **스마트 재시도**: 최대 3회까지 자동 복구 시도
- **폴백 메커니즘**: 복구 실패 시 기존 DB 데이터로 폴백

### 2. 사용자 친화적 UI
- **실시간 상태 표시**: 서버 상태와 복구 진행 상황 실시간 표시
- **수동 복구 옵션**: 사용자가 직접 복구 명령 실행 가능
- **상세 정보 제공**: 서버 상태, 마지막 확인 시간, 복구 메시지 등

### 3. 네트워크 복원력
- **연결 타임아웃**: 10초 내 응답 없으면 재시도
- **재시도 로직**: 실패 시 5초 간격으로 재시도
- **점진적 백오프**: 연속 실패 시 대기 시간 증가

## 구현된 컴포넌트

### 1. 핵심 서비스
```
lib/services/
├── pykrx_server_manager.dart          # 서버 자동 관리 및 복구
├── enhanced_foreign_investor_service.dart  # 자동 복구 기능이 포함된 서비스
```

### 2. 향상된 Provider
```
lib/providers/
├── enhanced_foreign_investor_provider.dart  # 자동 복구 기능이 통합된 Provider
```

### 3. UI 컴포넌트
```
lib/widgets/
├── pykrx_server_status_widget.dart    # 서버 상태 표시 위젯
```

### 4. 사용 예시
```
lib/examples/
├── pykrx_auto_recovery_example.dart   # 완전한 사용 예시
```

## 사용 방법

### 1. 기본 설정

```dart
// 기존 Provider 대신 향상된 Provider 사용
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EnhancedForeignInvestorProvider()..initState(),
      child: MaterialApp(
        home: MyHomePage(),
      ),
    );
  }
}
```

### 2. UI에 서버 상태 위젯 추가

```dart
// 홈 화면에 서버 상태 위젯 추가
Column(
  children: [
    // 기존 UI...
    
    // pykrx 서버 상태 표시
    Consumer<EnhancedForeignInvestorProvider>(
      builder: (context, provider, child) {
        return PykrxServerStatusWidget(
          isHealthy: provider.isPykrxServerHealthy,
          isRecovering: provider.isPykrxServerRecovering,
          currentMessage: provider.pykrxServerMessage,
          onManualRecovery: () async {
            await provider.manualServerRecovery();
          },
        );
      },
    ),
    
    // 기존 UI...
  ],
)
```

### 3. 자동 복구 설정

```dart
// Provider에서 자동 복구 설정
final provider = Provider.of<EnhancedForeignInvestorProvider>(context);

// 자동 복구 활성화/비활성화
provider.setAutoRecoveryEnabled(true);

// 수동 복구 실행
await provider.manualServerRecovery();

// 서버 상태 확인
await provider.checkServerHealth();
```

## 동작 시나리오

### 1. 정상 동작
1. 앱 시작 시 pykrx 서버 상태 확인
2. 30초마다 정기적으로 헬스 체크
3. API 호출 시 자동으로 서버 상태 확인
4. 모든 것이 정상이면 기존대로 동작

### 2. 서버 연결 실패 시
1. **감지**: API 호출 실패 또는 헬스 체크 실패
2. **알림**: 사용자에게 "서버 연결 실패" 메시지 표시
3. **복구 시도**: 자동으로 다음 단계 실행
   - 기존 서버 프로세스 종료 (`pkill`, `lsof -ti:8000`)
   - 2초 대기
   - pykrx 서버 재시작 (`python main.py`)
   - 최대 30초간 상태 확인
4. **재시도**: 복구 성공 시 원래 API 호출 재시도
5. **폴백**: 복구 실패 시 기존 DB 데이터 사용

### 3. 사용자 개입
- **수동 복구**: 사용자가 직접 복구 버튼 클릭
- **상태 확인**: 현재 서버 상태 수동 확인
- **설정 변경**: 자동 복구 활성화/비활성화

## 설정 옵션

### PykrxServerManager 설정
```dart
// 서버 주소 및 포트
static const String _serverUrl = 'http://127.0.0.1:8000';

// 헬스 체크 간격 (기본: 30초)
static const Duration _healthCheckInterval = Duration(seconds: 30);

// 연결 타임아웃 (기본: 10초)
static const Duration _connectionTimeout = Duration(seconds: 10);

// 최대 재시도 횟수 (기본: 3회)
static const int _maxRetryAttempts = 3;

// 재시도 간격 (기본: 5초)
static const Duration _retryDelay = Duration(seconds: 5);
```

## 로그 및 모니터링

### 1. 콘솔 로그
```
🔄 pykrx 서버 상태 확인 중...
✅ pykrx 서버가 정상적으로 실행 중입니다.
❌ pykrx 서버에 연결할 수 없습니다.
🔧 pykrx 서버 비정상 감지 - 자동 복구 시작
🚀 pykrx 서버 재시작 완료
```

### 2. 사용자 메시지
- "서버 상태를 확인하고 있습니다..."
- "서버 복구를 시도합니다..."
- "서버가 성공적으로 복구되었습니다."
- "서버 복구에 실패했습니다."

### 3. 서버 로그
```
pykrx_server/server.log 파일에 상세 로그 기록
```

## 문제 해결

### 1. 자동 복구가 작동하지 않는 경우
- 헬스 모니터링 활성화 확인: `provider.isHealthMonitoringActive`
- 자동 복구 설정 확인: `provider.autoRecoveryEnabled`
- 복구 시도 횟수 확인: `provider.recoveryAttempts`

### 2. 수동 복구도 실패하는 경우
- Python 가상환경 확인
- pykrx_server 디렉토리 존재 확인
- 포트 8000 사용 가능 확인
- 권한 문제 확인

### 3. 로그 확인 방법
```dart
// 서버 상태 정보 확인
final status = provider.pykrxServerStatus;
print('서버 상태: $status');

// 복구 메시지 확인
print('복구 메시지: ${provider.pykrxRecoveryMessage}');
```

## 성능 고려사항

### 1. 네트워크 오버헤드
- 헬스 체크는 30초마다만 실행
- API 호출 시에만 연결 상태 확인
- 타임아웃 10초로 제한

### 2. 메모리 사용량
- 백그라운드 타이머 1개만 실행
- 필요시에만 프로세스 실행

### 3. 배터리 영향
- 최소한의 백그라운드 작업
- 앱 종료 시 자동으로 모니터링 중지

## 향후 개선 사항

1. **지능형 복구**: 실패 패턴 학습하여 복구 전략 최적화
2. **알림 시스템**: 복구 성공/실패 푸시 알림
3. **통계 수집**: 서버 안정성 지표 수집 및 분석
4. **클러스터 지원**: 여러 pykrx 서버 인스턴스 관리
5. **원격 복구**: 원격 서버 관리 기능

## 결론

이 자동 복구 시스템을 통해 pykrx API 연결 문제가 발생하더라도 사용자는 거의 중단 없이 애플리케이션을 사용할 수 있습니다. 시스템이 자동으로 문제를 감지하고 복구를 시도하며, 필요한 경우 사용자가 수동으로 개입할 수 있는 옵션도 제공합니다.