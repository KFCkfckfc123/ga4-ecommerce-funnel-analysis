# Validation and acceptance

## Fixed analytical baseline

| Check | Result and scope |
|---|---|
| Snapshot | 10,000 rows, 25 columns; unchanged source SHA-256 documented in `data/README.md` |
| Composite session key | No missing or duplicate user-session keys |
| Date coverage | 2020-11-01 through 2021-01-31, 92 dates |
| Parsing | Dates and seven UTC timestamp columns parse successfully |
| Counts and flags | Nonnegative integer event counts, component totals and timestamp/flag consistency pass |
| Ordered stages | Each subsequent stage has its prerequisite and a strictly later timestamp |
| Overall funnel | 9,965 → 1,807 → 644 → 348 |
| Adjacent-stage conversion | 18.13%, 35.64%, 54.04% |
| Overall conversion | 348 / 9,965 = 3.49% |
| Saved MySQL comparison | All device counts and four rounded rates match Python; this does not compare the original MySQL table row by row |
| Notebook | Public English notebook must run all 46 code cells from a fresh kernel, with saved outputs and two embedded figures |
| Tableau package | ZIP integrity, matching workbook/CSV/Hyper bytes, relative data references and filter scope checked |

## Desktop acceptance

On 2026-10-23 the owner confirmed that the `.twbx` opened without errors. The tablet screenshot showed 214 views, 12 purchases, 5.61% conversion and a 214 → 31 → 13 → 12 funnel. The subsequent All screenshot restored 9,965 views, 348 purchases, 3.49% and the overall funnel. Both retained all three devices in the comparison chart. The screenshots were directly reviewed against the analytical baseline.

This is user-operated desktop acceptance supported by screenshot review. It is not a claim of independent automated GUI control. English translation changes the notebook, labels and documentation; the Tableau workbook's analytical definitions remain unchanged.

## Public-release checks

`scripts/check_public_release.py` checks file paths, text, notebook content and embedded Tableau XML for Chinese text, private workspace references and common credential patterns. It also verifies that no populated connection-password field is packaged. The public release excludes private career files, learning plans, personal work logs, backup files and the original learning notebook.

Automated checks are complemented by direct inspection of the notebook outputs, chart images and dashboard preview. They are evidence of the inspected release, not a guarantee against every possible disclosure pattern.

## Scope boundaries

- The sample contains only sessions with at least one target event, not all website visits.
- The source is historical and obfuscated; internal checks do not establish tracking completeness or representativeness.
- No fresh BigQuery extraction or MySQL connection is claimed for this release.
- Hyper/CSV equality was previously checked across all 10,000 rows and 25 columns using the composite key; package byte checks preserve that baseline.
- No causal effect, statistical significance or actual business uplift is established.
- Publication status must be verified on the live destinations; local preparation alone is not publication.
