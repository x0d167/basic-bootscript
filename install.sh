#!/usr/bin/env bash
set -euo pipefail

# Initialize logging
LOG_DIR="$HOME/.local/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bootstrap-$(date +%F_%H-%M-%S).log"
export LOG_FILE

# Package List
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/src" &>/dev/null && pwd)"
PKG_LIST="$SCRIPT_DIR/packagelist.txt"
export PKG_LIST

# Keep sudo alive
sudo -v
( while true; do sudo -n true; sleep 60; done ) & 
KEEPALIVE_PID=$!
trap 'kill $KEEPALIVE_PID' EXIT

# Start logging
echo "Bootstrap started at $(date)" | tee -a "$LOG_FILE"


# Execute staging
$SCRIPT_DIR/000-staging.sh

# Execute package installation
$SCRIPT_DIR/001-package.sh

echo "Bootstrap completed at $(date)" | tee -a "$LOG_FILE"
