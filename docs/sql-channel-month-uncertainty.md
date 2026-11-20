# SQL topic: conversion by month and channel, with uncertainty

Query file: [`sql/06_channel_month_uncertainty.sql`](../sql/06_channel_month_uncertainty.sql)

## Question

The project reports **3.49%** view-to-purchase conversion (348 / 9,965). Does that rate differ by month or acquisition channel, and are the differences large enough, given the sample sizes, to be worth investigating?

## What the queries do

| Query | Technique | Output |
|---|---|---|
| Q1 monthly conversion | CTE → CTE → `LAG()` over months | Rate and change versus the previous month (percentage points) |
| Q2 device intervals | Aggregate CTE → Wilson 95% interval in plain SQL | Rate with lower and upper bound per device |
| Q3 channel ranking | Aggregate CTE → eligibility filter → `DENSE_RANK()` and `SUM() OVER ()` | Ranked channels with intervals and share of ranked views |

Definitions are unchanged from the main project: the denominator is sessions with a view, and the numerator is sessions that completed the strictly ordered view → cart → checkout → purchase path.

## Results (saved in `results/`)

Monthly, based on `session_date` (point estimates only; no interval is computed for months):

| Month | View sessions | Purchase sessions | Conversion | Change vs previous |
|---|---:|---:|---:|---:|
| 2020-11 | 3,353 | 50 | 1.49% | — |
| 2020-12 | 3,589 | 194 | 5.41% | +3.91 pp |
| 2021-01 | 3,023 | 104 | 3.44% | −1.97 pp |

Channels with at least 100 view sessions, excluding the `<Other>` and `(data deleted)` labels:

| Rank | Source / medium | View sessions | Purchase sessions | Conversion | 95% Wilson interval |
|---:|---|---:|---:|---:|---|
| 1 | shop.googlemerchandisestore.com / referral | 874 | 47 | 5.38% | 4.07%–7.08% |
| 2 | (direct) / (none) | 2,313 | 80 | 3.46% | 2.79%–4.28% |
| 3 | google / organic | 3,072 | 85 | 2.77% | 2.24%–3.41% |
| 4 | google / cpc | 418 | 11 | 2.63% | 1.48%–4.65% |

Device intervals (Q2) reproduce the tablet caution in the main README: tablet is 5.61% on 12 purchases, with an interval of 3.24%–9.54% that overlaps desktop's 2.98%–3.92%.

## How to read this

- The monthly swing is large (1.49% in November, 5.41% in December). The sample cannot say why. Seasonality, promotions or a change in traffic mix are all possible, and none is tested here.
- The top-ranked channel's interval (4.07%–7.08%) does not overlap google / organic (2.24%–3.41%) or google / cpc (1.48%–4.65%). Overlapping or non-overlapping intervals are a rough guide, not a formal test of a difference.
- `first_user_source` and `first_user_medium` describe the user's first acquisition, not necessarily the source of the session being counted.
- Ranks describe observed conversion in this sample. They do not show that a channel causes higher conversion.
- The sample contains only sessions with at least one selected funnel event, so these rates are not site-wide conversion rates.

## Validation

`python scripts/validate_sql_topic.py` loads the checked-in snapshot into an in-memory SQLite database that mirrors the MySQL staging table, runs the three queries, and checks them against an independent pandas calculation. When `scipy` is installed it also checks the intervals against `scipy.stats.binomtest(...).proportion_ci(method="wilson")`.

The saved result files are named `*_sqlite.csv` because they were produced by that run.

**MySQL check (2026-11-19):** the three queries were also run against the local MySQL staging table `ga4_project.ga4_sessions_staging`, in the same Query editor used for `05_mysql_device_funnel.sql`. Every count, rate and interval bound in Q1–Q3 matched the saved `*_sqlite.csv` files exactly. Evidence: the learner ran the queries locally, and screenshots of the three result grids were compared cell by cell. The MySQL output was not exported to a file.
