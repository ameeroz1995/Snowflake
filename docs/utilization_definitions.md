# Product Utilization Definitions

This document outlines how "Utilization" is calculated for each product listed in the `utilization_products.sql` report.

| Product Name | Utilization Definition |
| :--- | :--- |
| **F5 - Inventory** | Percentage of days in the month where the merchant performed at least one inventory transaction (within a rolling 7-day activity window). |
| **F5 - Table Management** | Ratio of dine-in orders that were assigned to a physical table versus total dine-in orders. |
| **F5 - Gift Cards** | Percentage of total orders that included a gift card transaction. |
| **F5 - Coupons** | Percentage of total orders that had a coupon applied. |
| **F5 - Promotions** | Percentage of total orders that utilized at least one promotion. |
| **F5 - Foodics Advanced BI Dashboards** | Percentage of days in the month where at least one active BI session was recorded. |
| **F5 Kitchen Display System (KDS)** | Ratio of orders sent to the KDS versus the total number of orders processed. |
| **F5 Customer Display App** | Percentage of days with sales where the Customer Display System (CDS) processed at least one order. |
| **F5 Waiter App** | Percentage of days with sales where the Waiter App was used to process at least one payment. |
| **Online - Website** | Share of active "Online" days (Web/App/Kiosk) where at least one order was placed via the Website. |
| **Online - Mobile App** | Share of active "Online" days (Web/App/Kiosk) where at least one order was placed via the Mobile App. |
| **Online - Kiosk** | Share of active "Online" days (Web/App/Kiosk) where at least one order was placed via the Kiosk. |

> [!NOTE]
> Products marked with `0` in the SQL (e.g., Timed Events, Marketplace) currently do not have an automated utilization metric defined in this specific query.
