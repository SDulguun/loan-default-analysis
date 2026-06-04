-- 02_default_by_purpose_ownership.sql
-- Question: How does default rate vary by stated loan purpose and the
--           borrower's home ownership status?
-- Techniques: CTE, two-dimensional GROUP BY, HAVING for sparse-cell suppression
--
-- Business read: "Why does the borrower want the money" matters. A debt-
-- consolidation loan funded for a homeowner is a fundamentally different
-- risk than a small_business loan for a renter. Crossing purpose with
-- home_ownership tells underwriters where to set tighter cutoffs.

WITH completed AS (
    SELECT
        purpose,
        home_ownership,
        is_default,
        loan_amnt
    FROM loans
    WHERE is_completed = 1
      AND purpose IS NOT NULL
      AND home_ownership IN ('OWN', 'MORTGAGE', 'RENT')   -- drop NONE/OTHER
)
SELECT
    purpose,
    home_ownership,
    COUNT(*)                                       AS completed_loans,
    SUM(is_default)                                AS defaults,
    ROUND(100.0 * SUM(is_default) / COUNT(*), 2)   AS default_rate_pct,
    ROUND(AVG(loan_amnt), 0)                       AS avg_loan_amount
FROM completed
GROUP BY purpose, home_ownership
HAVING COUNT(*) >= 200                              -- suppress noise
ORDER BY purpose, default_rate_pct DESC;
