# Ansible Elastic Stack Training Lab — first Ansible role

This checkpoint begins the transition from the proven manual lab to an
Ansible-managed one. The complete manual implementation remains available on
`answers/01-manual`.

Only host preparation and Elasticsearch have been converted here. This small first step exposes the inventory, variables, templates, shared tasks, and idempotent deployment pattern before it is repeated across the other six projects.

## Transition boundary

Stop all seven manual Compose projects in the reverse-order sequence documented
on `answers/01-manual` before checking out and deploying this state. The
Ansible projects reuse the same container names and host ports from new project
directories under `/var/docker`; they cannot safely start beside the earlier
manual containers.

GitLab is separate. Leave the `gitlab` container running and do not remove or
alter `/var/training/gitlab`.

## Prerequisites

- a maintained Linux host with Docker Engine and the Compose plugin
- a dedicated `ansible` account reachable over SSH at `training-lab.local`
- Ansible Core and the collections pinned in `requirements.yml`
- the hostname contract in [docs/reference-contract.md](docs/reference-contract.md)

## Deploy the first managed project

Install the collections, verify the inventory, prepare the host, and deploy Elasticsearch. Before the Vault checkpoint, supply the passworded account's become credential interactively:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-inventory --graph
ansible all -m ping
ansible-playbook roles-system_files_setup.yml --ask-become-pass
ansible-playbook roles-elasticsearch_nodes.yml --ask-become-pass
```

Inspect `/var/docker/elasticsearch` after the run. Re-run both playbooks and
confirm that a converged host reports no changes. The
`answers/03-full-ansible` branch applies the same design to Kafka, Kibana, both
Logstash projects, and both Filebeat projects.
