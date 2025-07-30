#!/usr/bin/env python3

import requests
import json

# Supabase 설정
SUPABASE_URL = "https://ggkhmksvypmlxhttqthb.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"

def clear_fake_data():
    """더미/테스트 데이터 삭제"""
    
    print("🧹 더미 데이터 삭제 중...")
    
    # 헤더 설정
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    try:
        url = f"{SUPABASE_URL}/rest/v1/foreign_investor_data"
        
        # 더미 데이터 조건: 순매수 금액이 정확히 -200,000,000원인 데이터
        params = {
            'net_amount': 'eq.-200000000'
        }
        
        response = requests.delete(url, headers=headers, params=params)
        
        if response.status_code == 204:
            print("   ✅ 더미 데이터 삭제 완료")
        else:
            print(f"   ❌ 삭제 실패: {response.status_code}")
            print(f"   응답: {response.text}")
            
        # 삭제 후 확인
        print("\n🔍 삭제 후 데이터 확인...")
        params = {
            'select': 'id',
            'limit': 1
        }
        
        response = requests.get(url, headers=headers, params=params)
        if response.status_code == 200:
            data = response.json()
            if data:
                print(f"   📊 남은 데이터: {len(data)}개")
            else:
                print(f"   ✅ 데이터베이스가 완전히 비워짐")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")

if __name__ == "__main__":
    clear_fake_data()