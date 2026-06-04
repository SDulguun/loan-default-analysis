-- 06_grade_calibration.sql
-- Question: Is Lending Club's own A-G grade well-calibrated? Does each
--           grade's interest rate compensate for the default risk it carries?
-- Techniques: GROUP BY with derived risk-adjusted return, ordered output
--
-- Business read: Lending Club assigned every loan an A-G grade and a matching
-- interest rate (A = cheapest, G = most expensive). This query measures
-- whether the spread between grades held up — i.e. whether grade-G loans
-- actually returned more than grade-A loans after accounting for defaults.
-- For an analyst, this is the "does the bank's own pricing model work" test.

WITH completed AS (
    SELECT
        grade,
        is_default,
        int_rate,
        loan_amnt,
        total_pymnt,
        total_rec_prncp,
        total_rec_int,
        recoveries
    FROM loans
    WHERE is_completed = 1
      AND grade IS NOT NULL
)
SELECT
    grade,
    COUNT(*)                                                                  AS completed_loans,
    SUM(is_default)                                                           AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)                              AS default_rate_pct,
    ROUND(AVG(int_rate), 2)                                                   AS avg_int_rate_pct,
    -- Realized return = (total_pymnt - loan_amnt) / loan_amnt, averaged
    ROUND(100.0 * AVG((total_pymnt - loan_amnt) / NULLIF(loan_amnt, 0)), 2)   AS realized_return_pct,
    -- Loss given default = average principal not recovered on defaulted loans
    ROUND(AVG(CASE WHEN is_default = 1
        THEN (loan_amnt - total_rec_prncp - recoveries) / NULLIF(loan_amnt, 0)
        END) * 100, 2)                                                        AS avg_loss_given_default_pct
FROM completed
GROUP BY grade
ORDER BY grade;
