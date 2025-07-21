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

  DailyForeignSummary({
    required this.date,
    required this.marketType,
    required this.foreignNetAmount,
    required this.otherForeignNetAmount,
    required this.totalForeignNetAmount,
    required this.foreignBuyAmount,
    required this.foreignSellAmount,
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