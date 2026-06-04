-- 05_fico_score_tertiles.sql
-- Question: How well does FICO score at origination separate defaulters
--           from non-defaulters? What is the lift from low to high tertile?
-- Techniques: NTILE window function for tertile assignment, CTE
--
-- Business read: FICO is the single most expensive feature a US lender pulls
-- on every applicant (bureau pulls cost real money). We want to quantify the
-- discriminatory lift FICO actually delivers — the gap between the worst
-- and best tertile is the practical value of the score.

WITH completed AS (
    SELECT
        is_default,
        fico_avg,
        int_rate,
        loan_amnt
    FROM loans
    WHERE is_completed = 1
      AND fico_avg IS NOT NULL
),
tertiled AS (
    SELECT
        is_default,
        fico_avg,
        int_rate,
        loan_amnt,
        'T' || NTILE(3) OVER (ORDER BY fico_avg) AS fico_tertile
    FROM completed
)
SELECT
    fico_tertile,
    COUNT(*)                                            AS completed_loans,
    SUM(is_default)                                     AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)        AS default_rate_pct,
    MIN(fico_avg)                                       AS fico_min,
    ROUND(AVG(fico_avg), 0)                             AS fico_avg,
    MAX(fico_avg)                                       AS fico_max,
    ROUND(AVG(int_rate), 2)                             AS avg_int_rate_pct
FROM tertiled
GROUP BY fico_tertile
ORDER BY fico_tertile;
