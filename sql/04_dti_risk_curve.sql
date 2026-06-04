-- 04_dti_risk_curve.sql
-- Question: How does debt-to-income (DTI) at origination correlate with default?
-- Techniques: CASE bucketing, filtered aggregation, threshold reporting
--
-- Business read: DTI is the textbook origination guardrail. Lending Club
-- historically capped at 40% then 50%. This query plots the actual default
-- curve so we can see whether higher DTI bands are pulling their weight
-- (i.e. are priced correctly given the risk).

WITH completed AS (
    SELECT
        is_default,
        dti,
        int_rate,
        loan_amnt
    FROM loans
    WHERE is_completed = 1
      AND dti IS NOT NULL
      AND dti >= 0          -- a few rows have negative sentinels
      AND dti < 100         -- and a few have wild outliers
)
SELECT
    CASE
        WHEN dti < 5  THEN '01. <5%'
        WHEN dti < 10 THEN '02. 5-10%'
        WHEN dti < 15 THEN '03. 10-15%'
        WHEN dti < 20 THEN '04. 15-20%'
        WHEN dti < 25 THEN '05. 20-25%'
        WHEN dti < 30 THEN '06. 25-30%'
        WHEN dti < 35 THEN '07. 30-35%'
        WHEN dti < 40 THEN '08. 35-40%'
        ELSE              '09. 40%+'
    END AS dti_band,
    COUNT(*)                                            AS completed_loans,
    SUM(is_default)                                     AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)        AS default_rate_pct,
    ROUND(AVG(dti), 1)                                  AS avg_dti_in_band,
    ROUND(AVG(int_rate), 2)                             AS avg_interest_rate_pct,
    ROUND(AVG(loan_amnt), 0)                            AS avg_loan_amount
FROM completed
GROUP BY dti_band
ORDER BY dti_band;
