#!/bin/bash
# Compare current processes against the baseline from when f13/AeroSpace was working.
# Run this when f13 stops working to find what's new.
#
# Usage: ~/.config/aerospace/debug-f13.sh

BASELINE=~/.config/aerospace/baseline-processes.txt

if [ ! -f "$BASELINE" ]; then
  echo "No baseline file found at $BASELINE"
  echo "Capture one when things are working:"
  echo "  ps -e -o comm= | sed 's|.*/||' | sort -u | grep -v '^com\\.apple\\.' > $BASELINE"
  exit 1
fi

echo "=== New processes (not in baseline) ==="
comm -23 <(ps -e -o comm= | sed 's|.*/||' | sort -u | grep -v '^com\.apple\.') "$BASELINE"

echo ""
echo "=== Missing processes (were in baseline) ==="
comm -13 <(ps -e -o comm= | sed 's|.*/||' | sort -u | grep -v '^com\.apple\.') "$BASELINE"
