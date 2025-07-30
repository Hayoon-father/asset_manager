class ForeignInvestorData {
  final int? id;
  final String date; // YYYYMMDD 형식
  final String marketType; // KOSPI, KOSDAQ
  final String investorType; // 외국인, 기타외국인
  final String? ticker; // 종목코드 (전체시장의 경우 null)
  final String? stockName; // 종목명
  final int sellAmount; // 매도금액
  final int buyAmount; // 매수금액  
  final int netAmount; // 순매수금액
  final int? sellVolume; // 매도거래량
  final int? buyVolume; // 매수거래량
  final int? netVolume; // 순매수거래량
  final DateTime createdAt;
  final DateTime? updatedAt;

  ForeignInvestorData({
    this.id,
    required this.date,
    required this.marketType,
    required this.investorType,
    this.ticker,
    this.stockName,
    required this.sellAmount,
    required this.buyAmount,
    required this.netAmount,
    this.sellVolume,
    this.buyVolume,
    this.netVolume,
    required this.createdAt,
    this.updatedAt,
  });

  factory ForeignInvestorData.fromJson(Map<String, dynamic> json) {
    return ForeignInvestorData(
      id: json['id'],
      date: json['date'] ?? '',
      marketType: json['market_type'] ?? '',
      investorType: json['investor_type'] ?? '',
      ticker: json['ticker'],
      stockName: json['stock_name'],
      sellAmount: json['sell_amount'] ?? 0,
      buyAmount: json['buy_amount'] ?? 0,
      netAmount: json['net_amount'] ?? 0,
      sellVolume: json['sell_volume'],
      buyVolume: json['buy_volume'],
      netVolume: json['net_volume'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  // pykrx API 응답용 팩토리 메서드
  factory ForeignInvestorData.fromPykrxJson(Map<String, dynamic> json) {
    return ForeignInvestorData(
      date: json['날짜'] ?? json['date'] ?? '',
      marketType: json['시장구분'] ?? json['market_type'] ?? '',
      investorType: json['투자자구분'] ?? json['investor_type'] ?? '외국인',  
      ticker: json['종목코드'] ?? json['ticker'],
      stockName: json['종목명'] ?? json['stock_name'],
      sellAmount: _parseAmount(json['매도금액'] ?? json['sell_amount'] ?? 0) ?? 0,
      buyAmount: _parseAmount(json['매수금액'] ?? json['buy_amount'] ?? 0) ?? 0,
      netAmount: _parseAmount(json['순매수금액'] ?? json['net_amount'] ?? 0) ?? 0,
      sellVolume: _parseAmount(json['매도수량'] ?? json['sell_volume']),
      buyVolume: _parseAmount(json['매수수량'] ?? json['buy_volume']),
      netVolume: _parseAmount(json['순매수수량'] ?? json['net_volume']),
      createdAt: DateTime.now(),
      updatedAt: null,
    );
  }

  // 문자열이나 숫자를 int로 파싱하는 헬퍼 메서드
  static int? _parseAmount(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      // 쉼표 제거하고 숫자만 추출
      final cleanValue = value.replaceAll(',', '').replaceAll(' ', '');
      return int.tryParse(cleanValue);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'market_type': marketType,
      'investor_type': investorType,
      if (ticker != null) 'ticker': ticker,
      if (stockName != null) 'stock_name': stockName,
      'sell_amount': sellAmount,
      'buy_amount': buyAmount,
      'net_amount': netAmount,
      if (sellVolume != null) 'sell_volume': sellVolume,
      if (buyVolume != null) 'buy_volume': buyVolume,
      if (netVolume != null) 'net_volume': netVolume,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // 순매수 여부 판단
  bool get isNetBuy => netAmount > 0;
  
  // 순매도 여부 판단  
  bool get isNetSell => netAmount < 0;
  
  // 거래대금 총합
  int get totalTradeAmount => buyAmount + sellAmount;
  
  // 매수 비율
  double get buyRatio => totalTradeAmount > 0 ? buyAmount / totalTradeAmount : 0.0;
  
  // 순매수율 (순매수금액 / 총거래금액)
  double get netBuyRatio => totalTradeAmount > 0 ? netAmount / totalTradeAmount : 0.0;

  @override
  String toString() {
    return 'ForeignInvestorData{date: $date, marketType: $marketType, investorType: $investorType, ticker: $ticker, netAmount: $netAmount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForeignInvestorData &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          marketType == other.marketType &&
          investorType == other.investorType &&
          ticker == other.ticker;

  @override
  int get hashCode =>
      date.hashCode ^
      marketType.hashCode ^
      investorType.hashCode ^
      (ticker?.hashCode ?? 0);
}

// 일별 외국인 수급 요약 모델
class DailyForeignSummary {
  final String date;
  final String marketType;
  final int foreignNetAmount; // 외국인 순매수
  final int otherForeignNetAmount; // 기타외국인 순매수
  final int totalForeignNetAmount; // 전체 외국인 순매수
  final int foreignBuyAmount; // 외국인 매수금액
  final int foreignSellAmount; // 외국인 매도금액
  
  // 누적 보유액 (계산된 값) - 순매수 누적
  int cumulativeHoldings = 0;
  
  // 실제 보유액 (pykrx API에서 계산된 값)
  int actualHoldingsValue = 0;

  DailyForeignSummary({
    required this.date,
    required this.marketType,
    required this.foreignNetAmount,
    required this.otherForeignNetAmount,
    required this.totalForeignNetAmount,
    required this.foreignBuyAmount,
    required this.foreignSellAmount,
    this.cumulativeHoldings = 0,
    this.actualHoldingsValue = 0,
  });

  factory DailyForeignSummary.fromJson(Map<String, dynamic> json) {
    return DailyForeignSummary(
      date: json['date'] ?? '',
      marketType: json['market_type'] ?? '',
      foreignNetAmount: json['foreign_net_amount'] ?? 0,
      otherForeignNetAmount: json['other_foreign_net_amount'] ?? 0,
      totalForeignNetAmount: json['total_foreign_net_amount'] ?? 0,
      foreignBuyAmount: json['foreign_buy_amount'] ?? 0,
      foreignSellAmount: json['foreign_sell_amount'] ?? 0,
    );
  }

  // 외국인 매수 우세 여부
  bool get isForeignNetBuy => totalForeignNetAmount > 0;
  
  // 외국인 매도 우세 여부
  bool get isForeignNetSell => totalForeignNetAmount < 0;
  
  // 외국인 거래 활성도 (총 거래금액)
  int get foreignTotalTradeAmount => foreignBuyAmount + foreignSellAmount;

  @override
  String toString() {
    return 'DailyForeignSummary{date: $date, marketType: $marketType, totalForeignNetAmount: $totalForeignNetAmount}';
  }
}