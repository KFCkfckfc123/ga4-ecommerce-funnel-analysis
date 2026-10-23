"""Validate the checked-in GA4 snapshot and derived deliverables; no network access."""
from pathlib import Path
import json
import zipfile
import xml.etree.ElementTree as ET

import nbformat
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
data = pd.read_csv(ROOT / 'data/ga4_session_funnel_sample.csv',
                   dtype={'user_pseudo_id': 'string', 'ga_session_id': 'string'})
keys = ['user_pseudo_id', 'ga_session_id']
flags = ['has_view_item', 'has_add_to_cart_after_view',
         'has_checkout_after_cart', 'has_purchase_after_checkout']
times = ['first_view_item_utc', 'add_to_cart_after_view_utc',
         'begin_checkout_after_cart_utc', 'purchase_after_checkout_utc']
assert data.shape == (10000, 25), 'Unexpected snapshot dimensions'
assert not data[keys].isna().any().any(), 'Missing session key'
assert not data.duplicated(keys).any(), 'Duplicate session key'
assert all(data[f].dtype == bool for f in flags), 'Stage flags must be Boolean'
assert data[flags].sum().tolist() == [9965, 1807, 644, 348]
date = pd.to_datetime(data['session_date'], format='%Y-%m-%d', errors='raise')
assert date.min() == pd.Timestamp('2020-11-01')
assert date.max() == pd.Timestamp('2021-01-31') and date.nunique() == 92
for col in times + ['first_add_to_cart_utc', 'first_begin_checkout_utc', 'first_purchase_utc']:
    data[col] = pd.to_datetime(data[col], format='mixed', errors='raise', utc=True)
for flag, timestamp in zip(flags, times):
    assert data[flag].equals(data[timestamp].notna()), f'Flag/time mismatch: {flag}'
for earlier, later in zip(times, times[1:]):
    active = data[later].notna()
    assert data.loc[active, earlier].notna().all(), f'Missing prerequisite: {later}'
    assert (data.loc[active, later] > data.loc[active, earlier]).all(), f'Invalid order: {later}'
count_cols = [c for c in data if c.endswith('_event_count')]
assert not data[count_cols].isna().any().any()
assert (data[count_cols] >= 0).all().all() and (data[count_cols] % 1 == 0).all().all()
assert data['funnel_event_count'].equals(data[[c for c in count_cols if c != 'funnel_event_count']].sum(axis=1))
for count, timestamp in [('view_item_event_count', times[0]),
                         ('add_to_cart_event_count', 'first_add_to_cart_utc'),
                         ('begin_checkout_event_count', 'first_begin_checkout_utc'),
                         ('purchase_event_count', 'first_purchase_utc')]:
    assert (data[count] > 0).equals(data[timestamp].notna())

expected = data.groupby('device_category').agg(
    total_sessions=('ga_session_id', 'size'), view_sessions=(flags[0], 'sum'),
    cart_sessions=(flags[1], 'sum'), checkout_sessions=(flags[2], 'sum'),
    purchase_sessions=(flags[3], 'sum'))
for metric, numerator, denominator in [
    ('view_to_purchase_pct', 'purchase_sessions', 'view_sessions'),
    ('view_to_cart_pct', 'cart_sessions', 'view_sessions'),
    ('cart_to_checkout_pct', 'checkout_sessions', 'cart_sessions'),
    ('checkout_to_purchase_pct', 'purchase_sessions', 'checkout_sessions')]:
    expected[metric] = (expected[numerator] / expected[denominator].replace(0, float('nan')) * 100).round(2)
for name in ['ga4_device_funnel_python.csv', 'ga4_device_funnel_mysql.csv']:
    actual = pd.read_csv(ROOT / 'results' / name, index_col='device_category')
    pd.testing.assert_frame_equal(expected.sort_index().sort_index(axis=1),
                                  actual.sort_index().sort_index(axis=1), check_dtype=False, check_exact=True)
overall = pd.read_csv(ROOT / 'results/ga4_overall_funnel_python.csv')
assert overall['sessions'].tolist() == [9965, 1807, 644, 348]
assert pd.isna(overall['conversion_from_previous_pct'].iloc[0])
assert overall['conversion_from_previous_pct'].iloc[1:].tolist() == [18.13, 35.64, 54.04]
kpis = pd.read_csv(ROOT / 'results/ga4_overall_kpis.csv')
assert kpis.iloc[0].to_dict() == dict(total_sessions=10000, view_sessions=9965,
                                    purchase_sessions=348, view_to_purchase_pct=3.49)

notebook = nbformat.read(ROOT / 'notebooks/01_ga4_data_quality.ipynb', as_version=4)
nbformat.validate(notebook)
code = [c for c in notebook.cells if c.cell_type == 'code' and c.source.strip()]
assert [c.execution_count for c in code] == list(range(1, len(code) + 1))
assert not any(o.output_type == 'error' for c in code for o in c.outputs)
assert sum('image/png' in o.get('data', {}) for c in code for o in c.outputs) == 2

package = ROOT / 'tableau/ga4_funnel_project_dashboard.twbx'
with zipfile.ZipFile(package) as z:
    assert z.testzip() is None
    xml = z.read('ga4_funnel_project_dashboard.twb')
    assert xml == (ROOT / 'tableau/ga4_funnel_project_dashboard.twb').read_bytes()
    assert z.read('Data/ga4_session_funnel_sample.csv') == (ROOT / 'data/ga4_session_funnel_sample.csv').read_bytes()
    assert z.read('Data/ga4_session_funnel.hyper') == (ROOT / 'tableau/Data/ga4_session_funnel.hyper').read_bytes()
    workbook = ET.fromstring(xml)
    for c in workbook.iter('connection'):
        if c.get('class') == 'hyper': assert c.get('dbname') in z.namelist()
        if c.get('class') == 'textscan': assert c.get('directory') + '/' + c.get('filename') in z.namelist()
    for sheet in workbook.findall('.//worksheet'):
        device_filters = [f for f in sheet.iter('filter') if 'device_category' in f.get('column', '')]
        assert bool(device_filters) == (sheet.get('name') != 'Device Conversion')

print(json.dumps({'status': 'PASS', 'rows': len(data), 'notebook_code_cells': len(code),
                  'funnel_counts': [9965, 1807, 644, 348], 'view_to_purchase_pct': 3.49,
                  'scope': 'snapshot, saved MySQL aggregates, notebook outputs, package integrity'}, indent=2))
