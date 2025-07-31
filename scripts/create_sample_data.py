#!/usr/bin/env python3
"""
KOSPI/KOSDAQ 샘플 데이터 생성 스크립트
"""

from supabase import create_client
from datetime import datetime, timedelta
import random

# Supabase 설정
SUPABASE_URL = "https://fhcdhdvhbbvtskguvdfz.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoY2RoZHZoYmJ2dHNrZ3V2ZGZ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzEzMTI5MDIsImV4cCI6MjA0Njg4ODkwMn0.WxSlVFgUZjsY3e6I9yWz6gIa6A4YPzAWGnLLyxgdHGo"

def create_sample_data():
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        
        print("🔧 KOSPI/KOSDAQ 샘플 데이터 생성 시작")
        
        # 최근 30일간 데이터 생성
        end_date = datetime.now()
        
        sample_data = []
        
        for i in range(30):
            date = end_date - timedelta(days=i)
            date_str = date.strftime('%Y%m%d')
            
            # KOSPI 데이터
            kospi_data = {
                'date': date_str,
                'market_type': 'KOSPI',
                'foreign_net_amount': random.randint(-500000000000, 1000000000000),  # -5000억 ~ 1조
                'other_foreign_net_amount': random.randint(-100000000000, 200000000000),  # -1000억 ~ 2000억
                'total_foreign_net_amount': 0,  # 계산됨
                'foreign_buy_amount': random.randint(1000000000000, 5000000000000),  # 1조 ~ 5조
                'foreign_sell_amount': random.randint(1000000000000, 5000000000000),  # 1조 ~ 5조
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
            kospi_data['total_foreign_net_amount'] = kospi_data['foreign_net_amount'] + kospi_data['other_foreign_net_amount']
            
            # KOSDAQ 데이터
            kosdaq_data = {
                'date': date_str,
                'market_type': 'KOSDAQ',
                'foreign_net_amount': random.randint(-300000000000, 500000000000),  # -3000억 ~ 5000억
                'other_foreign_net_amount': random.randint(-50000000000, 100000000000),  # -500억 ~ 1000억
                'total_foreign_net_amount': 0,  # 계산됨
                'foreign_buy_amount': random.randint(500000000000, 2000000000000),  # 5000억 ~ 2조
                'foreign_sell_amount': random.randint(500000000000, 2000000000000),  # 5000억 ~ 2조
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            }
            kosdaq_data['total_foreign_net_amount'] = kosdaq_data['foreign_net_amount'] + kosdaq_data['other_foreign_net_amount']
            
            sample_data.extend([kospi_data, kosdaq_data])
        
        print(f"📊 {len(sample_data)}개의 샘플 데이터 생성 완료")
        
        # 기존 데이터 삭제 (최근 30일)
        delete_start = (datetime.now() - timedelta(days=30)).strftime('%Y%m%d')
        delete_end = datetime.now().strftime('%Y%m%d')
        
        print(f"🗑️ 기존 데이터 삭제: {delete_start} ~ {delete_end}")
        
        delete_response = supabase.table('foreign_investor_summary').delete().gte('date', delete_start).lte('date', delete_end).execute()
        print(f"🗑️ 삭제 완료")
        
        # 새 데이터 삽입
        print("📥 새 샘플 데이터 삽입 시작")
        
        # 배치로 삽입 (10개씩)
        batch_size = 10
        for i in range(0, len(sample_data), batch_size):
            batch = sample_data[i:i + batch_size]
            
            response = supabase.table('foreign_investor_summary').insert(batch).execute()
            print(f"📥 배치 {i//batch_size + 1}: {len(batch)}개 삽입 완료")
        
        print("✅ KOSPI/KOSDAQ 샘플 데이터 생성 완료!")
        
        # 결과 확인
        check_response = supabase.table('foreign_investor_summary').select('date, market_type, total_foreign_net_amount').order('date', desc=True).limit(10).execute()
        
        print("\n📊 생성된 데이터 확인 (최신 10개):")
        for item in check_response.data:
            amount = item['total_foreign_net_amount'] / 100000000  # 억원 단위
            print(f"  {item['date']} | {item['market_type']} | {amount:,.0f}억원")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")

if __name__ == "__main__":
    create_sample_data()