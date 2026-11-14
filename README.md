
# Sysnova ERP Data Pipeline (Order-to-Cash ELT)

A robust, idempotent ELT (Extract, Load, Transform) pipeline built in Python and PostgreSQL to ingest, audit, clean, and report on legacy food-distribution enterprise data.

---

## 1. Project Overview & Tech Stack
* **Domain:** Food distribution ERP — Order-to-Cash (O2C) cycle across Poultry, Dairy, Feed, Eggs, Frozen, and Bakery sectors (amounts in BDT).
* **Tech Stack:** 
  * **Database:** PostgreSQL (strict relational constraints, CHECK constraints, and Foreign Keys).
  * **Automation & Export:** Python 3 (`psycopg2-binary`, standard library `pathlib`, `csv`, `json`, `os`).
  * **Version Control:** Git.

### Repository Structure

```text
sysnova-erp-data-pipeline/
├── data/raw/              # Read-only input CSV files (7 files)
├── docs/                  # Data quality documentation (data_issues.md)
├── results/               # Exported business reports (q1-q3.csv) and summary.json
├── scripts/               # Python ETL automation (load_raw.py, export_results.py)
├── sql/                   # Database scripts (01_create_raw.sql, 02_clean.sql, q1-q3.sql)
├── .env.example           # Environment variable template
├── requirements.txt       # Python dependencies
└── README.md              # Project documentation
```

---

## 2. How to Run From a Clean Checkout

Follow these steps to set up and run the entire pipeline locally from scratch:

1. **Clone the Repository & Set Up Virtual Environment**
   ```powershell
   git clone https://github.com/naham6/sysnova-erp-data-pipeline.git
   cd sysnova-erp-data-pipeline
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```

2. **Configure Environment Variables**
* Copy `.env.example` to `.env`:
```powershell
copy .env.example .env
```

* Update `.env` with your local PostgreSQL credentials (`DB_PASSWORD`, etc.).

3. **Create the Database**
```powershell
createdb -U postgres sysnova_erp
```

4. **Execute the Pipeline (End-to-End)**
Run the following sequence in your terminal:
```powershell
# Step 1: Create unconstrained raw landing tables
psql -U postgres -d sysnova_erp -f sql/01_create_raw.sql

# Step 2: Ingest raw CSVs idempotently using fast COPY
python scripts/load_raw.py

# Step 3: Run data cleaning, deduplication, constraint checks, and audit logging
psql -U postgres -d sysnova_erp -f sql/02_clean.sql

# Step 4: Export reporting CSVs (q1-q3) and generate summary.json
python scripts/export_results.py
```

---

## 3. Order-to-Cash (O2C) Process Summary

The pipeline models the core commercial lifecycle of the enterprise:

1. **Master Data & Orders:** Customers place orders (`orders.csv`) containing line-item product selections (`order_lines.csv`).
2. **Fulfillment & Invoicing:** Once an order is successfully fulfilled (`shipped`, `delivered`, or `returned`), finance issues a billed invoice (`invoices.csv`) with an established due date.
3. **Collections & Receivables:** Customers settle invoices via partial or full payments (`payments.csv`). Unpaid or partially paid balances past their due date accumulate into Accounts Receivable (AR aging), categorized across standardized overdue time buckets.

---

## 4. Data Quality Issues & Key Assumptions

Every anomaly discovered during data profiling (`docs/data_issues.md`) was handled systematically rather than deleted silently:

* **Idempotency & Reconciling:** Raw row counts reconcile perfectly against clean rows plus rejected audit logs (`Raw = Clean + Rejected + Deduplicated`).
* **Foreign Key Integrity:** Rejected parent orders or invoices cascade to dependent child order lines, invoices, and payments, routing them to `rejected_records` to prevent broken relational links.
* **Fallback Imputation:** Missing `unit_price` values on order lines were safely imputed using the product's standard `list_price` from `clean_products`.

---

## 5. What I Would Do With More Time

* Wrap the SQL cleaning transformations inside a PostgreSQL stored procedure with automated execution logging and error handling.  
* Use llm for further structured summary.
* Use automated dashboards to help understnading the summary visually.
* Add composite indexes on foreign keys and date columns to further optimize large-scale analytical query performance.
* Implement an automated `pytest` test suite to validate row-count reconciliation and constraint violations automatically on every run.
