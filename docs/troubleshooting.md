# Troubleshooting by boundary

Start at the last boundary known to work. A running container proves only that
its process has not exited; it does not prove name resolution, readiness,
topics, parsing, indexing, aliases, or data views.

| Symptom | Investigate first |
|---|---|
| Ansible host unreachable | `/etc/hosts`, host SSH, account key, file modes, `known_hosts` |
| SSH succeeds; become fails | `ansible` privilege policy and Vault value |
| Ansible warns about junk after module JSON | Fedora PAM/systemd OSC 3008 output; task result, recap, and postcondition |
| Manual play works; CI fails | runner tag/protection, service-account PATH/home/key, protected variable |
| Elasticsearch exits early | `vm.max_map_count`, data ownership, container logs |
| Kafka client connects then fails | advertised listener and container alias resolution |
| Topic is empty | Filebeat source path, registry, JSON decoding, output, topic spelling |
| Topic has data; index does not | processing pipeline health, consumer group, timestamp conversion, output alias |
| Filebeat is healthy; source remains empty | canonical source path, exact bind mounts, registry, and byte-level access inside the collector |
| Container label is empty or `spc_t` | Docker SELinux integration and recreation from the owning Compose project |
| Suricata read causes an AVC | dedicated log-reader process type and a plain read-only mount; preserve the native log label |
| Mission record is unparsed | exact source line, parser order, anchors, Grok tags, Date failure |
| Index has data; Kibana does not | data-view title, time field, time range, source timestamp |
| Changed configuration has no effect | owning role, rendered file, container recreation/restart |

## SSH and Ansible

```bash
getent ahostsv4 training-lab.local
ssh -vv ansible@training-lab.local true
ansible-inventory --graph
ansible training_lab_hosts -m ansible.builtin.debug \
  -a var=ansible_connection
ansible training_lab_hosts -m ansible.builtin.debug \
  -a var=ansible_user
ansible training_lab_hosts -m ansible.builtin.debug \
  -a var=ansible_port
ansible training_lab_hosts -m ping -vv
```

Do not use `ansible-inventory --host`, `ansible-inventory --list`, or
`ansible-inventory --graph --vars` after secret variables exist. Those forms
can print decrypted host variables, including the become credential. Use plain
`--graph` for membership and request only known non-secret values when
diagnosing connection settings.

Do not fix a host-key error with `host_key_checking=False`. Verify the current
host fingerprint, then deliberately repair the initiating account's
`known_hosts` entry if the key legitimately changed.

On Fedora, a successful become operation can cause PAM or systemd to append an
OSC 3008 terminal-context marker. Ansible may describe that trailing marker as
junk after the module's JSON data. It is benign only when the affected task
reports success, the play recap reports `failed=0`, and a direct check confirms
the intended state. Do not change sudo or PAM policy, or disable fingerprint
authentication, solely to remove this warning. If the task failed or the
trailing output is not the expected OSC marker, continue investigating it as a
real module or privilege-escalation failure.

## Rendered projects and containers

```bash
for project in \
  elasticsearch kibana kafka logstash_pipeline logstash_port-router \
  filebeat_zeek filebeat_suricata; do
  sudo docker compose -f "/var/docker/$project/docker-compose.yml" config --quiet
done

sudo docker ps -a --format 'table {{.Names}}\t{{.Status}}'
```

Use the exact owning logs next:

```bash
sudo docker logs --tail 200 elasticsearch
sudo docker logs --tail 200 kafka
sudo docker logs --tail 200 logstash_pipeline
sudo docker logs --tail 200 logstash_port-router
sudo docker logs --tail 200 filebeat_zeek
sudo docker logs --tail 200 filebeat_suricata
```

## Kafka boundary

```bash
sudo docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server 127.0.0.1:9092 --list
sudo docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server 127.0.0.1:9092 --all-groups --describe
```

Test `getent hosts kafka.local` inside a consuming container. Host-networking
does not copy the host's hosts file into the container. A successful bootstrap
connection followed by failures often means the broker advertised a name the
client cannot resolve.

## Logstash and Filebeat configuration

Use the validation harness to run native checks without sharing the active
Logstash `path.data`:

```bash
bash validation/validate.sh runtime --config-tests
```

For Zeek, inspect a source line and confirm it is valid JSON. If Filebeat is
healthy but no small fixture is ingested, inspect the filestream fingerprint
configuration and registry state. The reference uses a 64-byte fingerprint so
small training records are eligible.

Resolve the Zeek paths in the running collector and compare them with its
mounts. If `current` was administratively retargeted or `SpoolDir` changed,
rerun the sensor role so the external canonical mount and Filebeat input are
regenerated:

```bash
docker exec filebeat_zeek \
  readlink --canonicalize-existing -- /opt/zeek/logs/current
docker inspect --format '{{json .Mounts}}' filebeat_zeek
```

For a Suricata denial, inspect the effective process label, security option,
mount mode, and source label. The intended correction is the narrow
`container_logreader_t` process type with `/var/log/suricata` mounted plain
read-only. Do not use `audit2allow`, disable enforcement, add `:z`/`:Z`, or
relabel the host log tree as `container_file_t` for this known case.

Container health tests prove configuration parsing and Kafka reachability;
they do not prove a source file can be opened. The runtime validator therefore
byte-reads the actual Zeek and Suricata sources from their corresponding
collectors.

## Elasticsearch and Kibana

```bash
curl -fsS 'http://127.0.0.1:9200/_cluster/health?pretty'
curl -fsS 'http://127.0.0.1:9200/_cat/indices?v'
curl -fsS 'http://127.0.0.1:9200/_cat/aliases?v'
curl -fsS 'http://127.0.0.1:9200/_index_template/training-lab-*?pretty'
curl -fsS 'http://127.0.0.1:5601/api/status'
```

Templates affect index creation; correcting a template does not rewrite an
existing backing index's mappings. Compare the live mapping with the template
before resetting data. Kibana searches by the document's `@timestamp`; widen
the time range for the supplied historical fixtures.

## Mission record tracing

Send exactly one source line, then search its preserved `event.original` in the
declared alias. Check `_parser.id`, `_parser.version`, `event.created`, and
`@timestamp`. A date-failure fixture should be structurally attributed to its
parser but written to `active-unparsed`; that is different from a total Grok
nonmatch.

If the document reaches Kafka but the consumer attempts an invalid index name,
inspect the `target_index` Kafka record header and consumer event metadata.
Routing metadata does not appear in the JSON document by design.
