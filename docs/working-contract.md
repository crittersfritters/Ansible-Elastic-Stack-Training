# Working contract

Create a short design ledger before building services. Record decisions that
another component must rely on. Change a decision only after identifying every
consumer of it.

At minimum, record:

- GitLab hostname and host ports;
- the logical name used by Ansible for the localhost target;
- application service names and listening ports;
- the seven Compose project names and their configuration locations;
- persistent-data and source-log locations;
- Kafka topics and consumer groups;
- Logstash pipeline identifiers and input/output boundaries;
- Elasticsearch indices, aliases, and template patterns;
- Kibana data views;
- the visible parser identity fields;
- the source-timestamp policy; and
- destinations for successful, unmatched, timed-out, and malformed events.

The following values are the course interoperability contract. They tell you
what separately built components must agree on; they do not prescribe how to
express them in Compose, Logstash, Filebeat, or Ansible.

### Hostnames and ports

Map these names to `127.0.0.1` on the host: `training-lab.local`,
`gitlab.local`, `elasticsearch.local`, `kibana.local`, `kafka.local`,
`logstash-pipeline.local`, `log-aggregator.local`, and
`network-sensor.local`. A hostname must also resolve inside every container
that consumes it. A host-networked container does not inherit the host's
`/etc/hosts` file.

The seven Training Lab projects use host networking; GitLab remains on its
separate published-port network. This is a course interoperability constraint,
not a general production recommendation.

| Interface | TCP port |
|---|---:|
| Host SSH | 22 |
| GitLab HTTP | 8929 |
| GitLab port 443 publication (TLS not configured) | 443 |
| GitLab Git-over-SSH | 2424 |
| Mission input | 4444 |
| Temporary direct Zeek / Suricata inputs | 5044 / 5045 |
| Kibana / Kafka UI | 5601 / 8080 |
| Kafka broker / controller | 9092 / 9093 |
| Elasticsearch | 9200 |
| Processing / port-router Logstash APIs | 9600 / 9601 |

Every no-authentication application endpoint must listen only on loopback.
Host SSH may follow the host's administrative policy. Publishing GitLab port
`443` preserves the course endpoint but does not provide TLS while the
external URL remains `http://gitlab.local:8929`.

### Runtime names and paths

Use project/container names `elasticsearch`, `kibana`, `kafka` (with
`kafka-ui` and `kafka-topics-init`), `logstash_pipeline`,
`logstash_port-router`, `filebeat_zeek`, and `filebeat_suricata`. The
port-router pipeline ID is also `logstash_port-router`; the processing IDs are
`zeek`, `suricata`, and `grok_pipeline`.

GitLab is the independent Compose project, service, and container `gitlab`
under `/var/training/gitlab`. Its Compose file lives at that project root. It
uses `gitlab/gitlab-ee:19.4.1-ee.0`, advertises
`http://gitlab.local:8929` and Git SSH port `2424`, and bind-mounts the
project's `config`, `logs`, and `data` directories to GitLab's configuration,
log, and application-data paths.

The final automated deployment root is `/var/docker`. Zeek's stable mount root
is `/opt/zeek/logs`, its active JSON logs are under
`/opt/zeek/logs/current`, and the Suricata EVE source is
`/var/log/suricata/eve.json`.

### Data contracts

| Kafka topic | Producer | Consumer |
|---|---|---|
| `zeek-group` | Zeek Filebeat | `zeek` pipeline |
| `suricata-group` | Suricata Filebeat | `suricata` pipeline |
| `mission-group` | Port router | `grok_pipeline` |

| Backing index | Write alias | Kibana data view |
|---|---|---|
| `search-parsed` | `active-grok-match` | `search-parsed` |
| `search-unparsed` | `active-unparsed` | `search-unparsed` |
| `search-zeek` | `active-zeek` | `search-zeek` |
| `search-suricata` | `active-suricata` | `search-suricata` |

Each backing index must receive a matching composable template before it is
created. Each data view uses `@timestamp`. Mission records preserve the exact
input in `event.original`, preserve first-seen time in `event.created`, and
expose `_parser.id` plus `_parser.version`. A total nonmatch, timeout, missing
source time, or invalid source time belongs at `active-unparsed`.

### Release-candidate component baseline

The reference candidate preserves GitLab EE `19.4.1-ee.0` and uses Elastic
Stack `9.2.8`,
Apache Kafka `3.9.2`, and Kafka UI `v0.7.2`. Do not substitute mutable
`latest` tags. A GitLab edition or version change is a maintainer-led contract
revision, not a learner choice. The release remains a candidate until the
maintainer records a full runtime validation and the host platform used to
produce that evidence.

## Required topology

All components run on one Linux host. Training Lab services use the course's
localhost network model, while GitLab remains a separate Compose project.
Logical hostnames must resolve in every context that uses them, not merely in
the learner's interactive shell.

Use one Ansible inventory host assigned to every applicable service group.
Ansible must connect to that host over SSH as the dedicated `ansible` account.
Do not create several aliases that cause the same play to modify the physical
host repeatedly.

## Required Compose separation

Maintain one project for each of the following:

1. Elasticsearch
2. Kibana
3. Kafka, its supporting inspection interface, and one-shot topic setup
4. Kafka-to-Elasticsearch processing Logstash
5. Raw mission-input port-router Logstash
6. Zeek Filebeat
7. Suricata Filebeat

GitLab is an eighth, independently managed bootstrap project.

## Intentional constraints

This is a disposable, isolated lab. Plaintext service traffic, simplified
access controls, and a staged plaintext-to-Vault credential exercise are
permitted only within that boundary. Preserve source records for diagnosis,
avoid broad destructive cleanup, and never let Training Lab automation
operate on unrelated containers or GitLab state.

Docker is a prerequisite and owns GitLab before Ansible exists. Training Lab
automation must verify Docker but must not install, upgrade, restart, or prune
the shared daemon. Docker-group membership is equivalent to broad root access;
do not grant it to the runner as a shortcut.

The contract defines interoperability. It does not define your directory tree,
Compose syntax, Ansible modules, task layout, Grok expressions, or CI design.
