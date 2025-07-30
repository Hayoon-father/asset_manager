#!/usr/bin/env python3

import requests
import json

# 설정
SUPABASE_URL = "https://ggkhmksvypmlxhttqthb.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"
PYKRX_API_URL = "http://127.0.0.1:8000"

def sync_date(date_str):
    """특정 날짜의 데이터를 동기화"""
    
    print(f"🔄 {date_str} 데이터 동기화 시작...")
    
    # 헤더 설정
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    try:
        # 1. PyKRX API에서 데이터 가져오기
        print("1️⃣ PyKRX API 호출...")
        pykrx_response = requests.get(f"{PYKRX_API_URL}/foreign_investor_data?date={date_str}")
        
        if pykrx_response.status_code != 200:
            print(f"   ❌ PyKRX API 실패: {pykrx_response.status_code}")
            return False
            
        pykrx_data = pykrx_response.json()
        data_list = pykrx_data.get('data', [])
        
        if not data_list:
            print("   ⚠️ 데이터 없음")
            return True
            
        print(f"   ✅ {len(data_list)}개 데이터 가져옴")
        
        # 2. 시장별, 투자자별로 데이터 집계
        aggregated_data = {}
        
        for item in data_list:
            market = item['시장구분']
            investor = item['투자자구분']
            key = f"{market}_{investor}"
            
            if key not in aggregated_data:
                aggregated_data[key] = {
                    'date': item['날짜'],
                    'market_type': market,
                    'investor_type': investor,
                    'buy_amount': 0,
                    'sell_amount': 0,
                    'net_amount': 0,
                    'buy_volume': 0,
                    'sell_volume': 0,
                    'net_volume': 0,
                }
            
            # 합계 누적
            aggregated_data[key]['buy_amount'] += int(item.get('매수금액', 0))
            aggregated_data[key]['sell_amount'] += int(item.get('매도금액', 0))
            aggregated_data[key]['net_amount'] += int(item.get('순매수금액', 0))
            aggregated_data[key]['buy_volume'] += int(item.get('매수수량', 0))
            aggregated_data[key]['sell_volume'] += int(item.get('매도수량', 0))
            aggregated_data[key]['net_volume'] += int(item.get('순매수수량', 0))
        
        print(f"   📊 집계된 데이터: {list(aggregated_data.keys())}")
        
        # 3. Supabase 형식으로 변환
        supabase_data = []
        for agg_data in aggregated_data.values():
            supabase_item = {
                'date': agg_data['date'],
                'market_type': agg_data['market_type'],
                'investor_type': agg_data['investor_type'],
                'ticker': None,
                'stock_name': '전체시장',
                'buy_amount': agg_data['buy_amount'],
                'sell_amount': agg_data['sell_amount'],
                'net_amount': agg_data['net_amount'],
                'buy_volume': agg_data['buy_volume'],
                'sell_volume': agg_data['sell_volume'],
                'net_volume': agg_data['net_volume'],
            }
            supabase_data.append(supabase_item)
        
        # 4. Supabase에 저장 (upsert)
        print("2️⃣ Supabase에 저장...")
        supabase_url = f"{SUPABASE_URL}/rest/v1/foreign_investor_data"
        
        response = requests.post(
            supabase_url, 
            headers=headers,
            json=supabase_data
        )
        
        if response.status_code == 201:
            print(f"   ✅ {len(supabase_data)}개 데이터 저장 완료")
            return True
        else:
            print(f"   ❌ 저장 실패: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ 오류: {e}")
        return False

def main():
    """최신 날짜들 동기화"""
    dates_to_sync = ['20250729', '20250726', '20250725', '20250724', '20250723']
    
    for date in dates_to_sync:
        result = sync_date(date)
        if result:
            print(f"✅ {date} 동기화 성공\n")
        else:
            print(f"❌ {date} 동기화 실패\n")

if __name__ == "__main__":
    main()