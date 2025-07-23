-- ================================================
-- 외국인 수급현황 데이터베이스 스키마 (asset_manager 프로젝트용)
-- Supabase 프로젝트: asset_manager
-- ================================================

-- 1. 메인 테이블: foreign_investor_data
CREATE TABLE IF NOT EXISTS foreign_investor_data (
    id BIGSERIAL PRIMARY KEY,
    date VARCHAR(8) NOT NULL, -- YYYYMMDD 형식
    market_type VARCHAR(10) NOT NULL, -- KOSPI, KOSDAQ
    investor_type VARCHAR(20) NOT NULL, -- 외국인, 기타외국인
    ticker VARCHAR(20), -- 종목코드 (전체시장의 경우 NULL)
    stock_name VARCHAR(100), -- 종목명 (종목별 데이터의 경우)
    sell_amount BIGINT NOT NULL DEFAULT 0, -- 매도금액 (원)
    buy_amount BIGINT NOT NULL DEFAULT 0, -- 매수금액 (원)
    net_amount BIGINT NOT NULL DEFAULT 0, -- 순매수금액 (원)
    sell_volume BIGINT, -- 매도거래량 (주)
    buy_volume BIGINT, -- 매수거래량 (주)
    net_volume BIGINT, -- 순매수거래량 (주)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 성능 최적화를 위한 인덱스 생성
-- 복합 인덱스 (날짜, 시장, 투자자유형, 종목코드로 빠른 조회)
CREATE INDEX IF NOT EXISTS idx_foreign_investor_main 
ON foreign_investor_data (date, market_type, investor_type, ticker);

-- 날짜별 조회를 위한 인덱스 (최신순 정렬)
CREATE INDEX IF NOT EXISTS idx_foreign_investor_date 
ON foreign_investor_data (date DESC);

-- 순매수금액 기준 정렬을 위한 인덱스 (상위/하위 종목 조회)
CREATE INDEX IF NOT EXISTS idx_foreign_investor_net_amount
ON foreign_investor_data (date, net_amount DESC);

-- 시장별 조회를 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_foreign_investor_market
ON foreign_investor_data (market_type, date DESC);

-- 종목별 조회를 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_foreign_investor_ticker
ON foreign_investor_data (ticker, date DESC) WHERE ticker IS NOT NULL;

-- 3. 중복 방지를 위한 유니크 제약조건
-- (날짜, 시장, 투자자유형, 종목코드) 조합으로 중복 방지
CREATE UNIQUE INDEX IF NOT EXISTS uk_foreign_investor_unique
ON foreign_investor_data (date, market_type, investor_type, COALESCE(ticker, 'MARKET_TOTAL'));

-- 4. Row Level Security (RLS) 설정
ALTER TABLE foreign_investor_data ENABLE ROW LEVEL SECURITY;

-- 5. 보안 정책 생성
-- 모든 사용자가 읽기 가능하도록 정책 생성
CREATE POLICY "Enable read access for all users" ON foreign_investor_data
FOR SELECT USING (true);

-- 데이터 수집을 위한 쓰기 정책 (모든 사용자 쓰기 가능)
CREATE POLICY "Enable insert for all users" ON foreign_investor_data
FOR INSERT WITH CHECK (true);

-- 업데이트 정책
CREATE POLICY "Enable update for all users" ON foreign_investor_data
FOR UPDATE USING (true);

-- 삭제 정책 (필요시)
CREATE POLICY "Enable delete for all users" ON foreign_investor_data
FOR DELETE USING (true);

-- 6. 자동 업데이트 시간 갱신을 위한 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 7. updated_at 자동 업데이트 트리거 생성
CREATE TRIGGER update_foreign_investor_data_updated_at 
    BEFORE UPDATE ON foreign_investor_data 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 8. 유용한 뷰 생성
-- 8.1 일별 전체 외국인 순매수 현황 뷰
CREATE OR REPLACE VIEW daily_foreign_summary AS
SELECT 
    date,
    market_type,
    SUM(CASE WHEN investor_type = '외국인' THEN net_amount ELSE 0 END) as foreign_net_amount,
    SUM(CASE WHEN investor_type = '기타외국인' THEN net_amount ELSE 0 END) as other_foreign_net_amount,
    SUM(net_amount) as total_foreign_net_amount,
    SUM(CASE WHEN investor_type = '외국인' THEN buy_amount ELSE 0 END) as foreign_buy_amount,
    SUM(CASE WHEN investor_type = '외국인' THEN sell_amount ELSE 0 END) as foreign_sell_amount,
    SUM(CASE WHEN investor_type = '외국인' THEN sell_amount + buy_amount ELSE 0 END) as foreign_total_amount
FROM foreign_investor_data 
WHERE ticker IS NULL  -- 전체 시장 데이터만
GROUP BY date, market_type
ORDER BY date DESC, market_type;

-- 8.2 외국인 순매수 상위 종목 뷰 (최근 5일)
CREATE OR REPLACE VIEW top_foreign_buy_stocks AS
SELECT 
    date,
    market_type,
    ticker,
    stock_name,
    net_amount,
    buy_amount,
    sell_amount,
    net_volume,
    buy_volume,
    sell_volume,
    ROW_NUMBER() OVER (PARTITION BY date, market_type ORDER BY net_amount DESC) as rank
FROM foreign_investor_data 
WHERE ticker IS NOT NULL 
  AND date >= TO_CHAR(CURRENT_DATE - INTERVAL '5 days', 'YYYYMMDD')
  AND net_amount > 0
ORDER BY date DESC, market_type, net_amount DESC;

-- 8.3 외국인 순매도 상위 종목 뷰 (최근 5일)
CREATE OR REPLACE VIEW top_foreign_sell_stocks AS
SELECT 
    date,
    market_type,
    ticker,
    stock_name,
    net_amount,
    buy_amount,
    sell_amount,
    net_volume,
    buy_volume,
    sell_volume,
    ROW_NUMBER() OVER (PARTITION BY date, market_type ORDER BY net_amount ASC) as rank
FROM foreign_investor_data 
WHERE ticker IS NOT NULL 
  AND date >= TO_CHAR(CURRENT_DATE - INTERVAL '5 days', 'YYYYMMDD')
  AND net_amount < 0
ORDER BY date DESC, market_type, net_amount ASC;

-- 8.4 최근 거래일 정보 뷰
CREATE OR REPLACE VIEW latest_trading_date AS
SELECT 
    MAX(date) as latest_date,
    COUNT(DISTINCT date) as total_trading_days,
    MIN(date) as earliest_date
FROM foreign_investor_data;

-- 8.5 시장별 통계 뷰
CREATE OR REPLACE VIEW market_statistics AS
SELECT 
    date,
    SUM(CASE WHEN market_type = 'KOSPI' THEN total_foreign_net_amount ELSE 0 END) as kospi_net_amount,
    SUM(CASE WHEN market_type = 'KOSDAQ' THEN total_foreign_net_amount ELSE 0 END) as kosdaq_net_amount,
    SUM(total_foreign_net_amount) as total_net_amount,
    SUM(CASE WHEN market_type = 'KOSPI' THEN foreign_total_amount ELSE 0 END) as kospi_total_amount,
    SUM(CASE WHEN market_type = 'KOSDAQ' THEN foreign_total_amount ELSE 0 END) as kosdaq_total_amount
FROM daily_foreign_summary
GROUP BY date
ORDER BY date DESC;

-- 9. 테이블 및 컬럼 설명 추가
COMMENT ON TABLE foreign_investor_data IS '외국인 투자자 수급현황 데이터 - pykrx에서 수집한 한국거래소 데이터';
COMMENT ON COLUMN foreign_investor_data.id IS '고유 식별자 (자동 증가)';
COMMENT ON COLUMN foreign_investor_data.date IS '데이터 날짜 (YYYYMMDD 형식, 예: 20241215)';
COMMENT ON COLUMN foreign_investor_data.market_type IS '시장 구분 (KOSPI: 코스피, KOSDAQ: 코스닥)';
COMMENT ON COLUMN foreign_investor_data.investor_type IS '투자자 유형 (외국인: 일반 외국인, 기타외국인: 기타 외국계)';
COMMENT ON COLUMN foreign_investor_data.ticker IS '종목코드 (6자리, 전체시장 데이터의 경우 NULL)';
COMMENT ON COLUMN foreign_investor_data.stock_name IS '종목명 (개별 종목 데이터의 경우)';
COMMENT ON COLUMN foreign_investor_data.sell_amount IS '매도금액 (원 단위)';
COMMENT ON COLUMN foreign_investor_data.buy_amount IS '매수금액 (원 단위)';
COMMENT ON COLUMN foreign_investor_data.net_amount IS '순매수금액 (매수금액 - 매도금액, 원 단위)';
COMMENT ON COLUMN foreign_investor_data.sell_volume IS '매도거래량 (주식 수)';
COMMENT ON COLUMN foreign_investor_data.buy_volume IS '매수거래량 (주식 수)';
COMMENT ON COLUMN foreign_investor_data.net_volume IS '순매수거래량 (매수량 - 매도량, 주식 수)';
COMMENT ON COLUMN foreign_investor_data.created_at IS '데이터 생성 시간';
COMMENT ON COLUMN foreign_investor_data.updated_at IS '데이터 최종 수정 시간 (트리거로 자동 업데이트)';

-- 뷰 설명
COMMENT ON VIEW daily_foreign_summary IS '일별 전체 외국인 순매수 현황 요약 (시장별)';
COMMENT ON VIEW top_foreign_buy_stocks IS '외국인 순매수 상위 종목 (최근 5일)';
COMMENT ON VIEW top_foreign_sell_stocks IS '외국인 순매도 상위 종목 (최근 5일)';
COMMENT ON VIEW latest_trading_date IS '최근 거래일 및 데이터 수집 현황';
COMMENT ON VIEW market_statistics IS '시장별 외국인 자금 흐름 통계';

-- 10. 샘플 데이터 확인 쿼리 (주석 처리)
/*
-- 테이블 생성 후 데이터 확인을 위한 쿼리들
SELECT COUNT(*) as total_records FROM foreign_investor_data;
SELECT * FROM latest_trading_date;
SELECT * FROM daily_foreign_summary LIMIT 10;
SELECT * FROM top_foreign_buy_stocks WHERE rank <= 5;
SELECT * FROM market_statistics LIMIT 7;
*/

-- 스키마 생성 완료 메시지
SELECT 'asset_manager 프로젝트 외국인 수급 데이터베이스 스키마 생성 완료!' as status;