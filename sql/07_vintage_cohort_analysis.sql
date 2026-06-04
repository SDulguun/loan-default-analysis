-- 07_vintage_cohort_analysis.sql
-- Question: How has default rate evolved across quarterly origination
--           cohorts? Are recent vintages performing better or worse than
--           older ones — and what does the rolling 4-quarter trend show?
-- Techniques: DATE_TRUNC for cohort bucketing, AVG window function with
--             ROWS BETWEEN frame for rolling average, two-stage CTE
--
-- Business read: Vintage cohort analysis is the canonical bank portfolio
-- technique — it isolates origination-quality drift from external shocks.
-- A rising default rate across cohorts (with no macro event) is a signal
-- that underwriting standards have slipped. The 4-quarter rolling smoothes
-- noise and is the line a credit committee actually reviews.

WITH cohorts AS (
    SELECT
        DATE_TRUNC('quarter', issue_date) AS vintage_quarter,
        is_default,
        loan_amnt,
        int_rate
    FROM loans
    WHERE is_completed = 1
      AND issue_date IS NOT NULL
),
quarterly AS (
    SELECT
        vintage_quarter,
        COUNT(*)                                       AS originations,
        SUM(is_default)                                AS defaults,
        ROUND(100.0 * SUM(is_default) / COUNT(*), 2)   AS default_rate_pct,
        ROUND(AVG(loan_amnt), 0)                       AS avg_loan_amount,
        ROUND(AVG(int_rate), 2)                        AS avg_int_rate_pct
    FROM cohorts
    GROUP BY vintage_quarter
)
SELECT
    vintage_quarter,
    originations,
    defaults,
    default_rate_pct,
    avg_loan_amount,
    avg_int_rate_pct,
    -- Rolling 4-quarter average default rate (current + 3 preceding)
    ROUND(AVG(default_rate_pct) OVER (
        ORDER BY vintage_quarter
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 2)                                              AS rolling_4q_default_rate_pct,
    -- Quarter-over-quarter delta in default rate
    ROUND(default_rate_pct - LAG(default_rate_pct) OVER (ORDER BY vintage_quarter), 2)
                                                       AS qoq_default_rate_delta_pct
FROM quarterly
ORDER BY vintage_quarter;
