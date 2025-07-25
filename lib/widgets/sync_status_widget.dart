import 'package:flutter/material.dart';
import '../services/auto_sync_scheduler.dart';

/// 데이터 동기화 상태를 표시하는 위젯
class SyncStatusWidget extends StatefulWidget {
  const SyncStatusWidget({super.key});

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget> {
  final SmartSyncScheduler _scheduler = SmartSyncScheduler();
  Map<String, dynamic>? _status;
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    
    // 30초마다 상태 업데이트
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) {
        _updateStatus();
        return true;
      }
      return false;
    });
  }

  void _updateStatus() {
    if (mounted) {
      setState(() {
        _status = _scheduler.getStatus();
      });
    }
  }

  Future<void> _performManualSync() async {
    if (_isManualSyncing) return;
    
    setState(() {
      _isManualSyncing = true;
    });

    try {
      final result = await _scheduler.syncNow();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success 
                  ? '${result.message} ($result.newDataCount개 추가)' 
                  : '동기화 실패: ${result.message}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isManualSyncing = false;
        });
        _updateStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == null) {
      return const SizedBox.shrink();
    }

    final isRunning = _status!['isRunning'] as bool;
    final lastSyncTime = _status!['lastSyncTime'] as String?;
    final minutesSinceLastSync = _status!['minutesSinceLastSync'] as int?;
    final minutesUntilNextSync = _status!['minutesUntilNextSync'] as int?;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRunning ? Icons.sync : Icons.sync_disabled,
                  color: isRunning ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '데이터 동기화 상태',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isManualSyncing ? null : _performManualSync,
                  icon: _isManualSyncing 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '수동 동기화',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              '자동 동기화',
              isRunning ? '활성화' : '비활성화',
              isRunning ? Colors.green : Colors.red,
            ),
            if (lastSyncTime != null) ...[
              const SizedBox(height: 4),
              _buildStatusRow(
                '마지막 동기화',
                _formatLastSyncTime(minutesSinceLastSync),
                _getSyncTimeColor(minutesSinceLastSync),
              ),
            ],
            if (minutesUntilNextSync != null && minutesUntilNextSync > 0) ...[
              const SizedBox(height: 4),
              _buildStatusRow(
                '다음 동기화',
                '${minutesUntilNextSync}분 후',
                Colors.blue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatLastSyncTime(int? minutesSinceLastSync) {
    if (minutesSinceLastSync == null) return '없음';
    
    if (minutesSinceLastSync < 1) {
      return '방금 전';
    } else if (minutesSinceLastSync < 60) {
      return '$minutesSinceLastSync분 전';
    } else {
      final hours = minutesSinceLastSync ~/ 60;
      final minutes = minutesSinceLastSync % 60;
      if (minutes == 0) {
        return '$hours시간 전';
      } else {
        return '$hours시간 $minutes분 전';
      }
    }
  }

  Color _getSyncTimeColor(int? minutesSinceLastSync) {
    if (minutesSinceLastSync == null) return Colors.grey;
    
    if (minutesSinceLastSync < 30) {
      return Colors.green; // 최근
    } else if (minutesSinceLastSync < 120) {
      return Colors.orange; // 보통
    } else {
      return Colors.red; // 오래됨
    }
  }
}

/// 간단한 동기화 상태 표시 위젯 (상단바용)
class SimpleSyncStatusWidget extends StatefulWidget {
  const SimpleSyncStatusWidget({super.key});

  @override
  State<SimpleSyncStatusWidget> createState() => _SimpleSyncStatusWidgetState();
}

class _SimpleSyncStatusWidgetState extends State<SimpleSyncStatusWidget>
    with TickerProviderStateMixin {
  final SmartSyncScheduler _scheduler = SmartSyncScheduler();
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _quickSync() async {
    _animationController.repeat();
    
    try {
      final result = await _scheduler.syncNow();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.success 
                        ? '동기화 완료 ($result.newDataCount개 추가)' 
                        : result.message,
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _quickSync,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animation.value * 2 * 3.14159,
                  child: Icon(
                    Icons.sync,
                    size: 16,
                    color: Colors.blue,
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            const Text(
              '동기화',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}