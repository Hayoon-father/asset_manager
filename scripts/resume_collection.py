#!/usr/bin/env python3
"""
중단된 지점부터 데이터 수집을 재개하는 스크립트
"""

from foreign_investor_collector import ForeignInvestorDataCollector
from datetime import datetime, timedelta
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_last_collected_date():
    """마지막으로 수집된 날짜 확인"""
    try:
        collector = ForeignInvestorDataCollector()
        
        # 가장 최근 날짜 조회
        result = collector.supabase.table('foreign_investor_data')\
            .select('date')\
            .order('date', desc=True)\
            .limit(1)\
            .execute()
        
        if result.data:
            return result.data[0]['date']
        else:
            return '20191231'  # 데이터가 없으면 2020년 이전부터 시작
            
    except Exception as e:
        logger.error(f"마지막 수집 날짜 확인 중 오류: {e}")
        return '20191231'

def get_next_collection_date(last_date):
    """다음 수집 시작 날짜 계산"""
    try:
        last_dt = datetime.strptime(last_date, '%Y%m%d')
        next_dt = last_dt + timedelta(days=1)
        return next_dt.strftime('%Y%m%d')
    except:
        return '20200101'

def resume_collection():
    """중단된 지점부터 수집 재개"""
    logger.info("=== 데이터 수집 재개 시작 ===")
    
    # 마지막 수집 날짜 확인
    last_date = get_last_collected_date()
    next_date = get_next_collection_date(last_date)
    
    logger.info(f"마지막 수집 날짜: {last_date}")
    logger.info(f"다음 수집 시작 날짜: {next_date}")
    
    # 수집기 초기화
    collector = ForeignInvestorDataCollector()
    
    # 현재 날짜까지 수집
    yesterday = datetime.now() - timedelta(days=1)
    end_date = yesterday.strftime('%Y%m%d')
    
    logger.info(f"수집 범위: {next_date} ~ {end_date}")
    
    try:
        # 히스토리 데이터 수집 (다음 날짜부터)
        collector.collect_historical_data(next_date, end_date)
        
        logger.info("=== 데이터 수집 재개 완료 ===")
        
    except Exception as e:
        logger.error(f"데이터 수집 중 오류: {e}")

if __name__ == "__main__":
    resume_collection()