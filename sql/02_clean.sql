
BEGIN;

-- Drop existing clean tables 
DROP TABLE IF EXISTS rejected_records;
DROP TABLE IF EXISTS clean_payments;
DROP TABLE IF EXISTS clean_invoices;
DROP TABLE IF EXISTS clean_order_lines;
DROP TABLE IF EXISTS clean_orders;
DROP TABLE IF EXISTS clean_products;
DROP TABLE IF EXISTS clean_customers;

-- Create clean schema with strict data types, keys, and CHECK constraints
CREATE TABLE clean_customers (
    customer_id   VARCHAR(20) PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL,
    region        VARCHAR(50) NOT NULL,
    segment       VARCHAR(50) NOT NULL CHECK (segment IN ('Retail', 'Wholesale', 'Distributor', 'Corporate')),
    credit_limit  NUMERIC(14, 2) NOT NULL CHECK (credit_limit >= 0),
    email         VARCHAR(255) NOT NULL,
    created_at    DATE NOT NULL,
    updated_at    DATE NOT NULL
);

CREATE TABLE clean_products (
    product_id   VARCHAR(20) PRIMARY KEY,
    sku          VARCHAR(50) NOT NULL UNIQUE,
    product_name VARCHAR(255) NOT NULL,
    category     VARCHAR(100) NOT NULL,
    list_price   NUMERIC(12, 2) NOT NULL CHECK (list_price > 0),
    uom          VARCHAR(20) NOT NULL
);

CREATE TABLE clean_orders (
    order_id    VARCHAR(20) PRIMARY KEY,
    customer_id VARCHAR(20) NOT NULL REFERENCES clean_customers(customer_id),
    order_date  DATE NOT NULL,
    status      VARCHAR(20) NOT NULL CHECK (status IN ('placed', 'shipped', 'delivered', 'cancelled', 'returned')),
    channel     VARCHAR(50) NOT NULL
);

CREATE TABLE clean_order_lines (
    line_id      VARCHAR(20) PRIMARY KEY,
    order_id     VARCHAR(20) NOT NULL REFERENCES clean_orders(order_id),
    product_id   VARCHAR(20) NOT NULL REFERENCES clean_products(product_id),
    quantity     NUMERIC(12, 2) NOT NULL CHECK (quantity > 0),
    unit_price   NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    discount_pct NUMERIC(5, 2) NOT NULL CHECK (discount_pct >= 0 AND discount_pct <= 100),
    net_amount   NUMERIC(14, 4) NOT NULL
);

CREATE TABLE clean_invoices (
    invoice_id   VARCHAR(20) PRIMARY KEY,
    order_id     VARCHAR(20) NOT NULL UNIQUE REFERENCES clean_orders(order_id),
    invoice_date DATE NOT NULL,
    due_date     DATE NOT NULL CHECK (due_date >= invoice_date),
    amount       NUMERIC(14, 2) NOT NULL CHECK (amount > 0)
);

CREATE TABLE clean_payments (
    payment_id   VARCHAR(20) PRIMARY KEY,
    invoice_id   VARCHAR(20) NOT NULL REFERENCES clean_invoices(invoice_id),
    payment_date DATE NOT NULL,
    amount       NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    method       VARCHAR(50) NOT NULL CHECK (method IN ('bank_transfer', 'cash', 'bkash', 'cheque'))
);

CREATE TABLE rejected_records (
    reject_id    SERIAL PRIMARY KEY,
    source_table VARCHAR(50) NOT NULL,
    record_id    VARCHAR(50),
    reason       TEXT NOT NULL,
    raw_payload  JSONB
);

-- Populate clean_customers dedupe by latest updated_at, and apply latest region from customer_changes
WITH ranked_customers AS (
    SELECT
        TRIM(customer_id) AS customer_id,
        TRIM(customer_name) AS customer_name,
        INITCAP(TRIM(region)) AS base_region,
        INITCAP(TRIM(segment)) AS base_segment,
        TRIM(credit_limit)::NUMERIC(14, 2) AS credit_limit,
        TRIM(email) AS email,
        TRIM(created_at)::DATE AS created_at,
        TRIM(updated_at)::DATE AS updated_at,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(customer_id)
            ORDER BY TRIM(updated_at)::DATE DESC, TRIM(created_at)::DATE DESC
        ) AS rn
    FROM raw_customers
),
latest_changes AS (
    SELECT
        TRIM(customer_id) AS customer_id,
        INITCAP(TRIM(region)) AS new_region,
        INITCAP(TRIM(segment)) AS new_segment,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(customer_id)
            ORDER BY TRIM(effective_date)::DATE DESC
        ) AS rn
    FROM raw_customer_changes
)
INSERT INTO clean_customers (
    customer_id, customer_name, region, segment, credit_limit, email, created_at, updated_at
)
SELECT
    c.customer_id,
    c.customer_name,
    COALESCE(lc.new_region, c.base_region) AS region,
    COALESCE(lc.new_segment, c.base_segment) AS segment,
    c.credit_limit,
    c.email,
    c.created_at,
    c.updated_at
FROM ranked_customers c
LEFT JOIN latest_changes lc
    ON c.customer_id = lc.customer_id AND lc.rn = 1
WHERE c.rn = 1;

-- Populate clean_products
INSERT INTO clean_products (product_id, sku, product_name, category, list_price, uom)
SELECT
    TRIM(product_id),
    TRIM(sku),
    TRIM(product_name),
    TRIM(category),
    TRIM(list_price)::NUMERIC(12, 2),
    TRIM(uom)
FROM raw_products;

-- Populate clean_orders & log rejected orders 
WITH dedup_orders AS (
    SELECT
        TRIM(order_id) AS order_id,
        TRIM(customer_id) AS customer_id,
        CASE
            WHEN TRIM(order_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(order_date)::DATE
            ELSE TO_DATE(TRIM(order_date), 'DD/MM/YYYY')
        END AS parsed_order_date,
        LOWER(NULLIF(TRIM(status), '')) AS norm_status,
        TRIM(channel) AS channel,
        row_to_json(raw_orders)::JSONB AS payload,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(order_id)
            ORDER BY TRIM(order_date) DESC
        ) AS rn
    FROM raw_orders
),
evaluated_orders AS (
    SELECT
        o.*,
        CASE
            WHEN o.norm_status IS NULL THEN 'Missing order status'
            WHEN o.norm_status NOT IN ('placed', 'shipped', 'delivered', 'cancelled', 'returned')
                THEN 'Invalid order status: ' || o.norm_status
            WHEN c.customer_id IS NULL THEN 'Unknown customer_id not found in customer master'
            ELSE NULL
        END AS reject_reason
    FROM dedup_orders o
    LEFT JOIN clean_customers c ON o.customer_id = c.customer_id
    WHERE o.rn = 1
),
ins_clean AS (
    INSERT INTO clean_orders (order_id, customer_id, order_date, status, channel)
    SELECT order_id, customer_id, parsed_order_date, norm_status, channel
    FROM evaluated_orders
    WHERE reject_reason IS NULL
)
INSERT INTO rejected_records (source_table, record_id, reason, raw_payload)
SELECT 'raw_orders', order_id, reject_reason, payload
FROM evaluated_orders
WHERE reject_reason IS NOT NULL;

-- Populate clean_order_lines & log rejected lines
WITH evaluated_lines AS (
    SELECT
        TRIM(ol.line_id) AS line_id,
        TRIM(ol.order_id) AS order_id,
        TRIM(ol.product_id) AS product_id,
        TRIM(ol.quantity)::NUMERIC(12, 2) AS qty,
        COALESCE(NULLIF(TRIM(ol.unit_price), '')::NUMERIC(12, 2), p.list_price) AS resolved_unit_price,
        COALESCE(NULLIF(TRIM(ol.discount_pct), '')::NUMERIC(5, 2), 0) AS disc_pct,
        row_to_json(ol)::JSONB AS payload,
        CASE
            WHEN co.order_id IS NULL AND TRIM(ol.quantity)::NUMERIC <= 0
                THEN 'Parent order rejected and quantity <= 0'
            WHEN co.order_id IS NULL
                THEN 'Parent order rejected or missing from clean_orders'
            WHEN TRIM(ol.quantity)::NUMERIC <= 0
                THEN 'Quantity must be greater than 0'
            WHEN p.product_id IS NULL
                THEN 'Unknown product_id not found in product master'
            ELSE NULL
        END AS reject_reason
    FROM raw_order_lines ol
    LEFT JOIN clean_orders co ON TRIM(ol.order_id) = co.order_id
    LEFT JOIN clean_products p ON TRIM(ol.product_id) = p.product_id
),
ins_lines AS (
    INSERT INTO clean_order_lines (
        line_id, order_id, product_id, quantity, unit_price, discount_pct, net_amount
    )
    SELECT
        line_id,
        order_id,
        product_id,
        qty,
        resolved_unit_price,
        disc_pct,
        (qty * resolved_unit_price * (1 - disc_pct / 100.0))::NUMERIC(14, 4)
    FROM evaluated_lines
    WHERE reject_reason IS NULL
)
INSERT INTO rejected_records (source_table, record_id, reason, raw_payload)
SELECT 'raw_order_lines', line_id, reject_reason, payload
FROM evaluated_lines
WHERE reject_reason IS NOT NULL;

-- Populate clean_invoices & log rejected invoices
WITH evaluated_invoices AS (
    SELECT
        TRIM(i.invoice_id) AS invoice_id,
        TRIM(i.order_id) AS order_id,
        TRIM(i.invoice_date)::DATE AS invoice_date,
        TRIM(i.due_date)::DATE AS due_date,
        TRIM(i.amount)::NUMERIC(14, 2) AS amount,
        row_to_json(i)::JSONB AS payload,
        CASE
            WHEN co.order_id IS NULL THEN 'Parent order rejected or missing from clean_orders'
            ELSE NULL
        END AS reject_reason
    FROM raw_invoices i
    LEFT JOIN clean_orders co ON TRIM(i.order_id) = co.order_id
),
ins_invoices AS (
    INSERT INTO clean_invoices (invoice_id, order_id, invoice_date, due_date, amount)
    SELECT invoice_id, order_id, invoice_date, due_date, amount
    FROM evaluated_invoices
    WHERE reject_reason IS NULL
)
INSERT INTO rejected_records (source_table, record_id, reason, raw_payload)
SELECT 'raw_invoices', invoice_id, reject_reason, payload
FROM evaluated_invoices
WHERE reject_reason IS NOT NULL;

-- Populate clean_payments & log rejected payments 
WITH dedup_payments AS (
    SELECT
        TRIM(payment_id) AS payment_id,
        TRIM(invoice_id) AS invoice_id,
        TRIM(payment_date)::DATE AS payment_date,
        TRIM(amount)::NUMERIC(14, 2) AS amount,
        LOWER(TRIM(method)) AS method,
        row_to_json(raw_payments)::JSONB AS payload,
        ROW_NUMBER() OVER (
            PARTITION BY TRIM(payment_id)
            ORDER BY TRIM(payment_date) DESC
        ) AS rn
    FROM raw_payments
),
evaluated_payments AS (
    SELECT
        p.*,
        CASE
            WHEN ci.invoice_id IS NULL THEN 'Parent invoice rejected or missing from clean_invoices'
            ELSE NULL
        END AS reject_reason
    FROM dedup_payments p
    LEFT JOIN clean_invoices ci ON p.invoice_id = ci.invoice_id
    WHERE p.rn = 1
),
ins_payments AS (
    INSERT INTO clean_payments (payment_id, invoice_id, payment_date, amount, method)
    SELECT payment_id, invoice_id, payment_date, amount, method
    FROM evaluated_payments
    WHERE reject_reason IS NULL
)
INSERT INTO rejected_records (source_table, record_id, reason, raw_payload)
SELECT 'raw_payments', payment_id, reject_reason, payload
FROM evaluated_payments
WHERE reject_reason IS NOT NULL;

COMMIT;

-- verify raw = clean + rejected + duplicates_removed
SELECT
    'customers' AS entity,
    (SELECT COUNT(*) FROM raw_customers) AS raw_rows,
    8 AS deduped_removed,
    (SELECT COUNT(*) FROM clean_customers) AS clean_rows,
    (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_customers') AS rejected_rows
UNION ALL
SELECT 'products',
    (SELECT COUNT(*) FROM raw_products), 0,
    (SELECT COUNT(*) FROM clean_products),
    (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_products')
UNION ALL
SELECT 'orders',
    (SELECT COUNT(*) FROM raw_orders), 200,
    (SELECT COUNT(*) FROM clean_orders),
    (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_orders')
UNION ALL
SELECT 'order_lines',
    (SELECT COUNT(*) FROM raw_order_lines), 0,
    (SELECT COUNT(*) FROM clean_order_lines),
    (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_order_lines')
UNION ALL
SELECT 'invoices',
    (SELECT COUNT(*) FROM raw_invoices), 0,
    (SELECT COUNT(*) FROM clean_invoices),
    (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_invoices')
UNION ALL
SELECT 'payments',
    (SELECT COUNT(*) FROM raw_payments), 95,
    (SELECT COUNT(*) FROM clean_payments),
    (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_payments');