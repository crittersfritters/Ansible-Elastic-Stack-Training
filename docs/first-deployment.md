# First deployment and evidence checklist

This sequence assumes GitLab, Docker, Ansible, SSH, Zeek, and Suricata are
already installed. The training branch contains the supported new-host GitLab
bootstrap; this document starts at the answer implementation boundary.

If you are continuing from the manual checkpoint, stop all seven manual
Compose projects in the documented reverse order before deploying this state.
The managed projects under `/var/docker` reuse their container names and host
ports. Leave the separate GitLab project and `/var/training/gitlab` untouched.

## 1. Prove host prerequisites

Confirm the inventory hostname and application aliases resolve to loopback,
the host SSH service is reachable, sensor logs exist, and required ports are
not occupied by unrelated processes.

```bash
getent hosts training-lab.local elasticsearch.local kafka.local kibana.local
ssh ansible@training-lab.local id
sudo test -d /opt/zeek/logs/current
sudo test -s /var/log/suricata/eve.json
sudo ss -ltnp
```

Zeek records must be newline-delimited JSON. Inspect one complete line instead
of assuming a `.log` suffix implies the required format. Confirm
`vm.max_map_count` can be changed by the Ansible account's intended privilege
policy; the host role sets it to `1048576`.

## 2. Prepare Ansible inputs

Install the pinned collections and create the ignored local Vault working
file:

```bash
ansible-galaxy collection install -r requirements.yml -p .ansible/collections
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
chmod 0600 group_vars/all/vault.yml
${EDITOR:-vi} group_vars/all/vault.yml
```

Populate only the privilege-escalation credential required by this host. Do
not store SSH private keys in inventory or variables. Each initiating account
uses its own default-protected key and verified `known_hosts` entry.

```bash
ansible-inventory --graph
ansible training_lab_hosts -m ansible.builtin.debug \
  -a var=ansible_connection
ansible training_lab_hosts -m ansible.builtin.debug \
  -a var=ansible_user
ansible training_lab_hosts -m ansible.builtin.debug \
  -a var=ansible_port
ansible training_lab_hosts -m ping
ansible training_lab_hosts -b -m command -a 'id -u'
```

The graph must show one host in `training_lab_hosts` and all six service
groups. The targeted debug commands must report `ansible_connection=ssh`,
`ansible_user=ansible`, and `ansible_port=22`. Review `site-config.yml` to
confirm that the inventory does not replace its hostname with `127.0.0.1`
through `ansible_host`.

Do not use `ansible-inventory --host`, `ansible-inventory --list`, or
`ansible-inventory --graph --vars` after secret variables exist. Those forms
can render decrypted host variables, including the become credential, to the
terminal or a CI job log. Plain `--graph` and targeted checks of known
non-secret variables provide the required evidence without dumping hostvars.

## 3. Run static checks before mutation

```bash
ansible-inventory --graph
ansible-playbook --syntax-check roles-all.yml
```

Both commands must exit successfully. The maintained validation harness is
introduced on the final `answer-sheet` branch; this checkpoint intentionally
uses the Ansible-native checks available at this phase.

## 4. Deploy in the reference order

For the complete deployment:

```bash
ansible-playbook roles-all.yml
```

For learning or diagnosis, run the same component boundaries explicitly:

```bash
ansible-playbook roles-system_files_setup.yml
ansible-playbook roles-elasticsearch_nodes.yml
ansible-playbook roles-queue_nodes.yml
ansible-playbook roles-logstash_nodes.yml
ansible-playbook roles-logstash_port-router.yml
ansible-playbook roles-web_servers.yml
ansible-playbook roles-network_sensors.yml
```

Do not run a manual playbook while a GitLab deployment job holds the lab
resource lock.

## 5. Prove runtime behavior

Record the service state and query each local API:

```bash
docker inspect --format \
  '{{.Name}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' \
  elasticsearch kafka kafka-ui kibana logstash_pipeline logstash_port-router \
  filebeat_zeek filebeat_suricata
docker inspect --format \
  '{{.Name}} status={{.State.Status}} exit={{.State.ExitCode}}' \
  kafka-topics-init
curl -fsS 'http://127.0.0.1:9200/_cluster/health?pretty'
curl -fsS 'http://127.0.0.1:5601/api/status'
curl -fsS 'http://127.0.0.1:9600/_node/pipelines?pretty'
curl -fsS 'http://127.0.0.1:9601/_node/pipelines?pretty'
docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 127.0.0.1:9092 --list
```

Then send each mission fixture as one newline-delimited record to TCP/4444:

```bash
for sample_file in samples/mission/*.log; do
  while IFS= read -r sample_record; do
    printf '%s\n' "$sample_record" | nc -w 3 127.0.0.1 4444
  done < "$sample_file"
done
unset sample_file sample_record
```

Use Kibana or the Elasticsearch search API to compare the indexed documents
with `samples/mission/expected-outcomes.yml`. The final `answer-sheet` branch
adds an automated runtime validator for the same contract.

Also generate fresh network traffic and record one new Zeek and one new
Suricata document. A fixture already present from an earlier run is not proof
that the current collector path works.

Manual observations should include:

- GitLab remains healthy and its Compose project is unchanged;
- all unauthenticated listeners are loopback-only;
- `kafka-topics-init` created any missing topics successfully;
- all three processing pipelines and the port-router pipeline are available;
- each backing index has its intended template and one write alias;
- all four Kibana data views use `@timestamp`; and
- valid, unmatched, and invalid-date mission records meet
  `samples/mission/expected-outcomes.yml`.

## 6. Prove idempotence and drift correction

Run the same full playbook a second time and retain its recap:

```bash
mkdir -p .evidence
set -o pipefail
ansible-playbook roles-all.yml \
  | tee .evidence/ansible-idempotence.txt
```

Every second-run host recap must report `changed=0`, `unreachable=0`, and
`failed=0`. Then alter one harmless managed file in `/var/docker`, run the
owning playbook, and show that Ansible repairs it and activates the repaired
configuration without touching GitLab.

## 7. Complete the security transition

Only after the plaintext variable flow works, encrypt and deliberately track
the Vault file:

```bash
(
  set -euo pipefail
  set +x
  ansible-vault encrypt group_vars/all/vault.yml
  vault_header=
  IFS= read -r vault_header < group_vars/all/vault.yml || true
  if [[ "$vault_header" == '$ANSIBLE_VAULT;'* ]]; then
    git add -f -- group_vars/all/vault.yml
  else
    printf '%s\n' 'Refusing to stage a non-Vault credential file.' >&2
    exit 1
  fi
)
```

Test one correct and one incorrect Vault password. Configure the protected
GitLab variable and runner SSH boundary described in the
[identity and Vault guide](identity-and-vault.md) before enabling mutating CI
jobs.
