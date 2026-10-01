#!/usr/bin/env bash

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '[PASS] %s\n' "$*"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '[FAIL] %s\n' "$*" >&2
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf '[WARN] %s\n' "$*" >&2
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf '[SKIP] %s\n' "$*"
}

note() {
  printf '       %s\n' "$*"
}

section() {
  printf '\n== %s ==\n' "$*"
}

show_command_failure() {
  local output="$1"
  if [[ -n "$output" ]]; then
    while IFS= read -r line; do
      printf '       %s\n' "$line" >&2
    done <<< "$output"
  fi
}

summary() {
  printf '\nSummary: %d passed, %d failed, %d warnings, %d skipped\n' \
    "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT" "$SKIP_COUNT"
  (( FAIL_COUNT == 0 ))
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

absolute_from_project() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PROJECT_ROOT" "$path"
  fi
}

