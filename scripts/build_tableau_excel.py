"""Consolidate the 10 CSV query exports into a single Excel workbook
with one named sheet per query — used as the Tableau data source.

Output: dashboard/loan_default_tableau.xlsx
Usage: python scripts/build_tableau_excel.py
"""

from pathlib import Path
import pandas as pd

PROJECT_DIR = Path(__file__).resolve().parent.parent
CSV_DIR = PROJECT_DIR / "dashboard" / "data"
OUT_PATH = PROJECT_DIR / "dashboard" / "loan_default_tableau.xlsx"

# Map CSV filename -> sheet name (max 31 chars per Excel constraint)
SHEET_MAP = {
    "01_default_rate_overview.csv":          "default_rate_overview",
    "02_default_by_purpose_ownership.csv":   "default_by_purpose_owner",
    "03_default_by_income_employment.csv":   "default_by_income_employ",
    "04_dti_risk_curve.csv":                 "dti_risk_curve",
    "05_fico_score_tertiles.csv":            "fico_score_tertiles",
    "06_grade_calibration.csv":              "grade_calibration",
    "07_vintage_cohort_analysis.csv":        "vintage_cohort_analysis",
    "08_state_geographic_risk.csv":          "state_geographic_risk",
    "09_revolving_utilization.csv":          "revolving_utilization",
    "10_risk_segmentation_model.csv":        "risk_segmentation_model",
}


def main() -> None:
    with pd.ExcelWriter(OUT_PATH, engine="openpyxl") as writer:
        for csv_name, sheet_name in SHEET_MAP.items():
            csv_path = CSV_DIR / csv_name
            if not csv_path.exists():
                print(f"  SKIP {csv_name}  (missing)")
                continue
            df = pd.read_csv(csv_path)
            df.to_excel(writer, sheet_name=sheet_name, index=False)
            print(f"  OK   {csv_name:45s}  {len(df):>4} rows -> sheet '{sheet_name}'")

    size_mb = OUT_PATH.stat().st_size / 1e6
    print(f"\nWrote {OUT_PATH}  ({size_mb:.2f} MB)")


if __name__ == "__main__":
    main()
