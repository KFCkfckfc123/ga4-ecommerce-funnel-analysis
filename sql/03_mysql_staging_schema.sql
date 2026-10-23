-- MySQL; run in a database-connected Query editor, not a Python cell.
-- Matches the original 25-column session CSV.
-- Existing tables are intentionally not dropped or recreated.
CREATE DATABASE IF NOT EXISTS ga4_project;
USE ga4_project;

CREATE TABLE ga4_sessions_staging (
    user_pseudo_id VARCHAR(128),
    ga_session_id VARCHAR(128),
    session_date VARCHAR(32),
    device_category VARCHAR(64),
    country TEXT,
    first_user_source TEXT,
    first_user_medium TEXT,
    funnel_event_count BIGINT,
    view_item_event_count BIGINT,
    add_to_cart_event_count BIGINT,
    begin_checkout_event_count BIGINT,
    add_shipping_info_event_count BIGINT,
    add_payment_info_event_count BIGINT,
    purchase_event_count BIGINT,
    first_view_item_utc VARCHAR(64),
    first_add_to_cart_utc VARCHAR(64),
    first_begin_checkout_utc VARCHAR(64),
    first_purchase_utc VARCHAR(64),
    add_to_cart_after_view_utc VARCHAR(64),
    begin_checkout_after_cart_utc VARCHAR(64),
    purchase_after_checkout_utc VARCHAR(64),
    has_view_item VARCHAR(8),
    has_add_to_cart_after_view VARCHAR(8),
    has_checkout_after_cart VARCHAR(8),
    has_purchase_after_checkout VARCHAR(8)
);

-- Import data/ga4_session_funnel_sample.csv via the VS Code Database Client CSV importer.
-- Select the existing table; first row is headers; do not repeat an import into a populated table.
-- Timestamps and flags remain text; identifiers must not be converted to numbers.
-- If error 1050 occurs, inspect the existing table rather than deleting it.
DESCRIBE ga4_sessions_staging;
