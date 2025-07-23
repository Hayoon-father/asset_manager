# asset_manager Supabase 프로젝트 설정 가이드

## 🆔 프로젝트 정보
- **프로젝트 ID**: `ggkhmksvypmlxhttqthb`
- **프로젝트 URL**: `https://ggkhmksvypmlxhttqthb.supabase.co`
- **대시보드**: https://supabase.com/dashboard/project/ggkhmksvypmlxhttqthb

## 📋 1단계: anon public key 확인

1. Supabase 대시보드 접속: https://supabase.com/dashboard/project/ggkhmksvypmlxhttqthb
2. 좌측 메뉴에서 **Settings** → **API** 클릭
3. **Project API keys** 섹션에서 `anon public` 키 복사

## 🔧 2단계: 설정 파일 업데이트

다음 명령어로 실제 anon key로 설정을 업데이트하세요:

```bash
# 1. Python 스크립트 파일 업데이트
cd /Users/minhopang/Desktop/project/claude/flutter/asset_helper/scripts

# foreign_investor_collector.py 파일에서 다음 라인 찾아서 교체:
# self.supabase_key = "YOUR_ANON_KEY_HERE"  # 실제 anon public key로 교체 필요
# ↓
# self.supabase_key = "실제_anon_key_여기에_붙여넣기"

# setup_database.py 파일에서 동일하게 교체

# 2. Flutter 설정 파일 업데이트
# lib/config/supabase_config.dart 파일에서 다음 라인 찾아서 교체:
# static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
# ↓  
# static const String supabaseAnonKey = '실제_anon_key_여기에_붙여넣기';
```

## 💾 3단계: 데이터베이스 테이블 생성

1. **Supabase SQL Editor 접속**:
   https://supabase.com/dashboard/project/ggkhmksvypmlxhttqthb/sql

2. **SQL 스키마 실행**:
   ```bash
   # setup_new_database.sql 파일 내용을 복사하여 SQL Editor에서 실행
   cat setup_new_database.sql
   ```

3. **실행 결과 확인**:
   - `foreign_investor_data` 테이블 생성됨
   - 5개의 성능 인덱스 생성됨
   - 5개의 분석용 뷰 생성됨

## ✅ 4단계: 설정 검증

```bash
# 가상환경 활성화
source venv/bin/activate

# 데이터베이스 연결 및 테이블 존재 확인
python3 setup_database.py
```

**성공 메시지 예시**:
```
✅ foreign_investor_data 테이블이 존재합니다.
데이터베이스 설정이 완료되어 있습니다.
```

## 🚀 5단계: 데이터 수집 시작

```bash
# 2020년부터 현재까지 모든 외국인 수급 데이터 수집
./run_data_collection.sh
```

## 📊 6단계: 생성된 데이터베이스 구조

### 메인 테이블
- **`foreign_investor_data`**: 외국인 수급 원본 데이터

### 분석용 뷰
- **`daily_foreign_summary`**: 일별 외국인 순매수 현황 요약
- **`top_foreign_buy_stocks`**: 외국인 순매수 상위 종목 (최근 5일)
- **`top_foreign_sell_stocks`**: 외국인 순매도 상위 종목 (최근 5일)
- **`latest_trading_date`**: 최근 거래일 정보
- **`market_statistics`**: 시장별 외국인 자금 흐름 통계

### 성능 인덱스
- `idx_foreign_investor_main`: 복합 조회 최적화
- `idx_foreign_investor_date`: 날짜별 조회 최적화
- `idx_foreign_investor_net_amount`: 순매수금액 정렬 최적화
- `idx_foreign_investor_market`: 시장별 조회 최적화
- `idx_foreign_investor_ticker`: 종목별 조회 최적화

## 🔍 7단계: 데이터 확인

```sql
-- 수집된 데이터 확인
SELECT COUNT(*) as total_records FROM foreign_investor_data;

-- 최근 거래일 확인
SELECT * FROM latest_trading_date;

-- 일별 요약 현황 (최근 10일)
SELECT * FROM daily_foreign_summary LIMIT 10;

-- 외국인 순매수 상위 5개 종목
SELECT * FROM top_foreign_buy_stocks WHERE rank <= 5;
```

## ⚠️ 주의사항

1. **anon public key는 보안상 민감한 정보**이므로 GitHub 등에 커밋하지 마세요
2. **데이터 수집은 시간이 오래 걸립니다** (2020년부터 현재까지 약 4년치 데이터)
3. **pykrx API 호출 제한**을 고려하여 적절한 딜레이가 설정되어 있습니다
4. **네트워크 상태**에 따라 일부 날짜의 데이터 수집이 실패할 수 있습니다

## 🆘 문제 해결

### anon key 관련 오류
```
{'message': 'Invalid API key', 'code': '401'}
```
→ anon public key가 올바르지 않거나 복사 과정에서 누락된 문자가 있습니다.

### 테이블 존재하지 않음 오류
```
{'message': 'relation "public.foreign_investor_data" does not exist', 'code': '42P01'}
```
→ 3단계 데이터베이스 테이블 생성을 다시 확인하세요.

### 데이터 수집 오류
```
HTTP Request: GET ... "HTTP/2 403 Forbidden"
```
→ Row Level Security 정책 또는 API key 권한을 확인하세요.