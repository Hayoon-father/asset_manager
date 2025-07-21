import 'package:flutter/foundation.dart';
import '../models/foreign_investor_data.dart';
import '../services/foreign_investor_service.dart';

class ForeignInvestorProvider with ChangeNotifier {
  final ForeignInvestorService _service = ForeignInvestorService();
  
  // 상태 변수들
  bool _isLoading = false;
  String? _errorMessage;
  
  // 데이터 변수들
  List<ForeignInvestorData> _latestData = [];
  List<DailyForeignSummary> _dailySummary = [];
  List<ForeignInvestorData> _topBuyStocks = [];
  List<ForeignInvestorData> _topSellStocks = [];
  
  String _selectedMarket = 'ALL'; // ALL, KOSPI, KOSDAQ
  String _selectedDateRange = '7D'; // 1D, 7D, 30D, 3M
  
  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ForeignInvestorData> get latestData => _latestData;
  List<DailyForeignSummary> get dailySummary => _dailySummary;
  List<ForeignInvestorData> get topBuyStocks => _topBuyStocks;
  List<ForeignInvestorData> get topSellStocks => _topSellStocks;
  String get selectedMarket => _selectedMarket;
  String get selectedDateRange => _selectedDateRange;
  
  // 최근 총 외국인 순매수 금액 (KOSPI + KOSDAQ)
  int get totalForeignNetAmount {
    if (_dailySummary.isEmpty) return 0;
    
    // 가장 최근 날짜의 데이터 합계
    final latestDate = _dailySummary.first.date;
    return _dailySummary
        .where((summary) => summary.date == latestDate)
        .fold<int>(0, (sum, summary) => sum + summary.totalForeignNetAmount);
  }
  
  // 외국인 매수/매도 우세 여부
  bool get isForeignBuyDominant => totalForeignNetAmount > 0;
  
  ForeignInvestorProvider() {
    _initializeData();
    _startRealtimeSubscription();
  }
  
  // 초기 데이터 로드
  Future<void> _initializeData() async {
    await loadLatestData();
    await loadDailySummary();
    await loadTopStocks();
  }
  
  // 실시간 데이터 구독
  void _startRealtimeSubscription() {
    _service.startRealtimeSubscription();
    _service.dataStream.listen(
      (data) {
        if (data.isNotEmpty) {
          _latestData = data;
          notifyListeners();
        }
      },
      onError: (error) {
        _setError('실시간 데이터 구독 오류: $error');
      },
    );
  }
  
  // 최신 데이터 로드
  Future<void> loadLatestData() async {
    _setLoading(true);
    _clearError();
    
    try {
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      _latestData = await _service.getLatestForeignInvestorData(
        marketType: marketFilter,
        limit: 50,
      );
      
    } catch (e) {
      _setError('최신 데이터 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 일별 요약 데이터 로드
  Future<void> loadDailySummary() async {
    try {
      final days = _getDaysFromRange(_selectedDateRange);
      final startDate = ForeignInvestorService.getDaysAgoString(days);
      
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      _dailySummary = await _service.getDailyForeignSummary(
        startDate: startDate,
        marketType: marketFilter,
        limit: days,
      );
      
    } catch (e) {
      _setError('일별 요약 데이터 로드 실패: $e');
    }
  }
  
  // 상위 종목 데이터 로드
  Future<void> loadTopStocks() async {
    try {
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      // 병렬로 상위 매수/매도 종목 조회
      final futures = await Future.wait([
        _service.getTopForeignStocks(marketType: marketFilter, limit: 10),
        _service.getTopForeignSellStocks(marketType: marketFilter, limit: 10),
      ]);
      
      _topBuyStocks = futures[0];
      _topSellStocks = futures[1];
      
    } catch (e) {
      _setError('상위 종목 데이터 로드 실패: $e');
    }
  }
  
  // 특정 날짜 데이터 조회 (더미 구현)
  Future<List<ForeignInvestorData>> getDataByDate(String date) async {
    try {
      // 더미 데이터 반환
      return [];
    } catch (e) {
      _setError('날짜별 데이터 조회 실패: $e');
      return [];
    }
  }
  
  // 종목별 히스토리 조회 (더미 구현)
  Future<List<ForeignInvestorData>> getStockHistory(String ticker) async {
    try {
      // 더미 데이터 반환
      return [];
    } catch (e) {
      _setError('종목 히스토리 조회 실패: $e');
      return [];
    }
  }
  
  // 시장 필터 변경
  void setMarketFilter(String market) {
    if (_selectedMarket != market) {
      _selectedMarket = market;
      notifyListeners();
      _refreshAllData();
    }
  }
  
  // 날짜 범위 변경
  void setDateRange(String range) {
    if (_selectedDateRange != range) {
      _selectedDateRange = range;
      notifyListeners();
      _refreshAllData();
    }
  }
  
  // 수동 새로고침
  Future<void> refresh() async {
    await _refreshAllData();
  }
  
  // 모든 데이터 새로고침
  Future<void> _refreshAllData() async {
    _setLoading(true);
    
    try {
      await Future.wait([
        loadLatestData(),
        loadDailySummary(),
        loadTopStocks(),
      ]);
    } catch (e) {
      _setError('데이터 새로고침 실패: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // 날짜 범위를 일수로 변환
  int _getDaysFromRange(String range) {
    switch (range) {
      case '1D':
        return 1;
      case '7D':
        return 7;
      case '30D':
        return 30;
      case '3M':
        return 90;
      default:
        return 7;
    }
  }
  
  // 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  // 에러 메시지 설정
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }
  
  // 에러 메시지 클리어
  void _clearError() {
    _errorMessage = null;
  }
  
  // 에러 메시지 무시
  void dismissError() {
    _clearError();
    notifyListeners();
  }
  
  // 유틸리티 메서드들
  String formatAmount(int amount) {
    return ForeignInvestorService.formatAmount(amount);
  }
  
  String formatDateForDisplay(String date) {
    return ForeignInvestorService.formatDateForDisplay(date);
  }
  
  // KOSPI/KOSDAQ별 데이터 필터링
  List<DailyForeignSummary> getKospiSummary() {
    return _dailySummary.where((s) => s.marketType == 'KOSPI').toList();
  }
  
  List<DailyForeignSummary> getKosdaqSummary() {
    return _dailySummary.where((s) => s.marketType == 'KOSDAQ').toList();
  }
  
  // 최근 n일 순매수 추이 데이터
  List<Map<String, dynamic>> getNetAmountTrend(int days) {
    final filteredSummary = _dailySummary.take(days).toList();
    final result = <String, Map<String, int>>{};
    
    // 날짜별로 KOSPI + KOSDAQ 합계 계산
    for (final summary in filteredSummary) {
      final date = summary.date;
      if (!result.containsKey(date)) {
        result[date] = {'KOSPI': 0, 'KOSDAQ': 0, 'TOTAL': 0};
      }
      result[date]![summary.marketType] = summary.totalForeignNetAmount;
      result[date]!['TOTAL'] = 
          (result[date]!['KOSPI'] ?? 0) + (result[date]!['KOSDAQ'] ?? 0);
    }
    
    return result.entries
        .map((entry) => {
              'date': entry.key,
              'kospi': entry.value['KOSPI'],
              'kosdaq': entry.value['KOSDAQ'],
              'total': entry.value['TOTAL'],
            })
        .toList();
  }
  
  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}