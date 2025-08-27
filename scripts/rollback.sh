#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
git reset --hard last-good
bash scripts/deploy.sh
