# Ansible Elastic Stack Training Lab interface contract

This is the answer implementation's source of truth. The training branch
publishes the interoperability portions without the implementation syntax.

## Host model

- One Linux host runs the controller, GitLab, runner, sensors, and all service
  containers.
- Ansible reaches `training-lab.local` over SSH as the `ansible` account.
- The same inventory host belongs to `elasticsearch_nodes`, `web_servers`,
  `queue_nodes`, `logstash_nodes`, `port_router_nodes`, and `network_sensors`.
- Application aliases resolve to `127.0.0.1` both on the host and inside every
  container that consumes them.

Required aliases:

- `training-lab.local`
- `gitlab.local`
- `elasticsearch.local`
- `kibana.local`
- `kafka.local`
- `logstash-pipeline.local`
- `log-aggregator.local`
- `network-sensor.local`

The managed host entry also retains readable legacy short names (`web`,
`kibana`, `queue-server`, `kafka`, `elasticsearch`, `network-sensor`,
`logstash`, `logstash-pipeline`, and `log-aggregator`).

## Ports

| Purpose | Port |
|---|---:|
| GitLab HTTP | 8929 |
| GitLab port 443 publication (TLS not configured) | 443 |
| GitLab SSH | 2424 |
| Mission TCP input | 4444 |
| Direct-path checkpoint Zeek Beats input | 5044 (removed after Kafka insertion) |
| Direct-path checkpoint Suricata Beats input | 5045 (removed after Kafka insertion) |
| Kibana | 5601 |
| Kafka UI | 8080 |
| Kafka broker | 9092 |
| Kafka controller | 9093 |
| Elasticsearch | 9200 |
| Processing Logstash API | 9600 |
| Port-router Logstash API | 9601 |

Except for host SSH, every active final-state listener is loopback-only. GitLab
publishes HTTP, the reserved HTTPS port, and Git SSH to `127.0.0.1`;
Training Lab services bind directly to `127.0.0.1` while using host
networking. The HTTPS publication does not provide TLS while GitLab's external
URL remains `http://gitlab.local:8929`. Ports 5044 and 5045 exist only in the
earlier direct-path checkpoint.

## Compose projects and containers

| Project | Long-running containers | One-shot containers |
|---|---|---|
| `gitlab` | `gitlab` | |
| `elasticsearch` | `elasticsearch` | |
| `kibana` | `kibana` | |
| `kafka` | `kafka`, `kafka-ui` | `kafka-topics-init` |
| `logstash_pipeline` | `logstash_pipeline` | |
| `logstash_port-router` | `logstash_port-router` | |
| `filebeat_zeek` | `filebeat_zeek` | |
| `filebeat_suricata` | `filebeat_suricata` | |

GitLab is an eighth, independently managed Compose project under
`/var/training/gitlab` and must not be removed, restarted, or adopted by
Training Lab automation. It preserves the existing
`gitlab/gitlab-ee:19.4.1-ee.0` baseline, uses
`http://gitlab.local:8929` as its external URL, advertises SSH port `2424`,
and mounts `config`, `logs`, and `data` from that project root. A version or
edition change is outside the course bootstrap contract.

## Persistent and source paths

- Training Lab projects: `/var/docker/<project>`
- GitLab project and Compose file: `/var/training/gitlab`
- GitLab configuration, logs, and data: `/var/training/gitlab/config`,
  `/var/training/gitlab/logs`, and `/var/training/gitlab/data`
- Elasticsearch data: `/var/docker/elasticsearch/data`
- Kibana data: `/var/docker/kibana/data`
- Kafka data: `/var/docker/kafka/data`
- Zeek stable mount root: `/opt/zeek/logs`
- Zeek active JSON logs: `/opt/zeek/logs/current`
- Suricata events: `/var/log/suricata/eve.json`

The Zeek paths above are declared interfaces, not proof that the active files
physically reside below the stable root. The answer resolves both paths
canonically. If the active directory is outside the canonical root, it receives
its own source-equals-destination read-only bind. Changing the active target
requires rerunning the sensor role. Both native sensor sources are mounted
read-only without `:z` or `:Z` relabeling.

## Kafka contract

| Topic | Producer | Consumer |
|---|---|---|
| `zeek-group` | Zeek Filebeat | Zeek processing pipeline |
| `suricata-group` | Suricata Filebeat | Suricata processing pipeline |
| `mission-group` | Port router | Mission processing pipeline |

Automatic topic creation is disabled. `kafka-topics-init` owns idempotent topic
creation and exits successfully after reconciliation.

## Elasticsearch and Kibana contract

| Backing index | Write alias | Data-view name |
|---|---|---|
| `search-parsed` | `active-grok-match` | `search-parsed` |
| `search-unparsed` | `active-unparsed` | `search-unparsed` |
| `search-zeek` | `active-zeek` | `search-zeek` |
| `search-suricata` | `active-suricata` | `search-suricata` |

Each backing index must match a composable index template. Each alias has one
write index. Every data view uses `@timestamp` as its time field.

## Mission parsing contract

- TCP/4444 uses the line codec and receives one newline-delimited record per
  line.
- The original record is retained in `event.original`.
- First-seen time is retained in `event.created`.
- The source event time replaces `@timestamp`.
- Parser identity and version remain visible in the indexed document.
- Backend routing and temporary timestamps remain in Logstash metadata.
- Successful parsers independently select their destination alias.
- Normal nonmatches use `_grokparsefailure` while parsers are attempted.
- Grok timeout, total nonmatch, missing event time, and Date failure route to
  `active-unparsed`.
- Processing tags and Logstash `@version` are removed before indexing.
- The destination alias crosses Kafka in the `target_index` record header.

## Deployment order

1. Docker availability (verification only; never daemon management)
2. Host aliases and host prerequisites
3. Elasticsearch and its index assets
4. Kafka, topic initialization, and Kafka UI
5. Processing Logstash
6. Port-router Logstash
7. Kibana and its data views
8. Zeek and Suricata Filebeat collectors

## Training security boundary

The isolated course intentionally uses host networking, plaintext protocols,
and no application authentication. It is not production guidance. Secrets used
for SSH privilege escalation begin as local plaintext learning data and then
progress to whole-file Ansible Vault encryption and a masked GitLab variable.

Docker remains operator-owned, but on a host with SELinux enabled it must
report SELinux integration before deployment. Existing containers must be
recreated after that daemon capability is enabled. The answer expects ordinary
containers, including Zeek Filebeat, to run as `container_t`; Suricata
Filebeat alone uses `container_logreader_t`. Its native log tree keeps the
host's normal log label (`var_log_t` on the Fedora reference host) and must not
be relabeled as container storage.
