import 'package:flutter/foundation.dart';
import '../models/foreign_investor_data.dart';
import '../services/foreign_investor_service.dart';
import '../services/data_sync_service.dart';
import '../services/offline_service.dart';
import '../services/priority_data_service.dart';

class ForeignInvestorProvider with ChangeNotifier {
  final ForeignInvestorService _service = ForeignInvestorService();
  final DataSyncService _syncService = DataSyncService();
  final OfflineService _offlineService = OfflineService();
  final PriorityDataService _priorityService = PriorityDataService();
  
  // 상태 변수들
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDataSyncing = false;
  String? _syncMessage;
  
  // 우선순위 서비스 관련 상태
  DataSource _currentDataSource = DataSource.none;
  String? _priorityMessage;
  
  // 데이터 변수들
  List<ForeignInvestorData> _latestData = [];
  List<DailyForeignSummary> _dailySummary = [];
  List<DailyForeignSummary> _chartDailySummary = []; // 차트용 고정 1개월 데이터
  List<DailyForeignSummary> _historicalDailySummary = []; // 과거 데이터 캐시 (3개월~1년)
  List<DailyForeignSummary> _visibleChartData = []; // 현재 차트에 표시되는 데이터 (점진적 로딩)
  List<DailyForeignSummary> _fixedChartData = []; // 그래프용 고정 데이터 (60일간)
  List<ForeignInvestorData> _topBuyStocks = [];
  List<ForeignInvestorData> _topSellStocks = [];
  
  // 백그라운드 캐싱 상태
  bool _isCachingHistoricalData = false;
  
  String _selectedMarket = 'ALL'; // ALL, KOSPI, KOSDAQ
  String _selectedDateRange = '1D'; // 1D, 7D, 30D, 3M
  DateTime? _customFromDate;
  DateTime? _customToDate;
  
  // 실제 데이터 기준 날짜
  String? _actualDataDate;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isDataSyncing => _isDataSyncing;
  String? get syncMessage => _syncMessage;
  List<ForeignInvestorData> get latestData => _latestData;
  List<DailyForeignSummary> get dailySummary => _dailySummary;
  List<DailyForeignSummary> get chartDailySummary => _chartDailySummary; // 차트용 데이터
  List<DailyForeignSummary> get historicalDailySummary => _historicalDailySummary;
  List<DailyForeignSummary> get fixedChartData => _fixedChartData; // 그래프용 고정 데이터
  List<ForeignInvestorData> get topBuyStocks => _topBuyStocks;
  List<ForeignInvestorData> get topSellStocks => _topSellStocks;
  bool get isCachingHistoricalData => _isCachingHistoricalData;
  String get selectedMarket => _selectedMarket;
  String get selectedDateRange => _selectedDateRange;
  DateTime? get customFromDate => _customFromDate;
  DateTime? get customToDate => _customToDate;
  String? get actualDataDate => _actualDataDate;
  
  // 우선순위 서비스 관련 Getters
  DataSource get currentDataSource => _currentDataSource;
  String? get priorityMessage => _priorityMessage;
  
  // 선택된 기간 동안의 총 외국인 순매수 금액 (KOSPI + KOSDAQ 합계)
  int get totalForeignNetAmount {
    if (_dailySummary.isEmpty) return 0;
    
    // 선택된 기간의 모든 데이터 합계
    return _dailySummary
        .fold<int>(0, (sum, summary) => sum + summary.totalForeignNetAmount);
  }
  
  // KOSPI 선택된 기간 동안의 거래금액 합계
  int get kospiTotalTradeAmount {
    if (_dailySummary.isEmpty) return 0;
    
    return _dailySummary
        .where((summary) => summary.marketType == 'KOSPI')
        .fold<int>(0, (sum, summary) => sum + summary.foreignTotalTradeAmount);
  }
  
  // KOSDAQ 선택된 기간 동안의 거래금액 합계
  int get kosdaqTotalTradeAmount {
    if (_dailySummary.isEmpty) return 0;
    
    return _dailySummary
        .where((summary) => summary.marketType == 'KOSDAQ')
        .fold<int>(0, (sum, summary) => sum + summary.foreignTotalTradeAmount);
  }
  
  // 선택된 기간 동안의 총 거래금액 (KOSPI + KOSDAQ)
  int get totalTradeAmount {
    return kospiTotalTradeAmount + kosdaqTotalTradeAmount;
  }
  
  // 외국인 매수/매도 우세 여부
  bool get isForeignBuyDominant => totalForeignNetAmount > 0;
  
  ForeignInvestorProvider() {
    _initializeServices();
    _initializeData();
    _startRealtimeSubscription();
  }
  
  // 서비스 초기화
  Future<void> _initializeServices() async {
    await _offlineService.initialize();
    
    // 네트워크 상태 변화 모니터링
    _offlineService.networkStatusStream.listen((isOnline) {
      if (isOnline) {
        _performDataSyncInBackground(); // 온라인 복구 시 자동 동기화
      }
    });
    
    // 우선순위 서비스 동기화 상태 모니터링
    _priorityService.syncStatusStream.listen((status) {
      switch (status) {
        case DataSyncStatus.syncing:
          _priorityMessage = '백그라운드 동기화 중...';
          break;
        case DataSyncStatus.completed:
          _priorityMessage = '동기화 완료';
          break;
        case DataSyncStatus.failed:
          _priorityMessage = '동기화 실패';
          break;
        case DataSyncStatus.idle:
          _priorityMessage = null;
          break;
      }
      notifyListeners();
    });
  }
  
  // 초기 데이터 로드
  Future<void> _initializeData() async {
    _setLoading(true);
    _clearError();
    
    try {
      // 1단계: pykrx 데이터 동기화 (백그라운드)
      _performDataSyncInBackground();
      
      // 2단계: 기존 DB 데이터 로드 (즉시 UI 업데이트)
      await Future.wait([
        loadLatestData(),
        loadDailySummary(),
        loadChartDailySummary(), // 차트용 1개월 데이터 로드
        loadTopStocks(),
      ]);
      
      // 3단계: 백그라운드에서 과거 데이터 캐싱 시작
      _startHistoricalDataCaching();
    } catch (e) {
      _setError('초기 데이터 로드 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  // 백그라운드에서 데이터 동기화 수행 (개선된 버전)
  Future<void> _performDataSyncInBackground() async {
    _isDataSyncing = true;
    _syncMessage = 'pykrx API에서 최신 데이터 확인 중...';
    notifyListeners();
    
    try {
      final syncResult = await _syncService.syncLatestData();
      
      if (syncResult.isSuccessfulSync) {
        // 새로운 데이터가 성공적으로 동기화됨
        _syncMessage = '🎉 ${syncResult.newDataCount}개 새 데이터 동기화 완료';
        
        // UI 즉시 업데이트
        await _refreshAllDataSilently();
        
      } else if (syncResult.hasLatestData) {
        // 이미 최신 데이터 보유 중
        _syncMessage = '✅ 이미 최신 데이터 보유 중';
        
      } else if (syncResult.success) {
        // 성공했지만 새 데이터 없음
        _syncMessage = '📊 ${syncResult.message}';
        
      } else {
        // 동기화 실패
        _syncMessage = '⚠️ ${syncResult.message}';
      }
      
      // 동기화 결과를 로그로 기록
      if (kDebugMode) {
        // 디버그 모드에서만 로그 출력
      }
      
    } catch (e) {
      _syncMessage = '❌ pykrx API 연결 실패 - 기존 데이터 사용';
    } finally {
      _isDataSyncing = false;
      notifyListeners();
      
      // 상황에 따라 메시지 표시 시간 조절
      final displayDuration = _syncMessage?.contains('실패') == true 
          ? const Duration(seconds: 8)  // 실패 시 더 오래 표시
          : const Duration(seconds: 5);
          
      Future.delayed(displayDuration, () {
        _syncMessage = null;
        notifyListeners();
      });
    }
  }

  // 조용한 데이터 새로고침 (로딩 상태 표시 없이)
  Future<void> _refreshAllDataSilently() async {
    try {
      await Future.wait([
        loadLatestData(),
        loadDailySummary(),
        loadChartDailySummary(),
        loadTopStocks(),
      ]);
      notifyListeners();
    } catch (e) {
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
  
  // 최신 데이터 로드 (우선순위 로직 적용)
  Future<void> loadLatestData() async {
    try {
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      // 우선순위 데이터 서비스 사용
      final result = await _priorityService.loadLatestDataWithPriority(
        marketType: marketFilter,
        limit: 50,
      );
      
      if (result.success) {
        _latestData = result.data;
        _currentDataSource = result.source;
        _priorityMessage = result.message;
        
        // actualDataDate 업데이트 (화면 표시용)
        if (result.latestDate != null) {
          _actualDataDate = result.latestDate;
        }
        
        // 데이터 소스에 따른 추가 처리
        switch (result.source) {
          case DataSource.api:
            print('✅ API에서 최신 데이터 로드됨');
            break;
          case DataSource.database:
            print('🗄️ DB에서 데이터 로드됨 (API 실패)');
            break;
          case DataSource.cache:
            print('💾 캐시에서 데이터 로드됨');
            break;
          case DataSource.none:
            print('❌ 데이터 없음');
            break;
        }
        
      } else {
        _setError(result.message);
        _currentDataSource = DataSource.none;
      }
      
    } catch (e) {
      _setError('데이터 로드 실패: $e');
      _currentDataSource = DataSource.none;
    }
  }
  
  // 일별 요약 데이터 로드 (기준일자에 따라 변경)
  Future<void> loadDailySummary() async {
    try {
      int days;
      String startDate;
      
      if (_customFromDate != null && _customToDate != null) {
        try {
          days = _customToDate!.difference(_customFromDate!).inDays + 1;
          startDate = ForeignInvestorService.getDaysAgoString(days);
        } catch (e) {
          // Fall back to default range if custom dates are invalid
          days = _getDaysFromRange(_selectedDateRange);
          final searchDays = days == 1 ? 3 : days;
          startDate = ForeignInvestorService.getDaysAgoString(searchDays);
        }
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
      
      
      _dailySummary = await _service.getDailyForeignSummary(
        startDate: startDate,
        endDate: endDate,
        marketType: marketFilter,
        limit: days,
      );
      
      // 실제 데이터의 최신 날짜 업데이트
      if (_dailySummary.isNotEmpty) {
        _actualDataDate = _dailySummary.first.date;
      }
      
    } catch (e) {
      _setError('일별 요약 데이터 로드 실패: $e');
    }
  }

  // 차트용 고정 1개월 데이터 로드 (기준일자 변경과 무관, 항상 전체 시장)
  Future<void> loadChartDailySummary() async {
    try {
      const days = 30; // 고정 1개월
      final startDate = ForeignInvestorService.getDaysAgoString(days);
      final endDate = ForeignInvestorService.getDaysAgoString(0); // 오늘
      
      
      // 차트는 항상 전체 시장 데이터 (KOSPI + KOSDAQ 모두)
      _chartDailySummary = await _service.getDailyForeignSummary(
        startDate: startDate,
        endDate: endDate,
        marketType: 'ALL', // 항상 전체
        limit: days * 2, // 충분한 데이터 확보
      );
      
      // 초기 표시 데이터는 최근 60일만 설정
      _visibleChartData = List.from(_chartDailySummary);
      
      // 그래프용 고정 데이터 설정 (60일간 고정, loadMoreHistoricalData 영향 받지 않음)
      _fixedChartData = List.from(_chartDailySummary);
      
    } catch (e) {
      _setError('차트용 일별 요약 데이터 로드 실패: $e');
    }
  }
  
  // 상위 종목 데이터 로드 (선택된 기간 기준)
  Future<void> loadTopStocks() async {
    try {
      String? marketFilter;
      if (_selectedMarket != 'ALL') {
        marketFilter = _selectedMarket;
      }
      
      // 선택된 기간 정보 가져오기
      final dateRange = getCurrentDateRange();
      final fromDateStr = dateRange['fromDate'];
      final toDateStr = dateRange['toDate'];
      
      if (fromDateStr == null || toDateStr == null) {
        throw Exception('날짜 범위를 가져올 수 없습니다');
      }
      
      final fromDate = fromDateStr.replaceAll('.', '');
      final toDate = toDateStr.replaceAll('.', '');
      
      
      // 기간별 상위 매수/매도 종목 조회
      final futures = await Future.wait([
        _service.getTopForeignStocksByDateRange(
          fromDate: fromDate,
          toDate: toDate,
          marketType: marketFilter, 
          limit: 10
        ),
        _service.getTopForeignSellStocksByDateRange(
          fromDate: fromDate,
          toDate: toDate,
          marketType: marketFilter, 
          limit: 10
        ),
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
        try {
          final difference = _customToDate!.difference(_customFromDate!).inDays + 1;
          _latestData = await _service.getLatestForeignInvestorData(
            marketType: marketFilter,
            limit: difference * 50, // 일자별로 더 많은 데이터
          );
        } catch (e) {
          // Fall back to default limit if date calculation fails
          _latestData = await _service.getLatestForeignInvestorData(
            marketType: marketFilter,
            limit: 50,
          );
        }
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
      
      // 선택된 기간 정보 가져오기
      final dateRange = getCurrentDateRange();
      final fromDateStr = dateRange['fromDate'];
      final toDateStr = dateRange['toDate'];
      
      if (fromDateStr == null || toDateStr == null) {
        throw Exception('날짜 범위를 가져올 수 없습니다');
      }
      
      final fromDate = fromDateStr.replaceAll('.', '');
      final toDate = toDateStr.replaceAll('.', '');
      
      
      // 기간별 상위 매수/매도 종목 조회 (기간별 메서드 사용)
      final futures = await Future.wait([
        _service.getTopForeignStocksByDateRange(
          fromDate: fromDate,
          toDate: toDate,
          marketType: marketFilter, 
          limit: 10
        ),
        _service.getTopForeignSellStocksByDateRange(
          fromDate: fromDate,
          toDate: toDate,
          marketType: marketFilter, 
          limit: 10
        ),
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
    // chartDailySummary에서 최근 7일치 데이터 추출 (전체 시장)
    return _get7DaysSummary();
  }

  // 1주일치 요약 데이터 (내부 메서드)
  List<DailyForeignSummary> _get7DaysSummary() {
    // chartDailySummary를 사용하여 전체 시장 기준 최근 7일 데이터
    if (_chartDailySummary.isEmpty) return [];
    
    // 날짜별로 그룹화하여 KOSPI + KOSDAQ 합계 데이터 생성
    final Map<String, List<DailyForeignSummary>> groupedByDate = {};
    
    for (final summary in _chartDailySummary) {
      final date = summary.date;
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(summary);
    }
    
    // 날짜별로 KOSPI + KOSDAQ 합계를 계산하여 1개의 DailyForeignSummary 생성
    final weeklyData = <DailyForeignSummary>[];
    
    for (final entry in groupedByDate.entries) {
      final date = entry.key;
      final summaries = entry.value;
      
      int totalNetAmount = 0;
      int totalBuyAmount = 0;
      int totalSellAmount = 0;
      
      for (final summary in summaries) {
        totalNetAmount += summary.totalForeignNetAmount;
        totalBuyAmount += summary.foreignBuyAmount;
        totalSellAmount += summary.foreignSellAmount;
      }
      
      // 합계 데이터로 새로운 DailyForeignSummary 생성
      weeklyData.add(DailyForeignSummary(
        date: date,
        marketType: 'ALL', // 전체 시장
        foreignNetAmount: totalNetAmount, // 외국인 순매수 (일반적으로 totalForeignNetAmount와 동일)
        otherForeignNetAmount: 0, // 기타외국인은 0으로 설정
        totalForeignNetAmount: totalNetAmount,
        foreignBuyAmount: totalBuyAmount,
        foreignSellAmount: totalSellAmount,
      ));
    }
    
    // 최신순 정렬하여 최근 7일 반환
    weeklyData.sort((a, b) => b.date.compareTo(a.date));
    return weeklyData.take(7).toList();
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

  // 외국인 보유 총액 트렌드 데이터 (누적 계산) - 고정 60일 버전
  List<DailyForeignSummary> getForeignHoldingsTrendData() {
    // 고정 차트 데이터 사용 (60일 고정, loadMoreHistoricalData 영향 받지 않음)
    if (_fixedChartData.isEmpty) return [];
    
    // 날짜별로 그룹화하여 KOSPI + KOSDAQ 합계 데이터와 개별 데이터 모두 생성
    final Map<String, List<DailyForeignSummary>> groupedByDate = {};
    
    for (final summary in _fixedChartData) {
      final date = summary.date;
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(summary);
    }
    
    // 날짜순 정렬된 엔트리
    final sortedEntries = groupedByDate.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final result = <DailyForeignSummary>[];
    final Map<String, int> cumulativeByMarket = {'KOSPI': 0, 'KOSDAQ': 0, 'ALL': 0};
    
    for (final entry in sortedEntries) {
      final date = entry.key;
      final summaries = entry.value;
      
      // 각 시장별 데이터 처리
      for (final summary in summaries) {
        final marketType = summary.marketType;
        cumulativeByMarket[marketType] = 
            (cumulativeByMarket[marketType] ?? 0) + summary.totalForeignNetAmount;
        
        // 누적 보유액 저장
        final updatedSummary = DailyForeignSummary(
          date: summary.date,
          marketType: summary.marketType,
          foreignNetAmount: summary.foreignNetAmount,
          otherForeignNetAmount: summary.otherForeignNetAmount,
          totalForeignNetAmount: summary.totalForeignNetAmount,
          foreignBuyAmount: summary.foreignBuyAmount,
          foreignSellAmount: summary.foreignSellAmount,
        );
        updatedSummary.cumulativeHoldings = cumulativeByMarket[marketType]!;
        result.add(updatedSummary);
      }
      
      // 전체 시장 합계 데이터도 추가 (차트에서 통합 뷰용)
      final totalNetAmount = summaries.fold<int>(0, (sum, s) => sum + s.totalForeignNetAmount);
      final totalBuyAmount = summaries.fold<int>(0, (sum, s) => sum + s.foreignBuyAmount);
      final totalSellAmount = summaries.fold<int>(0, (sum, s) => sum + s.foreignSellAmount);
      
      cumulativeByMarket['ALL'] = (cumulativeByMarket['ALL'] ?? 0) + totalNetAmount;
      
      final combinedSummary = DailyForeignSummary(
        date: date,
        marketType: 'ALL',
        foreignNetAmount: totalNetAmount,
        otherForeignNetAmount: 0,
        totalForeignNetAmount: totalNetAmount,
        foreignBuyAmount: totalBuyAmount,
        foreignSellAmount: totalSellAmount,
      );
      combinedSummary.cumulativeHoldings = cumulativeByMarket['ALL']!;
      result.add(combinedSummary);
    }
    
    return result;
  }
  
  // 기존 메서드 호환성을 위해 유지 (deprecated)
  List<Map<String, dynamic>> getNetAmountTrend(int days) {
    return getForeignTrendData();
  }
  
  // 백그라운드에서 과거 데이터 캐싱 시작
  Future<void> _startHistoricalDataCaching() async {
    if (_isCachingHistoricalData) return;
    
    _isCachingHistoricalData = true;
    
    try {
      // 3개월~2년 과거 데이터를 점진적으로 캐싱 (더 많은 데이터 제공)
      final endDate = ForeignInvestorService.getDaysAgoString(90); // 3개월 전부터
      final startDate = ForeignInvestorService.getDaysAgoString(730); // 2년 전까지
      
      
      // 백그라운드에서 실행 (UI 블로킹 방지)
      Future.microtask(() async {
        try {
          _historicalDailySummary = await _service.getDailyForeignSummary(
            startDate: startDate,
            endDate: endDate,
            marketType: 'ALL', // 전체 시장 데이터
            limit: 730, // 2년치
          );
          
        } catch (e) {
        } finally {
          _isCachingHistoricalData = false;
          notifyListeners();
        }
      });
      
    } catch (e) {
      _isCachingHistoricalData = false;
    }
  }

  // 차트에 더 많은 과거 데이터 점진적 추가 (핑거 제스처로 과거 탐색 시 사용)
  Future<void> loadMoreHistoricalData() async {
    
    // 백그라운드 캐싱이 진행 중이면 완료까지 대기
    if (_isCachingHistoricalData) {
      while (_isCachingHistoricalData) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    // 캐시된 과거 데이터를 점진적으로 _visibleChartData에 추가
    if (_historicalDailySummary.isNotEmpty) {
      
      // 현재 표시 중인 데이터의 가장 오래된 날짜 확인
      final currentOldestDate = _visibleChartData.isNotEmpty
          ? _visibleChartData.map((e) => e.date).reduce((a, b) => a.compareTo(b) < 0 ? a : b)
          : '99999999';
      
      // 캐시된 데이터 중에서 현재 표시 데이터보다 오래된 것들만 선택
      final additionalData = _historicalDailySummary
          .where((data) => data.date.compareTo(currentOldestDate) < 0)
          .toList();
      
      if (additionalData.isNotEmpty) {
        // 기존 표시 데이터와 병합
        final combinedData = <DailyForeignSummary>[];
        combinedData.addAll(additionalData); // 과거 데이터 먼저
        combinedData.addAll(_visibleChartData); // 현재 데이터 나중에
        
        // 중복 제거
        final Map<String, DailyForeignSummary> uniqueData = {};
        for (final summary in combinedData) {
          final key = '${summary.date}_${summary.marketType}';
          uniqueData[key] = summary;
        }
        
        _visibleChartData = uniqueData.values.toList();
        
        notifyListeners();
        return;
      }
    }
    
    // 캐시된 데이터가 부족하면 추가로 더 오래된 데이터 로드
    try {
      final endDate = ForeignInvestorService.getDaysAgoString(730); // 2년 전
      final startDate = ForeignInvestorService.getDaysAgoString(1095); // 3년 전
      
      final additionalData = await _service.getDailyForeignSummary(
        startDate: startDate,
        endDate: endDate,
        marketType: 'ALL',
        limit: 365, // 1년치 추가
      );
      
      if (additionalData.isNotEmpty) {
        // 캐시에도 추가
        final combinedCache = <DailyForeignSummary>[];
        combinedCache.addAll(_historicalDailySummary);
        combinedCache.addAll(additionalData);
        
        final Map<String, DailyForeignSummary> uniqueCacheData = {};
        for (final summary in combinedCache) {
          final key = '${summary.date}_${summary.marketType}';
          uniqueCacheData[key] = summary;
        }
        _historicalDailySummary = uniqueCacheData.values.toList();
        
        // 표시 데이터에도 추가
        final combinedVisible = <DailyForeignSummary>[];
        combinedVisible.addAll(additionalData); // 새로운 과거 데이터
        combinedVisible.addAll(_visibleChartData); // 기존 표시 데이터
        
        final Map<String, DailyForeignSummary> uniqueVisibleData = {};
        for (final summary in combinedVisible) {
          final key = '${summary.date}_${summary.marketType}';
          uniqueVisibleData[key] = summary;
        }
        _visibleChartData = uniqueVisibleData.values.toList();
        
        notifyListeners();
      }
    } catch (e) {
    }
    
    // 캐시된 데이터가 있으면 그것을 사용하고, 없으면 실시간 로드
    if (_historicalDailySummary.isNotEmpty) {
      return;
    }
    
    try {
      // 실시간으로 추가 데이터 로드
      final moreStartDate = ForeignInvestorService.getDaysAgoString(60);
      final moreEndDate = ForeignInvestorService.getDaysAgoString(30);
      
      
      final moreData = await _service.getDailyForeignSummary(
        startDate: moreStartDate,
        endDate: moreEndDate,
        marketType: _selectedMarket != 'ALL' ? _selectedMarket : null,
        limit: 30,
      );
      
      // 기존 데이터와 병합 (중복 제거)
      final combinedData = [..._dailySummary, ...moreData];
      final uniqueData = <String, DailyForeignSummary>{};
      
      for (final data in combinedData) {
        final key = '${data.date}_${data.marketType}';
        uniqueData[key] = data;
      }
      
      _historicalDailySummary = uniqueData.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      
      
    } catch (e) {
    }
  }

  // 확장된 주간 요약 데이터 (캐시 포함)
  List<DailyForeignSummary> getExtendedWeeklySummaryForChart() {
    // 현재 데이터 + 캐시된 과거 데이터 병합
    final allData = <String, DailyForeignSummary>{};
    
    // 현재 데이터 추가
    for (final summary in _chartDailySummary) {
      final key = '${summary.date}_${summary.marketType}';
      allData[key] = summary;
    }
    
    // 캐시된 과거 데이터 추가
    for (final summary in _historicalDailySummary) {
      final key = '${summary.date}_${summary.marketType}';
      if (!allData.containsKey(key)) {
        allData[key] = summary;
      }
    }
    
    // 날짜별로 그룹화하여 전체 시장 기준 데이터 생성
    final Map<String, List<DailyForeignSummary>> groupedByDate = {};
    
    for (final summary in allData.values) {
      final date = summary.date;
      if (!groupedByDate.containsKey(date)) {
        groupedByDate[date] = [];
      }
      groupedByDate[date]!.add(summary);
    }
    
    // 날짜별로 KOSPI + KOSDAQ 합계를 계산하여 1개의 DailyForeignSummary 생성
    final extendedData = <DailyForeignSummary>[];
    
    for (final entry in groupedByDate.entries) {
      final date = entry.key;
      final summaries = entry.value;
      
      int totalNetAmount = 0;
      int totalBuyAmount = 0;
      int totalSellAmount = 0;
      
      for (final summary in summaries) {
        totalNetAmount += summary.totalForeignNetAmount;
        totalBuyAmount += summary.foreignBuyAmount;
        totalSellAmount += summary.foreignSellAmount;
      }
      
      // 합계 데이터로 새로운 DailyForeignSummary 생성
      extendedData.add(DailyForeignSummary(
        date: date,
        marketType: 'ALL', // 전체 시장
        foreignNetAmount: totalNetAmount,
        otherForeignNetAmount: 0,
        totalForeignNetAmount: totalNetAmount,
        foreignBuyAmount: totalBuyAmount,
        foreignSellAmount: totalSellAmount,
      ));
    }
    
    // 최신순 정렬
    extendedData.sort((a, b) => b.date.compareTo(a.date));
    return extendedData;
  }

  @override
  void dispose() {
    _service.dispose();
    _offlineService.dispose();
    _priorityService.dispose();
    super.dispose();
  }
}