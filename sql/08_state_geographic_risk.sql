-- 08_state_geographic_risk.sql
-- Question: Which US states carry the highest default risk, and how does
--           each state rank relative to the portfolio average?
-- Techniques: Window function for portfolio-wide benchmark (AVG OVER ()),
--             RANK window, CTE
--
-- Business read: Geographic concentration is a real risk dimension —
-- regional unemployment, housing markets, and state-level lending laws
-- all shift default rates. This query ranks every state against the
-- national average and flags the over- and under-performers.

WITH completed AS (
    SELECT
        addr_state,
        is_default,
        loan_amnt
    FROM loans
    WHERE is_completed = 1
      AND addr_state IS NOT NULL
),
by_state AS (
    SELECT
        addr_state,
        COUNT(*)                                       AS completed_loans,
        SUM(is_default)                                AS defaults,
        ROUND(100.0 * SUM(is_default) / COUNT(*), 2)   AS default_rate_pct,
        SUM(loan_amnt)                                 AS total_volume
    FROM completed
    GROUP BY addr_state
    HAVING COUNT(*) >= 1000                             -- suppress small states
)
SELECT
    addr_state,
    completed_loans,
    defaults,
    default_rate_pct,
    total_volume,
    -- Portfolio benchmark (same number on every row, computed once via window)
    ROUND(AVG(default_rate_pct) OVER (), 2)            AS portfolio_avg_default_pct,
    -- Delta vs portfolio
    ROUND(default_rate_pct - AVG(default_rate_pct) OVER (), 2)
                                                       AS delta_vs_portfolio_pct,
    -- State ranking (1 = highest default rate)
    RANK() OVER (ORDER BY default_rate_pct DESC)       AS risk_rank
FROM by_state
ORDER BY risk_rank;
