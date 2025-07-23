import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/foreign_investor_provider.dart';
import '../widgets/market_summary_card.dart';
import '../widgets/top_stocks_list.dart';
import '../widgets/daily_trend_chart.dart';
import '../widgets/daily_detail_list.dart';
import '../widgets/filter_chips.dart';
import '../services/foreign_investor_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '국내주식 수급 동향 모니터 현황',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ForeignInvestorProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: provider.isLoading ? null : () => provider.refresh(),
                tooltip: '새로고침',
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '외국인 수급', icon: Icon(Icons.dashboard)),
            Tab(text: '기관 수급', icon: Icon(Icons.trending_up)),
            Tab(text: '원달러 환율', icon: Icon(Icons.show_chart)),
          ],
        ),
      ),
      body: Consumer<ForeignInvestorProvider>(
        builder: (context, provider, child) {
          // 에러 표시
          if (provider.errorMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.errorMessage!),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: '확인',
                    textColor: Colors.white,
                    onPressed: provider.dismissError,
                  ),
                ),
              );
            });
          }

          return Stack(
            children: [
              Column(
                children: [
                  // 필터 칩들
                  const FilterChips(),
                  
                  // 탭 컨텐츠
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSummaryTab(provider),
                        _buildStocksTab(provider),
                        _buildChartTab(provider),
                      ],
                    ),
                  ),
                ],
              ),
              
              // 로딩 오버레이
              if (provider.isLoading)
                Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: Card(
                      elevation: 8,
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(height: 24),
                            Text(
                              '잠시만 기다려주십시오',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '데이터를 조회중입니다...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryTab(ForeignInvestorProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 기준 날짜 표시
          _buildDateRangeCard(context, provider),
          
          // 실제 데이터 기준 날짜 안내
          if (provider.actualDataDate != null) 
            _buildDataSourceNotice(context, provider),
          
          const SizedBox(height: 16),
          
          // 전체 시장 요약
          MarketSummaryCard(
            title: '전체 외국인 순매수',
            amount: provider.totalForeignNetAmount,
            isPositive: provider.isForeignBuyDominant,
            subtitle: provider.isForeignBuyDominant ? '매수 우세' : '매도 우세',
          ),
          
          const SizedBox(height: 16),
          
          // KOSPI/KOSDAQ 분리 요약
          if (provider.selectedMarket == 'ALL') ...[
            Row(
              children: [
                Expanded(
                  child: _buildMarketCard(
                    'KOSPI',
                    provider.getKospiSummary(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMarketCard(
                    'KOSDAQ',
                    provider.getKosdaqSummary(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // 외국인 순매수 상위
          TopStocksList(
            title: '외국인 순매수 상위',
            stocks: provider.topBuyStocks,
            isPositive: true,
          ),
          
          const SizedBox(height: 16),
          
          // 외국인 순매도 상위
          TopStocksList(
            title: '외국인 순매도 상위',
            stocks: provider.topSellStocks,
            isPositive: false,
          ),
          
          const SizedBox(height: 16),
          
          // 외국인 매매 현황 그래프 (최근 1개월)
          DailyTrendChart(
            summaryData: provider.getForeignHoldingsTrendData(),
            selectedMarket: 'ALL',
          ),
          
          const SizedBox(height: 16),
          
          // 일별 상세 데이터 (최근 1주일, 스크롤 가능)
          DailyDetailList(
            dailyData: provider.getWeeklySummaryForChart(),
            selectedMarket: provider.selectedMarket,
          ),
        ],
      ),
    );
  }

  Widget _buildStocksTab(ForeignInvestorProvider provider) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '기관 수급 데이터를 준비 중입니다...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildChartTab(ForeignInvestorProvider provider) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          '원달러 환율 데이터를 준비 중입니다...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildMarketCard(String market, List<dynamic> summaryList) {
    if (summaryList.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                market,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('데이터 없음'),
            ],
          ),
        ),
      );
    }

    final latestSummary = summaryList.first;
    final netAmount = latestSummary.totalForeignNetAmount;
    final isPositive = netAmount > 0;

    return Card(
      color: isPositive
          ? Colors.red[50]
          : netAmount < 0
              ? Colors.blue[50]
              : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              market,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Provider.of<ForeignInvestorProvider>(context, listen: false)
                  .formatAmount(netAmount),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPositive
                    ? Colors.red
                    : netAmount < 0
                        ? Colors.blue
                        : Colors.grey,
              ),
            ),
            Text(
              isPositive ? '순매수' : '순매도',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeCard(BuildContext context, ForeignInvestorProvider provider) {
    final dateRange = provider.getCurrentDateRange();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              '기준일자 : ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () => _showDatePicker(context, provider, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dateRange['fromDate']!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Text(
              ' ~ ',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            GestureDetector(
              onTap: () => _showDatePicker(context, provider, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dateRange['toDate']!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourceNotice(BuildContext context, ForeignInvestorProvider provider) {
    if (provider.actualDataDate == null) return const SizedBox();
    
    // 오늘 날짜와 실제 데이터 날짜 비교
    final today = DateTime.now();
    final todayString = DateFormat('yyyyMMdd').format(today);
    final actualDate = provider.actualDataDate!;
    
    // 실제 데이터 날짜가 오늘과 다르면 안내 메시지 표시
    if (actualDate != todayString) {
      final displayDate = ForeignInvestorService.formatDateForDisplay(actualDate);
      
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '해당 ${displayDate} 기준의 데이터입니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Future<void> _showDatePicker(BuildContext context, ForeignInvestorProvider provider, bool isFromDate) async {
    final currentDate = isFromDate 
        ? (provider.customFromDate ?? DateTime.now().subtract(const Duration(days: 1)))
        : (provider.customToDate ?? DateTime.now());
    
    final selectedDate = await _showCustomDateDialog(context, currentDate);
    
    if (selectedDate != null) {
      final fromDate = isFromDate 
          ? selectedDate 
          : (provider.customFromDate ?? DateTime.now().subtract(const Duration(days: 1)));
      final toDate = isFromDate 
          ? (provider.customToDate ?? DateTime.now())
          : selectedDate;
      
      if (fromDate.isBefore(toDate) || fromDate.isAtSameMomentAs(toDate)) {
        provider.setCustomDateRange(fromDate, toDate);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시작일은 종료일보다 이전이어야 합니다')),
        );
      }
    }
  }

  Future<DateTime?> _showCustomDateDialog(BuildContext context, DateTime initialDate) async {
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;
    int selectedDay = initialDate.day;
    
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentYear = DateTime.now().year;
            final years = List.generate(3, (index) => currentYear - index);
            final months = List.generate(12, (index) => index + 1);
            final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
            final days = List.generate(daysInMonth, (index) => index + 1);
            
            // 선택된 일이 해당 월의 일 수를 초과하면 조정
            if (selectedDay > daysInMonth) {
              selectedDay = daysInMonth;
            }
            
            return AlertDialog(
              title: const Text('날짜 선택'),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            value: selectedYear,
                            items: years.map((year) => DropdownMenuItem(
                              value: year,
                              child: Text('${year}년'),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedYear = value;
                                  // 윤년 처리 등을 위해 일 수 다시 계산
                                  final newDaysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
                                  if (selectedDay > newDaysInMonth) {
                                    selectedDay = newDaysInMonth;
                                  }
                                });
                              }
                            },
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<int>(
                            value: selectedMonth,
                            items: months.map((month) => DropdownMenuItem(
                              value: month,
                              child: Text('${month}월'),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedMonth = value;
                                  // 월이 바뀌면 일 수도 다시 계산
                                  final newDaysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
                                  if (selectedDay > newDaysInMonth) {
                                    selectedDay = newDaysInMonth;
                                  }
                                });
                              }
                            },
                            isExpanded: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButton<int>(
                            value: selectedDay,
                            items: days.map((day) => DropdownMenuItem(
                              value: day,
                              child: Text('${day}일'),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedDay = value;
                                });
                              }
                            },
                            isExpanded: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    final selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);
                    Navigator.of(context).pop(selectedDate);
                  },
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Widget _buildSimpleLineChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox();
    
    return _InteractiveChart(data: data);
  }

  Widget _buildDataTile(dynamic data) {
    final isStock = data.ticker != null;
    final isPositive = data.netAmount > 0;
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        isStock 
            ? '${data.stockName ?? data.ticker} (${data.ticker})'
            : '${data.marketType} 전체',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${data.investorType} • ${Provider.of<ForeignInvestorProvider>(context, listen: false).formatDateForDisplay(data.date)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Provider.of<ForeignInvestorProvider>(context, listen: false)
                .formatAmount(data.netAmount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.red : Colors.blue,
            ),
          ),
          Text(
            isPositive ? '순매수' : '순매도',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int maxValue;
  final int minValue;
  final int range;

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // 안전한 범위 계산
    final safeRange = range == 0 ? 1 : range;
    
    // 제로 라인 그리기
    double zeroY;
    if (minValue <= 0 && maxValue >= 0) {
      zeroY = size.height - ((-minValue) / safeRange) * size.height;
    } else {
      zeroY = minValue >= 0 ? size.height : 0;
    }
    
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      gridPaint..strokeWidth = 1.0,
    );

    final points = <Offset>[];

    // 포인트 계산
    for (int i = 0; i < data.length; i++) {
      final value = data[i]['total'] as int? ?? 0;
      final x = data.length == 1 
          ? size.width / 2 
          : (i / (data.length - 1)) * size.width;
      final y = size.height - ((value - minValue) / safeRange) * size.height;

      points.add(Offset(x, y.clamp(0.0, size.height)));
    }

    // 라인 그리기 (전일 대비 증감에 따라 색상 결정)
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final currentValue = data[i]['total'] as int? ?? 0;
        final nextValue = data[i + 1]['total'] as int? ?? 0;
        final isIncreasing = nextValue > currentValue;
        
        paint.color = isIncreasing ? Colors.red : Colors.blue;
        
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    // 데이터 포인트 그리기 (전일 대비 증감에 따라 색상 결정)
    for (int i = 0; i < points.length; i++) {
      Color pointColor;
      
      if (i == 0) {
        // 첫 번째 점은 다음 점과 비교
        final currentValue = data[i]['total'] as int? ?? 0;
        final nextValue = i + 1 < data.length ? (data[i + 1]['total'] as int? ?? 0) : currentValue;
        pointColor = nextValue > currentValue ? Colors.red : Colors.blue;
      } else {
        // 이전 점과 비교
        final currentValue = data[i]['total'] as int? ?? 0;
        final prevValue = data[i - 1]['total'] as int? ?? 0;
        pointColor = currentValue > prevValue ? Colors.red : Colors.blue;
      }
      
      fillPaint.color = pointColor;
      canvas.drawCircle(points[i], 3.0, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _InteractiveChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;

  const _InteractiveChart({required this.data});

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  double _scale = 1.0;
  double _panX = 0.0;
  double _lastPanX = 0.0;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox();

    final values = widget.data.map((d) => d['total'] as int).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    return GestureDetector(
      onScaleStart: (details) {
        _lastPanX = _panX;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.5, 3.0);
          
          if (details.scale == 1.0) {
            // 팬 제스처
            _panX = _lastPanX + details.focalPointDelta.dx;
            
            // 팬 범위 제한
            final maxPan = (widget.data.length * _scale - widget.data.length) * 20;
            _panX = _panX.clamp(-maxPan, 0);
          }
        });
      },
      child: ClipRect(
        child: Stack(
          children: [
            // 차트 영역
            CustomPaint(
              size: const Size(double.infinity, 200),
              painter: _InteractiveLineChartPainter(
                data: widget.data,
                maxValue: maxValue,
                minValue: minValue,
                range: range,
                scale: _scale,
                panX: _panX,
              ),
            ),
            // Y축 라벨 (왼쪽)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 60,
              child: _buildYAxisLabels(minValue, maxValue),
            ),
            // X축 라벨 (하단)
            Positioned(
              left: 60,
              right: 0,
              bottom: 0,
              height: 20,
              child: _buildXAxisLabels(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYAxisLabels(int minValue, int maxValue) {
    final steps = 5;
    final stepValue = (maxValue - minValue) / steps;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(steps + 1, (index) {
        final value = maxValue - (stepValue * index);
        final displayValue = (value / 10000000000).toStringAsFixed(0); // 100억원 단위
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
    final visibleDataCount = (widget.data.length / _scale).round().clamp(3, widget.data.length);
    final step = (widget.data.length / visibleDataCount).round().clamp(1, widget.data.length);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(visibleDataCount, (index) {
        final dataIndex = (index * step).clamp(0, widget.data.length - 1);
        final date = widget.data[dataIndex]['date'] as String;
        final displayDate = '${date.substring(4, 6)}/${date.substring(6, 8)}';
        
        return Text(
          displayDate,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        );
      }),
    );
  }
}

class _InteractiveLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int maxValue;
  final int minValue;
  final int range;
  final double scale;
  final double panX;

  _InteractiveLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.range,
    required this.scale,
    required this.panX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    // 차트 영역 (Y축 라벨과 X축 라벨 공간 제외)
    final chartArea = Rect.fromLTWH(60, 0, size.width - 60, size.height - 20);
    
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // 클리핑 적용
    canvas.clipRect(chartArea);

    // 안전한 범위 계산
    final safeRange = range == 0 ? 1 : range;
    
    // 제로 라인 그리기 (차트 영역 내에서)
    double zeroY;
    if (minValue <= 0 && maxValue >= 0) {
      zeroY = chartArea.height - ((-minValue) / safeRange) * chartArea.height;
    } else {
      zeroY = minValue >= 0 ? chartArea.height : 0;
    }
    
    canvas.drawLine(
      Offset(chartArea.left, zeroY),
      Offset(chartArea.right, zeroY),
      gridPaint..strokeWidth = 1.0,
    );

    // 격자 그리기
    for (int i = 1; i < 5; i++) {
      final y = chartArea.height * i / 5;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    final points = <Offset>[];
    final scaledWidth = chartArea.width * scale;
    final pointSpacing = scaledWidth / (data.length - 1);

    // 포인트 계산 (스케일과 팬 적용)
    for (int i = 0; i < data.length; i++) {
      final value = data[i]['total'] as int? ?? 0;
      final x = chartArea.left + panX + (i * pointSpacing);
      final y = chartArea.height - ((value - minValue) / safeRange) * chartArea.height;

      points.add(Offset(x, y.clamp(0.0, chartArea.height)));
    }

    // 라인 그리기
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final currentValue = data[i]['total'] as int? ?? 0;
        final nextValue = data[i + 1]['total'] as int? ?? 0;
        final isIncreasing = nextValue > currentValue;
        
        paint.color = isIncreasing ? Colors.red : Colors.blue;
        
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    // 데이터 포인트 그리기
    for (int i = 0; i < points.length; i++) {
      // 화면에 보이는 포인트만 그리기
      if (points[i].dx >= chartArea.left - 10 && points[i].dx <= chartArea.right + 10) {
        Color pointColor;
        
        if (i == 0) {
          final currentValue = data[i]['total'] as int? ?? 0;
          final nextValue = i + 1 < data.length ? (data[i + 1]['total'] as int? ?? 0) : currentValue;
          pointColor = nextValue > currentValue ? Colors.red : Colors.blue;
        } else {
          final currentValue = data[i]['total'] as int? ?? 0;
          final prevValue = data[i - 1]['total'] as int? ?? 0;
          pointColor = currentValue > prevValue ? Colors.red : Colors.blue;
        }
        
        fillPaint.color = pointColor;
        canvas.drawCircle(points[i], 3.0, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

