from pykrx import stock
from datetime import datetime, timedelta

def test_simple():
    # Test multiple recent dates
    test_dates = ['20250128', '20250127', '20250124', '20250123', '20250122']
    
    for date_str in test_dates:
        print(f"\nTesting date: {date_str}")
        
        # Try different market codes
        markets = ['STK', 'KSM', 'KOSPI', 'KOSDAQ']
    
        for market in markets:
            try:
                print(f"  Testing market: {market}")
                df = stock.get_market_net_purchases_of_equities_by_ticker(
                    date_str, date_str, market=market, investor="외국인"
                )
                print(f"  Success! {len(df)} records")
                if not df.empty:
                    print(f"  Columns: {list(df.columns)}")
                    print(f"  First few rows:")
                    print(df.head(3))
                    print(f"  ✅ Found working combination: date={date_str}, market={market}")
                    return
            except Exception as e:
                print(f"  Error with {market}: {e}")
    
    print("❌ No working combination found")

if __name__ == "__main__":
    test_simple()