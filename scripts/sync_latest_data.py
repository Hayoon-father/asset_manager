#!/usr/bin/env python3

import requests
import json
from datetime import datetime, timedelta

# Supabase 설정
SUPABASE_URL = "https://ggkhmksvypmlxhttqthb.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"

# PyKRX API 서버 설정
PYKRX_API_URL = "http://127.0.0.1:8000"

def sync_latest_data():
    """최신 외국인 투자자 데이터를 PyKRX에서 가져와 Supabase에 동기화"""
    
    print("🔄 최신 데이터 동기화 시작...")
    
    # 헤더 설정
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    try:
        # 1. DB에서 최신 날짜 확인
        print("1️⃣ DB 최신 날짜 확인...")
        
        url = f"{SUPABASE_URL}/rest/v1/foreign_investor_data"
        params = {
            'select': 'date',
            'order': 'date.desc',
            'limit': 1
        }
        
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            latest_db_date = data[0]['date'] if data else None
            print(f"   📅 DB 최신 날짜: {latest_db_date}")
        else:
            print(f"   ❌ DB 조회 실패: {response.status_code}")
            return False
            
        # 2. PyKRX API에서 최신 데이터 가져오기 (최근 5일)
        print("2️⃣ PyKRX에서 최신 데이터 가져오기...")
        
        # 최근 5일 데이터 가져오기
        today = datetime.now()
        from_date = (today - timedelta(days=5)).strftime('%Y%m%d')
        to_date = today.strftime('%Y%m%d')
        
        print(f"   📅 데이터 범위: {from_date} ~ {to_date}")
        
        # PyKRX API 서버 호출
        pykrx_url = f"{PYKRX_API_URL}/foreign_investor_data_range"
        pykrx_params = {
            'from_date': from_date,
            'to_date': to_date,
            'markets': 'KOSPI,KOSDAQ'
        }
        
        pykrx_response = requests.get(pykrx_url, params=pykrx_params, timeout=60)
        
        if pykrx_response.status_code != 200:
            print(f"   ❌ PyKRX API 호출 실패: {pykrx_response.status_code}")
            return False
            
        pykrx_data = pykrx_response.json()
        
        if not pykrx_data['data']:
            print("   ⚠️ PyKRX에서 새로운 데이터 없음")
            return True
            
        print(f"   ✅ PyKRX 데이터 {len(pykrx_data['data'])}개 가져옴")
        
        # 3. 새로운 데이터만 필터링
        print("3️⃣ 새로운 데이터 필터링...")
        new_data_list = []
        
        for item in pykrx_data['data']:
            # DB에 이미 존재하는지 확인
            params = {
                'select': 'id',
                'date': f"eq.{item['날짜']}",
                'market_type': f"eq.{item['시장구분']}",
                'investor_type': f"eq.{item['투자자구분']}",
                'limit': 1
            }
            
            if item.get('종목코드'):
                params['ticker'] = f"eq.{item['종목코드']}"
            else:
                params['ticker'] = 'is.null'
            
            response = requests.get(url, headers=headers, params=params)
            
            if response.status_code == 200 and not response.json():
                # 존재하지 않는 데이터만 추가
                supabase_item = {
                    'date': item['날짜'],
                    'market_type': item['시장구분'],
                    'investor_type': item['투자자구분'],
                    'ticker': item.get('종목코드'),
                    'stock_name': item.get('종목명'),
                    'buy_amount': int(item.get('매수금액', 0)),
                    'sell_amount': int(item.get('매도금액', 0)),
                    'net_amount': int(item.get('순매수금액', 0)),
                    'buy_volume': int(item.get('매수수량', 0)),
                    'sell_volume': int(item.get('매도수량', 0)),
                    'net_volume': int(item.get('순매수수량', 0)),
                }
                new_data_list.append(supabase_item)
        
        if not new_data_list:
            print("   ✅ 모든 데이터가 이미 DB에 존재함")
            return True
            
        print(f"   📊 새로운 데이터 {len(new_data_list)}개 발견")
        
        # 4. 새로운 데이터 저장
        print("4️⃣ 새로운 데이터 저장...")
        
        # 배치로 저장 (100개씩)
        batch_size = 100
        total_saved = 0
        
        for i in range(0, len(new_data_list), batch_size):
            batch = new_data_list[i:i + batch_size]
            
            response = requests.post(
                url,
                headers=headers,
                json=batch
            )
            
            if response.status_code == 201:
                total_saved += len(batch)
                print(f"   ✅ 배치 저장 완료: {len(batch)}개")
            else:
                print(f"   ❌ 배치 저장 실패: {response.status_code} - {response.text}")
                return False
        
        print(f"🎉 데이터 동기화 완료! 총 {total_saved}개 새로운 데이터 저장됨")
        return True
        
    except Exception as e:
        print(f"❌ 동기화 오류: {e}")
        return False

if __name__ == "__main__":
    sync_latest_data()