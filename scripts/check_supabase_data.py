#!/usr/bin/env python3

import requests
import json

# Supabase 설정
SUPABASE_URL = "https://ggkhmksvypmlxhttqthb.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"

def check_database():
    """Supabase 데이터베이스의 외국인 수급 데이터 확인"""
    
    print("🔍 Supabase 데이터베이스 연결 확인...")
    
    # 헤더 설정
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    try:
        # 1. 데이터 존재 여부 확인 (간단한 조회)
        print("\n1️⃣ 데이터 존재 여부 확인...")
        
        url = f"{SUPABASE_URL}/rest/v1/foreign_investor_data"
        params = {
            'select': 'id',
            'limit': 1
        }
        
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            if data:
                print(f"   ✅ 데이터베이스에 데이터 존재")
            else:
                print(f"   ⚠️ 데이터베이스가 비어있음")
                return
        else:
            print(f"   ❌ 데이터베이스 연결 실패: {response.status_code}")
            print(f"   응답: {response.text}")
            return
            
        # 2. 최신 데이터 5개 확인
        print("\n2️⃣ 최신 데이터 확인...")
        
        params = {
            'select': 'date,market_type,investor_type,ticker,stock_name,net_amount,created_at',
            'order': 'created_at.desc',
            'limit': 5
        }
        
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            for item in data:
                ticker_info = f"({item['ticker']})" if item['ticker'] else "(전체시장)"
                print(f"   📊 {item['date']} {item['market_type']} {item['investor_type']} {ticker_info}")
                print(f"      종목: {item['stock_name'] or '전체시장'}, 순매수: {item['net_amount']:,}원")
        else:
            print(f"   ❌ 최신 데이터 조회 실패: {response.status_code}")
            
        # 3. 날짜별 집계 확인
        print("\n3️⃣ 날짜별 데이터 현황...")
        
        params = {
            'select': 'date,market_type,investor_type,count(*)',  
            'order': 'date.desc',
            'limit': 10
        }
        
        # 실제로는 RPC나 집계 함수를 사용해야 하지만, 간단히 최근 날짜만 확인
        params = {
            'select': 'date',
            'order': 'date.desc',
            'limit': 10
        }
        
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            dates = list(set([item['date'] for item in data]))
            dates.sort(reverse=True)
            print(f"   📅 최근 날짜들: {', '.join(dates[:5])}")
        else:
            print(f"   ❌ 날짜별 데이터 조회 실패: {response.status_code}")
            
        # 4. 특정 날짜의 시장별 합계 확인 (최신 날짜 사용)
        if dates:
            latest_date = dates[0]
            print(f"\n4️⃣ {latest_date} 시장별 순매수 합계...")
            
            for market in ['KOSPI', 'KOSDAQ']:
                params = {
                    'select': 'net_amount',
                    'date': f'eq.{latest_date}',
                    'market_type': f'eq.{market}',
                    'investor_type': 'eq.외국인',
                    'ticker': 'is.null'  # 전체시장 데이터만
                }
                
                response = requests.get(url, headers=headers, params=params)
                if response.status_code == 200:
                    data = response.json()
                    if data:
                        total = sum(item['net_amount'] for item in data)
                        print(f"   {market}: {total:,}원 ({len(data)}개 데이터)")
                    else:
                        print(f"   {market}: 데이터 없음")
                        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")

if __name__ == "__main__":
    check_database()