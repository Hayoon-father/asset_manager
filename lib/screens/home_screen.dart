import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/foreign_investor_provider.dart';
import '../widgets/market_summary_card.dart';
import '../widgets/top_stocks_list.dart';
import '../widgets/daily_trend_chart.dart';
import '../widgets/filter_chips.dart';

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

          return Column(
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
          
          // 일별 트렌드 차트 (항상 1주일치)
          DailyTrendChart(
            summaryData: provider.getWeeklySummaryForChart(),
            selectedMarket: provider.selectedMarket,
          ),
          
          const SizedBox(height: 16),
          
          // 2개월 외국인 순매수 차트
          _buildForeignNetBuyChart(provider),
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

  Widget _buildForeignNetBuyChart(ForeignInvestorProvider provider) {
    final trendData = provider.getNetAmountTrend(60); // 2개월 데이터
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '외국인 순매수 추이 (최근 2개월)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '데이터 포인트: ${trendData.length}개',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (trendData.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('차트 데이터가 없습니다'),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: _buildSimpleLineChart(trendData),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLineChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox();
    
    final values = data.map((d) => d['total'] as int).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    
    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _LineChartPainter(
        data: data,
        maxValue: maxValue,
        minValue: minValue,
        range: range,
      ),
    );
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

    // 라인 그리기
    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final currentValue = data[i]['total'] as int? ?? 0;
        
        paint.color = currentValue >= 0 ? Colors.red : Colors.blue;
        
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }

    // 데이터 포인트 그리기
    for (int i = 0; i < points.length; i++) {
      final value = data[i]['total'] as int? ?? 0;
      fillPaint.color = value >= 0 ? Colors.red : Colors.blue;
      
      canvas.drawCircle(points[i], 3.0, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}