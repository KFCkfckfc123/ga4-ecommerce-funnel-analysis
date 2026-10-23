-- Export event-level records for funnel exploration.
-- Each row is an event, not a distinct user or session.
-- event_params is repeated; the scalar subquery avoids multiplying event rows.
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
ORDER BY event_date, user_pseudo_id, ga_session_id, event_timestamp;
