-- Metabase: Product Utilization Legend
-- This query provides a static lookup table for the definitions of each utilization metric.

SELECT 'F5 - Inventory' as "Product Name", 'Percentage of days in the month where the merchant performed at least one inventory transaction (within a rolling 7-day activity window).' as "Definition"
UNION ALL
SELECT 'F5 - Table Management', 'Ratio of dine-in orders that were assigned to a physical table versus total dine-in orders.'
UNION ALL
SELECT 'F5 - Gift Cards', 'Percentage of total orders that included a gift card transaction.'
UNION ALL
SELECT 'F5 - Coupons', 'Percentage of total orders that had a coupon applied.'
UNION ALL
SELECT 'F5 - Promotions', 'Percentage of total orders that utilized at least one promotion.'
UNION ALL
SELECT 'F5 - Foodics Advanced BI Dashboards', 'Percentage of days in the month where at least one active BI session was recorded.'
UNION ALL
SELECT 'F5 Kitchen Display System (KDS)', 'Ratio of orders sent to the KDS versus the total number of orders processed.'
UNION ALL
SELECT 'F5 Customer Display App', 'Percentage of days with sales where the Customer Display System (CDS) processed at least one order.'
UNION ALL
SELECT 'F5 Waiter App', 'Percentage of days with sales where the Waiter App was used to process at least one payment.'
UNION ALL
SELECT 'Online - Website', 'Web Share: Percentage of days with at least one Website order relative to total days with ANY online activity (Web+App+Kiosk).'
UNION ALL
SELECT 'Online - Mobile App', 'App Share: Percentage of days with at least one Mobile App order relative to total days with ANY online activity (Web+App+Kiosk).'
UNION ALL
SELECT 'Online - Kiosk', 'Kiosk Share: Percentage of days with at least one Kiosk order relative to total days with ANY online activity (Web+App+Kiosk).'

ORDER BY "Product Name" ASC;
