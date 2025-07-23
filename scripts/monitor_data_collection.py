#!/usr/bin/env python3
"""
외국인 수급 데이터 수집 진행 상황 모니터링 스크립트
"""

import time
import logging
from datetime import datetime
from foreign_investor_collector import ForeignInvestorDataCollector

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DataCollectionMonitor:
    def __init__(self):
        self.collector = ForeignInvestorDataCollector()
        self.last_count = 0
        self.start_time = datetime.now()
        
    def get_current_status(self):
        """현재 데이터 수집 상태 조회"""
        try:
            # 총 레코드 수
            count_result = self.collector.supabase.table('foreign_investor_data').select('*', count='exact').execute()
            total_records = count_result.count
            
            # 날짜별 통계
            date_result = self.collector.supabase.table('foreign_investor_data').select('date').execute()
            unique_dates = set(item['date'] for item in date_result.data)
            
            # 최신/최초 날짜
            dates = sorted(unique_dates) if unique_dates else []
            start_date = dates[0] if dates else None
            end_date = dates[-1] if dates else None
            
            return {
                'total_records': total_records,
                'trading_days': len(unique_dates),
                'start_date': start_date,
                'end_date': end_date,
                'dates': dates
            }
            
        except Exception as e:
            logger.error(f"상태 조회 중 오류: {e}")
            return None
    
    def check_completion_status(self, status):
        """수집 완료 여부 확인"""
        if not status or not status['end_date']:
            return False, "데이터 없음"
        
        end_date = status['end_date']
        current_year = datetime.now().year
        
        # 2025년 데이터가 있으면 수집 완료로 간주
        if end_date.startswith('2025'):
            return True, "2025년 데이터 수집 완료"
        elif end_date.startswith('2024'):
            return False, f"2024년 데이터 수집 중 (최신: {end_date})"
        elif end_date.startswith('2023'):
            return False, f"2023년 데이터 수집 중 (최신: {end_date})"
        elif end_date.startswith('2022'):
            return False, f"2022년 데이터 수집 중 (최신: {end_date})"
        elif end_date.startswith('2021'):
            return False, f"2021년 데이터 수집 중 (최신: {end_date})"
        else:
            return False, f"2020년 데이터 수집 중 (최신: {end_date})"
    
    def calculate_progress(self, status):
        """수집 진행률 계산"""
        if not status or not status['end_date']:
            return 0.0
        
        end_date = status['end_date']
        start_year = 2020
        current_year = datetime.now().year
        total_years = current_year - start_year + 1
        
        # 현재까지 수집된 년도 계산
        collected_year = int(end_date[:4])
        collected_years = collected_year - start_year + 1
        
        # 대략적인 진행률 (년도 기준)
        progress = (collected_years / total_years) * 100
        return min(progress, 100.0)
    
    def monitor_loop(self, check_interval=300):  # 5분마다 체크
        """모니터링 루프"""
        logger.info("=== 외국인 수급 데이터 수집 모니터링 시작 ===")
        logger.info(f"체크 간격: {check_interval}초")
        
        while True:
            try:
                status = self.get_current_status()
                
                if status:
                    # 진행 상황 출력
                    progress = self.calculate_progress(status)
                    is_complete, status_msg = self.check_completion_status(status)
                    
                    elapsed_time = datetime.now() - self.start_time
                    
                    logger.info(f"📊 현재 상태: {status['total_records']:,}개 레코드")
                    logger.info(f"📅 수집 기간: {status['start_date']} ~ {status['end_date']} ({status['trading_days']:,}일)")
                    logger.info(f"⏱️ 경과 시간: {elapsed_time}")
                    logger.info(f"📈 진행률: {progress:.1f}%")
                    logger.info(f"🎯 상태: {status_msg}")
                    
                    # 증가량 체크
                    if self.last_count > 0:
                        increase = status['total_records'] - self.last_count
                        logger.info(f"📈 증가량: +{increase:,}개 (최근 {check_interval}초)")
                    
                    self.last_count = status['total_records']
                    
                    # 완료 체크
                    if is_complete:
                        logger.info("🎉 *** 데이터 수집 완료! ***")
                        logger.info(f"✅ 최종 레코드 수: {status['total_records']:,}개")
                        logger.info(f"📅 최종 수집 기간: {status['start_date']} ~ {status['end_date']}")
                        logger.info(f"⏱️ 총 소요 시간: {elapsed_time}")
                        break
                else:
                    logger.warning("상태 조회 실패")
                
                logger.info("-" * 60)
                time.sleep(check_interval)
                
            except KeyboardInterrupt:
                logger.info("모니터링이 사용자에 의해 중단되었습니다.")
                break
            except Exception as e:
                logger.error(f"모니터링 중 오류: {e}")
                time.sleep(30)  # 오류 시 30초 대기

def main():
    """메인 함수"""
    monitor = DataCollectionMonitor()
    
    # 현재 상태 한번 체크
    current_status = monitor.get_current_status()
    if current_status:
        is_complete, status_msg = monitor.check_completion_status(current_status)
        
        if is_complete:
            logger.info("🎉 데이터 수집이 이미 완료되었습니다!")
            logger.info(f"✅ 총 레코드 수: {current_status['total_records']:,}개")
            logger.info(f"📅 수집 기간: {current_status['start_date']} ~ {current_status['end_date']}")
            return
        else:
            logger.info(f"🔄 데이터 수집 진행 중: {status_msg}")
    
    # 모니터링 시작
    try:
        monitor.monitor_loop(check_interval=300)  # 5분마다 체크
    except Exception as e:
        logger.error(f"모니터링 실행 중 오류: {e}")

if __name__ == "__main__":
    main()