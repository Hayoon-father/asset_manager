#!/bin/bash

echo "🚀 PyKRX API 서버 설정 및 실행"
echo "================================"

# Python 가상환경 생성 (없을 경우)
if [ ! -d "venv" ]; then
    echo "📦 Python 가상환경 생성 중..."
    python3 -m venv venv
fi

# 가상환경 활성화
echo "🔧 가상환경 활성화..."
source venv/bin/activate

# 패키지 설치
echo "📥 필요한 패키지 설치 중..."
pip install -r requirements.txt

# 서버 실행
echo "🌐 서버 시작..."
echo "   주소: http://127.0.0.1:8000"
echo "   문서: http://127.0.0.1:8000/docs"
echo ""
echo "서버를 중지하려면 Ctrl+C를 누르세요."
echo ""

python main.py