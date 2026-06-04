"""Execute every .sql file in sql/ against home_credit.duckdb and export
each result set as a CSV in dashboard/data/.

Usage:
    python scripts/run_all_queries.py
"""

from pathlib import Path
import duckdb

PROJECT_DIR = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_DIR / "data" / "processed" / "lending_club.duckdb"
SQL_DIR = PROJECT_DIR / "sql"
OUT_DIR = PROJECT_DIR / "dashboard" / "data"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH), read_only=True)

    sql_files = sorted(SQL_DIR.glob("*.sql"))
    if not sql_files:
        print("No SQL files found in sql/")
        return

    for sql_file in sql_files:
        query = sql_file.read_text()
        out_path = OUT_DIR / f"{sql_file.stem}.csv"
        try:
            df = con.execute(query).fetchdf()
            df.to_csv(out_path, index=False)
            print(f"  OK   {sql_file.name:50s}  {len(df):>6} rows → {out_path.name}")
        except Exception as e:
            print(f"  FAIL {sql_file.name:50s}  {e}")

    con.close()


if __name__ == "__main__":
    main()
