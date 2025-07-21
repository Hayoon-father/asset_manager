import 'package:flutter/material.dart';

class MarketSummaryCard extends StatelessWidget {
  final String title;
  final int amount;
  final bool isPositive;
  final String subtitle;

  const MarketSummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.isPositive,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = _formatAmount(amount);
    final color = isPositive ? Colors.red : Colors.blue;
    final backgroundColor = isPositive ? Colors.red[50] : Colors.blue[50];

    return Card(
      color: backgroundColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                ),
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formattedAmount,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            _buildProgressBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final color = isPositive ? Colors.red : Colors.blue;
    
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Colors.grey[300],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: 0.7, // 임시로 70%로 설정 (실제로는 비율 계산 필요)
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount == 0) return '0원';
    
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';
    
    if (absAmount >= 1000000000000) { // 1조 이상
      final cho = (absAmount / 1000000000000);
      return '${sign}${cho.toStringAsFixed(cho == cho.truncate() ? 0 : 1)}조원';
    } else if (absAmount >= 100000000) { // 1억 이상
      final eok = (absAmount / 100000000);
      return '${sign}${eok.toStringAsFixed(eok == eok.truncate() ? 0 : 1)}억원';
    } else if (absAmount >= 10000) { // 1만 이상
      final man = (absAmount / 10000);
      return '${sign}${man.toStringAsFixed(man == man.truncate() ? 0 : 1)}만원';
    } else {
      return '${sign}${absAmount}원';
    }
  }
}