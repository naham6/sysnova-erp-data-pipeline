

\echo '=========================================='
\echo '1. ROW COUNTS & DUPLICATE PRIMARY KEYS'
\echo '=========================================='
SELECT 'raw_customers' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_keys, COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_rows FROM raw_customers
UNION ALL
SELECT 'raw_customer_changes', COUNT(*), COUNT(DISTINCT customer_id || '|' || COALESCE(effective_date,'')), COUNT(*) - COUNT(DISTINCT customer_id || '|' || COALESCE(effective_date,'')) FROM raw_customer_changes
UNION ALL
SELECT 'raw_products', COUNT(*), COUNT(DISTINCT product_id), COUNT(*) - COUNT(DISTINCT product_id) FROM raw_products
UNION ALL
SELECT 'raw_orders', COUNT(*), COUNT(DISTINCT order_id), COUNT(*) - COUNT(DISTINCT order_id) FROM raw_orders
UNION ALL
SELECT 'raw_order_lines', COUNT(*), COUNT(DISTINCT line_id), COUNT(*) - COUNT(DISTINCT line_id) FROM raw_order_lines
UNION ALL
SELECT 'raw_invoices', COUNT(*), COUNT(DISTINCT invoice_id), COUNT(*) - COUNT(DISTINCT invoice_id) FROM raw_invoices
UNION ALL
SELECT 'raw_payments', COUNT(*), COUNT(DISTINCT payment_id), COUNT(*) - COUNT(DISTINCT payment_id) FROM raw_payments;

\echo '=========================================='
\echo '2. CUSTOMERS & CUSTOMER_CHANGES CHECKS'
\echo '=========================================='
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(customer_name), '') IS NULL) AS missing_name,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(region), '') IS NULL) AS missing_region,
    COUNT(*) FILTER (WHERE region <> INITCAP(TRIM(region))) AS unstandardized_region,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(segment), '') IS NULL) AS missing_segment,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(email), '') IS NULL) AS missing_email,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(credit_limit), '') IS NULL OR credit_limit !~ '^-?\d+(\.\d+)?$') AS bad_credit_limit
FROM raw_customers;

SELECT DISTINCT region AS raw_customer_regions, COUNT(*)
FROM raw_customers
GROUP BY region
ORDER BY region;

SELECT DISTINCT region AS raw_change_regions, segment AS raw_change_segments, COUNT(*)
FROM raw_customer_changes
GROUP BY region, segment
ORDER BY region, segment;

SELECT COUNT(*) AS orphan_customer_changes
FROM raw_customer_changes cc
LEFT JOIN raw_customers c ON TRIM(cc.customer_id) = TRIM(c.customer_id)
WHERE c.customer_id IS NULL;

\echo '=========================================='
\echo '3. PRODUCTS CHECKS'
\echo '=========================================='
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(list_price), '') IS NULL) AS missing_list_price,
    COUNT(*) FILTER (WHERE list_price ~ '^-?\d+(\.\d+)?$' AND list_price::NUMERIC <= 0) AS non_positive_list_price,
    COUNT(DISTINCT sku) AS distinct_skus
FROM raw_products;

\echo '=========================================='
\echo '4. ORDERS CHECKS (STATUS, DATES, ORPHANS)'
\echo '=========================================='
SELECT COALESCE(status, '<NULL>') AS raw_status, COUNT(*)
FROM raw_orders
GROUP BY status
ORDER BY COUNT(*) DESC;

SELECT
    CASE
        WHEN NULLIF(TRIM(order_date), '') IS NULL THEN 'MISSING'
        WHEN TRIM(order_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN 'ISO (YYYY-MM-DD)'
        WHEN TRIM(order_date) ~ '^\d{2}/\d{2}/\d{4}$' THEN 'DD/MM/YYYY'
        ELSE 'OTHER: ' || order_date
    END AS date_format,
    COUNT(*)
FROM raw_orders
GROUP BY 1
ORDER BY COUNT(*) DESC;

SELECT COUNT(*) AS orders_with_orphan_customer
FROM raw_orders o
LEFT JOIN raw_customers c ON TRIM(o.customer_id) = TRIM(c.customer_id)
WHERE c.customer_id IS NULL;

SELECT COALESCE(channel, '<NULL>') AS raw_channel, COUNT(*)
FROM raw_orders
GROUP BY channel
ORDER BY COUNT(*) DESC;

\echo '=========================================='
\echo '5. ORDER LINES CHECKS'
\echo '=========================================='
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(quantity), '') IS NULL OR quantity !~ '^-?\d+(\.\d+)?$') AS missing_or_non_numeric_qty,
    COUNT(*) FILTER (WHERE quantity ~ '^-?\d+(\.\d+)?$' AND quantity::NUMERIC <= 0) AS qty_le_zero,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(unit_price), '') IS NULL) AS missing_unit_price,
    COUNT(*) FILTER (WHERE unit_price ~ '^-?\d+(\.\d+)?$' AND unit_price::NUMERIC <= 0) AS unit_price_le_zero,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(discount_pct), '') IS NULL) AS missing_discount,
    COUNT(*) FILTER (WHERE discount_pct ~ '^-?\d+(\.\d+)?$' AND (discount_pct::NUMERIC < 0 OR discount_pct::NUMERIC > 100)) AS bad_discount_range
FROM raw_order_lines;

SELECT
    COUNT(*) FILTER (WHERE o.order_id IS NULL) AS orphan_order_id,
    COUNT(*) FILTER (WHERE p.product_id IS NULL) AS orphan_product_id
FROM raw_order_lines ol
LEFT JOIN raw_orders o ON TRIM(ol.order_id) = TRIM(o.order_id)
LEFT JOIN raw_products p ON TRIM(ol.product_id) = TRIM(p.product_id);

\echo '=========================================='
\echo '6. INVOICES & PAYMENTS CHECKS'
\echo '=========================================='
SELECT
    COUNT(*) AS total_invoices,
    COUNT(DISTINCT order_id) AS distinct_invoiced_orders,
    COUNT(*) FILTER (WHERE o.order_id IS NULL) AS orphan_order_id,
    COUNT(*) FILTER (WHERE LOWER(TRIM(COALESCE(o.status,''))) IN ('cancelled', 'placed')) AS invoiced_cancelled_or_placed,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(i.amount), '') IS NULL OR i.amount::NUMERIC <= 0) AS bad_invoice_amount,
    COUNT(*) FILTER (WHERE i.due_date < i.invoice_date) AS due_before_invoice
FROM raw_invoices i
LEFT JOIN raw_orders o ON TRIM(i.order_id) = TRIM(o.order_id);

SELECT
    COUNT(*) AS total_payments,
    COUNT(*) FILTER (WHERE i.invoice_id IS NULL) AS orphan_invoice_id,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(p.amount), '') IS NULL OR p.amount::NUMERIC <= 0) AS bad_payment_amount,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(p.payment_date), '') IS NULL) AS missing_payment_date
FROM raw_payments p
LEFT JOIN raw_invoices i ON TRIM(p.invoice_id) = TRIM(i.invoice_id);

SELECT COALESCE(method, '<NULL>') AS raw_payment_method, COUNT(*)
FROM raw_payments
GROUP BY method
ORDER BY COUNT(*) DESC;