#!/usr/bin/env python3
"""
데이터 수집 완료 여부를 간단히 체크하는 스크립트
"""

from foreign_investor_collector import ForeignInvestorDataCollector
from datetime import datetime
import logging

# 로그 레벨을 ERROR로 설정하여 불필요한 로그 숨김
logging.getLogger().setLevel(logging.ERROR)

def check_collection_status():
    """수집 완료 여부 체크"""
    try:
        collector = ForeignInvestorDataCollector()
        
        # 총 레코드 수
        count_result = collector.supabase.table('foreign_investor_data').select('*', count='exact').execute()
        total_records = count_result.count
        
        # 최신 날짜 확인
        date_result = collector.supabase.table('foreign_investor_data').select('date').order('date', desc=True).limit(1).execute()
        
        if not date_result.data:
            print("❌ 데이터가 없습니다.")
            return False
        
        latest_date = date_result.data[0]['date']
        current_year = datetime.now().year
        
        print(f"📊 현재 총 레코드: {total_records:,}개")
        print(f"📅 최신 수집 날짜: {latest_date}")
        
        # 완료 여부 판단 (2024년 12월 또는 2025년 데이터가 있으면 완료)
        if latest_date >= '20241201':  # 2024년 12월 이후면 거의 완료
            print("🎉 *** 데이터 수집 완료! ***")
            print(f"✅ 총 {total_records:,}개 레코드 수집 완료")
            print(f"📅 수집 기간: 2020-01-01 ~ {latest_date}")
            return True
        else:
            # 진행률 계산
            year = int(latest_date[:4])
            month = int(latest_date[4:6])
            
            start_year = 2020
            current_year = datetime.now().year
            
            # 대략적인 진행률
            years_passed = year - start_year
            months_passed = years_passed * 12 + month
            total_months = (current_year - start_year) * 12 + datetime.now().month
            
            progress = (months_passed / total_months) * 100
            
            print(f"🔄 데이터 수집 진행 중...")
            print(f"📈 진행률: 약 {progress:.1f}%")
            print(f"⏰ 수집 중인 기간: {year}년 {month}월")
            return False
            
    except Exception as e:
        print(f"❌ 상태 확인 중 오류: {e}")
        return False

if __name__ == "__main__":
    is_complete = check_collection_status()
    
    if not is_complete:
        print("\n💡 팁: 다음 명령어로 언제든 진행 상황을 확인할 수 있습니다:")
        print("python3 check_completion.py")
        print("\n🚀 데이터 수집이 백그라운드에서 계속 진행됩니다.")