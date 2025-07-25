import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/foreign_investor_data.dart';

class AdvancedDailyTrendChart extends StatefulWidget {
  final List<DailyForeignSummary> summaryData;
  final String selectedMarket;
  final VoidCallback? onRequestMoreData; // 더 많은 데이터 요청 콜백

  const AdvancedDailyTrendChart({
    super.key,
    required this.summaryData,
    required this.selectedMarket,
    this.onRequestMoreData,
  });

  @override
  State<AdvancedDailyTrendChart> createState() => _AdvancedDailyTrendChartState();
}

class _AdvancedDailyTrendChartState extends State<AdvancedDailyTrendChart>
    with TickerProviderStateMixin {
  
  // 차트 상태
  double _scale = 1.0;
  double _panX = 0.0;
  double _lastPanX = 0.0;
  bool _isInitialViewSet = false; // 초기 뷰 설정 여부
  
  // 툴팁 상태
  Offset? _tooltipPosition;
  DailyForeignSummary? _selectedData;
  bool _showTooltip = false;
  
  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late AnimationController _tooltipController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _tooltipAnimation;
  
  // 차트 옵션
  bool _showKospiData = true;
  bool _showKosdaqData = true;
  final bool _showCombinedData = true;
  ChartViewType _viewType = ChartViewType.combined;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _tooltipController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _tooltipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tooltipController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.summaryData.isEmpty) {
      return _buildEmptyState();
    }
    
    // 데이터가 변경되면 초기 뷰포트 재설정
    if (!_isInitialViewSet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isInitialViewSet) {
          setState(() {
            _setInitialViewport();
          });
        }
      });
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLegendAndControls(),
              const SizedBox(height: 20),
              Container(
                height: 350,
                width: double.infinity,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _buildAdvancedChart(),
              ),
              const SizedBox(height: 16),
              _buildChartInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '차트 데이터가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '데이터를 불러오는 중이거나 선택된 기간에 데이터가 없습니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '외국인 주식보유 총액 추이',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildViewTypeSelector(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.summaryData.length}일간의 누적 보유액 변화',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildViewTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(ChartViewType.combined, '통합', Icons.show_chart),
          _buildViewButton(ChartViewType.separated, '분리', Icons.stacked_line_chart),
        ],
      ),
    );
  }

  Widget _buildViewButton(ChartViewType type, String label, IconData icon) {
    final isSelected = _viewType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewType = type;
        });
        _animationController.reset();
        _animationController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendAndControls() {
    return Column(
      children: [
        // 범례 - 상승/하강 색상 표시
        Row(
          children: [
            if (_viewType == ChartViewType.combined) ...[
              _buildLegendItem(Colors.red, '상승 구간', true, (value) {}),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.blue, '하강 구간', true, (value) {}),
            ] else ...[
              _buildLegendItem(Colors.blue.shade600, 'KOSPI', _showKospiData, (value) {
                setState(() => _showKospiData = value);
              }),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.orange.shade600, 'KOSDAQ', _showKosdaqData, (value) {
                setState(() => _showKosdaqData = value);
              }),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // 제스처 가이드
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '터치: 상세정보 • 핀치: 확대/축소 • 좌측 드래그: 과거 • 우측 드래그: 최신',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, bool isVisible, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!isVisible),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isVisible ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
              boxShadow: isVisible ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: isVisible ? Icon(
              Icons.check,
              size: 10,
              color: Colors.white,
            ) : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isVisible ? Colors.black87 : Colors.grey.shade500,
                fontWeight: isVisible ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedChart() {
    // 초기 뷰포트 설정 (60일 전부터 현재까지 표시)
    if (!_isInitialViewSet && widget.summaryData.isNotEmpty) {
      _setInitialViewport();
    }
    
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              // 메인 차트
              GestureDetector(
                onScaleStart: (details) {
                  _lastPanX = _panX;
                  _hideTooltip();
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_scale * details.scale).clamp(0.5, 5.0);
                    
                    if (details.scale == 1.0) {
                      // 핑거 제스처 개선: 좌측으로 드래그하면 과거 데이터, 우측으로 드래그하면 최신 데이터
                      final deltaX = details.focalPointDelta.dx;
                      _panX = _lastPanX + deltaX;
                      
                      // 팬 범위 제한 계산 개선
                      final screenWidth = MediaQuery.of(context).size.width;
                      final chartWidth = screenWidth - 120; // 여백 고려
                      final scaledWidth = chartWidth * _scale;
                      final dataWidth = widget.summaryData.length > 1 
                          ? scaledWidth
                          : chartWidth;
                      
                      // 팬 범위: 
                      // - 왼쪽 한계: 모든 과거 데이터가 보이도록
                      // - 오른쪽 한계: 최신 데이터가 항상 보이도록
                      final maxPanLeft = -(dataWidth - chartWidth).clamp(0.0, double.infinity);
                      const maxPanRight = 0.0; // 최신 데이터 위치 고정
                      
                      _panX = _panX.clamp(maxPanLeft, maxPanRight);
                      
                      // 사용자가 과거 데이터 영역에 가까이 가면 더 많은 데이터 로드 요청
                      if (_panX < maxPanLeft * 0.8) { // 80% 지점에서 트리거
                        _requestMoreHistoricalData();
                      }
                    }
                  });
                },
                onTapDown: (details) {
                  _handleChartTap(details.localPosition);
                },
                child: ClipRect(
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: _AdvancedChartPainter(
                        data: widget.summaryData,
                        scale: _scale,
                        panX: _panX,
                        viewType: _viewType,
                        showKospi: _showKospiData,
                        showKosdaq: _showKosdaqData,
                        showCombined: _showCombinedData,
                        animationValue: _fadeAnimation.value,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Y축 라벨
              Positioned(
                left: 0,
                top: 0,
                bottom: 40,
                width: 80,
                child: ClipRect(child: _buildYAxisLabels()),
              ),
              
              // X축 라벨
              Positioned(
                left: 80,
                right: 0,
                bottom: 0,
                height: 40,
                child: ClipRect(child: _buildXAxisLabels()),
              ),
              
              // 툴팁
              if (_showTooltip && _tooltipPosition != null && _selectedData != null)
                Positioned(
                  left: _tooltipPosition!.dx,
                  top: _tooltipPosition!.dy,
                  child: AnimatedBuilder(
                    animation: _tooltipAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _tooltipAnimation.value,
                        child: _buildTooltip(_selectedData!),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleChartTap(Offset position) {
    // 차트 영역 내의 탭인지 확인
    if (position.dx < 80 || position.dy > 310) return;
    
    // 가장 가까운 데이터 포인트 찾기
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = screenWidth - 120;
    final dataIndex = _findNearestDataIndex(position.dx - 80, chartWidth);
    
    if (dataIndex >= 0 && dataIndex < widget.summaryData.length) {
      setState(() {
        _selectedData = widget.summaryData[dataIndex];
        _tooltipPosition = Offset(
          (position.dx - 100).clamp(10, screenWidth - 210),
          (position.dy - 80).clamp(10, 200),
        );
        _showTooltip = true;
      });
      
      _tooltipController.reset();
      _tooltipController.forward();
      
      // 3초 후 툴팁 자동 숨김
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _hideTooltip();
        }
      });
    }
  }

  int _findNearestDataIndex(double x, double chartWidth) {
    if (widget.summaryData.isEmpty) return 0;
    
    final clampedScale = _scale.clamp(0.01, 100.0); // Prevent division by very small numbers
    final scaledWidth = chartWidth * clampedScale;
    final pointSpacing = widget.summaryData.length > 1 
        ? (scaledWidth / (widget.summaryData.length - 1)).clamp(0.1, double.infinity)
        : (scaledWidth / 2).clamp(0.1, double.infinity);
    
    final adjustedX = x - _panX;
    final index = (adjustedX / pointSpacing).round();
    
    return index.clamp(0, widget.summaryData.length - 1);
  }

  void _hideTooltip() {
    if (_showTooltip) {
      setState(() {
        _showTooltip = false;
      });
    }
  }

  // 더 많은 과거 데이터 요청
  void _requestMoreHistoricalData() {
    // 과도한 요청 방지를 위해 쓰로틀링
    if (_lastHistoricalDataRequest != null && 
        DateTime.now().difference(_lastHistoricalDataRequest!) < const Duration(seconds: 2)) {
      return;
    }
    
    _lastHistoricalDataRequest = DateTime.now();
    
    // Provider를 통해 과거 데이터 로드 요청
    try {
      // context가 유효한지 확인
      if (!mounted) return;
      
      
      // ForeignInvestorProvider의 loadMoreHistoricalData 메서드 호출
      if (widget.onRequestMoreData != null) {
        widget.onRequestMoreData!();
      } else {
        // 콜백이 없으면 기본 동작
        Future.microtask(() {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('과거 데이터를 불러오는 중...'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        });
      }
    } catch (e) {
    }
  }

  DateTime? _lastHistoricalDataRequest;

  // 초기 뷰포트 설정 (60일 전부터 현재까지 표시)
  void _setInitialViewport() {
    if (widget.summaryData.isEmpty) return;
    
    // 데이터를 날짜순으로 정렬 (과거 -> 최신)
    final sortedData = List<DailyForeignSummary>.from(widget.summaryData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));
    
    // 화면 크기 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = screenWidth - 120; // 여백 고려
    
    // 전체 데이터 길이가 60일보다 많으면 최근 60일만 보이도록 조정
    if (sortedData.length > 60) {
      // 전체 데이터에서 최근 60일이 화면에 맞도록 스케일과 팬 조정
      final visibleDataRatio = 60.0 / sortedData.length;
      _scale = (1.0 / visibleDataRatio).clamp(1.0, 5.0);
      
      // 최신 데이터(오른쪽 끝)이 보이도록 팬 위치 조정
      final scaledWidth = chartWidth * _scale;
      _panX = -(scaledWidth - chartWidth);
    } else {
      // 60일 이하면 전체 데이터 표시
      _scale = 1.0;
      _panX = 0.0;
    }
    
    _isInitialViewSet = true;
  }

  Widget _buildTooltip(DailyForeignSummary data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(data.date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '보유액: ${_formatAmount(data.cumulativeHoldings)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '순매수: ${_formatAmount(data.totalForeignNetAmount)}',
            style: TextStyle(
              color: data.totalForeignNetAmount > 0 ? Colors.green.shade300 : Colors.red.shade300,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '거래액: ${_formatAmount(data.foreignTotalTradeAmount)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildYAxisLabels() {
    final values = widget.summaryData.map((d) => d.cumulativeHoldings).toList();
    if (values.isEmpty) return const SizedBox();
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    
    // 적절한 Y축 간격 계산
    const stepCount = 6;
    final rawStep = range / (stepCount - 1);
    final magnitude = _getMagnitude(rawStep);
    final normalizedStep = (rawStep / magnitude).ceil() * magnitude;
    
    // 시작값을 적절히 조정 (minValue보다 작거나 같은 가장 가까운 step 배수)
    final startValue = (minValue / normalizedStep).floor() * normalizedStep;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(stepCount, (index) {
        final value = startValue + (normalizedStep * (stepCount - 1 - index));
        final formattedValue = _formatAxisValue(value);
        
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            formattedValue,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }),
    );
  }

  // Y축 값의 적절한 단위로 포맷팅
  String _formatAxisValue(int value) {
    final absValue = value.abs();
    final sign = value < 0 ? '-' : '';
    
    if (absValue >= 1000000000000) { // 1조 이상
      final trillion = absValue / 1000000000000;
      if (trillion >= 100) {
        return '$sign${trillion.toStringAsFixed(0)}조';
      } else if (trillion >= 10) {
        return '$sign${trillion.toStringAsFixed(1)}조';
      } else {
        return '$sign${trillion.toStringAsFixed(2)}조';
      }
    } else if (absValue >= 100000000000) { // 1000억 이상
      final hundredBillion = absValue / 100000000000;
      return '$sign${hundredBillion.toStringAsFixed(1)}천억';
    } else if (absValue >= 100000000) { // 1억 이상
      final billion = absValue / 100000000;
      return '$sign${billion.toStringAsFixed(0)}억';
    } else if (absValue >= 10000) { // 1만 이상
      final million = absValue / 10000;
      return '$sign${million.toStringAsFixed(0)}만';
    } else {
      return '$sign$absValue';
    }
  }

  // 수치의 크기(magnitude) 계산
  int _getMagnitude(double value) {
    if (value == 0) return 1;
    int magnitude = 1;
    final absValue = value.abs();
    
    if (absValue >= 1) {
      while (magnitude * 10 <= absValue) {
        magnitude *= 10;
      }
    } else {
      while (magnitude > absValue * 10) {
        magnitude = (magnitude / 10).round();
      }
    }
    return magnitude;
  }

  Widget _buildXAxisLabels() {
    if (widget.summaryData.isEmpty) return const SizedBox();
    
    // 스케일과 화면 크기에 따른 적응적 라벨 개수 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 120; // 여백 고려
    final clampedScale = _scale.clamp(0.01, 100.0);
    
    // 라벨간 최소 간격을 60픽셀로 설정
    final maxLabels = (availableWidth / 60).floor().clamp(3, 8);
    final visibleDataCount = (widget.summaryData.length / clampedScale).round().clamp(3, widget.summaryData.length);
    final actualLabelCount = math.min(maxLabels, visibleDataCount);
    
    // 데이터를 시간순으로 정렬 (과거 -> 최신)
    final sortedData = List<DailyForeignSummary>.from(widget.summaryData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));
    
    // 현재 표시되는 데이터 범위 계산 (팬 위치 고려)
    
    // 표시할 라벨의 인덱스들 계산
    final labelIndices = <int>[];
    if (actualLabelCount > 0) {
      final step = (sortedData.length - 1) / (actualLabelCount - 1);
      for (int i = 0; i < actualLabelCount; i++) {
        final index = (i * step).round().clamp(0, sortedData.length - 1);
        if (!labelIndices.contains(index)) {
          labelIndices.add(index);
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labelIndices.map((index) {
          final data = sortedData[index];
          final displayDate = _formatDateForAxis(data.date);
          
          return Flexible(
            child: Text(
              displayDate,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          );
        }).toList(),
      ),
    );
  }

  // X축용 날짜 포맷팅 (더 읽기 쉽게)
  String _formatDateForAxis(String date) {
    if (date.length < 8) return date;
    
    final year = date.substring(0, 4);
    final month = date.substring(4, 6);
    final day = date.substring(6, 8);
    
    // 현재 년도와 비교하여 년도 표시 여부 결정
    final currentYear = DateTime.now().year.toString();
    
    if (year == currentYear) {
      // 올해 데이터는 월/일만 표시
      return '$month/$day';
    } else {
      // 다른 년도는 년/월 표시
      return '$year/$month월';
    }
  }

  Widget _buildChartInfo() {
    if (widget.summaryData.isEmpty) return const SizedBox();
    
    try {
      final latest = widget.summaryData.first;
      final earliest = widget.summaryData.last;
    final change = latest.cumulativeHoldings - earliest.cumulativeHoldings;
    final changePercent = earliest.cumulativeHoldings != 0 
        ? (change / earliest.cumulativeHoldings * 100) 
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoItem(
              '현재 보유액',
              _formatAmount(latest.cumulativeHoldings),
              Colors.blue.shade600,
              Icons.account_balance_wallet,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _buildInfoItem(
              '기간 변화',
              '${change > 0 ? '+' : ''}${_formatAmount(change)}',
              change > 0 ? Colors.green.shade600 : Colors.red.shade600,
              change > 0 ? Icons.trending_up : Icons.trending_down,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(
            child: _buildInfoItem(
              '변화율',
              '${change > 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
              change > 0 ? Colors.green.shade600 : Colors.red.shade600,
              Icons.percent,
            ),
          ),
        ],
      ),
    );
    } catch (e) {
      return const SizedBox(); // Return empty widget if data access fails
    }
  }

  Widget _buildInfoItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    if (date.length >= 8) {
      return '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)}';
    }
    return date;
  }

  String _formatAmount(int amount) {
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 1000000000000) {
      return '$sign${(absAmount / 1000000000000).toStringAsFixed(1)}조원';
    } else if (absAmount >= 100000000) {
      return '$sign${(absAmount / 100000000).toStringAsFixed(0)}억원';
    } else if (absAmount >= 10000) {
      return '$sign${(absAmount / 10000).toStringAsFixed(0)}만원';
    } else {
      return '$sign$absAmount원';
    }
  }
}

enum ChartViewType { combined, separated }

class _AdvancedChartPainter extends CustomPainter {
  final List<DailyForeignSummary> data;
  final double scale;
  final double panX;
  final ChartViewType viewType;
  final bool showKospi;
  final bool showKosdaq;
  final bool showCombined;
  final double animationValue;

  _AdvancedChartPainter({
    required this.data,
    required this.scale,
    required this.panX,
    required this.viewType,
    required this.showKospi,
    required this.showKosdaq,
    required this.showCombined,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Ensure safe dimensions
    final safeWidth = size.width.clamp(80.0, double.infinity);
    final safeHeight = size.height.clamp(40.0, double.infinity);
    final chartArea = Rect.fromLTWH(
      80, 
      0, 
      (safeWidth - 80).clamp(1.0, double.infinity), 
      (safeHeight - 40).clamp(1.0, double.infinity)
    );
    
    // 클리핑 적용
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, safeWidth, safeHeight));

    _drawGrid(canvas, chartArea);
    
    if (viewType == ChartViewType.combined && showCombined) {
      _drawCombinedChart(canvas, chartArea);
    } else {
      if (showKospi) _drawKospiChart(canvas, chartArea);
      if (showKosdaq) _drawKosdaqChart(canvas, chartArea);
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Rect chartArea) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 0.5;

    // 수평 그리드
    for (int i = 0; i <= 5; i++) {
      final y = chartArea.top + (chartArea.height * i / 5);
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    // 수직 그리드
    final visiblePoints = (data.length / scale).round().clamp(5, data.length);
    for (int i = 0; i <= visiblePoints; i++) {
      final x = chartArea.left + panX + (chartArea.width * scale * i / visiblePoints);
      if (x >= chartArea.left && x <= chartArea.right) {
        canvas.drawLine(
          Offset(x, chartArea.top),
          Offset(x, chartArea.bottom),
          gridPaint,
        );
      }
    }
  }

  void _drawCombinedChart(Canvas canvas, Rect chartArea) {
    final values = data.map((d) => d.cumulativeHoldings).toList();
    if (values.isEmpty) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final rawRange = maxValue - minValue;
    final range = rawRange == 0 ? 1.0 : rawRange.abs().clamp(0.001, double.infinity);

    final sortedData = List<DailyForeignSummary>.from(data);
    sortedData.sort((a, b) => a.date.compareTo(b.date));

    final points = <Offset>[];
    final clampedScale = scale.clamp(0.01, 100.0);
    final scaledWidth = chartArea.width * clampedScale;
    final pointSpacing = sortedData.length > 1 
        ? (scaledWidth / (sortedData.length - 1)).clamp(0.1, double.infinity)
        : (scaledWidth / 2).clamp(0.1, double.infinity);

    for (int i = 0; i < sortedData.length; i++) {
      final x = chartArea.left + panX + (i * pointSpacing);
      final value = sortedData[i].cumulativeHoldings;
      final normalizedValue = ((value - minValue) / range).clamp(0.0, 1.0);
      final y = chartArea.bottom - (normalizedValue * chartArea.height);
      points.add(Offset(x, y.clamp(chartArea.top, chartArea.bottom)));
    }

    _drawAnimatedLine(canvas, points, Colors.blue.shade600, 3.0);
    _drawAnimatedArea(canvas, points, chartArea, Colors.grey.withOpacity(0.1)); // 중성적인 배경색
    _drawAnimatedPoints(canvas, points, sortedData, Colors.blue.shade600);
  }

  void _drawKospiChart(Canvas canvas, Rect chartArea) {
    // KOSPI 데이터만 필터링하여 그리기
    _drawMarketChart(canvas, chartArea, 'KOSPI', Colors.blue.shade600);
  }

  void _drawKosdaqChart(Canvas canvas, Rect chartArea) {
    // KOSDAQ 데이터만 필터링하여 그리기
    _drawMarketChart(canvas, chartArea, 'KOSDAQ', Colors.orange.shade600);
  }

  void _drawMarketChart(Canvas canvas, Rect chartArea, String market, Color color) {
    final marketData = data.where((d) => d.marketType == market).toList();
    if (marketData.isEmpty) return;

    final values = marketData.map((d) => d.cumulativeHoldings).toList();
    if (values.isEmpty) return;
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final rawRange = maxValue - minValue;
    final range = rawRange == 0 ? 1.0 : rawRange.abs().clamp(0.001, double.infinity);

    final sortedData = List<DailyForeignSummary>.from(marketData);
    sortedData.sort((a, b) => a.date.compareTo(b.date));

    final points = <Offset>[];
    final clampedScale = scale.clamp(0.01, 100.0);
    final scaledWidth = chartArea.width * clampedScale;
    final pointSpacing = sortedData.length > 1 
        ? (scaledWidth / (sortedData.length - 1)).clamp(0.1, double.infinity)
        : (scaledWidth / 2).clamp(0.1, double.infinity);

    for (int i = 0; i < sortedData.length; i++) {
      final x = chartArea.left + panX + (i * pointSpacing);
      final value = sortedData[i].cumulativeHoldings;
      final normalizedValue = ((value - minValue) / range).clamp(0.0, 1.0);
      final y = chartArea.bottom - (normalizedValue * chartArea.height);
      points.add(Offset(x, y.clamp(chartArea.top, chartArea.bottom)));
    }

    _drawAnimatedLine(canvas, points, color, 2.5);
    _drawAnimatedPoints(canvas, points, sortedData, color);
  }

  void _drawAnimatedLine(Canvas canvas, List<Offset> points, Color baseColor, double strokeWidth) {
    if (points.isEmpty || points.length < 2) return;

    // 각 구간별로 상승/하강에 따라 색상을 다르게 그리기
    for (int i = 0; i < points.length - 1; i++) {
      final animatedIndex = ((i + 1) * animationValue).floor();
      if (animatedIndex <= i) continue;
      
      final startPoint = points[i];
      final endPoint = points[i + 1];
      
      // 상승/하강 판단 (y값이 작을수록 위쪽)
      final isRising = endPoint.dy < startPoint.dy;
      final segmentColor = isRising ? Colors.red : Colors.blue;
      
      final paint = Paint()
        ..color = segmentColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 직선으로 그리기 (더 명확한 색상 구분)
      canvas.drawLine(startPoint, endPoint, paint);
    }
  }

  void _drawAnimatedArea(Canvas canvas, List<Offset> points, Rect chartArea, Color color) {
    if (points.isEmpty || points.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(points[0].dx, chartArea.bottom);
    path.lineTo(points[0].dx, points[0].dy);

    for (int i = 1; i < (points.length * animationValue).floor(); i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    path.lineTo(points[(points.length * animationValue).floor() - 1].dx, chartArea.bottom);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawAnimatedPoints(Canvas canvas, List<Offset> points, List<DailyForeignSummary> sortedData, Color baseColor) {
    if (points.isEmpty || sortedData.isEmpty) return;
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final maxIndex = (points.length * animationValue).floor().clamp(0, points.length);
    for (int i = 0; i < maxIndex; i++) {
      if (i >= points.length) break;
      
      final point = points[i];
      if (point.dx >= 80 - 10 && point.dx <= 80 + 300 + 10) {
        // 상승/하강에 따른 포인트 색상 결정
        Color pointColor = baseColor; // 기본 색상
        
        if (i > 0 && i < sortedData.length) {
          final prevValue = i > 0 ? sortedData[i - 1].cumulativeHoldings : 0;
          final currentValue = sortedData[i].cumulativeHoldings;
          final isIncrease = currentValue > prevValue;
          pointColor = isIncrease ? Colors.red : Colors.blue;
        }
        
        final pointPaint = Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill;
        
        // 큰 원 그리기
        canvas.drawCircle(point, 4.0, pointPaint);
        canvas.drawCircle(point, 4.0, borderPaint);
        
        // 내부 강조 원 (더 작은 원으로 색상 강조)
        final innerPaint = Paint()
          ..color = pointColor.withOpacity(0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(point, 2.0, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}