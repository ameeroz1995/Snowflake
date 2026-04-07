		with 
		t_1 as (
		    select agg.* exclude(product_name) 
		    ,act.id as account_id
		    ,act.f5number__c as f5_number
		    ,case 
				when product2.name in ('Online - Mobile App (Additional Branch)','Online - Mobile App (Main)')
				then 'Online - Mobile App'
				when product2.name in ('Online - Website (Additional Branch)','Online - Website (Main)')
				then 'Online - Website'
				when lower(product2.name) like '%kisok%' then 'Online - Kiosk'
				else product2.name end as product_name
		    ,ql.SBQQ__ListPrice__c as list_price
		    ,coalesce(ql.sbqq__bundled__c,false) as is_bundled
		    ,ql.sbqq__quantity__c as quantity
		    ,quote.name as quote_name
		    ,sum(coalesce(arr_lc,0)) over (partition by quote_name) as quote_total_arr
		
		    ,max(case when product_name='F5 Cashier - New Advanced Package'  and arr_lc>0 then 1 else 0 end)
		            over (partition by business_account_id) as New_advanced_package
		    ,max(case when product_name='F5 Cashier - Legacy Advanced Package'  and arr_lc>0  then 1 else 0 end)
		             over (partition by business_account_id) as Legacy_advanced_package
		    ,max(case when product_name='F5 Cashier - Basic Package'  and arr_lc>0  then 1 else 0 end)
		             over (partition by business_account_id) as basic_package
		    ,max(case when product_name='F5 Cashier - Starter Package'  and arr_lc>0  then 1 else 0 end)
		             over (partition by business_account_id) as starter_package
		             
		    from airbyte_data.salesforce.sbqq__quoteline__c ql
		
			-- select distinct name from airbyte_data.salesforce.product2 order by 1
		    
		    left join  (
		       select * from bi_team.tanar_okrs.agg_monthly_quoteline_revenue
		       where true
		       and snapshot_month = (select max(snapshot_month) from bi_team.tanar_okrs.agg_monthly_quoteline_revenue)
		    ) agg
		    on ql.id = agg.quoteline_id
		
		    left join airbyte_data.salesforce.product2
		    on ql.sbqq__product__c  = product2.id
		
		    left join airbyte_data.salesforce.sbqq__quote__c quote
		    on quote.id = ql.sbqq__quote__c
		
		    left join airbyte_data.salesforce.account act
		    on act.id = quote.sbqq__account__c
		    
		    where true
		    and act.billingcountrycode = 'SA'
		    -- and quote_name = 'Q-255624'
		)
		,t_2 as (
		    select 
		    -- quote_name
		    product_name
		    ,count( distinct
		        case 
		        when coalesce(quote_total_arr,0) >0 
		        and coalesce(is_bundled,false) = true 
		        -- and coalesce(list_price,0) > 0
		        then f5_number
		        when coalesce(is_bundled,false) = false
		        and coalesce(arr_lc,0) = 0
		        and coalesce(quote_total_arr,0) >0 
		        then f5_number
		        -- else 0
		        end
		    ) as bundled_licenses 
		    ,count( distinct
		        case 
		        when coalesce(quote_total_arr,0) >0 
		        and coalesce(is_bundled,false) = false 
		        and coalesce(arr_lc,0) > 0
		        then f5_number
		        -- else 0
		        end
		    ) as standalone_licenses
		    ,array_agg( distinct
		        case 
		        when coalesce(quote_total_arr,0) >0 
		        and coalesce(is_bundled,false) = true 
		        -- and coalesce(list_price,0) > 0
		        then f5_number
		        when coalesce(is_bundled,false) = false
		        and coalesce(arr_lc,0) = 0
		        and coalesce(quote_total_arr,0) >0 
		        then f5_number
		        -- else 0
		        end
		    ) as bundled_licenses_list
		    ,array_agg( distinct
		        case 
		        when coalesce(quote_total_arr,0) >0 
		        and coalesce(is_bundled,false) = false 
		        and coalesce(arr_lc,0) > 0
		        then f5_number
		        -- else 0
		        end
		    ) as standalone_licenses_list
		    ,(bundled_licenses+standalone_licenses) as total_licenses
		    ,total_licenses/
		        nullif(
		        (select count(distinct case when coalesce(quote_total_arr,0)>0 then f5_number end) from t_1)
		        ,0) as product_penetration
		    
		    
		    
		    from t_1
		    where true
		    and product_name in (
		         'F5 - Inventory',
		         'F5 - Table Management',
		         'F5 - Timed Events',
		         'F5 - Gift Cards',
		         'F5 - Coupons',
		         'F5 - Promotions',
		         'F5 - Marketplace',
		         'F5 - Loyalty',
		         'F5 - Private Token - Custom API Integration',
		         'F5 - Foodics Advanced BI Dashboards',
		         'F5 - Cloud Kitchen',
		         'F5 Customer Display App',
		         'F5 Kitchen Display System (KDS)',
		         'F5 Order Notifier App',
		         'F5 Sub-Cashier App',
		         'F5 Waiter App',
		         'Online - Website',
		         'Foodics Accounting - Main License',
		         'Online - Mobile App',
		         'Online - Delivery Management System (DMS)',
		         'Online - Loyalty',
		         'Online - Kiosk'
		    )
		    group by all
		    order by 1
		)
		
		,base_activity as (
		    select *
		    
		    ,total_active_online_branches
		    ,sum(inventory_transaction_count) 
		        over (
		            partition by business_reference_id 
		            order by snapshot_date asc
		            rows between 7 preceding and current row
		    ) inventory_transaction_count_7_days
		    from bi_team.tanar_okrs.agg_daily_merchant_activity
		)
		,utilization as (    
		    select 
		    date_trunc(month,ac.snapshot_date) as snapshot_month
		    ,business_reference_id
		    
		    ,coalesce(
		        least(sum(ac.total_branch_count)
		        /nullif(sum(lc.branches_count),0),1)
		    ,0) as branch_utilization
		        
		    ,coalesce(
		        least(sum(ac.total_device_count)
		        /nullif(sum(lc.cashier_licences),0),1)
		    ,0) as cashier_utilization
		        
		    ,coalesce(
		        least(sum(ac.total_kitchen_order_count)
		        /nullif(sum(ac.total_order_count),0),1)
		    ,0) as kitchen_utilization
		        
		    ,coalesce(
		        least(sum(ac.total_coupon_order_count)
		        /nullif(sum(ac.total_order_count),0),1)
		    ,0) as cupon_utilization
		        
		    ,coalesce(
		        least(sum(ac.total_giftcard_order_count)
		        /nullif(sum(ac.total_order_count),0),1)
		    ,0) as giftcard_utilization
		        
		    ,coalesce(
		        least(sum(ac.TOTAL_PROMOTION_ORDER_COUNT)
		        /nullif(sum(ac.total_order_count),0),1) 
		    ,0) as promotion_utilization
		        
		    ,coalesce(
		        least(sum(ac.TOTAL_TABLE_ORDER_COUNT)
		        /nullif(sum(ac.total_dine_in_order_count),0),1)
		    ,0) as table_utilization
		        
		    ,coalesce(
		        least(sum(ac.inventory_ingredients_transaction_count)
		        /nullif(sum(ac.total_order_count),0),1)
		    ,0) as inventory_consumption_utilization
		
		        
		    ,coalesce(
		        least(count(distinct case when ac.TOTAL_BI_ACTIVE_SESSIONS >0  then ac.snapshot_date end)
		        /nullif(count(ac.snapshot_date),0),1)
		    ,0)  as bi_utilization
		        
		    ,coalesce(
		        least(count(distinct 
		            case when ac.inventory_transaction_count_7_days >0  
		            then ac.snapshot_date 
		            end)
		        /nullif(count(ac.snapshot_date),0),1)
		    ,0) as inventory_utilization
		    
		    ,coalesce(
		        least(count(distinct case when ac.total_cds_orders>0 then ac.snapshot_date end)
		            /nullif(count(distinct case when ac.total_pay_transactions>0 then ac.snapshot_date end),0),1)
		    ,0) as total_cds_utilization
		    
		    ,coalesce(
		        least(count(distinct case when ac.total_waiter_payments>0 then ac.snapshot_date end)
		            /nullif(count(distinct case when ac.total_pay_transactions>0 then ac.snapshot_date end),0),1)
		    ,0) as total_waiter_utilization
		    
		    -- ,coalesce(
		    --     least(count(ac.total_active_kisok_devices)
		    --         /nullif(count(lc.ONLINE_KIOSK_LICENCES)
		    --             ,0),1)
		    -- ,0) as total_kiosk_utilization
		    
		    ,coalesce(
		        least(count(distinct case when ac.total_kisok_orders>0 then ac.snapshot_date end)
		            /nullif(count(distinct 
		                case 
		                when (
		                        coalesce(ac.total_kisok_orders,0) +
		                        coalesce(ac.total_web_orders,0) +
		                        coalesce(ac.total_app_orders,0) 
		                        )>0 
		                then ac.snapshot_date 
		                end)
		                ,0),1)
		    ,0) as total_kiosk_utilization
		    
		    ,coalesce(
		        least(count(distinct case when ac.total_web_orders>0 then ac.snapshot_date end)
		            /nullif(count(distinct 
		                case 
		                when (
		                        coalesce(ac.total_kisok_orders,0) +
		                        coalesce(ac.total_web_orders,0) +
		                        coalesce(ac.total_app_orders,0) 
		                        )>0 
		                then ac.snapshot_date 
		                end)
		                ,0),1)
		    ,0) as total_web_utilization
		    
		    ,coalesce(
		        least(count(distinct case when ac.total_app_orders>0 then ac.snapshot_date end)
		            /nullif(count(distinct 
		                case 
		                when (
		                        coalesce(ac.total_kisok_orders,0) +
		                        coalesce(ac.total_web_orders,0) +
		                        coalesce(ac.total_app_orders,0) 
		                        )>0 
		                then ac.snapshot_date 
		                end)
		                ,0),1)
		    ,0) as total_app_utilization
		    
		    
		    
		    
		    from base_activity ac
		    
		    left join bi_team.tanar_okrs.agg_daily_merchant_licenses lc
		    on lc.BUSINESS_account_ID = ac.business_reference_id
		    and lc.snapshot_date = ac.snapshot_date
		    
		    where ac.snapshot_date >= date_trunc('month', current_date()) 
		    
		    group by all
		)
		,utilization_per_product as (
		    with p1 as (
		        select 
		        snapshot_month
		        ,business_reference_id
		        ,f.key::varchar as metric_name
		        ,f.value::float as metric_value
		        from utilization
		        ,lateral flatten(input=>object_construct(
		             'F5 - Inventory',inventory_utilization,
		             'F5 - Table Management',table_utilization,
		             'F5 - Timed Events',0,
		             'F5 - Gift Cards',giftcard_utilization,
		             'F5 - Coupons',cupon_utilization,
		             'F5 - Promotions',promotion_utilization,
		             'F5 - Marketplace',0,
		             'F5 - Loyalty',0,
		             'F5 - Private Token - Custom API Integration',0,
		             'F5 - Foodics Advanced BI Dashboards',bi_utilization,
		             'F5 - Cloud Kitchen',0,
		             'F5 Customer Display App',total_cds_utilization,
		             'F5 Kitchen Display System (KDS)',kitchen_utilization,
		             'F5 Order Notifier App',0,
		             'F5 Sub-Cashier App',0,
		             'F5 Waiter App',total_waiter_utilization,
		             'Online - Website',total_web_utilization,
		             'Foodics Accounting - Main License',0,
		             'Online - Mobile App',total_app_utilization,
		             'Online - Delivery Management System (DMS)',0,
		             'Online - Loyalty',0,
		             'Online - Kiosk',total_kiosk_utilization
					--  'Online - Web',0
		        )) f
		    )
		    select 
		        metric_name as product_name
		        ,array_agg(distinct [business_reference_id,metric_value::float]) as active_f5_numbers
		    from p1
		    group by all
		)
		select 
		product_name
		,bundled_licenses
		,standalone_licenses
		,total_licenses
		,product_penetration
		,count(distinct 
		    case 
		    when allf.value[1]::float > 0 
		    and array_intersection([allf.value[0]::varchar],bundled_licenses_list)[0] is not null
		    then allf.value[0]
		    end
		)/bundled_licenses as bundled_utilized
		,count(distinct 
		    case 
		    when allf.value[1]::float > 0 
		    and array_intersection([allf.value[0]::varchar],standalone_licenses_list)[0] is not null
		    then allf.value[0]
		    end
		)/standalone_licenses as standalone_utilized
		,count(distinct 
		    case 
		    when allf.value[1]::float > 0 
		    and array_intersection([allf.value[0]::varchar],all_licenses)[0] is not null
		    then allf.value[0]
		    end
		)/(standalone_licenses+bundled_licenses) as overall_utilized
		
		from (
		   select * 
		   ,array_cat(standalone_licenses_list,bundled_licenses_list) as all_licenses
		   from  t_2 
		   left join utilization_per_product using(product_name)
		) base
		,lateral flatten(input => active_f5_numbers) allf
		
		group by all