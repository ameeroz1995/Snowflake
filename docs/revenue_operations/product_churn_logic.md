# 📉 Product Churn & ARR Movement Logic

This document explains the business logic used in `TSK__CREATE_AGG_MONTHLY_BUSINESS_PRODUCT_CHURN` to categorize revenue movements.

---

### 🔍 Churn Classification Criteria

The following logic is used to assign a `churn_criteria` to each account/product combination at the end of the month:

| Category | Logic Condition | Business Meaning |
| :--- | :--- | :--- |
| **Full Churn** | `previous_arr > 0` AND `current_arr <= 0` | The customer completely cancelled the product/account. |
| **Branch Churn** | `removed_branches > 0` AND `added_branches = 0` | Loss of ARR specifically caused by closing physical locations. |
| **Package Downgrade** | `removed_branches > 0` AND `added_branches > 0` (where `added < removed`) | Switching to a lower-tier package or downsizing. |
| **Addon Churn** | `churn_arr_usd < 0` AND `removed_branches = 0` | Cancellation of a specific addon (e.g., KDS, Waiter App) without closing a branch. |
| **Upgrade** | `churn_arr_usd > 0` | Net increase in ARR for this product. |

---

### 🛠️ Technical Implementation Notes

1. **Snapshot Logic**: The task compares the state between the first day of the month (`date_trunc(month, snapshot_date)`) and the last day of the month.
2. **Package Hierarchy**: A numerical scale is applied to distinguish between "Basic", "Legacy Advanced", "New Advanced", etc., to identify upgrades/downgrades between tiers.
3. **Conversion**: All churn is calculated in **USD** using the daily conversion rate at the time of the snapshot to ensure global reporting consistency.

---

> [!IMPORTANT]
> This logic relies on the `agg_daily_quoteline_revenue` table. Ensure that daily snapshots are up-to-date before running the monthly churn aggregation.
