import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/foreign_investor_data.dart';
import 'cache_service.dart';
import 'foreign_investor_service.dart';
import 'pykrx_data_service.dart';

class OfflineService {
  final CacheService _cacheService = CacheService();
  final PykrxDataService _pykrxService = PykrxDataService();
  final Connectivity _connectivity = Connectivity();
  
  // 네트워크 상태 스트림
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<bool> _networkStatusController = 
      StreamController<bool>.broadcast();
  
  Stream<bool> get networkStatusStream => _networkStatusController.stream;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  // 싱글톤 패턴
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // 서비스 초기화
  Future<void> initialize() async {
    // 초기 네트워크 상태 확인
    await _checkNetworkStatus();
    
    // 네트워크 상태 변화 모니터링 시작
    _startNetworkMonitoring();
  }

  // 네트워크 상태 확인
  Future<void> _checkNetworkStatus() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final hasConnection = !connectivityResults.contains(ConnectivityResult.none);
      
      if (hasConnection) {
        // 실제 인터넷 연결 확인 (서버 ping)
        _isOnline = await _checkActualConnection();
      } else {
        _isOnline = false;
      }
      
      _networkStatusController.add(_isOnline);
      print('네트워크 상태: ${_isOnline ? "온라인" : "오프라인"}');
    } catch (e) {
      _isOnline = false;
      _networkStatusController.add(_isOnline);
      print('네트워크 상태 확인 실패: $e');
    }
  }

  // 실제 인터넷 연결 확인
  Future<bool> _checkActualConnection() async {
    try {
      // pykrx 서버 연결 확인
      final serverHealthy = await _pykrxService.checkApiHealth();
      if (serverHealthy) return true;
      
      // Google DNS로 fallback 확인
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 네트워크 상태 모니터링 시작
  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        await _checkNetworkStatus();
      },
    );
  }

  // 오프라인 모드에서 데이터 가져오기
  Future<List<ForeignInvestorData>> getOfflineData({
    String? marketType,
    int limit = 50,
  }) async {
    try {
      print('오프라인 모드: 캐시에서 데이터 조회');
      
      // 1. 최신 데이터 캐시 시도
      var cachedData = await _cacheService.getCachedData(
        'latest',
        market: marketType,
      );
      
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData.take(limit).toList();
      }
      
      // 2. 다른 시장 타입의 캐시 데이터 시도
      if (marketType != null && marketType != 'ALL') {
        cachedData = await _cacheService.getCachedData('latest');
        if (cachedData != null && cachedData.isNotEmpty) {
          final filteredData = cachedData
              .where((data) => data.marketType == marketType)
              .take(limit)
              .toList();
          
          if (filteredData.isNotEmpty) {
            return filteredData;
          }
        }
      }
      
      // 3. 상위 매수 종목 캐시 시도
      cachedData = await _cacheService.getCachedTopStocks('buy', marketType);
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData.take(limit).toList();
      }
      
      // 4. 빈 리스트 반환 (오프라인이고 캐시도 없음)
      print('오프라인 모드: 사용 가능한 캐시 데이터 없음');
      return [];
      
    } catch (e) {
      print('오프라인 데이터 조회 실패: $e');
      return [];
    }
  }

  // 네트워크 재연결 시 데이터 동기화
  Future<bool> syncOnReconnect() async {
    if (!_isOnline) {
      print('오프라인 상태: 동기화 건너뜀');
      return false;
    }
    
    try {
      print('네트워크 재연결: 데이터 동기화 시작');
      
      // 서버 상태 확인
      final serverHealthy = await _pykrxService.checkServerWithRetry(maxRetries: 2);
      if (!serverHealthy) {
        print('서버 연결 실패: 동기화 건너뜀');
        return false;
      }
      
      // 최신 데이터 가져오기 시도
      final latestData = await _pykrxService.getLatestForeignInvestorData();
      
      if (latestData.isNotEmpty) {
        // 캐시 업데이트
        await _cacheService.setCachedLatestData(latestData);
        print('네트워크 재연결 동기화 완료: ${latestData.length}개 항목');
        return true;
      }
      
      return false;
    } catch (e) {
      print('재연결 동기화 실패: $e');
      return false;
    }
  }

  // 안전한 데이터 요청 (온라인/오프라인 자동 처리)
  Future<List<ForeignInvestorData>> safeDataRequest({
    required Future<List<ForeignInvestorData>> Function() onlineRequest,
    required Future<List<ForeignInvestorData>> Function() offlineRequest,
    String? cacheKey,
  }) async {
    try {
      if (_isOnline) {
        // 온라인 모드: 실제 API 호출 시도
        try {
          final data = await onlineRequest();
          
          // 성공 시 캐시 업데이트
          if (data.isNotEmpty && cacheKey != null) {
            await _cacheService.setCachedData(cacheKey, data);
          }
          
          return data;
        } catch (e) {
          print('온라인 요청 실패, 오프라인 모드로 전환: $e');
          _isOnline = false;
          _networkStatusController.add(_isOnline);
          return await offlineRequest();
        }
      } else {
        // 오프라인 모드: 캐시에서 데이터 반환
        return await offlineRequest();
      }
    } catch (e) {
      print('안전한 데이터 요청 실패: $e');
      return [];
    }
  }

  // 에러 복구 전략
  Future<List<ForeignInvestorData>> recoverFromError({
    required Exception error,
    String? marketType,
    int limit = 50,
  }) async {
    print('에러 복구 시도: $error');
    
    try {
      // 1. 네트워크 상태 재확인
      await _checkNetworkStatus();
      
      // 2. 캐시에서 데이터 조회
      final cachedData = await getOfflineData(
        marketType: marketType,
        limit: limit,
      );
      
      if (cachedData.isNotEmpty) {
        print('에러 복구: 캐시에서 ${cachedData.length}개 데이터 반환');
        return cachedData;
      }
      
      // 3. 더미 데이터 생성 (최후의 수단)
      return _generateFallbackData(marketType: marketType, limit: limit);
      
    } catch (e) {
      print('에러 복구 실패: $e');
      return _generateFallbackData(marketType: marketType, limit: limit);
    }
  }

  // Fallback 더미 데이터 생성
  List<ForeignInvestorData> _generateFallbackData({
    String? marketType,
    int limit = 10,
  }) {
    final today = DateTime.now();
    final dateString = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    
    final dummyStocks = [
      {'ticker': '005930', 'name': '삼성전자', 'market': 'KOSPI'},
      {'ticker': '000660', 'name': 'SK하이닉스', 'market': 'KOSPI'},
      {'ticker': '035420', 'name': 'NAVER', 'market': 'KOSPI'},
      {'ticker': '005380', 'name': '현대차', 'market': 'KOSPI'},
      {'ticker': '035720', 'name': '카카오', 'market': 'KOSPI'},
    ];
    
    final result = <ForeignInvestorData>[];
    
    for (int i = 0; i < dummyStocks.length && i < limit; i++) {
      final stock = dummyStocks[i];
      
      // 시장 필터 적용
      if (marketType != null && marketType != 'ALL' && stock['market'] != marketType) {
        continue;
      }
      
      result.add(ForeignInvestorData(
        date: dateString,
        marketType: stock['market'] as String,
        investorType: '외국인',
        ticker: stock['ticker'] as String,
        stockName: '${stock['name']} (오프라인)',
        sellAmount: 1000000000,
        buyAmount: 1200000000,
        netAmount: 200000000,
        createdAt: DateTime.now(),
      ));
    }
    
    print('Fallback 더미 데이터 생성: ${result.length}개');
    return result;
  }

  // 캐시 상태 정보
  Future<Map<String, dynamic>> getCacheInfo() async {
    return await _cacheService.getCacheStats();
  }

  // 서비스 종료
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }
}