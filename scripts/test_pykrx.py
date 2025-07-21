#!/usr/bin/env python3
"""
pykrx 라이브러리 테스트 스크립트
외국인 수급 데이터가 정상적으로 수집되는지 확인
"""

from pykrx import stock
from datetime import datetime, timedelta
import pandas as pd

def test_pykrx():
    print("pykrx 라이브러리 테스트 시작")
    
    # 테스트할 날짜 (최근 영업일)
    today = datetime.now()
    # 최근 일주일 전부터 어제까지 테스트
    end_date = (today - timedelta(days=1)).strftime("%Y%m%d")
    start_date = (today - timedelta(days=7)).strftime("%Y%m%d")
    
    print(f"테스트 기간: {start_date} ~ {end_date}")
    
    try:
        # 1. KOSPI 전체 시장 투자자별 거래대금
        print("\n1. KOSPI 전체 시장 외국인 거래 데이터:")
        kospi_data = stock.get_market_trading_value_by_investor(start_date, end_date, "KOSPI")
        print(kospi_data)
        
        if '외국인' in kospi_data.index:
            foreign_data = kospi_data.loc['외국인']
            print(f"외국인 순매수: {foreign_data['순매수']:,}원")
        
        print("\n" + "="*50)
        
        # 2. KOSDAQ 전체 시장 투자자별 거래대금
        print("\n2. KOSDAQ 전체 시장 외국인 거래 데이터:")
        kosdaq_data = stock.get_market_trading_value_by_investor(start_date, end_date, "KOSDAQ")
        print(kosdaq_data)
        
        print("\n" + "="*50)
        
        # 3. 외국인 순매수 상위 종목 (KOSPI)
        print("\n3. KOSPI 외국인 순매수 상위 10개 종목:")
        kospi_top = stock.get_market_net_purchases_of_equities_by_ticker(start_date, end_date, "KOSPI", "외국인")
        top_10 = kospi_top.nlargest(10, '순매수거래대금')
        print(top_10)
        
        print("\n" + "="*50)
        
        # 4. 개별 종목 테스트 (삼성전자)
        print("\n4. 삼성전자(005930) 투자자별 거래 데이터:")
        samsung_data = stock.get_market_trading_value_by_investor(start_date, end_date, "005930")
        print(samsung_data)
        
        print("\npykrx 테스트 성공!")
        return True
        
    except Exception as e:
        print(f"pykrx 테스트 실패: {e}")
        return False

if __name__ == "__main__":
    test_pykrx()