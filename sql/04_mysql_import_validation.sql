-- MySQL: read-only import checks run by the learner on 2026-10-21.
-- Historical import results were confirmed locally; this release does not reconnect to MySQL.
-- These aggregate checks do not establish full row-by-row equality with the CSV.

-- Expected: 10000.
SELECT COUNT(*) AS row_count
FROM ga4_project.ga4_sessions_staging;

-- Expected: no rows.
SELECT user_pseudo_id, ga_session_id, COUNT(*) AS records_per_session
FROM ga4_project.ga4_sessions_staging
GROUP BY user_pseudo_id, ga_session_id
HAVING COUNT(*) > 1;

-- Expected: 0.
SELECT COUNT(*) AS missing_key_rows
FROM ga4_project.ga4_sessions_staging
WHERE user_pseudo_id IS NULL OR TRIM(user_pseudo_id) = ''
   OR ga_session_id IS NULL OR TRIM(ga_session_id) = '';

-- Expected: 35 NULLs, 0 blank strings.
SELECT COUNT(*) - COUNT(first_view_item_utc) AS null_count,
       SUM(CASE WHEN TRIM(first_view_item_utc) = '' THEN 1 ELSE 0 END) AS blank_count
FROM ga4_project.ga4_sessions_staging;

-- Expected combinations: FFFF=35, TFFF=8158, TTFF=1163, TTTF=296, TTTT=348.
SELECT has_view_item, has_add_to_cart_after_view, has_checkout_after_cart, has_purchase_after_checkout,
       COUNT(*) AS session_count
FROM ga4_project.ga4_sessions_staging
GROUP BY has_view_item, has_add_to_cart_after_view, has_checkout_after_cart, has_purchase_after_checkout;

-- Expected: 9965, 1807, 644, 348.
-- Text flags are compared explicitly; do not SUM the text column directly.
SELECT SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS view_sessions,
       SUM(CASE WHEN has_add_to_cart_after_view = 'true' THEN 1 ELSE 0 END) AS cart_sessions,
       SUM(CASE WHEN has_checkout_after_cart = 'true' THEN 1 ELSE 0 END) AS checkout_sessions,
       SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS purchase_sessions
FROM ga4_project.ga4_sessions_staging;

-- Expected: 2020-11-01, 2021-01-31, 92.
-- Text ordering assumes the verified YYYY-MM-DD format.
-- This is coverage validation, not exhaustive date parsing/validity validation.
SELECT MIN(session_date) AS first_date,
       MAX(session_date) AS last_date,
       COUNT(DISTINCT session_date) AS date_count
FROM ga4_project.ga4_sessions_staging;

-- Expected: desktop=5838, mobile=3947, tablet=215.
SELECT device_category, COUNT(*) AS session_count
FROM ga4_project.ga4_sessions_staging
GROUP BY device_category
ORDER BY session_count DESC;
