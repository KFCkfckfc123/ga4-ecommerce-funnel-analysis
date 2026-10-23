# GA4 Ecommerce Funnel — Business Summary

**Decision:** Prioritize investigation of the product-view → add-to-cart stage before committing to a product or device-specific change.

## Evidence

In a 10,000-session snapshot from Google's obfuscated ecommerce sample (November 1, 2020–January 31, 2021), 9,965 sessions had a product view and 348 completed the ordered same-session purchase funnel: **3.49% view-to-purchase conversion**.

| Transition | Next-stage / starting-stage sessions | Conversion |
|---|---:|---:|
| View → cart | 1,807 / 9,965 | 18.13% |
| Cart → checkout | 644 / 1,807 | 35.64% |
| Checkout → purchase | 348 / 644 | 54.04% |

View-to-cart lost **8,158 sessions (81.87%)**, the largest adjacent-stage loss by count and percentage. This identifies an investigation priority, not a demonstrated cause.

Device conversion was **3.42% desktop**, **3.49% mobile**, and **5.61% tablet**. Tablet had only **214 product-view sessions and 12 completed purchase sessions**; its observed ranking is insufficient evidence for a device investment decision.

## Recommended actions

1. Check instrumentation at the view-to-cart boundary. If tracking is reliable, compare product availability, pricing, traffic mix, and add-to-cart interactions. These explanations remain hypotheses.
2. Before a device-specific change, compare comparable traffic/product segments and time periods. Evaluate an intervention through an experiment with a defined assignment unit, primary metric, and guardrails. No experiment was conducted here.

## Measurement boundaries

- One row is a pseudonymous user-session. Eligible sessions contain at least one of six selected funnel events; this is not a sample of all website visits.
- Stages must occur in the same session with strictly increasing timestamps. Purchases outside the sequence are excluded.
- Rates use starting-stage sessions as the denominator. Sessions are not unique customers or orders; a user can contribute multiple sessions.
- The historical data is obfuscated and sampled. Tracking completeness and current-business representativeness are not established. Acquisition fields describe first-user source, not session source.
- No statistical significance, causal effect, or realized conversion improvement is claimed.

## Audit trail

The project includes extraction SQL, a fixed input snapshot, an executed pandas notebook, reconciled saved MySQL device aggregates, and Tableau with packaged data. Notebook execution and CSV reconciliation passed on October 23, 2026; warehouse/database queries were not rerun. See [validation details](VALIDATION.md) and [metric definitions](README.md).
