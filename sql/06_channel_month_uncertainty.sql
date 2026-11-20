-- Topic 06: conversion by month and acquisition channel, with uncertainty.
--
-- Business question: the project reports 3.49% overall view-to-purchase conversion.
-- Does that number move by month or acquisition channel, and are the differences
-- large enough, given the sample sizes, to be worth investigating?
--
-- Engine: MySQL 8.0+ (needs window functions). The statements use only syntax that also
-- runs unchanged in SQLite 3.25+, which scripts/validate_sql_topic.py uses for validation.
-- 2026-11-19: learner ran Q1-Q3 in local MySQL; result grids matched the saved
--   results/*_sqlite.csv files exactly (compared from screenshots).
-- Table: ga4_project.ga4_sessions_staging (see 03_mysql_staging_schema.sql).
--   Flags are text 'true' / 'false'; session_date is text 'YYYY-MM-DD'.
-- Unit: user-session. Denominator: sessions with has_view_item = 'true'.
--   Numerator: sessions that completed the ordered funnel (has_purchase_after_checkout = 'true').
-- Population caveat: only sessions containing at least one selected funnel event, so
--   rates describe this sample, not all site visits.
-- session_date is the earliest selected event date in the session, so months are
--   approximate session months.
-- Each statement is standalone; run one [Qn] block at a time.
-- The [Qn] markers are read by scripts/validate_sql_topic.py; keep them on their own line.

-- [Q1] Monthly conversion and change versus the previous month (LAG).
-- Window ORDER BY (inside OVER) only defines which row is "previous";
-- the final ORDER BY separately sorts the output.
WITH monthly AS (
    SELECT SUBSTR(session_date, 1, 7) AS session_month,
           SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS view_sessions,
           SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS purchase_sessions
    FROM ga4_project.ga4_sessions_staging
    GROUP BY SUBSTR(session_date, 1, 7)
),
monthly_rate AS (
    SELECT session_month, view_sessions, purchase_sessions,
           100.0 * purchase_sessions / NULLIF(view_sessions, 0) AS conversion_pct
    FROM monthly
)
SELECT session_month, view_sessions, purchase_sessions,
       ROUND(conversion_pct, 2) AS conversion_pct,
       ROUND(conversion_pct - LAG(conversion_pct) OVER (ORDER BY session_month), 2)
           AS change_vs_prev_month_pp
FROM monthly_rate
ORDER BY session_month;

-- [Q2] Device conversion with a 95% Wilson interval (z = 1.96).
-- Wilson interval for x successes in n trials, p = x / n, z2 = z * z:
--   centre = (p + z2 / (2n)) / (1 + z2 / n)
--   half-width = z * SQRT(p * (1 - p) / n + z2 / (4 * n * n)) / (1 + z2 / n)
-- A small n gives a wide interval, so a high point estimate alone is weak evidence.
WITH device_counts AS (
    SELECT device_category AS segment,
           SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS n,
           SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS x
    FROM ga4_project.ga4_sessions_staging
    GROUP BY device_category
),
wilson_inputs AS (
    SELECT segment, n, x, 1.0 * x / n AS p, 1.96 * 1.96 AS z2
    FROM device_counts
    WHERE n > 0
)
SELECT segment, n AS view_sessions, x AS purchase_sessions,
       ROUND(100.0 * p, 2) AS conversion_pct,
       ROUND(100.0 * ((p + z2 / (2.0 * n))
             - 1.96 * SQRT(p * (1 - p) / n + z2 / (4.0 * n * n))) / (1 + z2 / n), 2) AS ci_low_pct,
       ROUND(100.0 * ((p + z2 / (2.0 * n))
             + 1.96 * SQRT(p * (1 - p) / n + z2 / (4.0 * n * n))) / (1 + z2 / n), 2) AS ci_high_pct
FROM wilson_inputs
ORDER BY n DESC;

-- [Q3] Acquisition-channel ranking among attributable channels with enough volume.
-- first_user_source / first_user_medium describe the user's first acquisition, not
-- necessarily this session's source. '<Other>' and '(data deleted)' are obfuscation
-- labels in the public sample, so they are not ranked. Channels need >= 100 view
-- sessions. DENSE_RANK() orders by conversion; SUM() OVER () gives each channel's
-- share of the ranked channels' view sessions.
WITH channel_counts AS (
    SELECT first_user_source AS source,
           first_user_medium AS medium,
           SUM(CASE WHEN has_view_item = 'true' THEN 1 ELSE 0 END) AS n,
           SUM(CASE WHEN has_purchase_after_checkout = 'true' THEN 1 ELSE 0 END) AS x
    FROM ga4_project.ga4_sessions_staging
    GROUP BY first_user_source, first_user_medium
),
eligible AS (
    SELECT source, medium, n, x, 1.0 * x / n AS p, 1.96 * 1.96 AS z2
    FROM channel_counts
    WHERE n >= 100
      AND source NOT IN ('<Other>', '(data deleted)')
)
SELECT DENSE_RANK() OVER (ORDER BY p DESC) AS conversion_rank,
       source, medium, n AS view_sessions, x AS purchase_sessions,
       ROUND(100.0 * p, 2) AS conversion_pct,
       ROUND(100.0 * ((p + z2 / (2.0 * n))
             - 1.96 * SQRT(p * (1 - p) / n + z2 / (4.0 * n * n))) / (1 + z2 / n), 2) AS ci_low_pct,
       ROUND(100.0 * ((p + z2 / (2.0 * n))
             + 1.96 * SQRT(p * (1 - p) / n + z2 / (4.0 * n * n))) / (1 + z2 / n), 2) AS ci_high_pct,
       ROUND(100.0 * n / SUM(n) OVER (), 2) AS share_of_ranked_views_pct
FROM eligible
ORDER BY conversion_rank, source, medium;
