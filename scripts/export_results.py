import csv
import json
import os
from pathlib import Path
import psycopg2


def load_env(env_path: Path) -> None:
    """Read key=value pairs from .env into os.environ."""
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def export_query_to_csv(cur, sql_path: Path, csv_path: Path) -> int:
    """Execute a SQL file and write its headers + rows to a CSV file."""
    query = sql_path.read_text(encoding="utf-8")
    cur.execute(query)
    headers = [desc[0] for desc in cur.description]
    rows = cur.fetchall()

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    return len(rows)


def build_summary(cur) -> dict:
    """Compute required summary metrics directly from the database."""
    cur.execute(
        """
        SELECT
            (SELECT COUNT(*) FROM clean_customers) AS clean_customers,
            (SELECT COUNT(*) FROM clean_orders) AS clean_orders,
            (SELECT COUNT(*) FROM rejected_records WHERE source_table = 'raw_orders') AS rejected_orders,
            (SELECT COUNT(*) FROM clean_order_lines) AS clean_order_lines,
            (
                SELECT COALESCE(ROUND(SUM(ol.net_amount), 2), 0.00)
                FROM clean_orders o
                JOIN clean_order_lines ol ON o.order_id = ol.order_id
                WHERE o.status = 'delivered'
            ) AS total_recognized_revenue,
            (SELECT COUNT(*) FROM clean_payments) AS payments_after_dedupe,
            (
                WITH as_of_payments AS (
                    SELECT invoice_id, SUM(amount) AS paid_amount
                    FROM clean_payments
                    WHERE payment_date <= DATE '2025-12-31'
                    GROUP BY invoice_id
                )
                SELECT COALESCE(ROUND(SUM(i.amount - COALESCE(p.paid_amount, 0)), 2), 0.00)
                FROM clean_invoices i
                LEFT JOIN as_of_payments p ON i.invoice_id = p.invoice_id
                WHERE i.invoice_date <= DATE '2025-12-31'
                  AND (i.amount - COALESCE(p.paid_amount, 0)) > 0
            ) AS ar_total_outstanding;
        """
    )
    row = cur.fetchone()
    return {
        "clean_customers": int(row[0]),
        "clean_orders": int(row[1]),
        "rejected_orders": int(row[2]),
        "clean_order_lines": int(row[3]),
        "total_recognized_revenue": float(row[4]),
        "payments_after_dedupe": int(row[5]),
        "ar_total_outstanding": float(row[6]),
    }


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    load_env(project_root / ".env")

    sql_dir = project_root / "sql"
    results_dir = project_root / "results"
    results_dir.mkdir(exist_ok=True)

    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "sysnova_erp"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
    )

    try:
        with conn.cursor() as cur:
            for q_name in ["q1", "q2", "q3"]:
                row_count = export_query_to_csv(
                    cur,
                    sql_dir / f"{q_name}.sql",
                    results_dir / f"{q_name}.csv",
                )
                print(f"Exported results/{q_name}.csv ({row_count} rows)")

            summary = build_summary(cur)
            summary_path = results_dir / "summary.json"
            summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
            print("\nGenerated results/summary.json:")
            print(json.dumps(summary, indent=2))
    finally:
        conn.close()


if __name__ == "__main__":
    main()