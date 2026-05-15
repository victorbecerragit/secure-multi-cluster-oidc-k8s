#!/bin/bash
set -euo pipefail

# Helper function: Assert positive authorization (expect "yes")
expect_yes() {
  local check="$1"
  local result
  result="$(eval "$check")"
  echo "CHECK (expect yes): $check => $result"
  [ "$result" = "yes" ] || { echo "Authorization check failed (expected yes)."; exit 1; }
}

# Helper function: Assert negative authorization (expect "no" - deny guardrail)
expect_no() {
  local check="$1"
  local result
  result="$(eval "$check")"
  echo "CHECK (expect no): $check => $result"
  [ "$result" = "no" ] || { echo "Authorization check failed (expected no)."; exit 1; }
}