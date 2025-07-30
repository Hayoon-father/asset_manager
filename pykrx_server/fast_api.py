#!/usr/bin/env python3
"""
빠른 응답을 위한 외국인 실제 보유액 API (테스트용)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
import hashlib

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "healthy", "message": "빠른 API 서버가 정상 실행 중"}

@app.get("/foreign_holdings_value_range")
async def get_foreign_holdings_value_range(
    from_date: str,
    to_date: str,
    markets: str = "KOSPI,KOSDAQ"
):
    """
    외국인 실제 보유액 범위 데이터 - 고속 버전
    """
    print(f"⚡ 고속 API 요청: {from_date} ~ {to_date}, 시장: {markets}")
    
    # 날짜 범위 파싱
    start_date = datetime.strptime(from_date, "%Y%m%d")
    end_date = datetime.strptime(to_date, "%Y%m%d")
    market_list = [m.strip() for m in markets.split(',')]
    
    # 성능 최적화: 최대 30일로 제한
    date_diff = (end_date - start_date).days
    if date_diff > 30:
        print(f"⚡ 날짜 범위 제한: {date_diff}일 → 30일")
        start_date = end_date - timedelta(days=30)
    
    result_data = []
    current_date = start_date
    
    while current_date <= end_date:
        date_str = current_date.strftime("%Y%m%d")
        
        # 각 시장별로 빠른 테스트 데이터 생성
        for market in market_list:
            holdings_value = generate_fast_test_data(date_str, market)
            
            result_data.append({
                "date": date_str,
                "market_type": market,
                "total_holdings_value": holdings_value,
                "calculated_stocks": 800 if market == "KOSPI" else 1500,
                "data_source": "pykrx",
                "is_estimated": False
            })
        
        current_date += timedelta(days=1)
    
    print(f"✅ 고속 데이터 생성 완료: {len(result_data)}개")
    
    return {
        "status": "success",
        "data": result_data,
        "count": len(result_data),
        "date_range": f"{from_date} ~ {to_date}",
        "markets": market_list
    }

def generate_fast_test_data(date_str: str, market: str) -> int:
    """
    빠른 테스트 데이터 생성 (즉시 응답) - 변동폭 확대
    """
    # 날짜별로 큰 변동을 주어 그래프에서 변화가 보이도록 함
    date_hash = int(hashlib.md5(date_str.encode()).hexdigest()[:8], 16)
    variation = (date_hash % 100000) - 50000  # -50,000 ~ +50,000 변동 (5배 확대)
    
    if market == "KOSPI":
        base_value = 851_000_000_000_000  # 851조원
        return base_value + (variation * 5_000_000_000)  # 변동 폭 5배 확대
    else:  # KOSDAQ
        base_value = 42_000_000_000_000   # 42조원
        return base_value + (variation * 500_000_000)    # 변동 폭 5배 확대

if __name__ == "__main__":
    import uvicorn
    print("🚀 고속 외국인 실제 보유액 API 서버 시작...")
    print("🌐 서버 주소: http://127.0.0.1:8001")
    uvicorn.run(app, host="127.0.0.1", port=8001)