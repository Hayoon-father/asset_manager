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
  List<DailyForeignSummary> _chartDailySummary = []; // 차트용 고정 1개월 데이터
  List<ForeignInvestorData> _topBuyStocks = [];
  List<ForeignInvestorData> _topSellStocks = [];
  
  String _selectedMarket = 'ALL'; // ALL, KOSPI, KOSDAQ
  String _selectedDateRange = '1D'; // 1D, 7D, 30D, 3M
  DateTime? _customFromDate;
  DateTime? _customToDate;
  
  // 실제 데이터 기준 날짜
  String? _actualDataDate;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ForeignInvestorData> get latestData => _latestData;
  List<DailyForeignSummary> get dailySummary => _dailySummary;
  List<DailyForeignSummary> get chartDailySummary => _chartDailySummary; // 차트용 데이터
  List<ForeignInvestorData> get topBuyStocks => _topBuyStocks;
  List<ForeignInvestorData> get topSellStocks => _topSellStocks;
  String get selectedMarket => _selectedMarket;
  String get selectedDateRange => _selectedDateRange;
  DateTime? get customFromDate => _customFromDate;
  DateTime? get customToDate => _customToDate;
  String? get actualDataDate => _actualDataDate;
  
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
    print('=== 초기 데이터 로드 시작 ===');
    _setLoading(true);
    _clearError();
    
    try {
      print('데이터 로딩 중...');
      await Future.wait([
        loadLatestData(),
        loadDailySummary(),
        loadChartDailySummary(), // 차트용 1개월 데이터 로드
        loadTopStocks(),
      ]);
      print('=== 초기 데이터 로드 완료 ===');
      print('최신 데이터 개수: ${_latestData.length}');
      print('일별 요약 데이터 개수: ${_dailySummary.length}');
      print('차트용 일별 데이터 개수: ${_chartDailySummary.length}');
      print('상위 매수 종목 개수: ${_topBuyStocks.length}');
      print('상위 매도 종목 개수: ${_topSellStocks.length}');
    } catch (e) {
      _setError('초기 데이터 로드 실패: $e');
      print('=== 초기 데이터 로드 실패 ===');
      print('에러: $e');
    } finally {
      _setLoading(false);
      print('로딩 상태 해제됨');
    }
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
      print('최신 데이터 로드 실패: $e');
    }
  }
  
  // 일별 요약 데이터 로드 (기준일자에 따라 변경)
  Future<void> loadDailySummary() async {
    try {
      int days;
      String startDate;
      
      if (_customFromDate != null && _customToDate != null) {
        days = _customToDate!.difference(_customFromDate!).inDays + 1;
        startDate = ForeignInvestorService.getDaysAgoString(days);
      } else {
        days = _getDaysFromRange(_selectedDateRange);
        // 1일치 조회도 최근 3일로 확장 (DB 최신 데이터 확보를 위해)
        final searchDays = days == 1 ? 3 : days;
        startDate = ForeignInvestorService.getDaysAgoString(searchDays);
      }
      
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      // endDate도 명시적으로 전달 (DB에 최신 데이터까지 포함)
      final endDate = ForeignInvestorService.getDaysAgoString(0); // 오늘
      
      print('🔍 일별 요약 데이터 조회: ${startDate} ~ ${endDate}, 시장: ${marketFilter ?? 'ALL'}, ${days}일');
      
      _dailySummary = await _service.getDailyForeignSummary(
        startDate: startDate,
        endDate: endDate,
        marketType: marketFilter,
        limit: days,
      );
      
      // 실제 데이터의 최신 날짜 업데이트
      if (_dailySummary.isNotEmpty) {
        _actualDataDate = _dailySummary.first.date;
        print('📅 실제 데이터 기준 날짜: $_actualDataDate');
      }
      
    } catch (e) {
      _setError('일별 요약 데이터 로드 실패: $e');
      print('일별 요약 데이터 로드 실패: $e');
    }
  }

  // 차트용 고정 1개월 데이터 로드 (기준일자 변경과 무관, 항상 전체 시장)
  Future<void> loadChartDailySummary() async {
    try {
      final days = 30; // 고정 1개월
      final startDate = ForeignInvestorService.getDaysAgoString(days);
      final endDate = ForeignInvestorService.getDaysAgoString(0); // 오늘
      
      print('🔍 차트용 데이터 조회: ${startDate} ~ ${endDate}, 시장: ALL, ${days * 2}일');
      
      // 차트는 항상 전체 시장 데이터 (KOSPI + KOSDAQ 모두)
      _chartDailySummary = await _service.getDailyForeignSummary(
        startDate: startDate,
        endDate: endDate,
        marketType: 'ALL', // 항상 전체
        limit: days * 2, // 충분한 데이터 확보
      );
      
    } catch (e) {
      _setError('차트용 일별 요약 데이터 로드 실패: $e');
      print('차트용 일별 요약 데이터 로드 실패: $e');
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
      print('상위 종목 데이터 로드 실패: $e');
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
      _refreshDataForDateRange();
    }
  }
  
  // 날짜 범위 변경
  void setDateRange(String range) {
    if (_selectedDateRange != range) {
      _selectedDateRange = range;
      _customFromDate = null;
      _customToDate = null;
      notifyListeners();
      _refreshDataForDateRange();
    }
  }

  // 커스텀 날짜 범위 설정
  void setCustomDateRange(DateTime fromDate, DateTime toDate) {
    _customFromDate = fromDate;
    _customToDate = toDate;
    _selectedDateRange = 'CUSTOM';
    notifyListeners();
    _refreshDataForDateRange();
  }

  // 날짜 범위에 따른 데이터 새로고침 (차트 데이터 제외)
  Future<void> _refreshDataForDateRange() async {
    _setLoading(true);
    _clearError();
    
    try {
      // 6가지 데이터 새로고침 (차트는 시장 필터와 무관하게 별도 관리)
      await Future.wait([
        _loadLatestDataForDateRange(), // 1) 전체 외국인 순매수
        _loadDailySummaryForDateRange(), // 2) 코스피/코스닥 수급 데이터  
        _loadTopStocksForDateRange(), // 3,4) 순매수/순매도 상위 데이터
        loadChartDailySummary(), // 5) 차트용 2주 데이터 (항상 전체 시장)
      ]);
      
    } catch (e) {
      _setError('날짜 범위 데이터 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 날짜 범위별 최신 데이터 로드
  Future<void> _loadLatestDataForDateRange() async {
    try {
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      // 커스텀 날짜 범위의 모든 데이터 로드
      if (_customFromDate != null && _customToDate != null) {
        final difference = _customToDate!.difference(_customFromDate!).inDays + 1;
        _latestData = await _service.getLatestForeignInvestorData(
          marketType: marketFilter,
          limit: difference * 50, // 일자별로 더 많은 데이터
        );
      } else {
        _latestData = await _service.getLatestForeignInvestorData(
          marketType: marketFilter,
          limit: 50,
        );
      }
      
    } catch (e) {
      _setError('날짜 범위별 최신 데이터 로드 실패: $e');
    }
  }

  // 날짜 범위별 일별 요약 데이터 로드
  Future<void> _loadDailySummaryForDateRange() async {
    await loadDailySummary(); // 기존 메서드 재사용
  }

  // 날짜 범위별 상위 종목 데이터 로드
  Future<void> _loadTopStocksForDateRange() async {
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
      _setError('날짜 범위별 상위 종목 데이터 로드 실패: $e');
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

  // 차트용 1주일치 데이터 (기간 선택과 무관)
  List<DailyForeignSummary> getWeeklySummaryForChart() {
    // 별도로 1주일치 데이터를 가져와야 함
    return _get7DaysSummary();
  }

  // 1주일치 요약 데이터 (내부 메서드)
  List<DailyForeignSummary> _get7DaysSummary() {
    // dailySummary에서 최근 7일치 데이터만 추출
    final allData = List<DailyForeignSummary>.from(_dailySummary);
    allData.sort((a, b) => b.date.compareTo(a.date)); // 최신순 정렬
    return allData.take(7).toList();
  }
  
  // 현재 날짜 범위 정보 가져오기
  Map<String, String> getCurrentDateRange() {
    if (_customFromDate != null && _customToDate != null) {
      return {
        'fromDate': _formatDateForRange(_customFromDate!),
        'toDate': _formatDateForRange(_customToDate!),
      };
    }
    
    final today = DateTime.now();
    final days = _getDaysFromRange(_selectedDateRange);
    final fromDate = today.subtract(Duration(days: days - 1));
    
    return {
      'fromDate': _formatDateForRange(fromDate),
      'toDate': _formatDateForRange(today),
    };
  }
  
  // 날짜를 표시용 문자열로 포맷
  String _formatDateForRange(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  // 외국인 수급 추이 데이터 (고정 1개월간, KOSPI/KOSDAQ 구분, 우측이 최신일)
  List<Map<String, dynamic>> getForeignTrendData() {
    if (_chartDailySummary.isEmpty) return [];
    
    final result = <String, Map<String, int>>{};
    
    // 날짜별로 KOSPI, KOSDAQ 데이터 분리하여 저장
    for (final summary in _chartDailySummary) {
      final date = summary.date;
      if (!result.containsKey(date)) {
        result[date] = {'KOSPI': 0, 'KOSDAQ': 0};
      }
      result[date]![summary.marketType] = summary.totalForeignNetAmount;
    }
    
    // 날짜순 정렬 (과거부터 현재까지 - 차트에서 좌측부터 우측으로)
    final sortedEntries = result.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // 차트 데이터 생성 (좌측이 과거, 우측이 최신)
    final chartData = <Map<String, dynamic>>[];
    
    for (final entry in sortedEntries) {
      chartData.add({
        'date': entry.key,
        'kospi': entry.value['KOSPI']!,
        'kosdaq': entry.value['KOSDAQ']!,
        'total': entry.value['KOSPI']! + entry.value['KOSDAQ']!,
      });
    }
    
    return chartData; // 좌측이 과거, 우측이 최신
  }

  // 외국인 보유 총액 트렌드 데이터 (누적 계산)
  List<DailyForeignSummary> getForeignHoldingsTrendData() {
    if (_chartDailySummary.isEmpty) return [];
    
    // 날짜순 정렬 (과거부터 현재까지)
    final sortedData = List<DailyForeignSummary>.from(_chartDailySummary);
    sortedData.sort((a, b) => a.date.compareTo(b.date));
    
    // KOSPI, KOSDAQ 별로 누적 계산
    final Map<String, int> cumulativeByMarket = {'KOSPI': 0, 'KOSDAQ': 0};
    
    for (final summary in sortedData) {
      // 누적 보유액 계산 (이전 보유액 + 당일 순매수)
      cumulativeByMarket[summary.marketType] = 
          (cumulativeByMarket[summary.marketType] ?? 0) + summary.totalForeignNetAmount;
      
      // 계산된 누적 보유액을 객체에 저장
      summary.cumulativeHoldings = cumulativeByMarket[summary.marketType]!;
    }
    
    return sortedData;
  }
  
  // 기존 메서드 호환성을 위해 유지 (deprecated)
  List<Map<String, dynamic>> getNetAmountTrend(int days) {
    return getForeignTrendData();
  }
  
  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}