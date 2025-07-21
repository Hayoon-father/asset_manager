#!/usr/bin/env python3
"""
외국인 수급현황 데이터 수집 스크립트
pykrx를 이용하여 한국 증시의 외국인 투자자 거래 데이터를 수집하고 Supabase에 저장
"""

import os
import sys
from datetime import datetime, timedelta
import pandas as pd
from pykrx import stock
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ForeignInvestorDataCollector:
    def __init__(self):
        # 환경 변수 로드
        load_dotenv()
        
        # Supabase 설정 (earthquake 프로젝트와 동일한 설정 사용)
        self.supabase_url = "https://myvuxuwczrlhwnnceile.supabase.co"
        self.supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15dnV4dXdjenJsaHdubmNlaWxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4MjE3MTcsImV4cCI6MjA2ODM5NzcxN30.-DZ4pyYwRmG3dRwR3jkXIc37ARo2mPui36Ji9PmJ690"
        
        # Supabase 클라이언트 생성
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        
        logger.info("ForeignInvestorDataCollector 초기화 완료")
    
    def get_foreign_investor_data(self, start_date: str, end_date: str, market: str = "KOSPI"):
        """
        외국인 투자자 거래 데이터 수집
        
        Args:
            start_date: 시작일 (YYYYMMDD 형식)
            end_date: 종료일 (YYYYMMDD 형식)  
            market: 시장 구분 ("KOSPI", "KOSDAQ", "ALL")
        
        Returns:
            pd.DataFrame: 외국인 투자자 거래 데이터
        """
        try:
            logger.info(f"{market} 시장 외국인 투자자 데이터 수집: {start_date} ~ {end_date}")
            
            # 전체 시장의 투자자별 거래대금 조회
            df = stock.get_market_trading_value_by_investor(start_date, end_date, market)
            
            # 외국인 관련 데이터만 추출
            foreign_data = df.loc[['외국인', '기타외국인']].copy()
            
            # 데이터 재구성
            result_data = []
            
            # 외국인 데이터
            if '외국인' in foreign_data.index:
                foreign_row = foreign_data.loc['외국인']
                result_data.append({
                    'date': end_date,  # 종료일을 대표 날짜로 사용
                    'market_type': market,
                    'investor_type': '외국인',
                    'ticker': None,  # 전체 시장이므로 null
                    'sell_amount': int(foreign_row['매도']),
                    'buy_amount': int(foreign_row['매수']),
                    'net_amount': int(foreign_row['순매수']),
                    'created_at': datetime.now().isoformat()
                })
            
            # 기타외국인 데이터  
            if '기타외국인' in foreign_data.index:
                other_foreign_row = foreign_data.loc['기타외국인']
                result_data.append({
                    'date': end_date,
                    'market_type': market,
                    'investor_type': '기타외국인',
                    'ticker': None,
                    'sell_amount': int(other_foreign_row['매도']),
                    'buy_amount': int(other_foreign_row['매수']),
                    'net_amount': int(other_foreign_row['순매수']),
                    'created_at': datetime.now().isoformat()
                })
            
            return pd.DataFrame(result_data)
            
        except Exception as e:
            logger.error(f"데이터 수집 중 오류 발생: {e}")
            return pd.DataFrame()
    
    def get_foreign_top_stocks(self, start_date: str, end_date: str, market: str = "KOSPI", limit: int = 20):
        """
        외국인 순매수 상위 종목 데이터 수집
        
        Args:
            start_date: 시작일 (YYYYMMDD 형식)
            end_date: 종료일 (YYYYMMDD 형식)
            market: 시장 구분 ("KOSPI", "KOSDAQ")
            limit: 상위 n개 종목
        
        Returns:
            pd.DataFrame: 외국인 순매수 상위 종목 데이터
        """
        try:
            logger.info(f"{market} 외국인 순매수 상위 {limit}개 종목 데이터 수집")
            
            # 외국인 순매수 종목별 데이터 조회
            df = stock.get_market_net_purchases_of_equities_by_ticker(start_date, end_date, market, "외국인")
            
            # 순매수거래대금 기준 상위 종목 추출
            top_stocks = df.nlargest(limit, '순매수거래대금')
            
            result_data = []
            
            for ticker, row in top_stocks.iterrows():
                result_data.append({
                    'date': end_date,
                    'market_type': market,
                    'investor_type': '외국인',
                    'ticker': ticker,
                    'stock_name': row['종목명'] if '종목명' in row else None,
                    'sell_amount': int(row['매도거래대금']),
                    'buy_amount': int(row['매수거래대금']),
                    'net_amount': int(row['순매수거래대금']),
                    'sell_volume': int(row['매도거래량']) if '매도거래량' in row else None,
                    'buy_volume': int(row['매수거래량']) if '매수거래량' in row else None,
                    'net_volume': int(row['순매수거래량']) if '순매수거래량' in row else None,
                    'created_at': datetime.now().isoformat()
                })
            
            return pd.DataFrame(result_data)
            
        except Exception as e:
            logger.error(f"상위 종목 데이터 수집 중 오류 발생: {e}")
            return pd.DataFrame()
    
    def save_to_supabase(self, data: pd.DataFrame, table_name: str = "foreign_investor_data"):
        """
        데이터를 Supabase에 저장
        
        Args:
            data: 저장할 데이터프레임
            table_name: 테이블명
        """
        if data.empty:
            logger.warning("저장할 데이터가 없습니다")
            return
        
        try:
            # 데이터프레임을 딕셔너리 리스트로 변환
            records = data.to_dict('records')
            
            # Supabase에 데이터 삽입 (upsert 사용하여 중복 방지)
            result = self.supabase.table(table_name).upsert(records).execute()
            
            logger.info(f"성공적으로 {len(records)}개 레코드를 {table_name} 테이블에 저장")
            
        except Exception as e:
            logger.error(f"Supabase 저장 중 오류 발생: {e}")
    
    def collect_daily_data(self, target_date: str = None):
        """
        특정 일자의 외국인 수급 데이터 수집
        
        Args:
            target_date: 수집할 날짜 (YYYYMMDD), None이면 어제 날짜 사용
        """
        if target_date is None:
            # 어제 날짜 사용 (증시는 하루 늦게 데이터가 나옴)
            yesterday = datetime.now() - timedelta(days=1)
            target_date = yesterday.strftime("%Y%m%d")
        
        logger.info(f"일별 데이터 수집 시작: {target_date}")
        
        # KOSPI 전체 시장 데이터 수집
        kospi_data = self.get_foreign_investor_data(target_date, target_date, "KOSPI")
        if not kospi_data.empty:
            self.save_to_supabase(kospi_data)
        
        # KOSDAQ 전체 시장 데이터 수집
        kosdaq_data = self.get_foreign_investor_data(target_date, target_date, "KOSDAQ")
        if not kosdaq_data.empty:
            self.save_to_supabase(kosdaq_data)
        
        # KOSPI 상위 종목 데이터 수집
        kospi_top = self.get_foreign_top_stocks(target_date, target_date, "KOSPI", 10)
        if not kospi_top.empty:
            self.save_to_supabase(kospi_top)
        
        # KOSDAQ 상위 종목 데이터 수집
        kosdaq_top = self.get_foreign_top_stocks(target_date, target_date, "KOSDAQ", 10)
        if not kosdaq_top.empty:
            self.save_to_supabase(kosdaq_top)
        
        logger.info(f"일별 데이터 수집 완료: {target_date}")
    
    def collect_historical_data(self, start_date: str, end_date: str = None):
        """
        기간별 히스토리 데이터 수집
        
        Args:
            start_date: 시작일 (YYYYMMDD)
            end_date: 종료일 (YYYYMMDD), None이면 어제 날짜 사용
        """
        if end_date is None:
            yesterday = datetime.now() - timedelta(days=1)
            end_date = yesterday.strftime("%Y%m%d")
        
        logger.info(f"히스토리 데이터 수집 시작: {start_date} ~ {end_date}")
        
        # 시작일과 종료일을 datetime으로 변환
        start_dt = datetime.strptime(start_date, "%Y%m%d")
        end_dt = datetime.strptime(end_date, "%Y%m%d")
        
        # 일주일 단위로 데이터 수집 (API 부하 방지)
        current_date = start_dt
        while current_date <= end_dt:
            week_end = min(current_date + timedelta(days=6), end_dt)
            
            current_str = current_date.strftime("%Y%m%d")
            week_end_str = week_end.strftime("%Y%m%d")
            
            logger.info(f"주간 데이터 수집: {current_str} ~ {week_end_str}")
            
            # 주간 데이터 수집
            kospi_data = self.get_foreign_investor_data(current_str, week_end_str, "KOSPI")
            if not kospi_data.empty:
                # 주간 데이터는 마지막 날짜를 기준으로 저장
                kospi_data['date'] = week_end_str
                self.save_to_supabase(kospi_data)
            
            kosdaq_data = self.get_foreign_investor_data(current_str, week_end_str, "KOSDAQ")
            if not kosdaq_data.empty:
                kosdaq_data['date'] = week_end_str
                self.save_to_supabase(kosdaq_data)
            
            current_date = week_end + timedelta(days=1)
        
        logger.info(f"히스토리 데이터 수집 완료: {start_date} ~ {end_date}")


def main():
    """메인 함수"""
    collector = ForeignInvestorDataCollector()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "daily":
            # 일별 데이터 수집
            target_date = sys.argv[2] if len(sys.argv) > 2 else None
            collector.collect_daily_data(target_date)
            
        elif command == "historical":
            # 히스토리 데이터 수집
            if len(sys.argv) < 3:
                logger.error("시작일을 지정해주세요. 예: python foreign_investor_collector.py historical 20230101")
                return
            
            start_date = sys.argv[2]
            end_date = sys.argv[3] if len(sys.argv) > 3 else None
            collector.collect_historical_data(start_date, end_date)
            
        else:
            logger.error("올바른 명령어를 사용해주세요: daily 또는 historical")
    else:
        # 기본값: 어제 데이터 수집
        logger.info("기본 모드: 어제 데이터 수집")
        collector.collect_daily_data()


if __name__ == "__main__":
    main()