-- Formal analysis input: exactly one row per pseudonymous user-session.
-- The sample is selected across the full available date range, not by taking
-- the first 10,000 event rows. Each output row contains ordered funnel stages.
-- Check BigQuery's estimated bytes before running.

WITH event_rows AS (
  SELECT
    event_date,
    TIMESTAMP_MICROS(event_timestamp) AS event_timestamp_utc,
    event_name,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    device.category AS device_category,
    geo.country AS country,
    traffic_source.source AS first_user_source,
    traffic_source.medium AS first_user_medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN (
      'view_item',
      'add_to_cart',
      'begin_checkout',
      'add_shipping_info',
      'add_payment_info',
      'purchase'
    )
),
session_metrics AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    PARSE_DATE('%Y%m%d', MIN(event_date)) AS session_date,
    ANY_VALUE(device_category) AS device_category,
    ANY_VALUE(country) AS country,
    ANY_VALUE(first_user_source) AS first_user_source,
    ANY_VALUE(first_user_medium) AS first_user_medium,
    COUNT(*) AS funnel_event_count,
    COUNTIF(event_name = 'view_item') AS view_item_event_count,
    COUNTIF(event_name = 'add_to_cart') AS add_to_cart_event_count,
    COUNTIF(event_name = 'begin_checkout') AS begin_checkout_event_count,
    COUNTIF(event_name = 'add_shipping_info') AS add_shipping_info_event_count,
    COUNTIF(event_name = 'add_payment_info') AS add_payment_info_event_count,
    COUNTIF(event_name = 'purchase') AS purchase_event_count,
    MIN(IF(event_name = 'view_item', event_timestamp_utc, NULL)) AS first_view_item_utc,
    MIN(IF(event_name = 'add_to_cart', event_timestamp_utc, NULL)) AS first_add_to_cart_utc,
    MIN(IF(event_name = 'begin_checkout', event_timestamp_utc, NULL)) AS first_begin_checkout_utc,
    MIN(IF(event_name = 'purchase', event_timestamp_utc, NULL)) AS first_purchase_utc
  FROM event_rows
  WHERE user_pseudo_id IS NOT NULL
    AND ga_session_id IS NOT NULL
  GROUP BY user_pseudo_id, ga_session_id
),
cart_after_view AS (
  SELECT
    s.user_pseudo_id,
    s.ga_session_id,
    MIN(e.event_timestamp_utc) AS add_to_cart_after_view_utc
  FROM session_metrics AS s
  JOIN event_rows AS e
    USING (user_pseudo_id, ga_session_id)
  WHERE s.first_view_item_utc IS NOT NULL
    AND e.event_name = 'add_to_cart'
    AND e.event_timestamp_utc > s.first_view_item_utc
  GROUP BY s.user_pseudo_id, s.ga_session_id
),
checkout_after_cart AS (
  SELECT
    c.user_pseudo_id,
    c.ga_session_id,
    MIN(e.event_timestamp_utc) AS begin_checkout_after_cart_utc
  FROM cart_after_view AS c
  JOIN event_rows AS e
    USING (user_pseudo_id, ga_session_id)
  WHERE e.event_name = 'begin_checkout'
    AND e.event_timestamp_utc > c.add_to_cart_after_view_utc
  GROUP BY c.user_pseudo_id, c.ga_session_id
),
purchase_after_checkout AS (
  SELECT
    c.user_pseudo_id,
    c.ga_session_id,
    MIN(e.event_timestamp_utc) AS purchase_after_checkout_utc
  FROM checkout_after_cart AS c
  JOIN event_rows AS e
    USING (user_pseudo_id, ga_session_id)
  WHERE e.event_name = 'purchase'
    AND e.event_timestamp_utc > c.begin_checkout_after_cart_utc
  GROUP BY c.user_pseudo_id, c.ga_session_id
),
session_funnel AS (
  SELECT
    s.*,
    c.add_to_cart_after_view_utc,
    k.begin_checkout_after_cart_utc,
    p.purchase_after_checkout_utc,
    s.first_view_item_utc IS NOT NULL AS has_view_item,
    c.add_to_cart_after_view_utc IS NOT NULL AS has_add_to_cart_after_view,
    k.begin_checkout_after_cart_utc IS NOT NULL AS has_checkout_after_cart,
    p.purchase_after_checkout_utc IS NOT NULL AS has_purchase_after_checkout
  FROM session_metrics AS s
  LEFT JOIN cart_after_view AS c
    USING (user_pseudo_id, ga_session_id)
  LEFT JOIN checkout_after_cart AS k
    USING (user_pseudo_id, ga_session_id)
  LEFT JOIN purchase_after_checkout AS p
    USING (user_pseudo_id, ga_session_id)
),
sampled_sessions AS (
  SELECT
    *,
    FARM_FINGERPRINT(
      CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING))
    ) AS sample_key
  FROM session_funnel
  ORDER BY sample_key
  LIMIT 10000
)
SELECT
  user_pseudo_id,
  ga_session_id,
  session_date,
  device_category,
  country,
  first_user_source,
  first_user_medium,
  funnel_event_count,
  view_item_event_count,
  add_to_cart_event_count,
  begin_checkout_event_count,
  add_shipping_info_event_count,
  add_payment_info_event_count,
  purchase_event_count,
  first_view_item_utc,
  first_add_to_cart_utc,
  first_begin_checkout_utc,
  first_purchase_utc,
  add_to_cart_after_view_utc,
  begin_checkout_after_cart_utc,
  purchase_after_checkout_utc,
  has_view_item,
  has_add_to_cart_after_view,
  has_checkout_after_cart,
  has_purchase_after_checkout
FROM sampled_sessions
ORDER BY sample_key;
