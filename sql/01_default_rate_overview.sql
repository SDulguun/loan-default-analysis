-- 01_default_rate_overview.sql
-- Question: What is the overall portfolio default rate, and how does it
--           differ by loan term (36 vs 60 months) and Lending Club grade?
-- Techniques: Filtered aggregation, GROUP BY ROLLUP, conditional reporting
--
-- Business read: This is the "what does our book look like" question every
-- portfolio review starts with. We only look at COMPLETED loans because
-- in-progress loans don't have a known outcome — including them would
-- mechanically depress the default rate.

SELECT
    COALESCE(term, 'TOTAL')                            AS loan_term,
    COUNT(*)                                            AS completed_loans,
    SUM(is_default)                                     AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)        AS default_rate_pct,
    ROUND(AVG(loan_amnt), 0)                            AS avg_loan_amount,
    ROUND(AVG(int_rate), 2)                             AS avg_interest_rate_pct,
    ROUND(AVG(annual_inc), 0)                           AS avg_annual_income
FROM loans
WHERE is_completed = 1
GROUP BY ROLLUP (term)
ORDER BY loan_term;
