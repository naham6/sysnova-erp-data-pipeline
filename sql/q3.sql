--  Accounts Receivable (AR) aging as of 2025-12-31 

WITH as_of_payments AS (
    SELECT
        invoice_id,
        SUM(amount) AS paid_amount
    FROM clean_payments
    WHERE payment_date <= DATE '2025-12-31'
    GROUP BY invoice_id
),
open_invoices AS (
    SELECT
        i.invoice_id,
        i.due_date,
        (i.amount - COALESCE(p.paid_amount, 0)) AS outstanding,
        (DATE '2025-12-31' - i.due_date) AS days_past_due
    FROM clean_invoices i
    LEFT JOIN as_of_payments p
        ON i.invoice_id = p.invoice_id
    WHERE i.invoice_date <= DATE '2025-12-31'
      AND (i.amount - COALESCE(p.paid_amount, 0)) > 0
),
bucketed_invoices AS (
    SELECT
        invoice_id,
        outstanding,
        CASE
            WHEN days_past_due <= 0 THEN 'not yet due'
            WHEN days_past_due BETWEEN 1 AND 30 THEN '1-30'
            WHEN days_past_due BETWEEN 31 AND 60 THEN '31-60'
            WHEN days_past_due BETWEEN 61 AND 90 THEN '61-90'
            ELSE '90+'
        END AS aging_bucket
    FROM open_invoices
),
all_buckets (sort_order, aging_bucket) AS (
    VALUES
        (1, 'not yet due'),
        (2, '1-30'),
        (3, '31-60'),
        (4, '61-90'),
        (5, '90+')
)
SELECT
    b.aging_bucket,
    COUNT(bi.invoice_id) AS invoice_count,
    COALESCE(ROUND(SUM(bi.outstanding), 2), 0.00) AS outstanding_amount
FROM all_buckets b
LEFT JOIN bucketed_invoices bi
    ON b.aging_bucket = bi.aging_bucket
GROUP BY b.sort_order, b.aging_bucket
ORDER BY b.sort_order;