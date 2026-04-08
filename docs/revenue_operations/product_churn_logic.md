# 📉 Product Churn & ARR Movement Logic (Deep Dive)

This document provides a technical specification of the logic within the `TSK__CREATE_AGG_MONTHLY_BUSINESS_PRODUCT_CHURN` Snowflake task. This task is responsible for classifying how revenue moves between products and packages on a monthly basis.

---

## ⚡ Data Transformation Flow

The query uses a multi-stage Common Table Expression (CTE) pipeline to determine state changes:

1.  **`t_1` (Daily Base)**: Aggregates `agg_daily_quoteline_revenue`. It standardizes all currency to **USD** using `conversion_rate_to_usd` and calculates branch-level churn (`churned_locations`) for products tied to physical stores.
2.  **`t_2` (Monthly Windowing)**: Uses `SUM(...) OVER (PARTITION BY ...)` to calculate total churned ARR and locations across the entire month, regardless of specific day-to-day fluctuations.
3.  **`t_3` & `t_4` (State Ranking)**: Filters for the month-start, month-end, and "current-status" snapshots. It then assigns a `row_number()` ordered by date (ascending):
    *   `row_num = 1`: The state at the **beginning** of the month.
    *   `row_num = 2`: The state at the **end** of the month.
4.  **`t_5` (Pivot)**: Converts the ranked rows into a single wide row showing `previous_arr` vs `current_arr`. 
5.  **`t_6` (The Logic Engine)**: Applies business rules to classify the movement.

---

## 🏛️ Package Tier Ranking
To identify **Package Downgrades**, the logic assigns numerical ranks to cashier tiers:
*   `One Package` (1) → `One Plus Package` (2) → `Starter` (3) → `Basic` (4) → `Legacy Advanced` (5) → `New Advanced` (6)

---

## 🔍 Detailed Churn Classifications

The `churn_criteria` is determined by evaluating the following conditions in priority order:

### 1. Full Churn
*   **Condition**: `previous_business_arr >= 0` AND `business_churn_arr != 0` AND `current_business_arr <= 0`.
*   **Definition**: The account has zero remaining ARR across all products at the end of the month.

### 2. Package Downgrade
*   **Condition**: `removed_branches > 0` AND `added_branches > 0` AND (`abs(added) < abs(removed)`).
*   **Definition**: A customer swapped their package hierarchy (e.g., moved from Advanced to Basic) or downsized their location count while maintaining the account.

### 3. Branch Churn
*   **Condition**: `removed_branches > 0` AND `added_branches = 0` AND `is_full_churn = false`.
*   **Definition**: ARR loss specifically attributed to the closure of physical locations.

### 4. Addon Churn
*   **Condition**: `churn_arr_usd < 0` AND `removed_branches = 0`.
*   **Definition**: The customer stopped paying for a specific feature (like the Waiter App or Inventory) but kept their base package.

### 5. Upgrade
*   **Condition**: `churn_arr_usd > 0`.
*   **Definition**: Net positive revenue growth for that specific product/account.

---

## 📈 Key Formula References

| Metric | SQL Formula |
| :--- | :--- |
| **Month-Over-Month Delta** | `current_arr_usd - previous_arr_usd` |
| **USD Standard** | `arr_lc * conversion_rate_to_usd` |
| **Location Churn** | `ABS(quoteline_quantity) where store_count__c = TRUE` |

---

> [!CAUTION]
> **Data Integrity**: If `conversion_rate_to_usd` is missing or `0` in the daily revenue tables, the churn calculations will fail or return `null`. Always verify the FX rate source table.
