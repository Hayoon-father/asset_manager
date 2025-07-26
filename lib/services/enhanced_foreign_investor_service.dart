import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/foreign_investor_data.dart';
import '../services/foreign_investor_service.dart';
import '../services/pykrx_server_manager.dart';

/// 향상된 외국인 투자자 서비스 (pykrx 서버 자동 관리 포함)
class EnhancedForeignInvestorService extends ForeignInvestorService {
  late final PykrxServerManager _serverManager;
  bool _isInitialized = false;
  
  // 상태 알림 콜백
  Function(String message, bool isError)? onStatusUpdate;
  Function(String message)? onRecoveryProgress;
  
  EnhancedForeignInvestorService() {
    _initializeServerManager();
  }
  
  /// 서버 관리자 초기화
  void _initializeServerManager() {
    _serverManager = PykrxServerManager();
    
    // 서버 상태 변경 콜백 설정
    _serverManager.onStatusChanged = (isHealthy, message) {
      if (onStatusUpdate != null) {
        onStatusUpdate!(message, !isHealthy);
      }
    };
    
    // 복구 진행 상황 콜백 설정
    _serverManager.onRecoveryProgress = (message) {
      if (onRecoveryProgress != null) {
        onRecoveryProgress!(message);
      }
    };
    
    _isInitialized = true;
  }
  
  /// 서비스 시작 (헬스 모니터링 포함)
  void startService() {
    if (!_isInitialized) _initializeServerManager();
    _serverManager.startHealthMonitoring();
  }
  
  /// 서비스 중지
  void stopService() {
    _serverManager.stopHealthMonitoring();
  }
  
  /// pykrx API를 통한 최신 외국인 투자자 데이터 조회 (자동 복구 포함)
  Future<List<ForeignInvestorData>> getLatestForeignInvestorDataWithRetry({
    String? marketType,
    int limit = 50,
  }) async {
    try {
      // 1. 먼저 기존 DB 데이터 조회 시도
      final dbData = await super.getLatestForeignInvestorData(
        marketType: marketType,
        limit: limit,
      );
      
      if (dbData.isNotEmpty) {
        return dbData;
      }
      
      // 2. DB에 데이터가 없으면 pykrx API 직접 호출 (자동 복구 포함)
      final markets = marketType ?? 'KOSPI,KOSDAQ';
      final response = await _serverManager.makeApiCallWithRetry(
        '/foreign_investor_data',
        queryParams: {'markets': markets},
        maxRetries: 3,
      );
      
      if (response != null) {
        final jsonData = json.decode(response.body);
        final List<dynamic> dataList = jsonData['data'] ?? [];
        
        return dataList.map((item) => ForeignInvestorData(
          date: item['date'] ?? '',
          marketType: item['market_type'] ?? '',
          investorType: item['investor_type'] ?? '',
          ticker: item['ticker'],
          stockName: item['stock_name'] ?? '',
          buyAmount: item['buy_amount'] ?? 0,
          sellAmount: item['sell_amount'] ?? 0,
          netAmount: item['net_amount'] ?? 0,
          createdAt: DateTime.tryParse(item['created_at'] ?? '') ?? DateTime.now(),
        )).take(limit).toList();
      }
      
      return [];
    } catch (e) {
      print('❌ 향상된 외국인 투자자 데이터 조회 실패: $e');
      
      // 오류 시 기존 서비스 폴백
      try {
        return await super.getLatestForeignInvestorData(
          marketType: marketType,
          limit: limit,
        );
      } catch (fallbackError) {
        print('❌ 폴백 서비스도 실패: $fallbackError');
        return [];
      }
    }
  }
  
  /// pykrx API를 통한 일별 요약 데이터 조회 (자동 복구 포함)
  Future<List<DailyForeignSummary>> getDailyForeignSummaryWithRetry({
    required String startDate,
    required String endDate,
    String marketType = 'ALL',
    int limit = 100,
  }) async {
    try {
      // 1. 먼저 기존 DB 데이터 조회 시도
      final dbData = await super.getDailyForeignSummary(
        startDate: startDate,
        endDate: endDate,
        marketType: marketType,
        limit: limit,
      );
      
      if (dbData.isNotEmpty) {
        return dbData;
      }
      
      // 2. DB에 데이터가 없으면 pykrx API 직접 호출
      final response = await _serverManager.makeApiCallWithRetry(
        '/foreign_investor_data_range',
        queryParams: {
          'start_date': startDate,
          'end_date': endDate,
          'markets': marketType == 'ALL' ? 'KOSPI,KOSDAQ' : marketType,
        },
        maxRetries: 3,
      );
      
      if (response != null) {
        final jsonData = json.decode(response.body);
        final List<dynamic> dataList = jsonData['data'] ?? [];
        
        // 데이터를 날짜별로 그룹화하고 DailyForeignSummary로 변환
        final Map<String, Map<String, List<dynamic>>> groupedData = {};
        
        for (final item in dataList) {
          final date = item['date'] ?? '';
          final market = item['market_type'] ?? '';
          
          groupedData[date] ??= {};
          groupedData[date]![market] ??= [];
          groupedData[date]![market]!.add(item);
        }
        
        final summaries = <DailyForeignSummary>[];
        
        for (final dateEntry in groupedData.entries) {
          for (final marketEntry in dateEntry.value.entries) {
            final items = marketEntry.value;
            
            int totalBuyAmount = 0;
            int totalSellAmount = 0;
            int totalNetAmount = 0;
            
            for (final item in items) {
              totalBuyAmount += (item['buy_amount'] ?? 0) as int;
              totalSellAmount += (item['sell_amount'] ?? 0) as int;
              totalNetAmount += (item['net_amount'] ?? 0) as int;
            }
            
            summaries.add(DailyForeignSummary(
              date: dateEntry.key,
              marketType: marketEntry.key,
              totalForeignNetAmount: totalNetAmount,
              foreignTotalTradeAmount: totalBuyAmount + totalSellAmount,
              cumulativeHoldings: totalNetAmount, // 임시 값
            ));
          }
        }
        
        return summaries.take(limit).toList();
      }
      
      return [];
    } catch (e) {
      print('❌ 향상된 일별 요약 데이터 조회 실패: $e');
      
      // 오류 시 기존 서비스 폴백
      try {
        return await super.getDailyForeignSummary(
          startDate: startDate,
          endDate: endDate,
          marketType: marketType,
          limit: limit,
        );
      } catch (fallbackError) {
        print('❌ 폴백 서비스도 실패: $fallbackError');
        return [];
      }
    }
  }
  
  /// pykrx 서버 수동 복구 시도
  Future<bool> manualServerRecovery() async {
    if (onRecoveryProgress != null) {
      onRecoveryProgress!('수동 서버 복구를 시작합니다...');
    }
    
    final success = await _serverManager.attemptServerRecovery();
    
    if (success && onStatusUpdate != null) {
      onStatusUpdate!('pykrx 서버가 성공적으로 복구되었습니다.', false);
    } else if (!success && onStatusUpdate != null) {
      onStatusUpdate!('서버 복구에 실패했습니다. 관리자에게 문의하세요.', true);
    }
    
    return success;
  }
  
  /// 서버 상태 확인
  Future<bool> checkServerHealth() async {
    return await _serverManager.checkServerHealth();
  }
  
  /// 현재 서버 상태 정보
  Map<String, dynamic> getServerStatus() {
    return _serverManager.getServerStatus();
  }
  
  /// 헬스 모니터링 활성 여부
  bool get isHealthMonitoringActive => _serverManager._healthCheckTimer?.isActive ?? false;
  
  @override
  void dispose() {
    stopService();
    _serverManager.dispose();
    super.dispose();
  }
}