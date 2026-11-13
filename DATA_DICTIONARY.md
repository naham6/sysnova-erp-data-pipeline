# Data Dictionary

Synthetic data for a food-distribution business. All amounts are in BDT. Dates cover 2024-2025.
Remember: the files are raw extracts and are **not guaranteed to be clean**; see the rules in `TASK.md`.

## Relationships
```
customers 1 ──< orders 1 ──< order_lines >── 1 products
                  │
                  └── 1 ──< invoices 1 ──< payments
customers 1 ──< customer_changes
```

## customers.csv
| Column | Description |
|---|---|
| `customer_id` | Customer key, e.g. `C00001` |
| `customer_name` | Customer name |
| `region` | Sales region as at `created_at` |
| `segment` | `Retail`, `Wholesale`, `Distributor` or `Corporate` as at `created_at` |
| `credit_limit` | Credit limit |
| `email` | Contact email |
| `created_at` | Date the customer record was created |
| `updated_at` | Date this row was last updated |

## customer_changes.csv
Later changes to a customer's attributes. Each row gives the **new** `region` and `segment` that apply from `effective_date`
onward (until a later change for the same customer). See business rule 4 in `TASK.md`.
| Column | Description |
|---|---|
| `customer_id` | Customer key |
| `effective_date` | Date the new values start to apply |
| `region`, `segment` | New values |

## products.csv
| Column | Description |
|---|---|
| `product_id` | Product key, e.g. `P0001` |
| `sku` | Stock keeping unit code |
| `product_name`, `category` | Name and category (Poultry, Dairy, Feed, Eggs, Frozen, Bakery) |
| `list_price` | Standard price per unit of measure |
| `uom` | Unit of measure (`kg`, `pcs`, `dozen`, `carton`) |

## orders.csv (one row per sales order)
| Column | Description |
|---|---|
| `order_id` | Order key, e.g. `SO0000001` |
| `customer_id` | Customer who placed the order |
| `order_date` | Order date |
| `status` | Order status (`placed`, `shipped`, `delivered`, `cancelled`, `returned`) |
| `channel` | Sales channel (`Direct`, `Distributor`, `Online`, `Key Account`) |

## order_lines.csv (one row per product line on an order)
| Column | Description |
|---|---|
| `line_id` | Line key |
| `order_id`, `product_id` | Order and product |
| `quantity` | Quantity ordered |
| `unit_price` | Price per unit actually charged |
| `discount_pct` | Discount given on the line, in percent (e.g. `10` = 10%) |

## invoices.csv (one row per invoiced order; cancelled and placed orders are not invoiced)
| Column | Description |
|---|---|
| `invoice_id` | Invoice key |
| `order_id` | Order being invoiced |
| `invoice_date`, `due_date` | Dates |
| `amount` | Billed amount |

## payments.csv (one row per payment; an invoice may have several, or none)
| Column | Description |
|---|---|
| `payment_id` | Payment key |
| `invoice_id` | Invoice being paid |
| `payment_date` | Date payment was received |
| `amount` | Amount received |
| `method` | `bank_transfer`, `cash`, `bkash` or `cheque` |
