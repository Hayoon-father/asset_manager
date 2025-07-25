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
    try {
      
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
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> dataList = jsonData['data'] ?? [];
        
        
        return dataList
            .map((item) => ForeignInvestorData.fromPykrxJson(item))
            .toList();
      } else {
        throw Exception('pykrx API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 특정 기간의 외국인 수급 데이터 가져오기
  Future<List<ForeignInvestorData>> getForeignInvestorDataByDateRange({
    required String fromDate, // YYYYMMDD 형식
    required String toDate,   // YYYYMMDD 형식
    List<String>? markets,
  }) async {
    try {
      
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
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> dataList = jsonData['data'] ?? [];
        
        
        return dataList
            .map((item) => ForeignInvestorData.fromPykrxJson(item))
            .toList();
      } else {
        throw Exception('pykrx API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 최신 가능한 거래일 조회
  Future<String> getLatestTradingDate() async {
    try {
      
      const url = '$_baseUrl/latest_trading_date';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final String latestDate = jsonData['latest_date'] ?? '';
        
        return latestDate;
      } else {
        throw Exception('최신 거래일 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
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
}