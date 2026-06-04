#!/bin/bash
set -euo pipefail

# Helper function: Assert positive authorization (expect "yes")
expect_yes() {
  local check="$1"
  local result
  echo "Checking permission (expecting yes): $check"
  
  # Use a subshell to isolate from global set -e/pipefail during the check
  # Temporarily disable pipefail if active to allow capturing 'no' from kubectl (which returns 1)
  result=$(set +o pipefail; eval "$check" 2>/dev/null | tail -n 1 | xargs)
  
  if [ "$result" = "yes" ]; then
    echo "  => yes (Passed)"
  else
    echo "  => FAILED: Expected 'yes', got '$result'"
    exit 1
  fi
}

# Helper function: Assert negative authorization (expect "no" - deny guardrail)
expect_no() {
  local check="$1"
  local result
  echo "Checking guardrail (expecting no): $check"
  
  # Use a subshell to isolate from global set -e/pipefail during the check
  # kubectl auth can-i returns 1 for "no", which triggers set -e/pipefail if not handled
  result=$(set +o pipefail; eval "$check" 2>/dev/null | tail -n 1 | xargs)
  
  if [ "$result" = "no" ]; then
    echo "  => no (Passed)"
  else
    echo "  => FAILED: Expected 'no', got '$result'"
    exit 1
  fi
}