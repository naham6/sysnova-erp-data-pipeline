# Sysnova - Junior Data Programmer Take-Home Assessment

Thank you for your interest in the **Junior Data Programmer** role at Sysnova Information Systems.

This assessment mirrors the day-to-day work: loading data from files into a database, cleaning it, building
reliable SQL, and designing tables for ERP-style sales and finance data. It uses a **synthetic**
dataset of a food-distribution business (sales orders, invoices, payments). No real company data is involved.

**Freshers are very welcome.** We care about solid fundamentals, clear thinking and honesty far more than advanced tools.
**Do not worry about completing the whole task.** Submit whatever you have done, and tell us what is missing.

| | |
|---|---|
| **Expected effort** | About 5-6 hours for the required tasks. Optional tasks are extra. Please do not over-engineer |
| **Submit via** | A **public GitHub repository**. Email us the repo link |
| **Questions** | Email **jobs@sysnova.com** (subject: *DA Assessment - your name*). Answers are shared with all candidates |
| **AI tools** | Optional. You can code by hand. If you choose to use AI, follow `AI_AGENT_GUIDELINE.md` |

## What happens next
We review every submission. Strong submissions are invited to a **live session (about 45 min)** where you walk us
through your work and make a small change to it. Be ready to explain every decision you made.

---

## 1. The data

All files are in `data/raw/`. **Treat them as read-only inputs; do not edit them.**
Column descriptions and relationships are in `DATA_DICTIONARY.md`. All amounts are in BDT.

| File | Description |
|---|---|
| `customers.csv` | Customer master |
| `customer_changes.csv` | Later changes to a customer's `region` / `segment`, with `effective_date` |
| `products.csv` | Product master with `list_price` |
| `orders.csv` | Sales order headers |
| `order_lines.csv` | Sales order lines |
| `invoices.csv` | One invoice per shipped/delivered/returned order |
| `payments.csv` | Customer payments against invoices (an invoice can have several) |

**The data is realistic, which means it is messy.** Finding and handling the problems is part of the
assessment. Document every problem you find and how you handled it.

### Business rules (follow these exactly)

1. **Order status** values are `placed, shipped, delivered, cancelled, returned` (case and spacing are not reliable).
2. **Dates** in `orders.order_date` appear in more than one format. Where the format is not ISO it is `DD/MM/YYYY`.
3. **Customers:** `customer_id` is the key. If it appears more than once, keep the row with the latest `updated_at`.
   `region` must be standardised (trimmed, Title Case).
4. **Current region and segment:** for each customer, use the values from their **latest** row in `customer_changes.csv`
   (by `effective_date`); if a customer has no changes, use the values from `customers.csv`.
5. **Orders:** de-duplicate on `order_id`. Reject (do not load into the clean tables) any order with a **missing status**
   or a `customer_id` that **does not exist** in the customer master.
6. **Order lines:** reject lines with `quantity <= 0`. If `unit_price` is missing, use the product's `list_price`.
   Lines belonging to rejected orders are not loaded.
7. **Line net amount** = `quantity * unit_price * (1 - discount_pct / 100)`.
8. **Recognised revenue** = net amount of lines on orders with status **`delivered`**, by `order_date`.
9. **Payments:** de-duplicate on `payment_id`.
10. **Receivables:** `outstanding = invoice.amount - payments received on or before the as-of date`.
    The invoice `amount` in `invoices.csv` is the billed amount (use it as given).
    **As-of date for all receivable reporting: `2025-12-31`.** Invoices with `outstanding <= 0` are not "open".
11. **Rejected records** must not disappear silently. Write them to a rejects table with a reason.

---

## 2. Tasks

Use **PostgreSQL** if you can (it is what we use). MySQL, SQL Server or Oracle are also fine; say which you used.
Any scripting language (Python is a good choice) may be used for loading.

### Required

**Task 1 - Load the raw data**
Create the database and load every CSV **as-is** into raw tables (`raw_customers`, `raw_orders`, ...).
Provide scripts so we can reproduce it from a clean database (for example `sql/01_create_raw.sql` plus a load script).
Running them twice must not duplicate data.

**Task 2 - Find the data problems**
Profile the raw data and list every data-quality problem you find in `docs/data_issues.md`: what it is, roughly how
many rows, and how you handled it. A table works well.

**Task 3 - Clean the data with SQL**
Build the clean tables `clean_customers`, `clean_orders`, `clean_order_lines`, `clean_invoices`, `clean_payments`
and a `rejected_records` table (with a `reason` per record), applying the business rules above.
Put the logic in a clearly ordered set of SQL scripts (for example `sql/02_clean.sql`) that can be **re-run safely**.
A stored procedure or function is welcome but optional. Give the clean tables sensible data types, **primary keys, foreign keys**
and **NOT NULL / CHECK constraints** where they make sense.

**Task 4 - Three reporting queries**
Write three queries as `sql/q1.sql` ... `sql/q3.sql`. Save each result as CSV in `results/` (`results/q1.csv` ... `results/q3.csv`),
with a header row.

1. **`q1`**: Monthly recognised revenue with **month-over-month growth %**.
2. **`q2`**: **Top 3 customers by recognised revenue in each region for calendar year 2025** (use each customer's
   current region, rule 4).
3. **`q3`**: **Receivables aging** as of `2025-12-31`, bucketed: *not yet due, 1-30, 31-60, 61-90, 90+* days past due,
   showing invoice count and outstanding amount per bucket.

**Task 5 - README and Git**
The root `README.md` must contain:
- How to run everything from a clean checkout
- A short **order-to-cash explanation**, in your own words (5-8 lines): how an order becomes an invoice and then a
  payment, and which table in this dataset represents each step
- The data problems you found (or a link to `docs/data_issues.md`) and any assumptions you made where the rules were unclear
- What you would do with more time

Use **Git properly**: many small commits with meaningful messages.
If you used any AI tool, also add `AI_USAGE.md` (see `AI_AGENT_GUIDELINE.md`). If you used none, you do not need it.

### Optional extras (not required; do these only if you have time left)
- **Query rewrite:** the query in `sql/slow_query.sql` is slow on large data. Rewrite it to return the same result more
  efficiently as `sql/q4.sql`, and explain what you changed in `docs/q4_notes.md`.
- **One business report:** for example a Monthly Sales Summary or a Receivables Aging report. JasperReports is welcome, but
  any tool is fine (Excel, Power BI, Metabase, or a script that produces a PDF/HTML). Put the source and an exported PDF or
  screenshot in `report/`.
- **ER diagram:** an image or Mermaid diagram in `docs/`.
- **Stored procedure or function** wrapping the cleaning logic.
- **PySpark or a Python ETL script with logging.**

None of the optional items are needed to do well. We would rather see the required tasks done correctly.

---

## 3. Required results file
Write `results/summary.json` with these keys (the numbers must come from your database/pipeline output, not be typed in by hand):

```json
{
  "clean_customers": 0,
  "clean_orders": 0,
  "rejected_orders": 0,
  "clean_order_lines": 0,
  "total_recognized_revenue": 0.0,
  "payments_after_dedupe": 0,
  "ar_total_outstanding": 0.0
}
```

If your numbers differ from what you think is right because of an ambiguity, **say so in the README**. A
documented, defensible assumption is better than a silent guess.

---

## 4. Submission checklist
- [ ] Public GitHub repo, link emailed to jobs@sysnova.com
- [ ] `README.md` (and `AI_USAGE.md` only if you used AI)
- [ ] Scripts run from a clean checkout following your README
- [ ] `sql/` (create, load, cleaning scripts, q1-q3), `docs/data_issues.md`
- [ ] `results/` with `q1.csv` ... `q3.csv` and `summary.json`
- [ ] **Meaningful Git history** (many small commits, not one big "final" commit)
- [ ] No passwords or secrets committed; `data/raw/` unchanged

## 5. How we evaluate
Correctness of results, SQL quality, loading and cleaning, database design, handling of data problems,
Git and code hygiene, documentation and, if you used AI, honest disclosure of it. We value clear thinking and being able to explain your
work over feature count. **Partial but solid and well-explained beats complete but unexplained.**

## 6. Confidentiality
Your solution repo is public, but do not share the task brief or the dataset anywhere else (forums, gists, social media), and do not share it with other candidates.

Good luck. We look forward to seeing how you work.
