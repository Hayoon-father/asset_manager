# 외국인 수급현황 데이터 수집 스크립트

pykrx를 활용하여 한국 증시의 외국인 투자자 거래 데이터를 수집하고 Supabase에 저장하는 Python 스크립트입니다.

## 빠른 시작 (2020년부터 전체 데이터 수집)

```bash
# 스크립트 실행 권한 부여 (최초 1회)
chmod +x run_data_collection.sh

# 2020년 1월 1일부터 현재까지 모든 데이터 수집
./run_data_collection.sh
```

이 스크립트는 다음 작업을 자동으로 수행합니다:
1. Python 가상환경 생성 및 활성화
2. 필요한 패키지 설치
3. 2020년 1월 1일부터 현재까지 일별 데이터 수집
4. 수집된 데이터 검증

## 수동 설치 및 사용법

### 1. 설치 방법

1. Python 가상환경 생성 및 활성화
```bash
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# 또는
venv\Scripts\activate     # Windows
```

2. 필요한 패키지 설치
```bash
pip install -r requirements.txt
```

### 2. 사용 방법

#### 일별 데이터 수집 (기본 모드)
```bash
# 어제 데이터 수집
python foreign_investor_collector.py

# 또는 명시적으로
python foreign_investor_collector.py daily

# 특정 날짜 데이터 수집
python foreign_investor_collector.py daily 20240715
```

#### 기간별 데이터 수집
```bash
# 2023년 1월부터 현재까지
python foreign_investor_collector.py historical 20230101

# 특정 기간
python foreign_investor_collector.py historical 20230101 20231231
```

#### 대량 히스토리 데이터 수집 (2020년부터)
```bash
# 2020년 1월 1일부터 현재까지
python foreign_investor_collector.py bulk

# 특정 시작일부터
python foreign_investor_collector.py bulk 20200101

# 기간 지정
python foreign_investor_collector.py bulk 20200101 20231231
```

#### 데이터 완성도 검증
```bash
python foreign_investor_collector.py verify 20200101 20231231
```

## 수집되는 데이터

### 1. 전체 시장 데이터
- KOSPI/KOSDAQ 전체 시장의 외국인, 기타외국인 거래 데이터
- 매도금액, 매수금액, 순매수금액

### 2. 상위 종목 데이터
- 외국인 순매수 상위 10개 종목 (KOSPI/KOSDAQ 각각)
- 종목별 상세 거래 데이터 (거래대금, 거래량)

## 데이터베이스 스키마

foreign_investor_data 테이블 구조:
```sql
- date: 날짜 (YYYYMMDD 형식)
- market_type: 시장구분 (KOSPI/KOSDAQ)
- investor_type: 투자자유형 (외국인/기타외국인)
- ticker: 종목코드 (전체시장의 경우 null)
- stock_name: 종목명 (종목별 데이터의 경우)
- sell_amount: 매도금액
- buy_amount: 매수금액  
- net_amount: 순매수금액
- sell_volume: 매도거래량 (종목별 데이터)
- buy_volume: 매수거래량 (종목별 데이터)
- net_volume: 순매수거래량 (종목별 데이터)
- created_at: 데이터 생성시간
```

## 스케줄링

### Crontab을 이용한 자동 실행 (macOS/Linux)
```bash
# crontab 편집
crontab -e

# 매일 오후 7시에 전날 데이터 수집
0 19 * * * /path/to/venv/bin/python /path/to/foreign_investor_collector.py daily
```

### 주의사항
- 한국 증시 데이터는 거래일 종료 후 저녁에 최종 확정됩니다
- API 호출 빈도를 고려하여 적절한 간격으로 실행하세요
- 히스토리 데이터 수집 시 대량의 API 호출이 발생할 수 있습니다