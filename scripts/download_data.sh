#!/usr/bin/env bash
# Download Lending Club 2007-2018 dataset from Kaggle.
#
# Prerequisite: Kaggle API auth set up.
#   1. Go to https://www.kaggle.com/settings → API → Create New API Token
#   2. mkdir -p ~/.kaggle && mv ~/Downloads/kaggle.json ~/.kaggle/ && chmod 600 ~/.kaggle/kaggle.json
#   3. pip install kaggle  (or: conda install -c conda-forge kaggle)
#
# Usage: bash scripts/download_data.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RAW_DIR="$PROJECT_DIR/data/raw"

mkdir -p "$RAW_DIR"
cd "$RAW_DIR"

if ! command -v kaggle &> /dev/null; then
    echo "ERROR: kaggle CLI not found. Install with: pip install kaggle"
    exit 1
fi

echo "Downloading Lending Club 2007-2018 dataset (~600MB compressed)..."
kaggle datasets download -d wordsforthewise/lending-club

echo "Unzipping..."
unzip -o lending-club.zip
rm lending-club.zip

echo ""
echo "Done. Files in data/raw/:"
ls -lh *.csv* 2>/dev/null || ls -lh
