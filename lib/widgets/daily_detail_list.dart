import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/foreign_investor_data.dart';
import '../providers/foreign_investor_provider.dart';

class DailyDetailList extends StatefulWidget {
  final List<DailyForeignSummary> dailyData;
  final String selectedMarket;

  const DailyDetailList({
    super.key,
    required this.dailyData,
    required this.selectedMarket,
  });

  @override
  State<DailyDetailList> createState() => _DailyDetailListState();
}

class _DailyDetailListState extends State<DailyDetailList> {
  final ScrollController _scrollController = ScrollController();
  List<DailyForeignSummary> _displayData = [];
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  static const int _pageSize = 7; // 한 번에 로드할 데이터 수

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(DailyDetailList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dailyData != widget.dailyData || 
        oldWidget.selectedMarket != widget.selectedMarket) {
      _initializeData();
    }
  }

  void _initializeData() {
    setState(() {
      _displayData = widget.dailyData.take(_pageSize).toList();
      _hasMoreData = widget.dailyData.length > _pageSize;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 100) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    // 백그라운드에서 추가 데이터 로드
    final provider = Provider.of<ForeignInvestorProvider>(context, listen: false);
    await provider.loadMoreHistoricalData();

    // 시뮬레이션: 네트워크 지연
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      final currentLength = _displayData.length;
      final moreData = widget.dailyData
          .skip(currentLength)
          .take(_pageSize)
          .toList();
      
      _displayData.addAll(moreData);
      _hasMoreData = currentLength + moreData.length < widget.dailyData.length;
      _isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_displayData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              '일별 상세 데이터가 없습니다',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '일별 상세 데이터',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_displayData.length}/${widget.dailyData.length}일',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '날짜',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '시장',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '순매수금액',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '거래금액',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          
          // 데이터 리스트 (스크롤 가능)
          SizedBox(
            height: 280, // 고정 높이
            child: _displayData.isEmpty 
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        '표시할 데이터가 없습니다',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: _displayData.length + (_hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _displayData.length) {
                        final data = _displayData[index];
                        return _buildDataRow(data, index);
                      } else {
                        // 로딩 인디케이터
                        return _buildLoadingIndicator();
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '추가 데이터 로딩 중...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(DailyForeignSummary data, int index) {
    final isEvenRow = index % 2 == 0;
    final netAmount = data.totalForeignNetAmount;
    final tradeAmount = data.foreignTotalTradeAmount;
    final isPositive = netAmount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // 날짜
          Expanded(
            flex: 2,
            child: Text(
              _formatDate(data.date),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          
          // 시장
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: data.marketType == 'KOSPI' 
                    ? Colors.blue.shade100 
                    : data.marketType == 'KOSDAQ'
                        ? Colors.orange.shade100
                        : Colors.purple.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                data.marketType == 'ALL' ? '전체' : data.marketType,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: data.marketType == 'KOSPI' 
                      ? Colors.blue.shade700 
                      : data.marketType == 'KOSDAQ'
                          ? Colors.orange.shade700
                          : Colors.purple.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          // 순매수금액
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: isPositive ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatAmount(netAmount.abs()),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          // 거래금액
          Expanded(
            flex: 3,
            child: Text(
              _formatAmount(tradeAmount),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      if (date.length == 8) {
        final month = date.substring(4, 6);
        final day = date.substring(6, 8);
        return '$month/$day';
      }
      return date;
    } catch (e) {
      return date;
    }
  }

  String _formatAmount(int amount) {
    if (amount == 0) return '0';
    
    if (amount >= 1000000000000) { // 1조 이상
      return '${(amount / 1000000000000).toStringAsFixed(1)}조';
    } else if (amount >= 100000000) { // 1억 이상
      return '${(amount / 100000000).toStringAsFixed(0)}억';
    } else if (amount >= 10000) { // 1만 이상
      return '${(amount / 10000).toStringAsFixed(0)}만';
    } else {
      return amount.toString();
    }
  }
}