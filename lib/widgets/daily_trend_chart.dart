import 'package:flutter/material.dart';
import '../models/foreign_investor_data.dart';

class DailyTrendChart extends StatefulWidget {
  final List<DailyForeignSummary> summaryData;
  final String selectedMarket;

  const DailyTrendChart({
    super.key,
    required this.summaryData,
    required this.selectedMarket,
  });

  @override
  State<DailyTrendChart> createState() => _DailyTrendChartState();
}

class _DailyTrendChartState extends State<DailyTrendChart> {
  double _scale = 1.0;
  double _panX = 0.0;
  double _lastPanX = 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.summaryData.isEmpty) {
      return Card(
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text('차트 데이터가 없습니다'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '외국인 주식보유 총액 추이',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // 범례
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const Text(' 보유 총액  ', style: TextStyle(fontSize: 12)),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const Text(' 증감 추세', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '← 과거 날짜     |     최신 날짜 →',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _buildStockStyleChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStyleChart() {
    return GestureDetector(
      onScaleStart: (details) {
        _lastPanX = _panX;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.5, 5.0);
          
          if (details.scale == 1.0) {
            // 팬 제스처 (좌측으로 이동하면 과거 데이터 조회)
            _panX = _lastPanX + details.focalPointDelta.dx;
            
            // 팬 범위 제한
            final maxPan = (widget.summaryData.length * _scale - widget.summaryData.length) * 20;
            _panX = _panX.clamp(-maxPan, 0);
          }
        });
      },
      child: ClipRect(
        child: Stack(
          children: [
            // 차트 영역
            CustomPaint(
              size: const Size(double.infinity, 300),
              painter: _StockStyleChartPainter(
                data: widget.summaryData,
                scale: _scale,
                panX: _panX,
              ),
            ),
            // Y축 라벨 (왼쪽)
            Positioned(
              left: 0,
              top: 0,
              bottom: 30,
              width: 80,
              child: _buildYAxisLabels(),
            ),
            // X축 라벨 (하단)
            Positioned(
              left: 80,
              right: 0,
              bottom: 0,
              height: 30,
              child: _buildXAxisLabels(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYAxisLabels() {
    final values = widget.summaryData.map((d) => d.cumulativeHoldings).toList();
    if (values.isEmpty) return const SizedBox();
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    
    final steps = 6;
    final stepValue = (maxValue - minValue) / steps;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(steps + 1, (index) {
        final value = maxValue - (stepValue * index);
        final displayValue = (value / 1000000000000).toStringAsFixed(1); // 1조원 단위
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            '${displayValue}조',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        );
      }),
    );
  }

  Widget _buildXAxisLabels() {
    final visibleDataCount = (widget.summaryData.length / _scale).round().clamp(3, widget.summaryData.length);
    final step = (widget.summaryData.length / visibleDataCount).round().clamp(1, widget.summaryData.length);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(visibleDataCount, (index) {
        final dataIndex = (index * step).clamp(0, widget.summaryData.length - 1);
        final date = widget.summaryData[dataIndex].date;
        final displayDate = '${date.substring(4, 6)}/${date.substring(6, 8)}';
        
        return Text(
          displayDate,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        );
      }),
    );
  }
}

class _StockStyleChartPainter extends CustomPainter {
  final List<DailyForeignSummary> data;
  final double scale;
  final double panX;

  _StockStyleChartPainter({
    required this.data,
    required this.scale,
    required this.panX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    // 차트 영역 (Y축 라벨과 X축 라벨 공간 제외)
    final chartArea = Rect.fromLTWH(80, 0, size.width - 80, size.height - 30);
    
    // 페인트 설정

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    final zeroPaint = Paint()
      ..color = Colors.grey.withOpacity(0.8)
      ..strokeWidth = 1.0;

    // 클리핑 적용
    canvas.clipRect(chartArea);

    // 누적 보유액 데이터로 최대/최소값 계산
    final values = data.map((d) => d.cumulativeHoldings).toList();
    if (values.isEmpty) return;
    
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;

    // 기준선 그리기 (최소값 기준)
    final baselineY = chartArea.height;
    
    canvas.drawLine(
      Offset(chartArea.left, baselineY),
      Offset(chartArea.right, baselineY),
      zeroPaint,
    );

    // 격자 그리기
    for (int i = 1; i < 6; i++) {
      final y = chartArea.height * i / 6;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    final scaledWidth = chartArea.width * scale;
    final pointSpacing = data.length > 1 ? scaledWidth / (data.length - 1) : scaledWidth / 2;

    // 포인트 계산 (날짜순 정렬 - 좌측이 과거, 우측이 최신)
    final sortedData = List<DailyForeignSummary>.from(data);
    sortedData.sort((a, b) => a.date.compareTo(b.date));

    final points = <Offset>[];
    final increasingPoints = <Offset>[];
    final decreasingPoints = <Offset>[];

    for (int i = 0; i < sortedData.length; i++) {
      final x = chartArea.left + panX + (i * pointSpacing);
      final value = sortedData[i].cumulativeHoldings;
      final y = chartArea.height - ((value - minValue) / range) * chartArea.height;

      final point = Offset(x, y.clamp(0.0, chartArea.height));
      points.add(point);
      
      // 전일 대비 증감 판단
      if (i > 0) {
        final prevValue = sortedData[i - 1].cumulativeHoldings;
        if (value > prevValue) {
          increasingPoints.add(point);
        } else if (value < prevValue) {
          decreasingPoints.add(point);
        }
      } else {
        // 첫 번째 포인트는 증가로 처리
        increasingPoints.add(point);
      }
    }

    // 보유총액 트렌드 라인 그리기 (굵은 녹색 라인)
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);
      
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      
      final linePaint = Paint()
        ..color = Colors.green
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(path, linePaint);
    }

    // 영역 채우기 (그라데이션)
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points[0].dx, baselineY);
      path.lineTo(points[0].dx, points[0].dy);
      
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      
      path.lineTo(points.last.dx, baselineY);
      path.close();
      
      final fillPaint = Paint()
        ..color = Colors.green.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(path, fillPaint);
    }

    // 증가 포인트 그리기 (녹색 원)
    final increasePointPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    
    for (final point in increasingPoints) {
      if (point.dx >= chartArea.left - 10 && point.dx <= chartArea.right + 10) {
        canvas.drawCircle(point, 3.0, increasePointPaint);
        // 테두리
        canvas.drawCircle(point, 3.0, Paint()
          ..color = Colors.white
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);
      }
    }

    // 감소 포인트 그리기 (오렌지 원)
    final decreasePointPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.fill;
    
    for (final point in decreasingPoints) {
      if (point.dx >= chartArea.left - 10 && point.dx <= chartArea.right + 10) {
        canvas.drawCircle(point, 3.0, decreasePointPaint);
        // 테두리
        canvas.drawCircle(point, 3.0, Paint()
          ..color = Colors.white
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}