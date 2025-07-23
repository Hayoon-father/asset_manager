#!/bin/bash

# 외국인 수급 데이터 수집 실행 스크립트
# 2020년 1월 1일부터 현재까지의 모든 데이터 수집

echo "=========================================="
echo "외국인 수급 데이터 대량 수집 시작"
echo "=========================================="

# 스크립트 디렉토리로 이동
cd "$(dirname "$0")"

# 파이썬 가상환경 확인 및 설치
if [ ! -d "venv" ]; then
    echo "파이썬 가상환경을 생성합니다..."
    python3 -m venv venv
fi

# 가상환경 활성화
echo "가상환경을 활성화합니다..."
source venv/bin/activate

# 패키지 설치
echo "필요한 패키지를 설치합니다..."
pip install -r requirements.txt

# 데이터 수집 실행
echo "2020년 1월 1일부터 데이터 수집을 시작합니다..."
echo "이 작업은 몇 시간이 소요될 수 있습니다."

python3 foreign_investor_collector.py bulk

# 완료 메시지
echo "=========================================="
echo "데이터 수집이 완료되었습니다!"
echo "=========================================="

# 데이터 검증
echo "수집된 데이터를 검증합니다..."
python3 foreign_investor_collector.py verify 20200101 $(date -v-1d +%Y%m%d)

echo "작업이 모두 완료되었습니다."