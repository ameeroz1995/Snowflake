with t_1 as (
    select  
     act.name                       as business_account_name
    ,act.f5number__c                as business_reference_id
    ,inv.name                       as invoice_number
    ,inv.id                         as invoice_id
    ,inv.start_date__c              as invoice_start_date
    ,coalesce("ORDER".id,order2.id) as order_id
    ,coalesce(opp.id,opp2.id)       as opportunity_id
    ,coalesce(quote.id,quote2.id)   as quote_id
    ,coalesce(
        null
        ,quote.sanad_id__c
        ,quote2.sanad_id__c
        ,nullif(quote.pn_amount__c,0)
        ,nullif(quote2.pn_amount__c,0)
        ,quote.promissorynote__c
        ,quote2.promissorynote__c
    ) is not null                   as is_pn_invoice_quote
    ,coalesce("ORDER".id,order2.id) as order_id
    ,coalesce(opp.id,opp2.id)       as opportunity_id
    ,coalesce(quote.id,quote2.id)   as quote_id
    ,coalesce(
        quote.billingfrequency2__c
        ,quote2.billingfrequency2__c
     )                              as quote_billing_frequency
    ,inv.blng__invoiceposteddate__c as invoice_posted_date
    ,inv.start_date__c              as invice_start_date
    ,inv.blng__duedate__c           as invoice_due_date
    ,act.blocking_date__c           as account_blocking_date
    ,inv.collection_team_notes__c   as invoice_collection_notes
    ,inv.blng__notes__c             as invoice_notes
    ,inv.type__c                    as invoice_type
    ,inv.blng__paymentstatus__c     as invoice_payment_status
    ,inv.blng__invoicestatus__c     as invoice_status
    ,inv.blng__daysoutstanding__c   as invoice_days_outstanding
    ,inv.blng__balance__c           as invoice_balance
    ,coalesce(
        opp.name
        ,opp2.name
    )                               as opportunity_name
    ,coalesce(
        opp.Opportunity_Status__c 
        ,opp2.Opportunity_Status__c 
    )                               as opportunity_status
    ,coalesce(
        opp.contact_status__c
        ,opp2.contact_status__c
    )                               as opportunity_cantact_status
    ,coalesce(
        opp.description
        ,opp2.description
    )                               as opportunity_description
    ,inv.paymentlink__c             as invoice_payment_link
    ,act.mobile__c                  as business_account_mobile
    ,act.phone                      as business_account_phone
    ,coalesce(
        "ORDER".promissorynote__c
        ,ORDER2.promissorynote__c
    )                               as order_promissory_note
    ,inv.invoice_number_in_total__c as invoice_number_intotal
    ,inv.subscription_term__c       as invoice_subscription_term
    ,inv.blng__totalamount__c       as invoice_total_amount_lc
    ,inv.blng__taxamount__c         as invoice_tax_amount_lc
    ,coalesce(
        quote.totalarr__c
        ,quote2.totalarr__c
    )                               as total_arr
    ,inv.tf_invoice_category__c     as invoice_category
    ,act.vipcustomer__c             as is_vip_account
    ,cs.name                        as customer_success_name
    ,act.billingcountrycode         as business_account_billingcountrycode


    
    from airbyte_data.salesforce.blng__invoice__c inv
    left join airbyte_data.salesforce.account act
    on inv.blng__account__c = act.id
    
    left join airbyte_data.salesforce.user cs
    on act.customersuccess__c  = cs.id
    
    ---------
    left join airbyte_data.salesforce.sbqq__quote__c quote
    on quote.name = inv.quote_number__c    
  
    left join airbyte_data.salesforce."ORDER"  
    on "ORDER".sbqq__quote__c = quote.id
        
    left join airbyte_data.salesforce.opportunity opp
    on opp.sbqq__primaryquote__c = quote.id
     ---------
    left join airbyte_data.salesforce.opportunity opp2
    on opp2.id = inv.opportunity__c
    
    left join airbyte_data.salesforce.sbqq__quote__c quote2
    on quote2.id = opp2.sbqq__primaryquote__c    
  
    left join airbyte_data.salesforce."ORDER" order2
    on order2.sbqq__quote__c = quote2.id
     ---------

     
    where true
    and invoice_total_amount_lc > 0
    -- and lower(invoice_payment_status) != 'paid'
    and business_account_name not like '%Test%'
    and business_account_name != 'Foodics KSA'
    -- and invoice_type = 'Renewal'
    and (
        coalesce(inv.isdeleted,false)
        or coalesce(quote.isdeleted,false)
        or coalesce(act.isdeleted,false)
        or coalesce("ORDER".ISDELETED,false)
        or coalesce(order2.isdeleted,false)
        or coalesce(opp.isdeleted,false)
        or coalesce(opp2.isdeleted,false)
        or coalesce(quote2.isdeleted,false)
    ) = false
)

select * 
,case
    when is_vip_account =false and is_pn_invoice_quote = false
    then case lower(coalesce(quote_billing_frequency,''))
         when 'monthly' 
         then greatest(invoice_due_date,invoice_start_date)::date + 5
         when 'quarterly' 
         then greatest(invoice_due_date,invoice_start_date)::date + 10
         when 'annual' 
         then greatest(invoice_due_date,invoice_start_date)::date + 15
         when 'semiannual' 
         then greatest(invoice_due_date,invoice_start_date)::date + 15
         when ''
         then greatest(invoice_due_date,invoice_start_date)::date + 5
         end
    when is_vip_account =false and is_pn_invoice_quote = true
    then case lower(coalesce(quote_billing_frequency,''))
         when 'monthly' 
         then greatest(invoice_due_date,invoice_start_date)::date + 5
         when 'quarterly' 
         then greatest(invoice_due_date,invoice_start_date)::date + 10
         when 'annual' 
         then greatest(invoice_due_date,invoice_start_date)::date + 15
         when 'semiannual' 
         then greatest(invoice_due_date,invoice_start_date)::date + 15
         when ''
         then greatest(invoice_due_date,invoice_start_date)::date + 5
         end
  
from t_1;
,t_2 as (
    select 
        business_reference_id
        ,min(account_blocking_date) as  account_blocking_date
        ,split(array_agg(distinct invoice_number_intotal)[0],'/')[1]::int as total_invoices
        ,count(distinct  invoice_id) as remaining_invoice_count
        ,array_agg(invoice_category)
        ,reduce(
            array_agg(invoice_category)
            ,{}
            ,(acc,x)->object_insert(acc,x,coalesce(acc[x],0)+1,1)
        ) as account_cateogry_obj
        
    
        from t_1
    where true
    and lower(invoice_payment_status) != 'paid'
    and lower(invoice_status) = 'posted'
    group by all
)

select *
    ,reduce(
        object_keys(account_cateogry_obj)
        ,''
        ,(acc,x)->case when coalesce(account_cateogry_obj[x]::int,0) > coalesce(account_cateogry_obj[acc]::int,0) then x else acc end
    ) as most_frequent_category
from t_2

;


 --
 customer_type
 normal
 vip 

 only for renewal invoices:

 normal
 billing frequency [no pn]
 - monthly => from start date + 5 days
 - quarterly + semi-annual => from start date + 10 days
 - annually => from start date + 15 days

 vip
 billing frequency [no pn]
 - monthly => from start date + 45 days
 - quarterly + semi-annual => from start date + 45 days
 - annually => from start date + 45 days


 has 15 days to work on the system while offline  
 [then we remove the block]

 normal
 billing frequency [pn]
 - monthly =>                 after (2 accumulated invoices from start date + 5 days) 
 - quarterly + semi-annual => after (2 accumulated invoices from start date + 10 days)
 - annually =>                after (2 accumulated invoices from start date + 15 days)

 
 Discussion between CS and collection 
 
 vip
 billing frequency [pn] [No block]
 - monthly => from start date + 45 days 
 - quarterly + semi-annual => from start date + 45 days
 - annually => from start date + 45 days




Reporting Considerations:

- collection reporting


