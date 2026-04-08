create or replace task TSK__CREATE_AGG_MONTHLY_BUSINESS_PRODUCT_CHURN
	warehouse=BI_TEAM_WH
	schedule='USING CRON 30 5 * * * Asia/Riyadh'
	COMMENT='Create aggregate sama data'
	as create or replace table bi_team.tanar_okrs.agg_monthly_business_product_churn as (
    with t_1 as (
        select 
        snapshot_date
        ,business_account_id
        ,product_name
        ,legal_entity_name
        ,business_country_code
        ,sum(arr_lc * conversion_rate_to_usd) as arr_usd
        ,sum(churn_arr_lc * conversion_rate_to_usd) as churn_arr_usd
        ,sum(arr_lc) as arr_lc
        ,sum(churn_arr_lc) as churn_arr_lc
        ,sum(case when abs(churn_arr_lc)>0 and coalesce(p2.store_count__c,false) = true then abs(quoteline_quantity) else 0 end ) as churned_locations
        from bi_team.tanar_okrs.agg_daily_quoteline_revenue agg
        
        left join airbyte_data.salesforce.product2 p2
        on p2.id = agg.product_id
        
        group by all
    )
    ,t_2 as (
        select *
            ,sum(churn_arr_usd) over 
            (partition by date_trunc(month,snapshot_date),business_country_code,business_account_id,product_name,legal_entity_name) as month_churn_arr_usd
            ,sum(churn_arr_lc) over 
            (partition by date_trunc(month,snapshot_date),business_country_code,business_account_id,product_name,legal_entity_name) as month_churn_arr_lc
            ,sum(churned_locations) over 
            (partition by date_trunc(month,snapshot_date),business_country_code,business_account_id,product_name,legal_entity_name) as month_churned_locations
        from t_1
    )
    ,t_3 as (
        select * exclude(churn_arr_usd,churn_arr_lc,churned_locations) from t_2
        where true
        and (
            snapshot_date = date_trunc(month,snapshot_date)
            or snapshot_date = dateadd(month,1,date_trunc(month,snapshot_date))-1
            or snapshot_date = current_date - 1 
        )
    )
    ,t_4 as (
        select *,row_number() 
            over (partition by date_trunc(month,snapshot_date),business_country_code,business_account_id,product_name,legal_entity_name order by snapshot_date asc) as row_num 
        from t_3
        order by 1 desc
    )
    ,t_5 as (
        select date_trunc(month,snapshot_date) as snapshot_month
        ,business_account_id
        ,product_name
        ,legal_entity_name
        ,business_country_code
    
        ,sum(case when row_num = 1 then arr_usd else 0 end) as previous_arr_usd
        ,sum(case when row_num = 2 then arr_usd else 0 end) as current_arr_usd
       
        ,sum(case when row_num = 1 then month_churn_arr_usd else 0 end) as churn_arr_usd
        ,sum(case when row_num = 1 then month_churn_arr_lc else 0 end) as churn_arr_lc
        ,sum(case when row_num = 1 then month_churned_locations else 0 end) as churned_locations
        from t_4
        group by all
    )
    ,t_6 as (
        select *
        ,case
            when lower(product_name) = 'f5 cashier - basic package' then 4
            when lower(product_name) = 'f5 cashier - legacy advanced package' then 5
            when lower(product_name) = 'f5 cashier - new advanced package' then 6
            when lower(product_name) = 'f5 cashier - starter package' then 3
            when lower(product_name) = 'one package' then 1
            when lower(product_name) = 'one plus package' then 2
            end as product_package
        ,max(case when current_arr_usd>0 then  product_package end) over (partition by business_account_id,snapshot_month) as current_account_package
        ,max(case when previous_arr_usd>0 then  product_package end) over (partition by business_account_id,snapshot_month) as previous_account_package
        ,sum(churn_arr_usd) over (partition by business_account_id,snapshot_month)  as business_churn_arr_usd
        ,sum(churn_arr_lc) over (partition by business_account_id,snapshot_month)  as business_churn_arr_lc
        ,sum(current_arr_usd) over (partition by business_account_id,snapshot_month) as current_business_arr_usd
        ,sum(previous_arr_usd) over (partition by business_account_id,snapshot_month) as previous_business_arr_usd
        ,sum(case when churned_locations>0 and churn_arr_usd<=0 then churn_arr_usd else 0 end) 
            over (partition by business_account_id,snapshot_month) as removed_branches  
        ,sum(case when churned_locations>0 and churn_arr_usd>0 then churn_arr_usd else 0 end) 
            over (partition by business_account_id,snapshot_month) as added_branches
            
        ,coalesce(round(previous_business_arr_usd,0) >= 0
                and round(business_churn_arr_usd,0) != 0 
                and round(current_business_arr_usd,0) <=0,false) as is_full_churn
        ,case
            when churn_arr_usd > 0 then 'upgrade'
            when churn_arr_usd < 0  then 'addon_churn'
            end as arr_movement_type
        ,case
            when abs(removed_branches) > 0
            and abs(added_branches) > 0
            and is_full_churn = false
            and abs(added_branches) < abs(removed_branches)
            and arr_movement_type is not null
            then 'package_downgrade'
            
            when abs(removed_branches) > 0
            and abs(added_branches) = 0
            and is_full_churn = false
            and arr_movement_type is not null
            then 'branch_churn'
        
            when abs(removed_branches) = 0
            and abs(added_branches) = 0
            and is_full_churn = false
            and arr_movement_type is not null
            then 'addon_churn'
                
            when abs(removed_branches) = 0
            and abs(added_branches) > 0
            and is_full_churn = false
            and arr_movement_type is not null
            then arr_movement_type
        
            when is_full_churn = true
            and arr_movement_type is not null
            then 'full_churn'
            
            else arr_movement_type
            end as churn_criteria
        from t_5
    )

    select * from t_6 where churn_criteria is not null
);