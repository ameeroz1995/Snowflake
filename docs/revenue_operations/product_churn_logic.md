# 📈 Product Churn & ARR Movement Logic: Technical Reference

This document provides a comprehensive technical breakdown of the `TSK__CREATE_AGG_MONTHLY_BUSINESS_PRODUCT_CHURN` task. It details how Snowflake state changes are transformed into categorized business insights.

---

## 🏗️ Technical Architecture
The logic follows a **Snapshot Comparison** model, identifying differences between the start and end of a reporting month.

### 🔄 CTE Pipeline Flow
| Step | CTE Name | Primary Responsibility |
| :--- | :--- | :--- |
| **1** | `t_1` | **Base Aggregation**: Standardizes ARR to USD and identifies branch-level changes. |
| **2** | `t_2` | **Monthly Windowing**: Aggregates churned ARR across the entire month per account/product. |
| **3** | `t_3` & `t_4` | **State Ranking**: Identifies the specific snapshots for Month-Start vs Month-End using `row_number()`. |
| **4** | `t_5` | **State Pivot**: Flattens the ranked snapshots into a single row (`previous` vs `current`). |
| **5** | `t_6` | **Classification Engine**: Applies the business rules documented below. |

---

## 🔍 Churn & Movement Criteria

### 1. Revenue Direction (Base Movement)
Before detailed classification, the engine determines the primary direction of ARR:

```sql
case
    when churn_arr_usd > 0 then 'upgrade'
    when churn_arr_usd < 0 then 'addon_churn'
end as arr_movement_type
```

### 2. High-Priority Classifications
The final `churn_criteria` is assigned using the following prioritized table:

| Criteria | Business Definition | SQL Implementation Snippet |
| :--- | :--- | :--- |
| **Full Churn** | The customer completely cancelled the account/primary service. | `coalesce(round(previous_business_arr,0) >= 0 AND round(business_churn_arr,0) != 0 AND round(current_business_arr,0) <=0, false)` |
| **Package Downgrade** | Net loss of ARR where the customer swapped products (e.g., from Advanced to Basic). | `when abs(removed_branches) > 0 AND abs(added_branches) > 0 AND abs(added_branches) < abs(removed_branches) then 'package_downgrade'` |
| **Branch Churn** | ARR loss directly caused by the closure of physical locations. | `when abs(removed_branches) > 0 AND abs(added_branches) = 0 then 'branch_churn'` |
| **Addon Churn** | Cancellation of a secondary feature (KDS, Waiter App) without closing a branch. | `when abs(removed_branches) = 0 AND abs(added_branches) = 0 then 'addon_churn'` |
| **Upgrade** | Net positive increase in ARR for the product. | `when churn_arr_usd > 0 then 'upgrade'` |

---

## 🏛️ Package Tier Ranking (Weightage)
To accurately identify a "Downgrade" vs an "Addon Change," the system assigns weight to cashier packages:

```sql
case
    when lower(product_name) = 'f5 cashier - basic package' then 4
    when lower(product_name) = 'f5 cashier - legacy advanced package' then 5
    when lower(product_name) = 'f5 cashier - new advanced package' then 6
    when lower(product_name) = 'f5 cashier - starter package' then 3
    when lower(product_name) = 'one package' then 1
    when lower(product_name) = 'one plus package' then 2
end as product_package
```

---

## 📈 Key Metric Definitions

### **ARR Normalization**
All calculations are performed in USD to ensure global comparability across regions (KSA, UAE, etc.):
```sql
sum(arr_lc * conversion_rate_to_usd) as arr_usd
```

### **Location Churn Count**
Identifies movement specifically for products that represent physical terminals or stores:
```sql
sum(case 
    when abs(churn_arr_lc) > 0 
    and coalesce(p2.store_count__c, false) = true 
    then abs(quoteline_quantity) 
    else 0 
end) as churned_locations
```

---

> [!IMPORTANT]
> **Reporting Cycle**: This task is scheduled via CRON (`30 5 * * *`) and runs daily, but only captures "Churn" once a month-to-month change is finalized.

> [!WARNING]
> If a customer's package isn't listed in the **Package Tier Ranking**, the downgrade logic may fail to categorize the movement correctly.
