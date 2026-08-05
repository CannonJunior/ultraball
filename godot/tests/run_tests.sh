#!/usr/bin/env bash
## Run all headless Godot test scenes and report combined pass/fail counts.
## Usage: bash godot/tests/run_tests.sh   (from repo root)
##        bash run_tests.sh               (from godot/tests/)

set -euo pipefail

GODOT="${GODOT:-godot4}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCENES=(
  "tests/MatchStateTest.tscn"
  "tests/ScoringSystemTest.tscn"
  "tests/SubstitutionSystemTest.tscn"
  "tests/BallSystemTest.tscn"
  "tests/FinalReportShowsTest.tscn"
  "tests/PauseMenuShowsTest.tscn"
)

total_passed=0
total_failed=0
suite_failures=()

for scene in "${SCENES[@]}"; do
  echo "━━━ $scene ━━━"
  set +e
  output=$("$GODOT" --headless --path "$GODOT_ROOT" "$scene" 2>&1)
  exit_code=$?
  set -e
  echo "$output"

  passed=$(echo "$output" | grep -oP '\d+(?= passed)' | tail -1 || echo 0)
  failed=$(echo "$output" | grep -oP '\d+(?= failed)' | tail -1 || echo 0)
  total_passed=$(( total_passed + passed ))
  total_failed=$(( total_failed + failed ))

  if [[ $exit_code -ne 0 ]]; then
    suite_failures+=("$scene")
  fi
  echo ""
done

echo "══════════════════════════════════════"
echo "TOTAL  $total_passed passed, $total_failed failed"
if [[ ${#suite_failures[@]} -gt 0 ]]; then
  echo "FAILED SUITES:"
  for f in "${suite_failures[@]}"; do echo "  $f"; done
  exit 1
fi
echo "All suites passed."
