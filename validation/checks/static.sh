#!/usr/bin/env bash

check_required_paths() {
  section "Required answer-sheet files"
  local relative missing=0
  while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    if [[ -e "$PROJECT_ROOT/$relative" ]]; then
      pass "$relative exists"
    else
      fail "$relative is missing"
      missing=$((missing + 1))
    fi
  done <<< "$REQUIRED_PATHS"

  if (( missing == 0 )); then
    note "All required reference files are present."
  fi
}

check_yaml_syntax() {
  section "YAML syntax"
  if ! have_command python3; then
    skip "Python 3 is unavailable; YAML syntax was not parsed"
    return
  fi
  if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    skip "PyYAML is unavailable; install it to enable repository-wide YAML parsing"
    return
  fi

  local file output found=0
  while IFS= read -r -d '' file; do
    found=1
    if [[ "${file#"$PROJECT_ROOT/"}" == "group_vars/all/vault.yml" ]]; then
      if IFS= read -r first_line < "$file" \
        && [[ "$first_line" == '$ANSIBLE_VAULT;'* ]]; then
        pass "Ansible Vault payload detected: ${file#"$PROJECT_ROOT/"}"
      else
        skip "Secret-bearing plaintext YAML is left to secret-silent Ansible validation: ${file#"$PROJECT_ROOT/"}"
      fi
      continue
    fi
    if IFS= read -r first_line < "$file" && [[ "$first_line" == '$ANSIBLE_VAULT;'* ]]; then
      pass "Ansible Vault payload detected: ${file#"$PROJECT_ROOT/"}"
      continue
    fi
    if output=$(python3 - "$file" 2>&1 <<'PY'
import pathlib
import sys
import yaml

path = pathlib.Path(sys.argv[1])
with path.open("r", encoding="utf-8") as stream:
    list(yaml.compose_all(stream))
PY
    ); then
      pass "YAML parses: ${file#"$PROJECT_ROOT/"}"
    else
      fail "YAML does not parse: ${file#"$PROJECT_ROOT/"}"
      show_command_failure "$output"
    fi
  done < <(
    find "$PROJECT_ROOT" \
      -type d \( \
        -name '.git' -o -name '.ansible' -o \
        -name '.cache' -o -name '.venv' \
      \) -prune -o \
      -path "$PROJECT_ROOT/validation" -prune -o \
      -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 | sort -z
  )
  if (( found == 0 )); then
    fail "No YAML files were found"
  fi
}

check_reference_templates() {
  section "Rendered Compose and Filebeat templates"
  if ! have_command python3 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
    skip "Python 3 with PyYAML is unavailable; Compose templates were not rendered"
    return
  fi

  local temp_dir output file compose_count=0 filebeat_count=0
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/training-lab-compose.XXXXXX") || {
    fail "Unable to create a temporary directory for rendered Compose files"
    return
  }
  if output=$(python3 "$VALIDATION_DIR/lib/render_compose.py" "$PROJECT_ROOT" "$temp_dir" 2>&1); then
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      case "${file##*/}" in
        compose-*)
          compose_count=$((compose_count + 1))
          pass "Compose template renders as YAML: ${file##*/}"
          ;;
        filebeat-*)
          filebeat_count=$((filebeat_count + 1))
          pass "Filebeat template renders as YAML: ${file##*/}"
          ;;
        *)
          fail "Renderer produced an unexpected file: ${file##*/}"
          ;;
      esac
    done <<< "$output"
  else
    fail "One or more Compose templates could not be rendered"
    show_command_failure "$output"
    rm -rf -- "$temp_dir"
    return
  fi

  if (( compose_count != 7 )); then
    fail "Expected seven rendered Compose templates; renderer produced $compose_count"
  fi
  if (( filebeat_count != 2 )); then
    fail "Expected two rendered Filebeat templates; renderer produced $filebeat_count"
  fi

  set_docker_command
  if have_command "${DOCKER_PARTS[0]}" && docker_compose_available; then
    for file in "$temp_dir"/compose-*.yml; do
      if output=$("${DOCKER_PARTS[@]}" compose -f "$file" config --quiet 2>&1); then
        pass "Docker Compose accepts rendered template: ${file##*/}"
      else
        fail "Docker Compose rejects rendered template: ${file##*/}"
        show_command_failure "$output"
      fi
    done
  else
    skip "Docker Compose is unavailable; rendered YAML was not Compose-validated"
  fi
  rm -rf -- "$temp_dir"
}

check_sensor_collector_templates() {
  section "Sensor collector template contract"
  if ! have_command python3 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
    skip "Python 3 with PyYAML is unavailable; sensor template branches were not evaluated"
    return
  fi

  local output
  if output=$(python3 \
    "$VALIDATION_DIR/lib/check_sensor_templates.py" \
    "$PROJECT_ROOT" 2>&1); then
    pass "Sensor templates preserve canonical read-only sources and SELinux portability"
    note "$output"
  else
    fail "Sensor template contract is incorrect"
    show_command_failure "$output"
  fi
}

check_loopback_listener_classifier() {
  section "Loopback listener classification"

  local port=9443 address failures=0
  local -a accepted=(
    "127.0.0.1:${port}"
    "[::1]:${port}"
    "[::ffff:127.0.0.1]:${port}"
  )
  local -a rejected=(
    "0.0.0.0:${port}"
    "192.0.2.10:${port}"
    "*:${port}"
    "[::]:${port}"
    "[::ffff:192.0.2.10]:${port}"
  )

  for address in "${accepted[@]}"; do
    if ! is_expected_loopback_listener "$address" "$port"; then
      fail "Expected loopback endpoint was rejected: $address"
      failures=$((failures + 1))
    fi
  done
  for address in "${rejected[@]}"; do
    if is_expected_loopback_listener "$address" "$port"; then
      fail "Non-loopback endpoint was accepted: $address"
      failures=$((failures + 1))
    fi
  done

  if (( failures == 0 )); then
    pass "IPv4, IPv6, and IPv4-mapped loopback endpoints are classified safely"
  fi
}

set_docker_command() {
  read -r -a DOCKER_PARTS <<< "$DOCKER_COMMAND"
  if (( ${#DOCKER_PARTS[@]} == 0 )); then
    DOCKER_PARTS=(docker)
  fi
}

docker_compose_available() {
  "${DOCKER_PARTS[@]}" compose version >/dev/null 2>&1
}

check_concrete_compose_files() {
  section "Concrete Compose configuration"
  set_docker_command
  if ! have_command "${DOCKER_PARTS[0]}"; then
    skip "${DOCKER_PARTS[0]} is unavailable; Compose rendering checks were skipped"
    return
  fi
  if ! docker_compose_available; then
    skip "The Docker Compose plugin is unavailable; Compose rendering checks were skipped"
    return
  fi

  local file output found=0
  while IFS= read -r -d '' file; do
    found=1
    if output=$("${DOCKER_PARTS[@]}" compose -f "$file" config --quiet 2>&1); then
      pass "Compose renders: ${file#"$PROJECT_ROOT/"}"
    else
      fail "Compose does not render: ${file#"$PROJECT_ROOT/"}"
      show_command_failure "$output"
    fi
  done < <(
    find "$PROJECT_ROOT" \
      -type d \( \
        -name '.git' -o -name '.ansible' -o \
        -name '.cache' -o -name '.venv' \
      \) -prune -o \
      -path "$PROJECT_ROOT/validation" -prune -o \
      -type f \( \
        -name 'compose.yml' -o -name 'compose.yaml' -o \
        -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
      \) -print0 | sort -z
  )

  if (( found == 0 )); then
    skip "No concrete Compose files are committed; templates are checked after deployment by the runtime suite"
  fi
}

check_gitlab_bootstrap_contract() {
  section "GitLab bootstrap contract"
  local compose="$PROJECT_ROOT/bootstrap/gitlab/docker-compose.yml"

  if [[ ! -f "$compose" ]]; then
    fail "GitLab bootstrap Compose file is missing"
    return
  fi
  if ! have_command python3 || ! python3 -c 'import yaml' >/dev/null 2>&1; then
    skip "Python 3 with PyYAML is unavailable; the GitLab Compose contract was not evaluated"
    return
  fi

  local output
  if output=$(python3 - "$compose" <<'PY'
import pathlib
import sys
from collections import Counter

import yaml

path = pathlib.Path(sys.argv[1])
document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
problems = []

if document.get("name") != "gitlab":
    problems.append("top-level Compose project name must be 'gitlab'")

services = document.get("services") or {}
if set(services) != {"gitlab"}:
    problems.append(f"services must contain only 'gitlab'; got {sorted(services)!r}")
service = services.get("gitlab") or {}

expected_scalars = {
    "image": "gitlab/gitlab-ee:19.4.1-ee.0",
    "container_name": "gitlab",
    "hostname": "gitlab.local",
    "restart": "unless-stopped",
    "shm_size": "256m",
}
for field, expected in expected_scalars.items():
    actual = service.get(field)
    if str(actual) != expected:
        problems.append(f"gitlab.{field} must be {expected!r}; got {actual!r}")

environment = service.get("environment") or {}
if not isinstance(environment, dict):
    problems.append("gitlab.environment must use mapping syntax")
    omnibus = ""
else:
    omnibus = environment.get("GITLAB_OMNIBUS_CONFIG", "")
required_omnibus_lines = Counter({
    "external_url 'http://gitlab.local:8929'",
    "gitlab_rails['gitlab_shell_ssh_port'] = 2424",
})
actual_omnibus_lines = Counter(
    statement.strip()
    for line in str(omnibus).splitlines()
    for statement in line.split(";")
    if statement.strip()
)
if actual_omnibus_lines != required_omnibus_lines:
    missing_omnibus = required_omnibus_lines - actual_omnibus_lines
    unexpected_omnibus = actual_omnibus_lines - required_omnibus_lines
    if missing_omnibus:
        problems.append(
            "GITLAB_OMNIBUS_CONFIG is missing: "
            + ", ".join(sorted(missing_omnibus.elements()))
        )
    if unexpected_omnibus:
        problems.append(
            "GITLAB_OMNIBUS_CONFIG has unexpected settings: "
            + ", ".join(sorted(unexpected_omnibus.elements()))
        )

expected_ports = Counter({
    "127.0.0.1:8929:8929",
    "127.0.0.1:443:443",
    "127.0.0.1:2424:22",
})
actual_ports = Counter(str(value) for value in (service.get("ports") or []))
if actual_ports != expected_ports:
    problems.append(
        f"gitlab.ports must be exactly {sorted(expected_ports.elements())!r}; "
        f"got {sorted(actual_ports.elements())!r}"
    )

expected_volumes = Counter({
    "/var/training/gitlab/config:/etc/gitlab:Z",
    "/var/training/gitlab/logs:/var/log/gitlab:Z",
    "/var/training/gitlab/data:/var/opt/gitlab:Z",
})
actual_volumes = Counter(str(value) for value in (service.get("volumes") or []))
if actual_volumes != expected_volumes:
    problems.append(
        f"gitlab.volumes must be exactly {sorted(expected_volumes.elements())!r}; "
        f"got {sorted(actual_volumes.elements())!r}"
    )

if problems:
    print("\n".join(problems))
    raise SystemExit(1)
PY
  ); then
    pass "GitLab bootstrap Compose implements the pinned course contract"
  else
    fail "GitLab bootstrap Compose diverges from the pinned course contract"
    show_command_failure "$output"
  fi
}

check_ansible_inventory() {
  section "Ansible inventory"
  local inventory="$PROJECT_ROOT/$INVENTORY_FILE"
  if [[ ! -f "$inventory" ]]; then
    fail "$INVENTORY_FILE is unavailable for inventory validation"
    return
  fi
  if ! have_command ansible-inventory; then
    skip "ansible-inventory is unavailable; inventory semantics were not evaluated"
    return
  fi
  if ! have_command python3; then
    skip "Python 3 is unavailable; Ansible inventory JSON could not be evaluated"
    return
  fi

  local -a inventory_groups
  local output
  read -r -a inventory_groups <<< "$INVENTORY_GROUPS"

  if output=$(
    set -o pipefail

    ansible-inventory \
      -i "$inventory" \
      --list \
      2>/dev/null |
      python3 \
        "$VALIDATION_DIR/lib/check_inventory.py" \
        "$INVENTORY_HOST" \
        "${inventory_groups[@]}"
  ); then
    pass "Ansible parses $INVENTORY_FILE"
    pass "The host-preparation group and all six service groups contain only $INVENTORY_HOST"
  else
    fail "Inventory parsing or the one-host localhost contract failed"
    show_command_failure "$output"
    note "Use ansible-inventory --graph without --vars for secret-safe diagnosis."
  fi
}

check_ansible_syntax() {
  section "Ansible playbook syntax"
  if ! have_command ansible-playbook; then
    skip "ansible-playbook is unavailable; syntax-check was skipped"
    return
  fi
  local inventory="$PROJECT_ROOT/$INVENTORY_FILE"
  local playbook="$PROJECT_ROOT/$MAIN_PLAYBOOK"
  if [[ ! -f "$inventory" || ! -f "$playbook" ]]; then
    fail "Inventory or main playbook is missing; Ansible syntax-check cannot run"
    return
  fi

  if (cd "$PROJECT_ROOT" && \
    ANSIBLE_NOCOWS=1 ansible-playbook \
      -i "$inventory" \
      --syntax-check \
      "$playbook" \
      >/dev/null 2>&1); then
    pass "Ansible syntax-check passes for $MAIN_PLAYBOOK"
  else
    fail "Ansible syntax-check fails for $MAIN_PLAYBOOK"
    note "Raw Ansible diagnostics are suppressed because resolved variables may contain secrets."
  fi
}

check_configuration_assets() {
  section "Configuration assets"
  local port_router="$PROJECT_ROOT/roles/port_router/files/pipeline/logstash_port-router.conf"
  local grok_consumer="$PROJECT_ROOT/roles/logstash_pipeline/files/pipeline/grok_pipeline.conf"
  local zeek_filebeat="$PROJECT_ROOT/roles/filebeat_zeek/templates/filebeat.yml.j2"
  local suricata_filebeat="$PROJECT_ROOT/roles/filebeat_suricata/templates/filebeat.yml.j2"
  local ci_file="$PROJECT_ROOT/.gitlab-ci.yml"
  local child_ci_file="$PROJECT_ROOT/.gitlab/deploy.yml"
  local vault_password_client="$PROJECT_ROOT/vault_password.sh"

  if [[ -s "$port_router" ]] && grep -q 'grok[[:space:]]*{' "$port_router"; then
    pass "Port-router configuration contains Grok parsing"
  else
    fail "Port-router Grok configuration is absent or empty"
  fi
  if grep -q 'codec[[:space:]]*=>[[:space:]]*line' "$port_router"; then
    pass "Port-router TCP input uses newline-delimited framing"
  else
    fail "Port-router TCP input does not use the line codec"
  fi
  if grep -R -E -q 'bootstrap_servers[[:space:]]*=>[[:space:]]*\[' \
    "$PROJECT_ROOT/roles/logstash_pipeline/files/pipeline" \
    "$PROJECT_ROOT/roles/port_router/files/pipeline"; then
    fail "A Logstash Kafka plugin uses an invalid array-valued bootstrap_servers setting"
  else
    pass "Logstash Kafka bootstrap_servers settings use the required string form"
  fi
  if [[ -s "$grok_consumer" ]] && grep -q 'kafka[[:space:]]*{' "$grok_consumer"; then
    pass "Mission consumer configuration contains a Kafka input"
  else
    fail "Mission Kafka consumer configuration is absent or empty"
  fi
  if [[ -s "$zeek_filebeat" ]]; then
    pass "Zeek Filebeat configuration is nonempty"
  else
    fail "Zeek Filebeat configuration is absent or empty"
  fi
  if [[ -s "$suricata_filebeat" ]]; then
    pass "Suricata Filebeat configuration is nonempty"
  else
    fail "Suricata Filebeat configuration is absent or empty"
  fi
  if [[ -s "$ci_file" ]]; then
    pass "Answer-sheet GitLab pipeline reference is nonempty"
  else
    fail "GitLab pipeline reference is absent or empty"
  fi
  if [[ -s "$child_ci_file" ]] \
    && grep -q 'training-lab-local' "$child_ci_file" \
    && grep -q 'CI_COMMIT_REF_PROTECTED' "$ci_file"; then
    pass "GitLab deployment requires the intended runner and protected refs"
  else
    fail "GitLab deployment runner or protected-ref guard is missing"
  fi
  if have_command python3 && python3 -c 'import yaml' >/dev/null 2>&1; then
    local ci_contract_output
    if ci_contract_output=$(python3 \
      "$VALIDATION_DIR/lib/check_ci_contract.py" \
      "$ci_file" \
      "$child_ci_file" 2>&1); then
      pass "CI verifies Vault input and maps the Docker SELinux contract to its three callers"
    else
      fail "CI Vault verification or Docker SELinux change mapping is incorrect"
      show_command_failure "$ci_contract_output"
    fi
  else
    skip "Python 3 with PyYAML is unavailable; CI semantics were not evaluated"
  fi
  if [[ -x "$vault_password_client" ]]; then
    pass "The Vault password client is executable"
  else
    fail "vault_password.sh is missing or is not executable"
  fi
  if grep -Eq '^[[:space:]]*host_key_checking[[:space:]]*=[[:space:]]*[Ff]alse' \
    "$PROJECT_ROOT/ansible.cfg"; then
    fail "Ansible host-key checking is disabled"
  else
    pass "Ansible does not disable SSH host-key checking"
  fi
  local sample missing_sample=0
  for sample in pan-simple pan-full unmatched date-failure; do
    if [[ -s "$PROJECT_ROOT/samples/mission/$sample.log" ]]; then
      pass "Mission sample is present: $sample.log"
    else
      fail "Mission sample is missing: samples/mission/$sample.log"
      missing_sample=1
    fi
  done
  if (( missing_sample == 0 )) && [[ -s "$PROJECT_ROOT/samples/mission/expected-outcomes.yml" ]]; then
    pass "Canonical mission outcome assertions are present"
  elif [[ ! -s "$PROJECT_ROOT/samples/mission/expected-outcomes.yml" ]]; then
    fail "Canonical mission outcome assertions are missing"
  fi
}

check_documentation_integrity() {
  section "Documentation integrity"
  if ! have_command python3; then
    skip "Python 3 is unavailable; local Markdown links were not checked"
    return
  fi

  local output
  if output=$(python3 - "$PROJECT_ROOT" <<'PY'
import os
import pathlib
import re
import sys
import urllib.parse

root = pathlib.Path(sys.argv[1]).resolve()
problems = []
link_pattern = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
excluded_directories = {".git", ".ansible", ".cache", ".venv"}
documents = []
for directory, directory_names, file_names in os.walk(root):
    directory_names[:] = sorted(
        name for name in directory_names if name not in excluded_directories
    )
    documents.extend(
        pathlib.Path(directory, name)
        for name in sorted(file_names)
        if name.endswith(".md")
    )

for document in sorted(documents):
    text = document.read_text(encoding="utf-8")
    for raw in link_pattern.findall(text):
        target = raw.strip().split(maxsplit=1)[0].strip("<>")
        if not target or target.startswith(("#", "http://", "https://", "mailto:")):
            continue
        path_text = urllib.parse.unquote(target.split("#", 1)[0])
        destination = (document.parent / path_text).resolve()
        try:
            destination.relative_to(root)
        except ValueError:
            problems.append(f"{document.relative_to(root)}: link escapes repository: {target}")
            continue
        if not destination.exists():
            problems.append(f"{document.relative_to(root)}: missing target: {target}")

if problems:
    print("\n".join(problems))
    raise SystemExit(1)
PY
  ); then
    pass "All local Markdown links resolve inside the repository"
  else
    fail "One or more local Markdown links are broken"
    show_command_failure "$output"
  fi
}

check_idempotence_evidence() {
  section "Ansible idempotence evidence"
  local evidence
  evidence=$(absolute_from_project "$IDEMPOTENCE_EVIDENCE")
  if [[ ! -f "$evidence" ]]; then
    skip "No second-run transcript at ${evidence#"$PROJECT_ROOT/"}; see validation/README.md"
    return
  fi

  local line found=0 bad=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[^[:space:]].*ok=[0-9]+[[:space:]]+changed=([0-9]+)[[:space:]]+unreachable=([0-9]+)[[:space:]]+failed=([0-9]+) ]]; then
      found=1
      if [[ "${BASH_REMATCH[1]}" == 0 && "${BASH_REMATCH[2]}" == 0 && "${BASH_REMATCH[3]}" == 0 ]]; then
        pass "Idempotent recap: $line"
      else
        fail "Non-idempotent or unsuccessful recap: $line"
        bad=1
      fi
    fi
  done < "$evidence"

  if (( found == 0 )); then
    fail "The idempotence transcript contains no recognizable PLAY RECAP host lines"
  elif (( bad == 0 )); then
    note "Every captured second-run host reports changed=0, unreachable=0, failed=0."
  fi
}

run_static_checks() {
  check_required_paths
  check_yaml_syntax
  check_reference_templates
  check_sensor_collector_templates
  check_loopback_listener_classifier
  check_concrete_compose_files
  check_gitlab_bootstrap_contract
  check_ansible_inventory
  check_ansible_syntax
  check_configuration_assets
  check_documentation_integrity
  check_idempotence_evidence
}
