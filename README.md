# Ansible Elastic Stack Training Lab — complete Ansible checkpoint

This answer checkpoint has converted the proven manual lab into seven
independent, Ansible-managed Docker Compose projects on one Linux host. The
manual implementation remains available on `answers/01-manual`, and the first
role transition remains available on `answers/02-first-role`.

The roles manage Elasticsearch, Kibana, Kafka, processing Logstash, port-router Logstash, Zeek Filebeat, and Suricata Filebeat. GitLab remains a separate bootstrap project and is deliberately outside Ansible ownership.

Before deploying, stop the manual projects using the reverse-order instructions
on `answers/01-manual`. Their containers use the same names and ports as the
managed projects under `/var/docker`. Leave the separate GitLab project
running.

## Prerequisites

- a maintained Linux host with Docker Engine and the Compose plugin
- Zeek and Suricata installed as described in [docs/sensor-host-setup.md](docs/sensor-host-setup.md)
- an `ansible` account reachable over SSH at `training-lab.local`
- the hostname and port contract in [docs/reference-contract.md](docs/reference-contract.md)
- Ansible Core and the collections pinned in `requirements.yml`

## Deploy the complete stack

Install the collections, verify the single-host inventory, and run the ordered aggregate playbook. Before Vault is introduced, provide the become credential interactively:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph
ansible all -m ping
ansible-playbook roles-all.yml --ask-become-pass
```

The aggregate playbook prepares shared host paths once, then reconciles services in dependency order. Each component also retains its focused playbook for development and troubleshooting.

Re-run `roles-all.yml --ask-become-pass` without changing the repository and inspect the recap for idempotence. The next checkpoint introduces the plaintext-to-Ansible-Vault progression, and the later CI checkpoint adds protected deployment automation.
