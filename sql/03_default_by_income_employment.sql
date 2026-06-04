-- 03_default_by_income_employment.sql
-- Question: How do income decile and employment tenure jointly shape default risk?
-- Techniques: NTILE window function, CTE chain, conditional bucketing
--
-- Business read: A high salary at a short-tenure job is risk-equivalent to
-- a mid salary at a long-tenure job. This query crosses income decile
-- (data-driven, not arbitrary thresholds) with the standard 6-bucket
-- emp_length to find where the bank is taking on the most risk.

WITH completed AS (
    SELECT
        is_default,
        annual_inc,
        emp_length,
        NTILE(10) OVER (ORDER BY annual_inc) AS income_decile
    FROM loans
    WHERE is_completed = 1
      AND annual_inc IS NOT NULL
      AND annual_inc > 0
),
bucketed AS (
    SELECT
        income_decile,
        CASE
            WHEN emp_length IS NULL              THEN '0. Unknown'
            WHEN emp_length = '< 1 year'         THEN '1. <1 yr'
            WHEN emp_length IN ('1 year', '2 years')  THEN '2. 1-2 yr'
            WHEN emp_length IN ('3 years', '4 years', '5 years') THEN '3. 3-5 yr'
            WHEN emp_length IN ('6 years', '7 years', '8 years', '9 years') THEN '4. 6-9 yr'
            WHEN emp_length = '10+ years'        THEN '5. 10+ yr'
            ELSE                                       '0. Unknown'
        END AS employment_band,
        is_default
    FROM completed
)
SELECT
    income_decile,
    employment_band,
    COUNT(*)                                       AS completed_loans,
    SUM(is_default)                                AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)   AS default_rate_pct
FROM bucketed
GROUP BY income_decile, employment_band
ORDER BY income_decile, employment_band;
