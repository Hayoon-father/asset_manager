import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enhanced_foreign_investor_provider.dart';
import '../widgets/pykrx_server_status_widget.dart';

/// pykrx 서버 자동 복구 기능 사용 예시
class PykrxAutoRecoveryExample extends StatefulWidget {
  const PykrxAutoRecoveryExample({super.key});

  @override
  State<PykrxAutoRecoveryExample> createState() => _PykrxAutoRecoveryExampleState();
}

class _PykrxAutoRecoveryExampleState extends State<PykrxAutoRecoveryExample> {
  late EnhancedForeignInvestorProvider _provider;
  final GlobalKey<_PykrxServerStatusWidgetState> _statusWidgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    
    // 향상된 Provider 초기화
    _provider = EnhancedForeignInvestorProvider();
    _provider.initState();
    
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.loadInitialData();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EnhancedForeignInvestorProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('pykrx 자동 복구 예시'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Consumer<EnhancedForeignInvestorProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // pykrx 서버 상태 위젯
                PykrxServerStatusWidget(
                  key: _statusWidgetKey,
                  isHealthy: provider.isPykrxServerHealthy,
                  isRecovering: provider.isPykrxServerRecovering,
                  currentMessage: provider.pykrxServerMessage,
                  onManualRecovery: () async {
                    final success = await provider.manualServerRecovery();
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('서버 복구가 완료되었습니다.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  onStatusUpdate: (message, isError) {
                    _statusWidgetKey.currentState?.updateStatusMessage(message);
                    
                    if (isError && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  onRecoveryProgress: (message) {
                    _statusWidgetKey.currentState?.updateRecoveryMessage(message);
                  },
                ),
                
                // 설정 패널
                _buildSettingsPanel(provider),
                
                // 서버 상태 정보
                _buildServerInfo(provider),
                
                // 데이터 로드 테스트 버튼들
                _buildTestButtons(provider),
                
                // 데이터 표시 영역
                Expanded(
                  child: _buildDataDisplay(provider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(EnhancedForeignInvestorProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '자동 복구 설정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: Text(
                    '자동 복구 활성화',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                Switch(
                  value: provider.autoRecoveryEnabled,
                  onChanged: (value) {
                    provider.setAutoRecoveryEnabled(value);
                  },
                ),
              ],
            ),
            
            if (provider.recoveryAttempts > 0) ...[
              const SizedBox(height: 8),
              Text(
                '복구 시도 횟수: ${provider.recoveryAttempts}/3',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerInfo(EnhancedForeignInvestorProvider provider) {
    final status = provider.pykrxServerStatus;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '서버 상세 정보',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            _buildInfoRow('서버 주소', status['serverUrl'] ?? 'N/A'),
            _buildInfoRow('상태', provider.isPykrxServerHealthy ? '정상' : '비정상'),
            _buildInfoRow('복구 중', provider.isPykrxServerRecovering ? '예' : '아니오'),
            
            if (status['lastHealthCheck'] != null)
              _buildInfoRow(
                '마지막 확인',
                _formatDateTime(status['lastHealthCheck']),
              ),
            
            if (provider.pykrxRecoveryMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  provider.pykrxRecoveryMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButtons(EnhancedForeignInvestorProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: provider.isLoading ? null : () {
              provider.loadLatestData();
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('최신 데이터'),
          ),
          
          ElevatedButton.icon(
            onPressed: provider.isLoading ? null : () {
              provider.loadDailySummary();
            },
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text('일별 요약'),
          ),
          
          ElevatedButton.icon(
            onPressed: () {
              provider.checkServerHealth();
            },
            icon: const Icon(Icons.health_and_safety, size: 16),
            label: const Text('상태 확인'),
          ),
          
          ElevatedButton.icon(
            onPressed: provider.isPykrxServerRecovering ? null : () {
              provider.manualServerRecovery();
            },
            icon: const Icon(Icons.healing, size: 16),
            label: const Text('수동 복구'),
          ),
          
          TextButton.icon(
            onPressed: () {
              provider.resetRecoveryAttempts();
              provider.clearPykrxMessages();
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('상태 초기화'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataDisplay(EnhancedForeignInvestorProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('데이터를 로드하는 중...'),
          ],
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '오류 발생',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                provider.dismissError();
                provider.refresh();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '로드된 데이터: ${provider.latestData.length}개',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        ...provider.latestData.take(10).map((data) => Card(
          child: ListTile(
            title: Text(data.stockName),
            subtitle: Text('${data.marketType} - ${data.investorType}'),
            trailing: Text(
              '${data.netAmount > 0 ? '+' : ''}${data.netAmount}',
              style: TextStyle(
                color: data.netAmount > 0 ? Colors.red : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        )),
        
        if (provider.latestData.length > 10)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '... 외 ${provider.latestData.length - 10}개 더',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}