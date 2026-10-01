#!/usr/bin/env bash
set -euo pipefail

: "${ANSIBLE_VAULT_PASSWORD:?ANSIBLE_VAULT_PASSWORD must be set}"
printf '%s\n' "$ANSIBLE_VAULT_PASSWORD"
