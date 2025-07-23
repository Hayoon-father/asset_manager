#!/usr/bin/env python3
"""
우선순위 기반 외국인 수급 데이터 수집 스크립트
2025년 → 2024년 → 2023년 → 2022년 → 2021년 → 2020년 순서로 수집
"""

import os
import sys
from datetime import datetime, timedelta
import pandas as pd
from pykrx import stock
from supabase import create_client, Client
from dotenv import load_dotenv
import logging
import time

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class PriorityForeignInvestorCollector:
    def __init__(self):
        # 환경 변수 로드
        load_dotenv()
        
        # Supabase 설정 (asset_manager 프로젝트)
        self.supabase_url = "https://ggkhmksvypmlxhttqthb.supabase.co"
        self.supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"
        
        # Supabase 클라이언트 생성
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        
        logger.info("PriorityForeignInvestorCollector 초기화 완료")
    
    def is_date_collected(self, date_str):
        """특정 날짜의 데이터가 이미 수집되었는지 확인"""
        try:
            result = self.supabase.table('foreign_investor_data')\
                .select('date')\
                .eq('date', date_str)\
                .limit(1)\
                .execute()
            
            return len(result.data) > 0
        except Exception as e:
            logger.warning(f"날짜 {date_str} 확인 중 오류: {e}")
            return False
    
    def get_foreign_investor_data(self, start_date: str, end_date: str, market: str = "KOSPI"):
        """외국인 투자자 거래 데이터 수집"""
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
                    'date': end_date,
                    'market_type': market,
                    'investor_type': '외국인',
                    'ticker': None,
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
    
    def get_foreign_top_stocks(self, start_date: str, end_date: str, market: str = "KOSPI", limit: int = 10):
        """외국인 순매수 상위 종목 데이터 수집"""
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
        """데이터를 Supabase에 저장 (upsert 방식)"""
        if data.empty:
            logger.warning("저장할 데이터가 없습니다")
            return False
        
        try:
            # 데이터프레임을 딕셔너리 리스트로 변환
            records = data.to_dict('records')
            
            # Supabase에 데이터 삽입 (upsert 사용하여 중복 방지)
            result = self.supabase.table(table_name).upsert(records).execute()
            
            logger.info(f"성공적으로 {len(records)}개 레코드를 {table_name} 테이블에 저장")
            return True
            
        except Exception as e:
            if "duplicate key" in str(e).lower():
                logger.info(f"중복 데이터 건너뜀: {len(records)}개 레코드")
                return True  # 중복은 정상적인 상황
            else:
                logger.error(f"Supabase 저장 중 오류 발생: {e}")
                return False
    
    def collect_daily_data(self, target_date: str):
        """특정 일자의 외국인 수급 데이터 수집"""
        logger.info(f"일별 데이터 수집 시작: {target_date}")
        
        # 이미 수집된 날짜인지 확인
        if self.is_date_collected(target_date):
            logger.info(f"날짜 {target_date}는 이미 수집 완료, 건너뜀")
            return True
        
        success_count = 0
        
        try:
            # KOSPI 전체 시장 데이터 수집
            kospi_data = self.get_foreign_investor_data(target_date, target_date, "KOSPI")
            if not kospi_data.empty and self.save_to_supabase(kospi_data):
                success_count += 1
            
            # KOSDAQ 전체 시장 데이터 수집
            kosdaq_data = self.get_foreign_investor_data(target_date, target_date, "KOSDAQ")
            if not kosdaq_data.empty and self.save_to_supabase(kosdaq_data):
                success_count += 1
            
            # 금요일에만 상위 종목 수집 (API 부하 감소)
            target_dt = datetime.strptime(target_date, "%Y%m%d")
            if target_dt.weekday() == 4:  # 금요일
                # KOSPI 상위 종목 데이터 수집
                kospi_top = self.get_foreign_top_stocks(target_date, target_date, "KOSPI", 10)
                if not kospi_top.empty and self.save_to_supabase(kospi_top):
                    success_count += 1
                
                # KOSDAQ 상위 종목 데이터 수집
                kosdaq_top = self.get_foreign_top_stocks(target_date, target_date, "KOSDAQ", 10)
                if not kosdaq_top.empty and self.save_to_supabase(kosdaq_top):
                    success_count += 1
            
            # API 부하 방지를 위한 딜레이
            time.sleep(0.3)
            
            logger.info(f"일별 데이터 수집 완료: {target_date} (성공: {success_count})")
            return success_count > 0
            
        except Exception as e:
            logger.error(f"날짜 {target_date} 데이터 수집 중 오류: {e}")
            return False
    
    def collect_year_data(self, year: int):
        """특정 연도의 데이터를 수집"""
        logger.info(f"=== {year}년 데이터 수집 시작 ===")
        
        # 연도별 시작/종료일 설정
        start_date = f"{year}0101"
        
        if year == datetime.now().year:
            # 현재 연도는 어제까지만
            yesterday = datetime.now() - timedelta(days=1)
            end_date = yesterday.strftime("%Y%m%d")
        else:
            end_date = f"{year}1231"
        
        # 날짜 범위 생성
        start_dt = datetime.strptime(start_date, "%Y%m%d")
        end_dt = datetime.strptime(end_date, "%Y%m%d")
        
        current_date = start_dt
        success_count = 0
        total_days = 0
        
        while current_date <= end_dt:
            current_str = current_date.strftime("%Y%m%d")
            total_days += 1
            
            # 주말은 건너뛰기 (한국 증시는 주말 휴장)
            if current_date.weekday() >= 5:  # 5=토요일, 6=일요일
                current_date += timedelta(days=1)
                continue
            
            # 일별 데이터 수집
            if self.collect_daily_data(current_str):
                success_count += 1
            
            current_date += timedelta(days=1)
        
        logger.info(f"=== {year}년 데이터 수집 완료 ===")
        logger.info(f"총 {total_days}일 중 {success_count}일 성공")
        
        return success_count
    
    def collect_priority_data(self):
        """우선순위에 따른 데이터 수집 (2025→2024→2023→2022→2021→2020)"""
        logger.info("=== 우선순위 기반 데이터 수집 시작 ===")
        logger.info("수집 순서: 2025년 → 2024년 → 2023년 → 2022년 → 2021년 → 2020년")
        
        # 우선순위 순서 (최신 데이터부터)
        priority_years = [2025, 2024, 2023, 2022, 2021, 2020]
        
        total_success = 0
        
        for year in priority_years:
            try:
                logger.info(f"\n🚀 {year}년 데이터 수집 시작")
                success_count = self.collect_year_data(year)
                total_success += success_count
                
                logger.info(f"✅ {year}년 수집 완료: {success_count}일")
                
                # 연도별 수집 사이에 잠시 대기
                time.sleep(2)
                
            except Exception as e:
                logger.error(f"❌ {year}년 데이터 수집 중 오류: {e}")
                continue
        
        logger.info("=== 우선순위 기반 데이터 수집 완료 ===")
        logger.info(f"총 수집 성공: {total_success}일")

def main():
    """메인 함수"""
    collector = PriorityForeignInvestorCollector()
    
    logger.info("💡 우선순위 기반 외국인 수급 데이터 수집을 시작합니다.")
    logger.info("📅 수집 순서: 2025년 → 2024년 → 2023년 → 2022년 → 2021년 → 2020년")
    logger.info("⚡ 최신 데이터부터 우선적으로 수집하여 빠른 활용이 가능합니다.\n")
    
    try:
        collector.collect_priority_data()
    except KeyboardInterrupt:
        logger.info("사용자에 의해 수집이 중단되었습니다.")
    except Exception as e:
        logger.error(f"수집 중 예상치 못한 오류: {e}")

if __name__ == "__main__":
    main()