#!/usr/bin/env bash
set -uo pipefail

VALIDATION_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(cd -- "$VALIDATION_DIR/.." && pwd -P)

# Defaults controlled by command-line switches. contract.env may use them, and
# the operator may also export contract overrides before starting this script.
SEND_SAMPLES=0
RUN_CONFIG_TESTS=0
MODE=static

usage() {
  cat <<'EOF'
Usage: validation/validate.sh [static|runtime|all] [options]

Modes:
  static                 Repository-only validation (default)
  runtime                Live host checks; does not redeploy or stop services
  all                    Static checks followed by runtime checks

Options:
  --project-root PATH    Validate another repository checkout
  --idempotence-log PATH Parse an existing second-run Ansible transcript
  --config-tests         Run native config tests inside existing containers
  --send-samples         Add four mission events and validate their destinations
  -h, --help             Show this help
EOF
}

while (( $# > 0 )); do
  case "$1" in
    static|runtime|all)
      MODE="$1"
      shift
      ;;
    --project-root)
      if (( $# < 2 )); then
        printf 'Missing value for --project-root\n' >&2
        exit 2
      fi
      PROJECT_ROOT=$(cd -- "$2" && pwd -P) || exit 2
      shift 2
      ;;
    --idempotence-log)
      if (( $# < 2 )); then
        printf 'Missing value for --idempotence-log\n' >&2
        exit 2
      fi
      IDEMPOTENCE_EVIDENCE="$2"
      shift 2
      ;;
    --config-tests)
      RUN_CONFIG_TESTS=1
      shift
      ;;
    --send-samples)
      SEND_SAMPLES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Preserve a CLI-supplied evidence path while loading the other contract
# defaults. contract.env itself also respects exported overrides.
CLI_IDEMPOTENCE_EVIDENCE=${IDEMPOTENCE_EVIDENCE-}
# shellcheck source=contract.env
source "$VALIDATION_DIR/contract.env"
if [[ -n "$CLI_IDEMPOTENCE_EVIDENCE" ]]; then
  IDEMPOTENCE_EVIDENCE="$CLI_IDEMPOTENCE_EVIDENCE"
fi

# shellcheck source=lib/report.sh
source "$VALIDATION_DIR/lib/report.sh"
# shellcheck source=checks/static.sh
source "$VALIDATION_DIR/checks/static.sh"
# shellcheck source=checks/runtime.sh
source "$VALIDATION_DIR/checks/runtime.sh"

printf 'Training Lab answer-sheet validation\n'
printf 'Project root: %s\n' "$PROJECT_ROOT"
printf 'Mode: %s\n' "$MODE"

case "$MODE" in
  static)
    run_static_checks
    ;;
  runtime)
    run_runtime_checks
    ;;
  all)
    run_static_checks
    run_runtime_checks
    ;;
esac

if summary; then
  exit 0
fi
exit 1
