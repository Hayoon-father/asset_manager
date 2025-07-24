import 'package:flutter/material.dart';
import '../models/foreign_investor_data.dart';

class TopStocksList extends StatelessWidget {
  final String title;
  final List<ForeignInvestorData> stocks;
  final bool isPositive;

  const TopStocksList({
    super.key,
    required this.title,
    required this.stocks,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.red : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '${stocks.length}개',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stocks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('데이터가 없습니다'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stocks.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stock = stocks[index];
                  return _buildStockTile(context, stock, index + 1);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTile(BuildContext context, ForeignInvestorData stock, int rank) {
    final rankColor = _getRankColor(rank);
    
    return Container(
      height: 72, // 명시적인 높이 설정
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: rankColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rankColor, width: 1),
        ),
        child: Center(
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
        ),
      ),
      title: Text(
        stock.stockName ?? stock.ticker ?? '',
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            stock.ticker ?? '',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: stock.marketType == 'KOSPI' 
                  ? Colors.blue[100] 
                  : Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              stock.marketType,
              style: TextStyle(
                fontSize: 10,
                color: stock.marketType == 'KOSPI' 
                    ? Colors.blue[800] 
                    : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
      trailing: SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatAmount(stock.netAmount.abs()),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.red : Colors.blue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isPositive ? '순매수' : '순매도',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
            if (stock.totalTradeAmount > 0)
              Text(
                '거래: ${_formatAmount(stock.totalTradeAmount)}',
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      onTap: () => _showStockDetails(context, stock),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.orange;
      default:
        return Colors.grey[600]!;
    }
  }

  String _formatAmount(int amount) {
    if (amount >= 100000000) { // 1억 이상
      final eok = (amount / 100000000);
      return '${eok.toStringAsFixed(eok == eok.truncate() ? 0 : 1)}억원';
    } else if (amount >= 10000) { // 1만 이상
      final man = (amount / 10000);
      return '${man.toStringAsFixed(man == man.truncate() ? 0 : 1)}만원';
    } else {
      return '${amount}원';
    }
  }

  void _showStockDetails(BuildContext context, ForeignInvestorData stock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StockDetailsSheet(stock: stock),
    );
  }
}

class _StockDetailsSheet extends StatelessWidget {
  final ForeignInvestorData stock;

  const _StockDetailsSheet({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들러
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 종목 정보
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.stockName ?? stock.ticker ?? '',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stock.ticker} • ${stock.marketType}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stock.isNetBuy ? Colors.red[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stock.isNetBuy ? '순매수' : '순매도',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: stock.isNetBuy ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 거래 정보
            _buildInfoRow('순매수금액', _formatAmount(stock.netAmount)),
            _buildInfoRow('매수금액', _formatAmount(stock.buyAmount)),
            _buildInfoRow('매도금액', _formatAmount(stock.sellAmount)),
            if (stock.buyVolume != null)
              _buildInfoRow('매수거래량', '${_formatVolume(stock.buyVolume!)}주'),
            if (stock.sellVolume != null)
              _buildInfoRow('매도거래량', '${_formatVolume(stock.sellVolume!)}주'),
            if (stock.netVolume != null)
              _buildInfoRow('순매수거래량', '${_formatVolume(stock.netVolume!)}주'),
            
            const SizedBox(height: 16),
            
            // 비율 정보
            if (stock.totalTradeAmount > 0) ...[
              Text(
                '거래 분석',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('매수 비율', '${(stock.buyRatio * 100).toStringAsFixed(1)}%'),
              _buildInfoRow('순매수율', '${(stock.netBuyRatio * 100).toStringAsFixed(1)}%'),
              _buildInfoRow('총 거래금액', _formatAmount(stock.totalTradeAmount)),
            ],
            
            const Spacer(),
            
            // 닫기 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
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

  String _formatVolume(int volume) {
    if (volume >= 10000) {
      final man = (volume / 10000);
      return '${man.toStringAsFixed(man == man.truncate() ? 0 : 1)}만';
    }
    return volume.toString();
  }
}