import os
from pathlib import Path
import psycopg2


def load_env(env_path: Path) -> None:
    """Reading key=value pairs from .env into os.environ."""
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    load_env(project_root / ".env")

    raw_dir = project_root / "data" / "raw"

    # Mapping of target raw table -> source CSV filename
    tables_and_files = [
        ("raw_customers", "customers.csv"),
        ("raw_customer_changes", "customer_changes.csv"),
        ("raw_products", "products.csv"),
        ("raw_orders", "orders.csv"),
        ("raw_order_lines", "order_lines.csv"),
        ("raw_invoices", "invoices.csv"),
        ("raw_payments", "payments.csv"),
    ]

    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "sysnova_erp"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
    )

    try:
        with conn:  # wraps everything in a single transaction (all succeed or all rollback)
            with conn.cursor() as cur:
                table_names = ", ".join(t for t, _ in tables_and_files)
                cur.execute(f"TRUNCATE TABLE {table_names};")

                print("Loading raw CSV files into PostgreSQL...")
                for table_name, csv_name in tables_and_files:
                    csv_path = raw_dir / csv_name
                    with csv_path.open("r", encoding="utf-8") as f:
                        sql = f"COPY {table_name} FROM STDIN WITH (FORMAT csv, HEADER true)"
                        cur.copy_expert(sql, f)

                    cur.execute(f"SELECT COUNT(*) FROM {table_name};")
                    count = cur.fetchone()[0]
                    print(f"  {table_name:<22} <- {csv_name:<22} ({count:,} rows)")

        print("\nDone! All raw tables loaded cleanly.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()