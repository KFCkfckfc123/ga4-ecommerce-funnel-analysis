-- MySQL: execute in the database-connected Query editor.
-- Each statement is standalone; CTEs must be executed with their following SELECT.
-- Local results confirmed by the learner; assistant has not connected to local MySQL.
-- Unit: user-session. Stage flags describe the ordered path, not raw event counts.
-- Ratios below are percentages; NULLIF handles zero denominators.

-- 1. Device stage counts.
SELECT device_category, COUNT(*) AS total_sessions,
       SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS view_sessions,
       SUM(CASE WHEN has_add_to_cart_after_view = 'true' THEN 1 ELSE 0 END) AS cart_sessions,
       SUM(CASE WHEN has_checkout_after_cart = 'true' THEN 1 ELSE 0 END) AS checkout_sessions,
       SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS purchase_sessions
FROM ga4_project.ga4_sessions_staging
GROUP BY device_category
ORDER BY total_sessions DESC;

-- 2. View-to-purchase rate, denominator = view sessions.
WITH device_funnel AS (
    SELECT device_category,
           SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS view_sessions,
           SUM(CASE WHEN has_add_to_cart_after_view = 'true' THEN 1 ELSE 0 END) AS cart_sessions,
           SUM(CASE WHEN has_checkout_after_cart = 'true' THEN 1 ELSE 0 END) AS checkout_sessions,
           SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS purchase_sessions
    FROM ga4_project.ga4_sessions_staging
    GROUP BY device_category
)
SELECT device_category, view_sessions, purchase_sessions,
       ROUND(100.0 * purchase_sessions / NULLIF(view_sessions, 0), 2) AS view_to_purchase_pct
FROM device_funnel
ORDER BY view_sessions DESC;

-- 3. Adjacent-stage rates; retain counts to expose denominators.
WITH device_funnel AS (
    SELECT device_category,
           SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS view_sessions,
           SUM(CASE WHEN has_add_to_cart_after_view = 'true' THEN 1 ELSE 0 END) AS cart_sessions,
           SUM(CASE WHEN has_checkout_after_cart = 'true' THEN 1 ELSE 0 END) AS checkout_sessions,
           SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS purchase_sessions
    FROM ga4_project.ga4_sessions_staging
    GROUP BY device_category
)
SELECT device_category, view_sessions, cart_sessions, checkout_sessions, purchase_sessions,
       ROUND(100.0 * cart_sessions / NULLIF(view_sessions, 0), 2) AS view_to_cart_pct,
       ROUND(100.0 * checkout_sessions / NULLIF(cart_sessions, 0), 2) AS cart_to_checkout_pct,
       ROUND(100.0 * purchase_sessions / NULLIF(checkout_sessions, 0), 2) AS checkout_to_purchase_pct
FROM device_funnel
ORDER BY view_sessions DESC;
