"""Load Lending Club CSVs into a single DuckDB database.

The wordsforthewise/lending-club Kaggle dataset ships two gzipped CSVs:
  - accepted_2007_to_2018Q4.csv.gz  (~2.3M funded loans, the analysis target)
  - rejected_2007_to_2018Q4.csv.gz  (declined applications, not used here)

We load `accepted` into a single `loans` table and do some light cleanup:
  - strip '%' from int_rate and revol_util
  - parse issue_d (e.g. 'Dec-2015') into a proper DATE
  - add is_default flag (1 = Charged Off/Default, 0 = Fully Paid, NULL = in progress)

Usage:
    python scripts/build_duckdb.py
"""

from pathlib import Path
import duckdb

PROJECT_DIR = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_DIR / "data" / "raw"
DB_PATH = PROJECT_DIR / "data" / "processed" / "lending_club.duckdb"

ACCEPTED_GLOB = "accepted_*.csv*"  # matches .csv and .csv.gz


def main() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()

    # Find the accepted-loans CSV
    candidates = list(RAW_DIR.glob(ACCEPTED_GLOB))
    if not candidates:
        raise SystemExit(
            f"No accepted-loans CSV found in {RAW_DIR}. "
            f"Expected pattern: {ACCEPTED_GLOB}"
        )
    accepted_path = candidates[0]
    print(f"Loading {accepted_path.name}...")

    con = duckdb.connect(str(DB_PATH))

    # DuckDB reads .csv.gz natively. Use SAMPLE_SIZE=-1 to scan the whole file
    # for accurate type inference on this messy dataset.
    con.execute(f"""
        CREATE TABLE loans_raw AS
        SELECT * FROM read_csv_auto('{accepted_path}', SAMPLE_SIZE=-1, IGNORE_ERRORS=TRUE)
    """)

    raw_rows = con.execute("SELECT COUNT(*) FROM loans_raw").fetchone()[0]
    print(f"  Loaded {raw_rows:,} raw rows")

    # Build a cleaned analytic table. Lending Club's int_rate and revol_util
    # arrive as strings with '%' suffix; loan_status drives our target flag.
    con.execute("""
        CREATE TABLE loans AS
        SELECT
            id,
            loan_amnt,
            funded_amnt,
            term,
            -- int_rate may already be numeric or '%' string; handle both
            TRY_CAST(REPLACE(CAST(int_rate AS VARCHAR), '%', '') AS DOUBLE)   AS int_rate,
            installment,
            grade,
            sub_grade,
            emp_title,
            emp_length,
            home_ownership,
            annual_inc,
            verification_status,
            -- issue_d is 'Mon-YYYY' (e.g. 'Dec-2015'); parse to first of month
            TRY_CAST(STRPTIME(issue_d, '%b-%Y') AS DATE)                      AS issue_date,
            loan_status,
            purpose,
            title,
            addr_state,
            dti,
            delinq_2yrs,
            (fico_range_low + fico_range_high) / 2.0                          AS fico_avg,
            inq_last_6mths,
            open_acc,
            pub_rec,
            revol_bal,
            TRY_CAST(REPLACE(CAST(revol_util AS VARCHAR), '%', '') AS DOUBLE) AS revol_util,
            total_acc,
            application_type,
            total_pymnt,
            total_rec_prncp,
            total_rec_int,
            total_rec_late_fee,
            recoveries,
            collection_recovery_fee,
            last_pymnt_amnt,
            -- Target: 1 = bad (charged off / default), 0 = good (fully paid),
            -- NULL = in progress (current, late, grace) — exclude from default-rate stats.
            CASE
                WHEN loan_status IN ('Charged Off', 'Default')               THEN 1
                WHEN loan_status = 'Does not meet the credit policy. Status:Charged Off' THEN 1
                WHEN loan_status = 'Fully Paid'                              THEN 0
                WHEN loan_status = 'Does not meet the credit policy. Status:Fully Paid'  THEN 0
                ELSE NULL
            END AS is_default,
            -- Flag completed loans (where outcome is known)
            CASE
                WHEN loan_status IN (
                    'Charged Off', 'Default', 'Fully Paid',
                    'Does not meet the credit policy. Status:Charged Off',
                    'Does not meet the credit policy. Status:Fully Paid'
                ) THEN 1
                ELSE 0
            END AS is_completed
        FROM loans_raw
        WHERE id IS NOT NULL
    """)

    con.execute("DROP TABLE loans_raw")

    rows = con.execute("SELECT COUNT(*) FROM loans").fetchone()[0]
    completed = con.execute("SELECT COUNT(*) FROM loans WHERE is_completed = 1").fetchone()[0]
    defaults = con.execute("SELECT COUNT(*) FROM loans WHERE is_default = 1").fetchone()[0]
    print(f"  Cleaned table 'loans': {rows:,} rows")
    print(f"  Completed loans:        {completed:,}")
    print(f"  Defaults:               {defaults:,}  ({100*defaults/completed:.2f}% of completed)")

    # Useful index for window functions over time
    con.execute("CREATE INDEX idx_loans_issue ON loans(issue_date)")
    con.execute("CREATE INDEX idx_loans_status ON loans(loan_status)")

    print(f"\nDatabase written to: {DB_PATH}")
    print(f"Size: {DB_PATH.stat().st_size / 1e6:.1f} MB")
    con.close()


if __name__ == "__main__":
    main()
