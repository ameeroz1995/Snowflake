# Quotation Blocking Date Logic Documentation

This document explains the logic used in the Snowflake environment (specifically within `invoices_renewal.sql`) to determine the **Account Blocking Date** for quotation-based invoices.

## Overview

The blocking date is the date on which a customer's account is restricted if invoices remain unpaid. This date is calculated based on several factors:
1. **VIP Status**: Whether the account is marked as a VIP customer.
2. **Promissory Note (PN) Status**: Whether the invoice is associated with a Promissory Note.
3. **Billing Frequency**: Monthly, Quarterly, Semi-Annual, or Annual.
4. **Reference Date**: Usually the `greatest(invoice_due_date, invoice_start_date)`.

---

## Blocking Logic Rules

### 1. Normal Accounts (Non-VIP)
For accounts without VIP status, the blocking date depends on both the billing frequency and whether a Promissory Note (PN) is involved.

| Billing Frequency | No PN Offset | With PN (Promissory Note) Offset |
| :--- | :--- | :--- |
| **Monthly** | Reference Date + 5 days | After 2 accumulated unpaid invoices + 5 days |
| **Quarterly** | Reference Date + 10 days | After 2 accumulated unpaid invoices + 10 days |
| **Semi-Annual** | Reference Date + 10 days | After 2 accumulated unpaid invoices + 10 days |
| **Annual** | Reference Date + 15 days | After 2 accumulated unpaid invoices + 15 days |

> [!NOTE]
> For accounts with a Promissory Note (PN), the blocking is typically triggered only after **2 accumulated unpaid invoices** are present.

---

### 2. VIP Accounts
For VIP customers, the logic is more lenient and generally consistent across all billing frequencies.

- **Standard VIP Rule**: Reference Date + 45 days.
- **VIP with PN**: Often follows the same 45-day rule, with some cases having no automatic block (subject to manual review).

---

## Offline Grace Period
Customers have a **15-day grace period** to continue working on the system while offline after a block is initiated, allowing for synchronization and final payment arrangements.

---

## Technical Implementation Details

### SQL Logic (Snowflake)
The core calculation in `invoices_renewal.sql` uses a `CASE` statement to apply these offsets:

```sql
case
    when is_vip_account = false and is_pn_invoice_quote = false
    then case lower(coalesce(quote_billing_frequency,''))
         when 'monthly' then reference_date + 5
         when 'quarterly' then reference_date + 10
         when 'annual' then reference_date + 15
         when 'semiannual' then reference_date + 15
         else reference_date + 5
         end
    -- Similar logic applies to non-VIP with PN, 
    -- often filtered by cumulative invoice counts in the report.
end
```

### Key Fields Used
- `vipcustomer__c` (from `Account`)
- `sanad_id__c` / `pn_amount__c` / `promissorynote__c` (from `Quote`)
- `billingfrequency2__c` (from `Quote`)
- `start_date__c` / `blng__duedate__c` (from `Invoice`)

---

## Reporting Considerations
This logic is primarily used for **Collection Reporting** to monitor overdue accounts and prioritize follow-ups.
