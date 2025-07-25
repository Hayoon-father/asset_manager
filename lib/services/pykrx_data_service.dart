import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/foreign_investor_data.dart';

class PykrxDataService {
  static const String _baseUrl = 'http://127.0.0.1:8000'; // 로컬 FastAPI 서버
  
  // 싱글톤 패턴
  static final PykrxDataService _instance = PykrxDataService._internal();
  factory PykrxDataService() => _instance;
  PykrxDataService._internal();

  // 최신 외국인 수급 데이터 가져오기
  Future<List<ForeignInvestorData>> getLatestForeignInvestorData({
    String? targetDate, // 특정 날짜 조회 (null이면 최신일)
    List<String>? markets, // ['KOSPI', 'KOSDAQ'] 또는 null(전체)
  }) async {
    return await _executeWithRetry<List<ForeignInvestorData>>(() async {
      final Map<String, dynamic> params = {};
      if (targetDate != null) params['date'] = targetDate;
      if (markets != null) params['markets'] = markets.join(',');
      
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      
      final url = '$_baseUrl/foreign_investor_data?$queryString';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> dataList = jsonData['data'] ?? [];
        
        return dataList
            .map((item) => ForeignInvestorData.fromPykrxJson(item))
            .toList();
      } else {
        throw Exception('pykrx API 오류: ${response.statusCode} - ${response.body}');
      }
    });
  }

  // 특정 기간의 외국인 수급 데이터 가져오기
  Future<List<ForeignInvestorData>> getForeignInvestorDataByDateRange({
    required String fromDate, // YYYYMMDD 형식
    required String toDate,   // YYYYMMDD 형식
    List<String>? markets,
  }) async {
    return await _executeWithRetry<List<ForeignInvestorData>>(() async {
      final Map<String, dynamic> params = {
        'from_date': fromDate,
        'to_date': toDate,
      };
      if (markets != null) params['markets'] = markets.join(',');
      
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      
      final url = '$_baseUrl/foreign_investor_data_range?$queryString';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> dataList = jsonData['data'] ?? [];
        
        return dataList
            .map((item) => ForeignInvestorData.fromPykrxJson(item))
            .toList();
      } else {
        throw Exception('pykrx API 오류: ${response.statusCode} - ${response.body}');
      }
    });
  }

  // 최신 가능한 거래일 조회
  Future<String> getLatestTradingDate() async {
    return await _executeWithRetry<String>(() async {
      const url = '$_baseUrl/latest_trading_date';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final String latestDate = jsonData['latest_date'] ?? '';
        
        return latestDate;
      } else {
        throw Exception('최신 거래일 조회 실패: ${response.statusCode}');
      }
    });
  }

  // pykrx API 서버 상태 확인
  Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 재시도 로직이 포함된 서버 상태 확인
  Future<bool> checkServerWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (await checkApiHealth()) {
          return true;
        }
      } catch (e) {
        print('서버 연결 시도 ${i + 1}/$maxRetries 실패: $e');
      }
      
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(seconds: 2 * (i + 1))); // 2초, 4초, 6초 대기
      }
    }
    return false;
  }

  // 재시도 로직이 포함된 데이터 요청
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 2),
  }) async {
    Exception? lastException;
    
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        print('API 호출 시도 ${i + 1}/$maxRetries 실패: $e');
        
        if (i < maxRetries - 1) {
          final delay = Duration(seconds: baseDelay.inSeconds * (i + 1));
          await Future.delayed(delay);
        }
      }
    }
    
    throw lastException ?? Exception('알 수 없는 오류');
  }
}