#!/usr/bin/env python3
"""
차트 데이터 디버깅 스크립트 - KOSPI/KOSDAQ 데이터 확인
"""

import os
from supabase import create_client, Client
from datetime import datetime, timedelta

# Supabase 설정
SUPABASE_URL = "https://fhcdhdvhbbvtskguvdfz.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoY2RoZHZoYmJ2dHNrZ3V2ZGZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzMTI5MDIsImV4cCI6MjA0Njg4ODkwMn0.WxSlVFgUZjsY3e6I9yWz6gIa6A4YPzAWGnLLyxgdHGo"

def main():
    print("🔍 차트 데이터 디버깅 시작")
    
    try:
        # Supabase 클라이언트 생성
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        # 최근 60일 데이터 조회 (앱과 동일한 조건)
        end_date = datetime.now()
        start_date = end_date - timedelta(days=60)
        
        print(f"📅 조회 기간: {start_date.strftime('%Y%m%d')} ~ {end_date.strftime('%Y%m%d')}")
        
        # foreign_investor_summary 테이블에서 차트용 데이터 조회
        response = supabase.table('foreign_investor_summary').select(
            '*'
        ).gte('date', start_date.strftime('%Y%m%d')).lte(
            'date', end_date.strftime('%Y%m%d')
        ).order('date', desc=True).execute()
        
        data = response.data
        print(f"📊 총 조회된 데이터: {len(data)}개")
        
        # 시장별 분류
        kospi_data = [d for d in data if d['market_type'] == 'KOSPI']
        kosdaq_data = [d for d in data if d['market_type'] == 'KOSDAQ']
        
        print(f"   - KOSPI 데이터: {len(kospi_data)}개")
        print(f"   - KOSDAQ 데이터: {len(kosdaq_data)}개")
        
        # 날짜별 분포 확인
        dates = set()
        for item in data:
            dates.add(item['date'])
        
        sorted_dates = sorted(list(dates), reverse=True)
        print(f"\n📅 고유 날짜 수: {len(sorted_dates)}개")
        print("최근 5일 날짜별 데이터:")
        
        for date in sorted_dates[:5]:
            date_kospi = [d for d in kospi_data if d['date'] == date]
            date_kosdaq = [d for d in kosdaq_data if d['date'] == date]
            
            kospi_amount = date_kospi[0]['total_foreign_net_amount'] if date_kospi else 0
            kosdaq_amount = date_kosdaq[0]['total_foreign_net_amount'] if date_kosdaq else 0
            
            print(f"   - {date}: KOSPI={kospi_amount:,}원, KOSDAQ={kosdaq_amount:,}원")
        
        # 데이터 품질 확인
        print("\n🔍 데이터 품질 확인:")
        
        # 0이 아닌 데이터 확인
        non_zero_kospi = [d for d in kospi_data if d['total_foreign_net_amount'] != 0]
        non_zero_kosdaq = [d for d in kosdaq_data if d['total_foreign_net_amount'] != 0]
        
        print(f"   - KOSPI 0이 아닌 데이터: {len(non_zero_kospi)}개 / {len(kospi_data)}개")
        print(f"   - KOSDAQ 0이 아닌 데이터: {len(non_zero_kosdaq)}개 / {len(kosdaq_data)}개")
        
        # 최대/최소값 확인
        if kospi_data:
            kospi_amounts = [d['total_foreign_net_amount'] for d in kospi_data]
            print(f"   - KOSPI 최대값: {max(kospi_amounts):,}원")
            print(f"   - KOSPI 최소값: {min(kospi_amounts):,}원")
        
        if kosdaq_data:
            kosdaq_amounts = [d['total_foreign_net_amount'] for d in kosdaq_data]
            print(f"   - KOSDAQ 최대값: {max(kosdaq_amounts):,}원")
            print(f"   - KOSDAQ 최소값: {min(kosdaq_amounts):,}원")
            
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
    
    print("\n✅ 차트 데이터 디버깅 완료")

if __name__ == "__main__":
    main()