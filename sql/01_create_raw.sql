DROP TABLE IF EXISTS raw_payments;
DROP TABLE IF EXISTS raw_invoices;
DROP TABLE IF EXISTS raw_order_lines;
DROP TABLE IF EXISTS raw_orders;
DROP TABLE IF EXISTS raw_customer_changes;
DROP TABLE IF EXISTS raw_customers;
DROP TABLE IF EXISTS raw_products;

CREATE TABLE raw_customers (
    customer_id   TEXT,
    customer_name TEXT,
    region        TEXT,
    segment       TEXT,
    credit_limit  TEXT,
    email         TEXT,
    created_at    TEXT,
    updated_at    TEXT
);

CREATE TABLE raw_customer_changes (
    customer_id    TEXT,
    effective_date TEXT,
    region         TEXT,
    segment        TEXT
);

CREATE TABLE raw_products (
    product_id   TEXT,
    sku          TEXT,
    product_name TEXT,
    category     TEXT,
    list_price   TEXT,
    uom          TEXT
);

CREATE TABLE raw_orders (
    order_id    TEXT,
    customer_id TEXT,
    order_date  TEXT,
    status      TEXT,
    channel     TEXT
);

CREATE TABLE raw_order_lines (
    line_id      TEXT,
    order_id     TEXT,
    product_id   TEXT,
    quantity     TEXT,
    unit_price   TEXT,
    discount_pct TEXT
);

CREATE TABLE raw_invoices (
    invoice_id   TEXT,
    order_id     TEXT,
    invoice_date TEXT,
    due_date     TEXT,
    amount       TEXT
);

CREATE TABLE raw_payments (
    payment_id   TEXT,
    invoice_id   TEXT,
    payment_date TEXT,
    amount       TEXT,
    method       TEXT
);