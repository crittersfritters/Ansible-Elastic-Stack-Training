# Bounded lab resets

Reset only the project whose state you intend to discard. Never use broad
commands such as `docker system prune`, remove every container on the host, or
operate on `/var/training/gitlab`. GitLab and Training Lab share one Docker
daemon but not one lifecycle.

## Reconcile configuration without deleting data

Run the owning playbook. It restores managed files and applies the required
project recreation or restart:

```bash
ansible-playbook roles-elasticsearch_nodes.yml
ansible-playbook roles-queue_nodes.yml
ansible-playbook roles-logstash_nodes.yml
ansible-playbook roles-logstash_port-router.yml
ansible-playbook roles-web_servers.yml
ansible-playbook roles-network_sensors.yml
```

Use `roles-all.yml` when the owning boundary is unclear. This does not delete
the bind-mounted Elasticsearch, Kafka, Kibana, or Filebeat state.

## Reset one Filebeat registry

This causes that collector to treat visible source files as unseen, so expect
duplicate events. Stop only the selected Compose project, move its data aside,
create a replacement directory, and redeploy:

```bash
sudo docker compose -f /var/docker/filebeat_zeek/docker-compose.yml down
sudo mv /var/docker/filebeat_zeek/data \
  /var/docker/filebeat_zeek/data.before-reset
sudo install -d -m 0750 -o root -g root /var/docker/filebeat_zeek/data
ansible-playbook roles-network_sensors.yml
```

Use a unique backup name if `data.before-reset` already exists. Restore or
remove the backup only after verifying the outcome.

## Reset Kafka state

Kafka's data directory contains broker metadata, topics, messages, and
consumer offsets. Resetting it is intentionally disruptive to all three data
paths. Stop only Kafka, move the exact data directory to a recoverable backup,
and let the role recreate topics:

```bash
sudo docker compose -f /var/docker/kafka/docker-compose.yml down
sudo mv /var/docker/kafka/data /var/docker/kafka/data.before-reset
sudo install -d -m 0770 -o 1000 -g 0 /var/docker/kafka/data
ansible-playbook roles-queue_nodes.yml
ansible-playbook roles-logstash_nodes.yml
ansible-playbook roles-logstash_port-router.yml
ansible-playbook roles-network_sensors.yml
```

Do not change the KRaft cluster ID while reusing old Kafka data.

## Reset Elasticsearch state

This removes every course document, mapping, backing index, and alias from the
active cluster. Kibana data views may persist in Kibana but temporarily point
at missing indices. Stop only Elasticsearch and move its exact data directory:

```bash
sudo docker compose -f /var/docker/elasticsearch/docker-compose.yml down
sudo mv /var/docker/elasticsearch/data \
  /var/docker/elasticsearch/data.before-reset
sudo install -d -m 0770 -o 1000 -g 0 /var/docker/elasticsearch/data
ansible-playbook roles-elasticsearch_nodes.yml
ansible-playbook roles-logstash_nodes.yml
ansible-playbook roles-web_servers.yml
```

After either state reset, rerun `bash validation/validate.sh all` and generate
fresh Zeek, Suricata, and mission evidence. A successful container start alone
does not prove the restored data paths.
