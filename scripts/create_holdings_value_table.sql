-- ================================================
-- 외국인 실제 보유액 데이터 테이블 스키마
-- ================================================

-- 1. 실제 보유액 데이터 테이블
CREATE TABLE IF NOT EXISTS foreign_holdings_value (
    id BIGSERIAL PRIMARY KEY,
    date VARCHAR(8) NOT NULL, -- YYYYMMDD 형식
    market_type VARCHAR(10) NOT NULL, -- KOSPI, KOSDAQ
    total_holdings_value BIGINT NOT NULL DEFAULT 0, -- 외국인 실제 보유액 (원)
    calculated_stocks INTEGER NOT NULL DEFAULT 0, -- 계산에 포함된 종목 수
    data_source VARCHAR(20) NOT NULL DEFAULT 'pykrx', -- 데이터 소스 (pykrx, manual 등)
    is_estimated BOOLEAN NOT NULL DEFAULT false, -- 추정 데이터 여부
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. 성능 최적화를 위한 인덱스
-- 메인 조회 인덱스 (날짜, 시장별)
CREATE INDEX IF NOT EXISTS idx_holdings_main 
ON foreign_holdings_value (date DESC, market_type);

-- 날짜별 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_holdings_date 
ON foreign_holdings_value (date DESC);

-- 시장별 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_holdings_market
ON foreign_holdings_value (market_type, date DESC);

-- 3. 중복 방지를 위한 유니크 제약조건
CREATE UNIQUE INDEX IF NOT EXISTS uk_holdings_unique
ON foreign_holdings_value (date, market_type);

-- 4. Row Level Security (RLS) 설정
ALTER TABLE foreign_holdings_value ENABLE ROW LEVEL SECURITY;

-- 5. 보안 정책 생성
CREATE POLICY "Enable read access for all users" ON foreign_holdings_value
FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON foreign_holdings_value
FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update for all users" ON foreign_holdings_value
FOR UPDATE USING (true);

CREATE POLICY "Enable delete for all users" ON foreign_holdings_value
FOR DELETE USING (true);

-- 6. updated_at 자동 업데이트 트리거
CREATE TRIGGER update_holdings_value_updated_at 
    BEFORE UPDATE ON foreign_holdings_value 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. 유용한 뷰 생성
-- 7.1 최근 외국인 보유액 현황 뷰
CREATE OR REPLACE VIEW latest_holdings_summary AS
SELECT 
    date,
    SUM(CASE WHEN market_type = 'KOSPI' THEN total_holdings_value ELSE 0 END) as kospi_holdings,
    SUM(CASE WHEN market_type = 'KOSDAQ' THEN total_holdings_value ELSE 0 END) as kosdaq_holdings,
    SUM(total_holdings_value) as total_holdings,
    AVG(calculated_stocks) as avg_calculated_stocks,
    MAX(updated_at) as last_updated
FROM foreign_holdings_value
GROUP BY date
ORDER BY date DESC;

-- 7.2 일별 보유액 변화 뷰
CREATE OR REPLACE VIEW holdings_daily_change AS
SELECT 
    current_data.date,
    current_data.market_type,
    current_data.total_holdings_value as current_value,
    prev_data.total_holdings_value as previous_value,
    (current_data.total_holdings_value - COALESCE(prev_data.total_holdings_value, 0)) as change_amount,
    CASE 
        WHEN prev_data.total_holdings_value > 0 THEN 
            ROUND(((current_data.total_holdings_value - prev_data.total_holdings_value) * 100.0 / prev_data.total_holdings_value), 2)
        ELSE 0 
    END as change_percent
FROM foreign_holdings_value current_data
LEFT JOIN foreign_holdings_value prev_data ON 
    current_data.market_type = prev_data.market_type AND
    prev_data.date = (
        SELECT MAX(date) 
        FROM foreign_holdings_value 
        WHERE date < current_data.date AND market_type = current_data.market_type
    )
ORDER BY current_data.date DESC, current_data.market_type;

-- 7.3 보유액 데이터 가용성 체크 뷰
CREATE OR REPLACE VIEW holdings_data_status AS
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT date) as unique_dates,
    COUNT(DISTINCT market_type) as markets,
    MAX(date) as latest_date,
    MIN(date) as earliest_date,
    MAX(updated_at) as last_updated,
    SUM(CASE WHEN is_estimated THEN 1 ELSE 0 END) as estimated_records
FROM foreign_holdings_value;

-- 8. 테이블 및 컬럼 설명
COMMENT ON TABLE foreign_holdings_value IS '외국인 실제 보유액 데이터 - pykrx API에서 계산된 일별 보유액';
COMMENT ON COLUMN foreign_holdings_value.id IS '고유 식별자 (자동 증가)';
COMMENT ON COLUMN foreign_holdings_value.date IS '데이터 날짜 (YYYYMMDD 형식)';
COMMENT ON COLUMN foreign_holdings_value.market_type IS '시장 구분 (KOSPI, KOSDAQ)';
COMMENT ON COLUMN foreign_holdings_value.total_holdings_value IS '외국인 실제 보유액 (원 단위)';
COMMENT ON COLUMN foreign_holdings_value.calculated_stocks IS '보유액 계산에 포함된 종목 수';
COMMENT ON COLUMN foreign_holdings_value.data_source IS '데이터 소스 (pykrx, manual 등)';
COMMENT ON COLUMN foreign_holdings_value.is_estimated IS '추정 데이터 여부 (true: 추정, false: 실제)';
COMMENT ON COLUMN foreign_holdings_value.created_at IS '데이터 생성 시간';
COMMENT ON COLUMN foreign_holdings_value.updated_at IS '데이터 최종 수정 시간';

-- 뷰 설명
COMMENT ON VIEW latest_holdings_summary IS '최근 외국인 보유액 현황 요약';
COMMENT ON VIEW holdings_daily_change IS '일별 외국인 보유액 변화 추이';
COMMENT ON VIEW holdings_data_status IS '보유액 데이터 수집 현황 및 상태';

-- 9. 초기 데이터 삽입 함수 (필요시 사용)
CREATE OR REPLACE FUNCTION insert_holdings_data(
    p_date VARCHAR(8),
    p_market_type VARCHAR(10),
    p_holdings_value BIGINT,
    p_calculated_stocks INTEGER DEFAULT 0,
    p_data_source VARCHAR(20) DEFAULT 'pykrx'
) RETURNS BIGINT AS $$
DECLARE
    inserted_id BIGINT;
BEGIN
    INSERT INTO foreign_holdings_value (
        date, market_type, total_holdings_value, 
        calculated_stocks, data_source
    ) VALUES (
        p_date, p_market_type, p_holdings_value, 
        p_calculated_stocks, p_data_source
    )
    ON CONFLICT (date, market_type) 
    DO UPDATE SET 
        total_holdings_value = EXCLUDED.total_holdings_value,
        calculated_stocks = EXCLUDED.calculated_stocks,
        data_source = EXCLUDED.data_source,
        updated_at = NOW()
    RETURNING id INTO inserted_id;
    
    RETURN inserted_id;
END;
$$ LANGUAGE plpgsql;

-- 10. 데이터 정리 함수 (30일 이전 데이터 삭제)
CREATE OR REPLACE FUNCTION cleanup_old_holdings_data(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
    cutoff_date VARCHAR(8);
BEGIN
    -- 90일 이전 날짜 계산
    cutoff_date := TO_CHAR(CURRENT_DATE - INTERVAL '1 day' * days_to_keep, 'YYYYMMDD');
    
    DELETE FROM foreign_holdings_value 
    WHERE date < cutoff_date;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 스키마 생성 완료
SELECT 'foreign_holdings_value 테이블 및 관련 객체 생성 완료!' as status;