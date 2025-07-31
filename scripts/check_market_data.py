#!/usr/bin/env python3
"""
DB에서 KOSPI, KOSDAQ 개별 데이터 확인 스크립트
"""

import os
from supabase import create_client, Client
from datetime import datetime, timedelta

# Supabase 설정
SUPABASE_URL = "https://fhcdhdvhbbvtskguvdfz.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoY2RoZHZoYmJ2dHNrZ3V2ZGZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzMTI5MDIsImV4cCI6MjA0Njg4ODkwMn0.WxSlVFgUZjsY3e6I9yWz6gIa6A4YPzAWGnLLyxgdHGo"

def main():
    # Supabase 클라이언트 생성
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    print("🔍 DB에서 시장별 데이터 확인 시작")
    
    # 최근 7일 데이터 조회
    end_date = datetime.now()
    start_date = end_date - timedelta(days=7)
    
    # foreign_investor_summary 테이블에서 시장별 데이터 확인
    try:
        response = supabase.table('foreign_investor_summary').select(
            'date, market_type, total_foreign_net_amount'
        ).gte('date', start_date.strftime('%Y%m%d')).lte(
            'date', end_date.strftime('%Y%m%d')
        ).order('date', desc=True).limit(50).execute()
        
        data = response.data
        print(f"📊 조회된 foreign_investor_summary 데이터: {len(data)}개")
        
        # 시장별 분류
        kospi_data = [d for d in data if d['market_type'] == 'KOSPI']
        kosdaq_data = [d for d in data if d['market_type'] == 'KOSDAQ']
        
        print(f"   - KOSPI 데이터: {len(kospi_data)}개")
        print(f"   - KOSDAQ 데이터: {len(kosdaq_data)}개")
        
        # 최신 데이터 샘플 출력
        print("\n📈 최신 KOSPI 데이터 (최근 3일):")
        for item in kospi_data[:3]:
            amount = item['total_foreign_net_amount'] / 100000000  # 억원 단위
            print(f"   - {item['date']}: {amount:,.0f}억원")
        
        print("\n📈 최신 KOSDAQ 데이터 (최근 3일):")
        for item in kosdaq_data[:3]:
            amount = item['total_foreign_net_amount'] / 100000000  # 억원 단위
            print(f"   - {item['date']}: {amount:,.0f}억원")
            
    except Exception as e:
        print(f"❌ foreign_investor_summary 테이블 조회 실패: {e}")
    
    # holdings_value 테이블도 확인
    try:
        response = supabase.table('holdings_value').select(
            'date, market_type, total_holdings_value'
        ).gte('date', start_date.strftime('%Y%m%d')).lte(
            'date', end_date.strftime('%Y%m%d')
        ).order('date', desc=True).limit(50).execute()
        
        data = response.data
        print(f"\n💰 조회된 holdings_value 데이터: {len(data)}개")
        
        # 시장별 분류
        kospi_holdings = [d for d in data if d['market_type'] == 'KOSPI']
        kosdaq_holdings = [d for d in data if d['market_type'] == 'KOSDAQ']
        
        print(f"   - KOSPI 보유액 데이터: {len(kospi_holdings)}개")
        print(f"   - KOSDAQ 보유액 데이터: {len(kosdaq_holdings)}개")
        
        # 최신 보유액 데이터 샘플 출력
        print("\n💰 최신 KOSPI 보유액 데이터 (최근 3일):")
        for item in kospi_holdings[:3]:
            value = item['total_holdings_value'] / 1000000000000  # 조원 단위
            print(f"   - {item['date']}: {value:.1f}조원")
        
        print("\n💰 최신 KOSDAQ 보유액 데이터 (최근 3일):")
        for item in kosdaq_holdings[:3]:
            value = item['total_holdings_value'] / 1000000000000  # 조원 단위
            print(f"   - {item['date']}: {value:.1f}조원")
            
    except Exception as e:
        print(f"❌ holdings_value 테이블 조회 실패: {e}")
    
    print("\n✅ DB 시장별 데이터 확인 완료")

if __name__ == "__main__":
    main()