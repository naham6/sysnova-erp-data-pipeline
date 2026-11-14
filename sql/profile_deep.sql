

\echo '=== 1. INVOICES CHECK (WITH DEDUPED ORDERS) ==='
WITH dedup_orders AS (
    SELECT DISTINCT ON (TRIM(order_id))
        TRIM(order_id) AS order_id,
        TRIM(customer_id) AS customer_id,
        LOWER(TRIM(NULLIF(status, ''))) AS status
    FROM raw_orders
    ORDER BY TRIM(order_id)
)
SELECT
    COUNT(*) AS total_invoices,
    COUNT(DISTINCT i.order_id) AS distinct_invoiced_orders,
    COUNT(*) FILTER (WHERE o.order_id IS NULL) AS orphan_order_id,
    COUNT(*) FILTER (WHERE o.status IN ('cancelled', 'placed')) AS invoiced_cancelled_or_placed,
    COUNT(*) FILTER (WHERE o.status IS NULL) AS invoiced_missing_status_order,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(i.amount), '') IS NULL OR i.amount::NUMERIC <= 0) AS bad_invoice_amount,
    COUNT(*) FILTER (WHERE i.due_date::DATE < i.invoice_date::DATE) AS due_before_invoice
FROM raw_invoices i
LEFT JOIN dedup_orders o ON TRIM(i.order_id) = o.order_id;

\echo '=== 2. DUPLICATE CUSTOMERS (CHECK updated_at) ==='
WITH dup_cust AS (
    SELECT TRIM(customer_id) AS cid
    FROM raw_customers
    GROUP BY TRIM(customer_id)
    HAVING COUNT(*) > 1
)
SELECT c.customer_id, c.customer_name, c.region, c.segment, c.created_at, c.updated_at
FROM raw_customers c
JOIN dup_cust d ON TRIM(c.customer_id) = d.cid
ORDER BY c.customer_id, c.updated_at;

\echo '=== 3. DUPLICATE ORDERS: IDENTICAL CLONES OR DIFFERENT VALUES? ==='
WITH dup_ord AS (
    SELECT TRIM(order_id) AS oid
    FROM raw_orders
    GROUP BY TRIM(order_id)
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS total_rows_in_dup_groups,
    COUNT(DISTINCT (TRIM(o.order_id), TRIM(o.customer_id), TRIM(o.order_date), COALESCE(o.status,''), TRIM(o.channel))) AS distinct_full_rows
FROM raw_orders o
JOIN dup_ord d ON TRIM(o.order_id) = d.oid;

\echo '=== 4. DUPLICATE PAYMENTS: IDENTICAL CLONES OR DIFFERENT VALUES? ==='
WITH dup_pay AS (
    SELECT TRIM(payment_id) AS pid
    FROM raw_payments
    GROUP BY TRIM(payment_id)
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS total_rows_in_dup_groups,
    COUNT(DISTINCT (TRIM(p.payment_id), TRIM(p.invoice_id), TRIM(p.payment_date), TRIM(p.amount), TRIM(p.method))) AS distinct_full_rows
FROM raw_payments p
JOIN dup_pay d ON TRIM(p.payment_id) = d.pid;

\echo '=== 5. CASCADE IMPACT OF REJECTED ORDERS ==='
WITH dedup_orders AS (
    SELECT DISTINCT ON (TRIM(order_id))
        TRIM(order_id) AS order_id,
        TRIM(customer_id) AS customer_id,
        NULLIF(TRIM(status), '') AS status
    FROM raw_orders
    ORDER BY TRIM(order_id)
),
valid_customers AS (
    SELECT DISTINCT TRIM(customer_id) AS customer_id FROM raw_customers
),
rejected_orders AS (
    SELECT o.order_id
    FROM dedup_orders o
    LEFT JOIN valid_customers vc ON o.customer_id = vc.customer_id
    WHERE o.status IS NULL OR vc.customer_id IS NULL
)
SELECT
    (SELECT COUNT(*) FROM rejected_orders) AS unique_rejected_orders,
    (SELECT COUNT(*) FROM raw_order_lines ol JOIN rejected_orders ro ON TRIM(ol.order_id) = ro.order_id) AS lines_on_rejected_orders,
    (SELECT COUNT(*) FROM raw_invoices i JOIN rejected_orders ro ON TRIM(i.order_id) = ro.order_id) AS invoices_on_rejected_orders;