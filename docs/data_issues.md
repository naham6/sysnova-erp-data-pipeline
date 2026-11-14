# Data Quality Issues & Handling Summary


Tables and the issues found are as follows:

`raw_customers`
1. Duplicate `customer_id` records with older `updated_at` timestamps: 8 extra rows (408 total and 400 unique). Deduplicated and kept the latest `updated_at` row (Rule 3).
2. Inconsistent `region` casing and leading/trailing spaces (e.g., `dhaka`, `DHAKA`, ` Dhaka`, `Chattogram `): 25 rows standardized to clean Title Case (Rule 3).

`raw_customer_changes`
1. Slowly changing `region` and `segment` overrides by `effective_date` (73 change rows across 60 unique customers). Applied the latest `effective_date` change per customer onto `clean_customers`; customers without changes retain their `customers.csv` values (Rule 4).

`raw_orders`
1. Exact duplicate `order_id` rows: 200 extra rows (20,200 total and 20,000 unique). Deduplicated (Rule 5).
2. Mixed `order_date` formats (`YYYY-MM-DD` vs. `DD/MM/YYYY`): 1,614 rows in `DD/MM/YYYY`. Parsed conditionally using regex: ISO strings cast directly to `DATE`, and `DD/MM/YYYY` strings parsed via `TO_DATE(..., 'DD/MM/YYYY')` (Rule 2).
3. Inconsistent `status` casing and whitespace (e.g., `Delivered`, ` delivered`, `DELIVERED`): normalized so valid values match `placed`, `shipped`, `delivered`, `cancelled`, `returned` (Rule 1).
4. Missing / blank `status` (60 orders): rejected from `clean_orders` and logged to `rejected_records` with reason `Missing order status` (Rules 5 & 11).
5. Unknown `customer_id`s not present in `customers.csv` (100 orders): rejected from `clean_orders` and logged to `rejected_records` with reason `Unknown customer_id not found in customer master` (Rules 5 & 11).

`raw_order_lines`
1. Lines belonging to the 160 rejected orders (376 lines): excluded from `clean_order_lines` to preserve foreign key integrity and logged to `rejected_records` (Rules 6 & 11).
2. Non-positive `quantity` (`quantity <= 0`, 246 total lines): rejected from `clean_order_lines` and logged to `rejected_records` with reason `Quantity must be greater than 0` (Rules 6 & 11).
3. Missing / blank `unit_price` (147 lines): imputed missing `unit_price` using `COALESCE(NULLIF(TRIM(unit_price), '')::NUMERIC, products.list_price)` (Rule 6).

`raw_invoices`
1. Invoices linked to rejected orders (136 invoices): rejected from `clean_invoices` and logged to `rejected_records` so `clean_invoices.order_id` enforces a strict `FOREIGN KEY` to `clean_orders(order_id)` (Rule 11).

`raw_payments`
1. Exact duplicate `payment_id` rows: 95 extra rows (19,096 total and 19,001 unique). Deduplicated by `TRIM(payment_id)` (Rule 9).
2. Payments linked to the 136 rejected invoices (152 payments): rejected from `clean_payments` and logged to `rejected_records` so `clean_payments.invoice_id` enforces a strict `FOREIGN KEY` to `clean_invoices(invoice_id)` (Rule 11).