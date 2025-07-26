import 'package:flutter/material.dart';
import 'dart:async';

/// pykrx 서버 상태 및 복구 진행 상황을 표시하는 위젯
class PykrxServerStatusWidget extends StatefulWidget {
  final Function(String message, bool isError)? onStatusUpdate;
  final Function(String message)? onRecoveryProgress;
  final Function()? onManualRecovery;
  final bool isHealthy;
  final bool isRecovering;
  final String? currentMessage;
  
  const PykrxServerStatusWidget({
    super.key,
    this.onStatusUpdate,
    this.onRecoveryProgress,
    this.onManualRecovery,
    this.isHealthy = false,
    this.isRecovering = false,
    this.currentMessage,
  });

  @override
  State<PykrxServerStatusWidget> createState() => _PykrxServerStatusWidgetState();
}

class _PykrxServerStatusWidgetState extends State<PykrxServerStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  String _statusMessage = 'pykrx 서버 상태 확인 중...';
  String _recoveryMessage = '';
  bool _showRecoveryProgress = false;
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _updateAnimations();
  }
  
  @override
  void didUpdateWidget(PykrxServerStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isHealthy != widget.isHealthy ||
        oldWidget.isRecovering != widget.isRecovering) {
      _updateAnimations();
    }
    
    if (oldWidget.currentMessage != widget.currentMessage && 
        widget.currentMessage != null) {
      setState(() {
        _statusMessage = widget.currentMessage!;
      });
    }
  }
  
  void _updateAnimations() {
    if (widget.isRecovering) {
      _pulseController.repeat(reverse: true);
      _progressController.repeat();
      setState(() {
        _showRecoveryProgress = true;
      });
    } else {
      _pulseController.stop();
      _progressController.stop();
      setState(() {
        _showRecoveryProgress = false;
        _recoveryMessage = '';
      });
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  Color _getStatusColor() {
    if (widget.isRecovering) return Colors.orange;
    return widget.isHealthy ? Colors.green : Colors.red;
  }
  
  IconData _getStatusIcon() {
    if (widget.isRecovering) return Icons.autorenew;
    return widget.isHealthy ? Icons.check_circle : Icons.error;
  }
  
  String _getStatusText() {
    if (widget.isRecovering) return '복구 중';
    return widget.isHealthy ? '정상' : '오류';
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getStatusColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // 상태 헤더
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                children: [
                  // 상태 아이콘
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: widget.isRecovering ? _pulseAnimation.value : 1.0,
                        child: Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 20,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // 상태 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'pykrx 서버: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _getStatusColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        
                        if (_statusMessage.isNotEmpty)
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: _isExpanded ? null : 1,
                            overflow: _isExpanded ? null : TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  
                  // 확장/축소 아이콘
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            
            // 복구 진행 상황 (확장 시에만 표시)
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              
              // 진행 바 (복구 중일 때만)
              if (_showRecoveryProgress) ...[
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: widget.isRecovering ? null : 1.0,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
                        ),
                        const SizedBox(height: 8),
                        if (_recoveryMessage.isNotEmpty)
                          Text(
                            _recoveryMessage,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              
              // 액션 버튼들
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 수동 복구 버튼
                  if (!widget.isRecovering)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: widget.onManualRecovery,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          '수동 복구',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                  
                  if (!widget.isRecovering && widget.onManualRecovery != null)
                    const SizedBox(width: 8),
                  
                  // 상태 새로고침 버튼
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.isRecovering ? null : () {
                        // 상태 새로고침 로직
                        if (widget.onStatusUpdate != null) {
                          widget.onStatusUpdate!('서버 상태를 확인하고 있습니다...', false);
                        }
                      },
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text(
                        '상태 확인',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 복구 진행 메시지 업데이트
  void updateRecoveryMessage(String message) {
    if (mounted) {
      setState(() {
        _recoveryMessage = message;
      });
    }
  }
  
  /// 상태 메시지 업데이트
  void updateStatusMessage(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }
}