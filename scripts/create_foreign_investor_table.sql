-- 외국인 수급현황 데이터 테이블 생성
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

-- 복합 인덱스 생성 (날짜, 시장, 투자자유형, 종목코드로 빠른 조회)
CREATE INDEX IF NOT EXISTS idx_foreign_investor_main 
ON foreign_investor_data (date, market_type, investor_type, ticker);

-- 날짜별 조회를 위한 인덱스
CREATE INDEX IF NOT EXISTS idx_foreign_investor_date 
ON foreign_investor_data (date DESC);

-- 순매수금액 기준 정렬을 위한 인덱스  
CREATE INDEX IF NOT EXISTS idx_foreign_investor_net_amount
ON foreign_investor_data (date, net_amount DESC);

-- 중복 방지를 위한 유니크 제약조건
-- (날짜, 시장, 투자자유형, 종목코드) 조합으로 중복 방지
CREATE UNIQUE INDEX IF NOT EXISTS uk_foreign_investor_unique
ON foreign_investor_data (date, market_type, investor_type, COALESCE(ticker, 'MARKET_TOTAL'));

-- RLS (Row Level Security) 설정
ALTER TABLE foreign_investor_data ENABLE ROW LEVEL SECURITY;

-- 모든 사용자가 읽기 가능하도록 정책 생성
CREATE POLICY "Enable read access for all users" ON foreign_investor_data
FOR SELECT USING (true);

-- 인증된 사용자만 쓰기 가능하도록 정책 생성 (현재는 익명 사용자도 쓰기 가능하게 설정)
CREATE POLICY "Enable insert for all users" ON foreign_investor_data
FOR INSERT WITH CHECK (true);

-- 업데이트 정책
CREATE POLICY "Enable update for all users" ON foreign_investor_data
FOR UPDATE USING (true);

-- updated_at 자동 업데이트를 위한 트리거 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- updated_at 자동 업데이트 트리거 생성
CREATE TRIGGER update_foreign_investor_data_updated_at 
    BEFORE UPDATE ON foreign_investor_data 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 유용한 뷰 생성
-- 1. 일별 전체 외국인 순매수 현황 뷰
CREATE OR REPLACE VIEW daily_foreign_summary AS
SELECT 
    date,
    market_type,
    SUM(CASE WHEN investor_type = '외국인' THEN net_amount ELSE 0 END) as foreign_net_amount,
    SUM(CASE WHEN investor_type = '기타외국인' THEN net_amount ELSE 0 END) as other_foreign_net_amount,
    SUM(net_amount) as total_foreign_net_amount,
    SUM(CASE WHEN investor_type = '외국인' THEN buy_amount ELSE 0 END) as foreign_buy_amount,
    SUM(CASE WHEN investor_type = '외국인' THEN sell_amount ELSE 0 END) as foreign_sell_amount
FROM foreign_investor_data 
WHERE ticker IS NULL  -- 전체 시장 데이터만
GROUP BY date, market_type
ORDER BY date DESC, market_type;

-- 2. 외국인 순매수 상위 종목 뷰 (최근 5일)
CREATE OR REPLACE VIEW top_foreign_stocks AS
SELECT 
    date,
    market_type,
    ticker,
    stock_name,
    net_amount,
    buy_amount,
    sell_amount,
    ROW_NUMBER() OVER (PARTITION BY date, market_type ORDER BY net_amount DESC) as rank
FROM foreign_investor_data 
WHERE ticker IS NOT NULL 
  AND date >= TO_CHAR(CURRENT_DATE - INTERVAL '5 days', 'YYYYMMDD')
  AND net_amount > 0
ORDER BY date DESC, market_type, net_amount DESC;

-- 주석 추가
COMMENT ON TABLE foreign_investor_data IS '외국인 투자자 수급현황 데이터';
COMMENT ON COLUMN foreign_investor_data.date IS '데이터 날짜 (YYYYMMDD 형식)';
COMMENT ON COLUMN foreign_investor_data.market_type IS '시장 구분 (KOSPI/KOSDAQ)';
COMMENT ON COLUMN foreign_investor_data.investor_type IS '투자자 유형 (외국인/기타외국인)';
COMMENT ON COLUMN foreign_investor_data.ticker IS '종목코드 (전체시장 데이터의 경우 NULL)';
COMMENT ON COLUMN foreign_investor_data.net_amount IS '순매수금액 (매수-매도, 원 단위)';
COMMENT ON VIEW daily_foreign_summary IS '일별 전체 외국인 순매수 현황 요약';
COMMENT ON VIEW top_foreign_stocks IS '외국인 순매수 상위 종목 (최근 5일)';