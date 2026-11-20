"""Run sql/06_channel_month_uncertainty.sql on SQLite and cross-check it with pandas.

Loads the checked-in session snapshot into an in-memory SQLite database whose layout
matches the MySQL staging table (text flags, text dates), runs each [Qn] block, writes the
results to results/, and compares them with a separate pandas calculation.

This validates the SQL logic and the numbers. It does not execute the SQL in MySQL.
No network access is needed. scipy, when installed, adds an independent Wilson check.
"""
from math import sqrt
from pathlib import Path
import re
import sqlite3

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SQL_FILE = ROOT / 'sql/06_channel_month_uncertainty.sql'
Z = 1.96


def wilson(x, n, z=Z):
    p = x / n
    z2 = z * z
    centre = (p + z2 / (2 * n)) / (1 + z2 / n)
    half = z * sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / (1 + z2 / n)
    return 100 * (centre - half), 100 * (centre + half)


def load_blocks(text):
    parts = re.split(r'^-- \[(Q\d+)\][^\n]*\n', text, flags=re.M)
    return {parts[i]: parts[i + 1].strip() for i in range(1, len(parts), 2)}


data = pd.read_csv(ROOT / 'data/ga4_session_funnel_sample.csv',
                   dtype={'user_pseudo_id': 'string', 'ga_session_id': 'string'},
                   keep_default_na=False)
flags = ['has_view_item', 'has_add_to_cart_after_view',
         'has_checkout_after_cart', 'has_purchase_after_checkout']
staged = data.copy()
for flag in flags:
    staged[flag] = staged[flag].astype(str).str.lower()
assert set(staged[flags].stack().unique()) <= {'true', 'false'}

con = sqlite3.connect(':memory:')
con.execute("ATTACH DATABASE ':memory:' AS ga4_project")
columns = ', '.join(f'"{name}" TEXT' if staged[name].dtype == object or str(staged[name].dtype) == 'string'
                    else f'"{name}" INTEGER' for name in staged.columns)
con.execute(f'CREATE TABLE ga4_project.ga4_sessions_staging ({columns})')
placeholders = ', '.join('?' * len(staged.columns))
con.executemany(f'INSERT INTO ga4_project.ga4_sessions_staging VALUES ({placeholders})',
                staged.astype(object).where(staged.notna(), None).itertuples(index=False, name=None))
assert con.execute('SELECT COUNT(*) FROM ga4_project.ga4_sessions_staging').fetchone()[0] == 10000
blocks = load_blocks(SQL_FILE.read_text(encoding='utf-8'))
assert list(blocks) == ['Q1', 'Q2', 'Q3'], 'Expected blocks Q1-Q3'
sql = {name: pd.read_sql_query(query, con) for name, query in blocks.items()}

view = data[data['has_view_item'].astype(str).str.lower() == 'true'].copy()
view['buy'] = view['has_purchase_after_checkout'].astype(str).str.lower() == 'true'

# Q1: monthly rates and month-over-month change.
month = view.assign(session_month=view['session_date'].str[:7]).groupby('session_month').agg(
    view_sessions=('buy', 'size'), purchase_sessions=('buy', 'sum')).reset_index()
month['rate'] = 100 * month['purchase_sessions'] / month['view_sessions']
month['conversion_pct'] = month['rate'].round(2)
month['change_vs_prev_month_pp'] = (month['rate'] - month['rate'].shift()).round(2)
q1 = sql['Q1']
assert q1['session_month'].tolist() == month['session_month'].tolist()
assert q1['view_sessions'].tolist() == month['view_sessions'].tolist()
assert q1['purchase_sessions'].tolist() == month['purchase_sessions'].tolist()
assert q1['conversion_pct'].tolist() == month['conversion_pct'].tolist()
assert pd.isna(q1['change_vs_prev_month_pp'].iloc[0])
assert q1['change_vs_prev_month_pp'].iloc[1:].tolist() == month['change_vs_prev_month_pp'].iloc[1:].tolist()
assert int(q1['view_sessions'].sum()) == 9965 and int(q1['purchase_sessions'].sum()) == 348


def check_wilson(frame, groups, label):
    for _, row in frame.iterrows():
        low, high = wilson(row['purchase_sessions'], row['view_sessions'])
        assert abs(row['ci_low_pct'] - low) <= 0.005 + 1e-9, f'{label} low mismatch: {row.to_dict()}'
        assert abs(row['ci_high_pct'] - high) <= 0.005 + 1e-9, f'{label} high mismatch: {row.to_dict()}'
        try:
            from scipy.stats import binomtest
        except ImportError:
            continue
        ci = binomtest(int(row['purchase_sessions']), int(row['view_sessions'])).proportion_ci(
            confidence_level=0.95, method='wilson')
        assert abs(row['ci_low_pct'] - 100 * ci.low) <= 0.005 + 1e-9, f'{label} scipy low mismatch'
        assert abs(row['ci_high_pct'] - 100 * ci.high) <= 0.005 + 1e-9, f'{label} scipy high mismatch'


# Q2: device counts match the saved device results, then check the intervals.
q2 = sql['Q2']
device = pd.read_csv(ROOT / 'results/ga4_device_funnel_python.csv', index_col='device_category')
for _, row in q2.iterrows():
    assert row['view_sessions'] == device.loc[row['segment'], 'view_sessions']
    assert row['purchase_sessions'] == device.loc[row['segment'], 'purchase_sessions']
check_wilson(q2, 'segment', 'device')

# Q3: channel eligibility, ranking and shares.
chan = view.groupby(['first_user_source', 'first_user_medium']).agg(
    view_sessions=('buy', 'size'), purchase_sessions=('buy', 'sum')).reset_index()
chan = chan[(chan['view_sessions'] >= 100) &
            ~chan['first_user_source'].isin(['<Other>', '(data deleted)'])].copy()
chan['rate'] = chan['purchase_sessions'] / chan['view_sessions']
chan['rank'] = chan['rate'].rank(method='dense', ascending=False).astype(int)
chan['share'] = (100 * chan['view_sessions'] / chan['view_sessions'].sum()).round(2)
chan = chan.sort_values(['rank', 'first_user_source', 'first_user_medium']).reset_index(drop=True)
q3 = sql['Q3']
assert len(q3) == len(chan) > 0
assert q3['conversion_rank'].tolist() == chan['rank'].tolist()
assert q3['source'].tolist() == chan['first_user_source'].tolist()
assert q3['medium'].tolist() == chan['first_user_medium'].tolist()
assert q3['view_sessions'].tolist() == chan['view_sessions'].tolist()
assert q3['purchase_sessions'].tolist() == chan['purchase_sessions'].tolist()
assert q3['conversion_pct'].tolist() == (100 * chan['rate']).round(2).tolist()
assert q3['share_of_ranked_views_pct'].tolist() == chan['share'].tolist()
check_wilson(q3, 'channel', 'channel')

out = ROOT / 'results'
sql['Q1'].to_csv(out / 'ga4_monthly_conversion_sqlite.csv', index=False)
sql['Q2'].to_csv(out / 'ga4_device_wilson_sqlite.csv', index=False)
sql['Q3'].to_csv(out / 'ga4_channel_ranking_sqlite.csv', index=False)
print('PASS: SQL topic 06 matches the pandas cross-check (SQLite; not run in MySQL)')
