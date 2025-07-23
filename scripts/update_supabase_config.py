#!/usr/bin/env python3
"""
새로운 asset_manager Supabase 프로젝트 설정 업데이트 스크립트
"""

import os
import re

def update_supabase_config(project_url, anon_key):
    """
    Supabase 설정을 새로운 asset_manager 프로젝트로 업데이트
    
    Args:
        project_url: 새 프로젝트 URL (예: https://xxxxx.supabase.co)
        anon_key: 새 프로젝트의 anon public key
    """
    
    # 현재 스크립트 디렉토리
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 업데이트할 파일들
    files_to_update = [
        os.path.join(script_dir, "foreign_investor_collector.py"),
        os.path.join(script_dir, "setup_database.py"),
    ]
    
    print(f"=== asset_manager 프로젝트 설정 업데이트 ===")
    print(f"새 Project URL: {project_url}")
    print(f"새 API Key: {anon_key[:20]}...")
    print()
    
    for file_path in files_to_update:
        if not os.path.exists(file_path):
            print(f"⚠️  파일이 존재하지 않습니다: {file_path}")
            continue
            
        try:
            # 파일 읽기
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # URL 업데이트
            content = re.sub(
                r'self\.supabase_url = "[^"]*"',
                f'self.supabase_url = "{project_url}"',
                content
            )
            
            # API Key 업데이트
            content = re.sub(
                r'self\.supabase_key = "[^"]*"',
                f'self.supabase_key = "{anon_key}"',
                content
            )
            
            # 파일 쓰기
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            print(f"✅ 업데이트 완료: {os.path.basename(file_path)}")
            
        except Exception as e:
            print(f"❌ 업데이트 실패: {os.path.basename(file_path)} - {e}")
    
    print("\n=== Flutter 앱 설정 업데이트 안내 ===")
    flutter_service_path = "../lib/services/foreign_investor_service.dart"
    print(f"Flutter 서비스 파일도 수동으로 업데이트해주세요:")
    print(f"파일: {flutter_service_path}")
    print(f"- supabaseUrl: '{project_url}'")
    print(f"- supabaseKey: '{anon_key}'")
    print()

def main():
    """
    메인 함수 - 사용자로부터 새 프로젝트 정보 입력받기
    """
    print("새로운 asset_manager Supabase 프로젝트 정보를 입력해주세요:\n")
    
    project_url = input("Project URL (예: https://xxxxx.supabase.co): ").strip()
    if not project_url:
        print("❌ Project URL이 필요합니다.")
        return
    
    anon_key = input("anon public key: ").strip()
    if not anon_key:
        print("❌ anon public key가 필요합니다.")
        return
    
    # URL 형식 검증
    if not project_url.startswith('https://') or not project_url.endswith('.supabase.co'):
        print("❌ Project URL 형식이 올바르지 않습니다. (예: https://xxxxx.supabase.co)")
        return
    
    # 설정 업데이트 실행
    update_supabase_config(project_url, anon_key)
    
    print("\n=== 다음 단계 ===")
    print("1. Supabase 대시보드에서 SQL Editor 열기")
    print("2. setup_new_database.sql 파일 내용을 복사하여 실행")
    print("3. python3 setup_database.py 로 테이블 생성 확인")
    print("4. ./run_data_collection.sh 로 데이터 수집 시작")

if __name__ == "__main__":
    main()