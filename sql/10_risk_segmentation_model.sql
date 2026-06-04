-- 10_risk_segmentation_model.sql
-- Question: Combine FICO, DTI, and revolving utilization into a single
--           credit-policy decision matrix. Which (FICO × DTI × Util) cells
--           deserve auto-approve, manual review, or auto-decline?
-- Techniques: Multi-stage CTE pipeline, multiple CASE matrices, HAVING for
--             sparse-cell suppression, recommended-action mapping
--
-- Business read: This is the punch-line query — a credit-policy team would
-- use exactly this matrix to set portfolio cutoffs. The output is a default
-- rate per (FICO × DTI × Util) cell plus a recommended action band based
-- on observed risk. Cells with fewer than 500 historical loans are
-- suppressed because the rate estimate is too noisy to act on.

WITH base AS (
    SELECT
        is_default,
        fico_avg,
        dti,
        revol_util,
        int_rate
    FROM loans
    WHERE is_completed = 1
      AND fico_avg IS NOT NULL
      AND dti IS NOT NULL AND dti >= 0 AND dti < 100
      AND revol_util IS NOT NULL
),
segmented AS (
    SELECT
        is_default,
        int_rate,
        CASE
            WHEN fico_avg >= 740 THEN '1. Prime (740+)'
            WHEN fico_avg >= 680 THEN '2. Near-prime (680-739)'
            WHEN fico_avg >= 640 THEN '3. Sub-prime (640-679)'
            ELSE                      '4. Deep sub-prime (<640)'
        END AS fico_band,
        CASE
            WHEN dti < 15 THEN 'Low DTI (<15%)'
            WHEN dti < 25 THEN 'Mid DTI (15-25%)'
            ELSE               'High DTI (25%+)'
        END AS dti_band,
        CASE
            WHEN revol_util < 30 THEN 'Low Util (<30%)'
            WHEN revol_util < 70 THEN 'Mid Util (30-70%)'
            ELSE                      'High Util (70%+)'
        END AS util_band
    FROM base
),
cells AS (
    SELECT
        fico_band,
        dti_band,
        util_band,
        COUNT(*)                                          AS loans,
        SUM(is_default)                                   AS defaults,
        ROUND(100.0 * SUM(is_default) / COUNT(*), 2)      AS default_rate_pct,
        ROUND(AVG(int_rate), 2)                           AS avg_int_rate_pct
    FROM segmented
    GROUP BY fico_band, dti_band, util_band
    HAVING COUNT(*) >= 500
)
SELECT
    fico_band,
    dti_band,
    util_band,
    loans,
    defaults,
    default_rate_pct,
    avg_int_rate_pct,
    CASE
        WHEN default_rate_pct <  5 THEN 'A. Auto-approve'
        WHEN default_rate_pct < 10 THEN 'B. Approve standard'
        WHEN default_rate_pct < 15 THEN 'C. Manual review'
        WHEN default_rate_pct < 25 THEN 'D. Senior review'
        ELSE                            'E. Decline / restructure'
    END AS recommended_action
FROM cells
ORDER BY default_rate_pct;
