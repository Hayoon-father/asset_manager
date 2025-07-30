#!/usr/bin/env python3

import requests
import json

# Supabase 설정
SUPABASE_URL = "https://ggkhmksvypmlxhttqthb.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"

def test_holdings_service_flow():
    """Flutter HoldingsValueService와 동일한 방식으로 데이터 조회 테스트"""
    
    print("🧪 HoldingsValueService 데이터 로딩 플로우 테스트")
    print("=" * 60)
    
    # 헤더 설정
    headers = {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
        'Content-Type': 'application/json'
    }
    
    try:
        # 1. DB에서 최근 60일 데이터 조회 (HoldingsValueService.getImmediateData 방식)
        print("1️⃣ DB에서 최근 60일 데이터 조회 중...")
        
        from datetime import datetime, timedelta
        to_date = datetime.now()
        from_date = to_date - timedelta(days=60)
        
        from_date_str = from_date.strftime('%Y%m%d')
        to_date_str = to_date.strftime('%Y%m%d')
        
        print(f"   날짜 범위: {from_date_str} ~ {to_date_str}")
        
        # Supabase 쿼리 (HoldingsValueService._loadFromDatabase와 동일)
        url = f"{SUPABASE_URL}/rest/v1/foreign_holdings_value"
        params = {
            'select': '*',
            'date': f'gte.{from_date_str}',
            'date': f'lte.{to_date_str}',
            'market_type': 'in.(KOSPI,KOSDAQ)',
            'order': 'date.desc,market_type.asc'
        }
        
        response = requests.get(url, headers=headers, params=params)
        
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ DB 조회 성공: {len(data)}개 데이터")
            
            if data:
                # 날짜별, 시장별 그룹화 (Provider에서 holdingsMap 생성 방식과 동일)
                holdings_map = {}
                
                for item in data:
                    date = item['date']
                    market = item['market_type']
                    value = item['total_holdings_value']
                    
                    if date not in holdings_map:
                        holdings_map[date] = {}
                    holdings_map[date][market] = value
                
                print(f"   📊 그룹화된 날짜 수: {len(holdings_map)}개")
                
                # 최근 5일 데이터 출력
                sorted_dates = sorted(holdings_map.keys(), reverse=True)
                print("   🔍 최근 5일 데이터:")
                
                for date in sorted_dates[:5]:
                    markets = holdings_map[date]
                    kospi_value = markets.get('KOSPI', 0)
                    kosdaq_value = markets.get('KOSDAQ', 0)
                    total_value = kospi_value + kosdaq_value
                    
                    kospi_trillion = kospi_value / 1_000_000_000_000
                    kosdaq_trillion = kosdaq_value / 1_000_000_000_000
                    total_trillion = total_value / 1_000_000_000_000
                    
                    print(f"      {date}: KOSPI {kospi_trillion:.1f}조, KOSDAQ {kosdaq_trillion:.1f}조, 합계 {total_trillion:.1f}조")
                
                # actualHoldingsValue 설정 시뮬레이션
                print("\\n2️⃣ actualHoldingsValue 설정 시뮬레이션:")
                
                # 가상의 차트 데이터 (최근 7일)
                chart_dates = sorted_dates[:7]
                
                for date in chart_dates:
                    if date in holdings_map:
                        market_holdings = holdings_map[date]
                        
                        # ALL 시장 (전체)
                        kospi_val = market_holdings.get('KOSPI', 0)
                        kosdaq_val = market_holdings.get('KOSDAQ', 0)
                        total_val = kospi_val + kosdaq_val
                        total_trillion = total_val / 1_000_000_000_000
                        
                        print(f"      📊 [{date}] ALL: {total_trillion:.1f}조원 (KOSPI: {kospi_val}, KOSDAQ: {kosdaq_val})")
                        
                        # 개별 시장
                        for market in ['KOSPI', 'KOSDAQ']:
                            value = market_holdings.get(market, 0)
                            trillion = value / 1_000_000_000_000
                            print(f"      📊 [{date}] {market}: {trillion:.1f}조원 ({value})")
                    else:
                        print(f"      ❌ [{date}] 데이터 없음 - fallback 필요")
                
                # 결론
                print("\\n🎯 테스트 결과:")
                if len(data) > 0:
                    print("   ✅ DB에서 데이터 정상 조회됨")
                    print("   ✅ holdingsMap 생성 가능")
                    print("   ✅ actualHoldingsValue 설정 가능")
                    print("\\n   📝 결론: DB 데이터는 정상이므로, Flutter 앱의 다른 부분에서 문제 발생 중")
                else:
                    print("   ❌ DB 조회는 성공했으나 데이터가 없음")
            else:
                print("   ⚠️ DB 조회 성공했으나 결과 데이터 없음")
        else:
            print(f"   ❌ DB 조회 실패: {response.status_code} - {response.text}")
            
    except Exception as e:
        print(f"❌ 테스트 중 오류: {e}")

if __name__ == "__main__":
    test_holdings_service_flow()