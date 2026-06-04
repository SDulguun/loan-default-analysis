-- 09_revolving_utilization.sql
-- Question: How does revolving credit utilization (how much of a borrower's
--           existing credit-card limit they're using) at origination predict
--           default?
-- Techniques: CASE bucketing, filtered aggregation, multi-metric reporting
--
-- Business read: A maxed-out credit card is the textbook "borrower in
-- distress" signal — it means existing lenders see something the new lender
-- might not. This is one of the few features that consistently outperforms
-- naive FICO in default models.

WITH completed AS (
    SELECT
        is_default,
        revol_util,
        revol_bal,
        fico_avg,
        int_rate,
        loan_amnt
    FROM loans
    WHERE is_completed = 1
      AND revol_util IS NOT NULL
)
SELECT
    CASE
        WHEN revol_util < 10  THEN '01. <10%'
        WHEN revol_util < 25  THEN '02. 10-25%'
        WHEN revol_util < 50  THEN '03. 25-50%'
        WHEN revol_util < 75  THEN '04. 50-75%'
        WHEN revol_util < 90  THEN '05. 75-90%'
        WHEN revol_util <= 100 THEN '06. 90-100%'
        ELSE                       '07. Over-limit (>100%)'
    END AS utilization_band,
    COUNT(*)                                            AS completed_loans,
    SUM(is_default)                                     AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)        AS default_rate_pct,
    ROUND(AVG(revol_util), 1)                           AS avg_util_in_band,
    ROUND(AVG(fico_avg), 0)                             AS avg_fico,
    ROUND(AVG(int_rate), 2)                             AS avg_int_rate_pct
FROM completed
GROUP BY utilization_band
ORDER BY utilization_band;
