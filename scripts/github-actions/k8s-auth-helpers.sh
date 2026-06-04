#!/bin/bash
set -euo pipefail

# Helper function: Assert positive authorization (expect "yes")
expect_yes() {
  local check="$1"
  local result
  # Redirect stderr and only take the last line of stdout to avoid warnings polluting the check.
  result="$(eval "$check" 2>/dev/null | tail -n 1 | xargs)"
  echo "CHECK (expect yes): $check => $result"
  [ "$result" = "yes" ] || { echo "Authorization check failed (expected yes)."; exit 1; }
}

# Helper function: Assert negative authorization (expect "no" - deny guardrail)
expect_no() {
  local check="$1"
  local result
  # Redirect stderr and only take the last line of stdout to avoid warnings polluting the check.
  result="$(eval "$check" 2>/dev/null | tail -n 1 | xargs)"
  echo "CHECK (expect no): $check => $result"
  [ "$result" = "no" ] || { echo "Authorization check failed (expected no)."; exit 1; }
}