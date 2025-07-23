#!/bin/bash

# pykrx API 서버 시작 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 pykrx API 서버 시작 중..."

# 가상환경 활성화
if [ -d "venv" ]; then
    echo "📦 가상환경 활성화 중..."
    source venv/bin/activate
else
    echo "❌ 가상환경이 없습니다. setup_database.py를 먼저 실행해주세요."
    exit 1
fi

# 필요한 패키지 설치 확인
echo "📋 필요한 패키지 설치 확인 중..."
pip install -r requirements.txt

# pykrx API 서버 실행
echo "🌐 pykrx API 서버 실행 중..."
echo "   - 주소: http://127.0.0.1:8000"
echo "   - API 문서: http://127.0.0.1:8000/docs"
echo "   - 종료: Ctrl+C"
echo ""

python pykrx_api_server.py