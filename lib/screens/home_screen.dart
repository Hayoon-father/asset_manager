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
          '외국인 수급현황',
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
            Tab(text: '요약', icon: Icon(Icons.dashboard)),
            Tab(text: '종목', icon: Icon(Icons.trending_up)),
            Tab(text: '차트', icon: Icon(Icons.show_chart)),
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
          
          // 최근 데이터 리스트
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최근 거래 현황',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.latestData.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('데이터가 없습니다'),
                      ),
                    )
                  else
                    ...provider.latestData.take(10).map(
                          (data) => _buildDataTile(data),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStocksTab(ForeignInvestorProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
        ],
      ),
    );
  }

  Widget _buildChartTab(ForeignInvestorProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DailyTrendChart(
            summaryData: provider.dailySummary,
            selectedMarket: provider.selectedMarket,
          ),
        ],
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