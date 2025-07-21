#!/usr/bin/env python3
"""
Supabase에 foreign_investor_data 테이블 생성 스크립트
"""

from supabase import create_client, Client

def create_table():
    # Supabase 설정
    supabase_url = "https://myvuxuwczrlhwnnceile.supabase.co"
    supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15dnV4dXdjenJsaHdubmNlaWxlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI4MjE3MTcsImV4cCI6MjA2ODM5NzcxN30.-DZ4pyYwRmG3dRwR3jkXIc37ARo2mPui36Ji9PmJ690"
    
    supabase: Client = create_client(supabase_url, supabase_key)
    
    # 테이블 생성 SQL
    create_table_sql = """
    CREATE TABLE IF NOT EXISTS foreign_investor_data (
        id BIGSERIAL PRIMARY KEY,
        date VARCHAR(8) NOT NULL,
        market_type VARCHAR(10) NOT NULL,
        investor_type VARCHAR(20) NOT NULL,
        ticker VARCHAR(20),
        stock_name VARCHAR(100),
        sell_amount BIGINT NOT NULL DEFAULT 0,
        buy_amount BIGINT NOT NULL DEFAULT 0,
        net_amount BIGINT NOT NULL DEFAULT 0,
        sell_volume BIGINT,
        buy_volume BIGINT,
        net_volume BIGINT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
    """
    
    try:
        # 테이블 생성 (RPC 사용)
        result = supabase.rpc('create_foreign_investor_table').execute()
        print("테이블 생성 완료")
        return True
    except Exception as e:
        print(f"테이블 생성 실패: {e}")
        # 대신 간단한 데이터 삽입으로 테스트
        try:
            # 테스트 데이터 삽입
            test_data = {
                'date': '20240721',
                'market_type': 'KOSPI',
                'investor_type': '외국인',
                'ticker': None,
                'stock_name': None,
                'sell_amount': 1000000,
                'buy_amount': 2000000,
                'net_amount': 1000000,
                'sell_volume': None,
                'buy_volume': None,
                'net_volume': None
            }
            
            result = supabase.table('foreign_investor_data').insert(test_data).execute()
            print("테스트 데이터 삽입 성공 - 테이블이 이미 존재합니다")
            return True
        except Exception as insert_error:
            print(f"테스트 데이터 삽입도 실패: {insert_error}")
            print("Supabase 웹 콘솔에서 수동으로 테이블을 생성해주세요.")
            return False

if __name__ == "__main__":
    create_table()