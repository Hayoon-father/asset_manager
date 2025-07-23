#!/usr/bin/env python3
"""
데이터베이스 테이블 및 스키마 설정 스크립트
Supabase에 foreign_investor_data 테이블을 생성합니다.
"""

import os
import sys
from supabase import create_client, Client
from dotenv import load_dotenv
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DatabaseSetup:
    def __init__(self):
        # 환경 변수 로드
        load_dotenv()
        
        # Supabase 설정 (asset_manager 프로젝트)
        self.supabase_url = "https://ggkhmksvypmlxhttqthb.supabase.co"
        self.supabase_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdna2hta3N2eXBtbHhodHRxdGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNDQ1MTUsImV4cCI6MjA2ODgyMDUxNX0.pCQE4Hr7NNpX2zjAmLYq--j9CDyodK1PlDZX3kJRFJ8"
        
        # Supabase 클라이언트 생성
        self.supabase: Client = create_client(self.supabase_url, self.supabase_key)
        
        logger.info("DatabaseSetup 초기화 완료")

    def execute_sql_file(self, sql_file_path: str):
        """
        SQL 파일을 읽어서 실행
        """
        try:
            # SQL 파일 읽기
            with open(sql_file_path, 'r', encoding='utf-8') as file:
                sql_content = file.read()
            
            # SQL 문장들을 분리 (세미콜론 기준)
            sql_statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
            
            logger.info(f"{len(sql_statements)}개의 SQL 문장을 실행합니다...")
            
            for i, statement in enumerate(sql_statements, 1):
                try:
                    logger.info(f"SQL 문장 {i}/{len(sql_statements)} 실행 중...")
                    
                    # Supabase RPC를 통해 SQL 실행
                    result = self.supabase.rpc('exec_sql', {'sql': statement}).execute()
                    logger.info(f"SQL 문장 {i} 실행 완료")
                    
                except Exception as e:
                    logger.warning(f"SQL 문장 {i} 실행 중 경고: {e}")
                    # 경고는 로그만 남기고 계속 진행
                    continue
            
            logger.info("모든 SQL 문장 실행 완료")
            return True
            
        except Exception as e:
            logger.error(f"SQL 파일 실행 중 오류: {e}")
            return False

    def create_table_directly(self):
        """
        RPC 대신 직접 테이블 생성 (단순화된 버전)
        """
        try:
            logger.info("데이터베이스 테이블 생성을 시도합니다...")
            
            # 테이블이 이미 존재하는지 확인
            try:
                result = self.supabase.table("foreign_investor_data").select("*").limit(1).execute()
                logger.info("테이블이 이미 존재합니다.")
                return True
            except Exception:
                logger.info("테이블이 존재하지 않으므로 생성합니다.")
            
            # 테이블 생성 SQL (기본적인 구조만)
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
            
            # Supabase는 관리자 권한이 필요한 작업이므로, 
            # 실제로는 Supabase 대시보드에서 수동으로 생성해야 합니다.
            logger.warning("Supabase에서는 일반 사용자가 직접 테이블을 생성할 수 없습니다.")
            logger.info("다음 방법 중 하나를 사용하세요:")
            logger.info("1. Supabase 대시보드 > SQL Editor에서 create_foreign_investor_table.sql 실행")
            logger.info("2. Supabase CLI를 사용하여 마이그레이션 실행")
            
            return False
            
        except Exception as e:
            logger.error(f"테이블 생성 중 오류: {e}")
            return False

    def check_table_exists(self):
        """
        테이블이 존재하는지 확인
        """
        try:
            result = self.supabase.table("foreign_investor_data").select("*").limit(1).execute()
            logger.info("✅ foreign_investor_data 테이블이 존재합니다.")
            return True
        except Exception as e:
            logger.error(f"❌ foreign_investor_data 테이블이 존재하지 않습니다: {e}")
            return False

def main():
    """메인 함수"""
    setup = DatabaseSetup()
    
    # 테이블 존재 확인
    if setup.check_table_exists():
        logger.info("데이터베이스 설정이 완료되어 있습니다.")
        return True
    
    logger.info("=== 데이터베이스 설정 가이드 ===")
    logger.info("foreign_investor_data 테이블을 생성하려면:")
    logger.info("1. Supabase 프로젝트 대시보드에 로그인")
    logger.info("2. 'SQL Editor' 메뉴로 이동")  
    logger.info("3. 'create_foreign_investor_table.sql' 파일의 내용을 복사하여 실행")
    logger.info("4. 이 스크립트를 다시 실행하여 테이블 생성 확인")
    
    # SQL 파일 경로 출력
    current_dir = os.path.dirname(os.path.abspath(__file__))
    sql_file_path = os.path.join(current_dir, "create_foreign_investor_table.sql")
    logger.info(f"SQL 파일 위치: {sql_file_path}")
    
    return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)