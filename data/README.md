# Data and provenance

`ga4_session_funnel_sample.csv` is a fixed 10,000-row, 25-column snapshot from Google's [obfuscated GA4 ecommerce sample](https://developers.google.com/analytics/bigquery/web-ecommerce-demo-dataset), covering 2020-11-01 through 2021-01-31 (92 dates).

## Grain and sample population

One row represents one pseudonymous user-session. Read `user_pseudo_id` and `ga_session_id` as strings; together they form the unique session key.

The extraction filters to six target events before session aggregation, then selects up to 10,000 eligible sessions using a deterministic hash. Eligible sessions contain at least one selected event. The snapshot does not represent all website visits. `session_date` is the earliest selected event date in the session.

The snapshot SHA-256 is `fbef45d69878f331cc5bdadf0710a5f5d23d4128a37808d2b1c869a8596cdc4b`.

## Ordered funnel

The Boolean columns `has_view_item`, `has_add_to_cart_after_view`, `has_checkout_after_cart` and `has_purchase_after_checkout` describe a strictly ordered, same-session sequence. Counts are 9,965 → 1,807 → 644 → 348.

An absent ordered-stage timestamp can mean the event did not occur or did not satisfy the required order. It should not be uniformly imputed. There are 35 eligible sessions without a view event, so view-based conversion uses 9,965 rather than all 10,000 sessions as its denominator.

## Field interpretation

- `first_user_source` and `first_user_medium` describe first-user acquisition, not current-session attribution.
- `<Other>`, `(data deleted)` and other placeholder values can come from the obfuscated source.
- SQL uses `ANY_VALUE` for descriptive dimensions. Event-level dimension conflicts were not independently audited.
- Passing key, date, count and stage-order checks does not establish complete source-event tracking.

See [event_dictionary.csv](event_dictionary.csv) for event definitions and [the extraction SQL](../sql/02_export_session_funnel_sample.sql) for the exact sample logic. BigQuery execution requires a project and may incur usage costs; offline reproduction uses this fixed file.

The source data is third-party public sample data, not private store or employer data. This repository does not relicense Google's source dataset.
