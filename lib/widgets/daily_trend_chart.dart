import 'package:flutter/material.dart';
import '../models/foreign_investor_data.dart';

class DailyTrendChart extends StatelessWidget {
  final List<DailyForeignSummary> summaryData;
  final String selectedMarket;

  const DailyTrendChart({
    super.key,
    required this.summaryData,
    required this.selectedMarket,
  });

  @override
  Widget build(BuildContext context) {
    if (summaryData.isEmpty) {
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

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '외국인 순매수 추이',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  child: _buildSimpleChart(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '일별 상세 데이터',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...summaryData.take(10).map((summary) => _buildDataRow(summary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleChart(BuildContext context) {
    // 간단한 막대 차트 구현
    final maxAmount = summaryData
        .map((s) => s.totalForeignNetAmount.abs())
        .fold<int>(0, (max, amount) => amount > max ? amount : max);
    
    if (maxAmount == 0) {
      return const Center(child: Text('데이터가 없습니다'));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: summaryData.length,
      itemBuilder: (context, index) {
        final data = summaryData[index];
        final amount = data.totalForeignNetAmount;
        final isPositive = amount > 0;
        final heightRatio = amount.abs() / maxAmount;
        
        return Container(
          width: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 금액 표시 (작게)
              if (amount != 0)
                Text(
                  _formatAmountShort(amount),
                  style: const TextStyle(fontSize: 8),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 4),
              
              // 막대 차트
              Expanded(
                child: Container(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 24,
                    height: 150 * heightRatio,
                    decoration: BoxDecoration(
                      color: isPositive ? Colors.red : Colors.blue,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 4),
              
              // 날짜 표시
              Text(
                _formatDateShort(data.date),
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataRow(DailyForeignSummary summary) {
    final isPositive = summary.totalForeignNetAmount > 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 날짜
          SizedBox(
            width: 80,
            child: Text(
              _formatDateForDisplay(summary.date),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          
          // 시장
          SizedBox(
            width: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: summary.marketType == 'KOSPI' 
                    ? Colors.blue[100] 
                    : Colors.orange[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                summary.marketType,
                style: TextStyle(
                  fontSize: 10,
                  color: summary.marketType == 'KOSPI' 
                      ? Colors.blue[800] 
                      : Colors.orange[800],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // 순매수 금액
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(summary.totalForeignNetAmount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.red : Colors.blue,
                  ),
                ),
                Text(
                  isPositive ? '순매수' : '순매도',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // 트렌드 아이콘
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? Colors.red : Colors.blue,
            size: 16,
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount == 0) return '0원';
    
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 100000000) { // 1억 이상
      final eok = (absAmount / 100000000);
      return '${sign}${eok.toStringAsFixed(eok == eok.truncate() ? 0 : 1)}억원';
    } else if (absAmount >= 10000) { // 1만 이상
      final man = (absAmount / 10000);
      return '${sign}${man.toStringAsFixed(man == man.truncate() ? 0 : 1)}만원';
    } else {
      return '${sign}${absAmount}원';
    }
  }

  String _formatAmountShort(int amount) {
    if (amount == 0) return '0';
    
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 100000000) { // 1억 이상
      final eok = (absAmount / 100000000);
      return '${sign}${eok.toStringAsFixed(0)}억';
    } else if (absAmount >= 10000) { // 1만 이상
      final man = (absAmount / 10000);
      return '${sign}${man.toStringAsFixed(0)}만';
    } else {
      return '${sign}${(absAmount / 1000).toStringAsFixed(0)}천';
    }
  }

  String _formatDateForDisplay(String date) {
    try {
      final year = date.substring(0, 4);
      final month = date.substring(4, 6);
      final day = date.substring(6, 8);
      return '$month/$day';
    } catch (e) {
      return date;
    }
  }

  String _formatDateShort(String date) {
    try {
      final month = date.substring(4, 6);
      final day = date.substring(6, 8);
      return '$month/$day';
    } catch (e) {
      return date;
    }
  }
}