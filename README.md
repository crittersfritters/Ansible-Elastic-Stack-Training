# Training Lab localhost manual reference

This directory is the working manual-stage reference implementation for a
single Linux host. It keeps each Training Lab component in its own Docker
Compose project while using host networking for every container.

The seven-project data stack is intentionally manual at this checkpoint and
is later converted into Ansible-managed projects. GitLab remains the separate
bootstrap project under `bootstrap/gitlab`; it is not part of the seven
Training Lab projects and is never owned by their automation.

## Runtime prerequisites

Install and configure these items on the Linux host before starting the stack:

- Docker Engine with the Docker Compose v2 plugin;
- `curl`, a TCP client such as `nc`, and normal Linux administration tools;
- Zeek, producing JSON logs under `/opt/zeek/logs/current`;
- Suricata, producing `/var/log/suricata/eve.json`;
- enough memory for Elasticsearch, Kibana, two Logstash instances, Kafka,
  Kafka UI, and both Filebeat instances; and
- `vm.max_map_count=1048576`, as required by the pinned Elasticsearch image.

The reference assumes a rootful Docker daemon. Verify that the account running
Compose can access Docker and that TCP ports `4444`, `5601`, `8080`, `9092`,
`9093`, `9200`, `9600`, and `9601` are free.

Add the following logical names to `/etc/hosts`:

```text
127.0.0.1 training-lab.local gitlab.local
127.0.0.1 web.local web kibana.local kibana
127.0.0.1 queue-server.local queue-server kafka.local kafka
127.0.0.1 elasticsearch.local elasticsearch
127.0.0.1 network-sensor.local network-sensor
127.0.0.1 logstash.local logstash logstash-pipeline.local logstash-pipeline
127.0.0.1 log-aggregator.local log-aggregator
```

The Compose projects also add the aliases they consume to the corresponding
containers. Host-networked containers have their own `/etc/hosts`; adding the
host entries alone does not guarantee that a container can resolve an alias.

Zeek and Suricata must be configured and actively observing a suitable host
interface. Confirm that their log paths exist and are readable before starting
Filebeat. On an SELinux host, grant containers read access without blindly
relabeling the live sensor directories; the Filebeat mounts intentionally use
`ro`, not `:Z`.

## Project layout

Each top-level service directory is an independent Compose project:

| Directory | Containers | Host ports |
|---|---|---|
| `elasticsearch` | `elasticsearch` | `9200` |
| `kibana` | `kibana` | `5601` |
| `kafka` | `kafka`, `kafka-ui`, `kafka-topics-init` | `9092`, `9093`, `8080` |
| `logstash_pipeline` | `logstash_pipeline` | `9600` |
| `logstash_port-router` | `logstash_port-router` | `4444`, `9601` |
| `filebeat_zeek` | `filebeat_zeek` | none |
| `filebeat_suricata` | `filebeat_suricata` | none |

The reference pins Elastic `9.2.8`, Apache Kafka `3.9.2`, and Kafka UI
`v0.7.2`. Record resolved digests during release validation if byte-for-byte
image reproducibility is required.

This is an intentionally disposable lab: application traffic is plaintext,
application authentication is disabled, and containers use host networking.
All unauthenticated listeners bind to loopback. Elasticsearch, Kibana, Kafka,
and both Filebeat registries persist through the bind mounts described below.

## Prepare persistent paths

From this directory, create the bind-mounted state directories. The
Elastic and Kafka images currently use UID `1000` for their service account:

```bash
mkdir -p elasticsearch/data kibana/data kafka/data \
  filebeat_zeek/data filebeat_suricata/data
sudo chown -R 1000:0 elasticsearch/data kibana/data kafka/data
sudo chmod 0770 elasticsearch/data kibana/data kafka/data
```

If an image changes its runtime UID, update the ownership to match that image.
Do not change Kafka's `CLUSTER_ID` while reusing `kafka/data`; its persisted
`meta.properties` must agree with the configured ID.

## Manual deployment order

Run the commands from this directory. `--wait` uses each project's Docker
health check where one is defined.

1. Start Elasticsearch:

   ```bash
   docker compose -f elasticsearch/docker-compose.yml up -d --wait
   curl -fsS 'http://elasticsearch.local:9200/_cluster/health?pretty'
   ```

2. Create the four composable templates first, then their backing indices and
   write aliases:

   ```bash
   bash elasticsearch/setup-assets.sh
   ```

   Inspect both `/_index_template/training-lab-*` and `/_alias/active-*`.
   The order matters: a template affects index creation, not an already-created
   index retroactively.

3. Start Kibana and wait until its status is `available`:

   ```bash
   docker compose -f kibana/docker-compose.yml up -d
   until curl -fsS 'http://kibana.local:5601/api/status' | \
     grep -q '"level":"available"'; do sleep 5; done
   bash kibana/setup-data-views.sh
   ```

   The script creates `search-parsed`, `search-unparsed`, `search-zeek`, and
   `search-suricata` data views using `@timestamp`. A data view is a Kibana
   saved object; it is not an Elasticsearch index, template, or alias.

4. Start Kafka, wait for its health check, and run the one-shot topic
   initializer:

   ```bash
   docker compose -f kafka/docker-compose.yml up -d kafka
   until [ "$(docker inspect -f '{{.State.Health.Status}}' kafka)" = healthy ]; do
     sleep 5
   done

   docker compose -f kafka/docker-compose.yml up -d --no-deps \
     --force-recreate kafka-topics-init
   until [ "$(docker inspect -f '{{.State.Status}}' kafka-topics-init)" = exited ]; do
     sleep 2
   done
   test "$(docker inspect -f '{{.State.ExitCode}}' kafka-topics-init)" = 0

   docker compose -f kafka/docker-compose.yml up -d kafka-ui
   docker exec kafka /opt/kafka/bin/kafka-topics.sh \
     --bootstrap-server 127.0.0.1:9092 --list
   ```

   The expected topics are `mission-group`, `suricata-group`, and
   `zeek-group`. Kafka UI is available at `http://queue-server.local:8080`.

5. Start the Kafka-to-Elasticsearch processing Logstash project:

   ```bash
   docker compose -f logstash_pipeline/docker-compose.yml up -d --wait
   curl -fsS 'http://127.0.0.1:9600/_node/pipelines?pretty'
   ```

   The node must load `zeek`, `suricata`, and `grok_pipeline`.

6. Start the mission-data producer/port router:

   ```bash
   docker compose -f logstash_port-router/docker-compose.yml up -d --wait
   curl -fsS 'http://127.0.0.1:9601/_node/pipelines/logstash_port-router?pretty'
   ```

7. Start the two sensor collectors after Zeek and Suricata have created their
   source logs:

   ```bash
   docker compose -f filebeat_zeek/docker-compose.yml up -d --wait
   docker compose -f filebeat_suricata/docker-compose.yml up -d --wait
   ```

## Data paths

The completed stack has three independent inputs:

```text
Zeek logs -> Filebeat -> zeek-group -> Logstash zeek pipeline
          -> active-zeek -> search-zeek

Suricata eve.json -> Filebeat -> suricata-group -> Logstash suricata pipeline
                  -> active-suricata -> search-suricata

TCP/4444 -> port-router Grok parsers -> mission-group
         -> Logstash grok_pipeline -> parser-selected write alias
```

The port router sends JSON through Kafka. Its selected Elasticsearch write
alias travels separately in the Kafka record header named `target_index`; the
consumer reads that header from Logstash `@metadata`. Parser identity remains
visible in `_parser.id` and `_parser.version`.

## Smoke tests

Confirm container state:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker inspect kafka-topics-init \
  --format 'status={{.State.Status}} exit={{.State.ExitCode}}'
```

The initializer should be `exited` with exit code `0`; the other eight
containers should be running. Send the supplied simple PAN-shaped record:

```bash
printf '%s\n' \
  '2026-01-07 14:22:01,TRAFFIC,DROP,192.168.50.12,10.1.1.5,54212,443,outside,inside,rule-dmz-deny,tcp,40,0,0,0,0,0x0' \
  | nc -N 127.0.0.1 4444
```

If the local `nc` implementation lacks `-N`, use its equivalent option for
closing the connection after standard input ends. Then verify the destination:

```bash
curl -fsS 'http://elasticsearch.local:9200/active-grok-match/_search?pretty'
```

The document should show `_parser.id` equal to `pan_simple`, retain the raw
record in `event.original`, and use the source event time for `@timestamp`.
Because the sample is historical, widen Kibana's time range when viewing it.

Send a nonmatching record and verify that it reaches `active-unparsed`:

```bash
printf '%s\n' 'not-a-supported-record' | nc -N 127.0.0.1 4444
curl -fsS 'http://elasticsearch.local:9200/active-unparsed/_search?pretty'
```

## Applying configuration changes

These projects use bind-mounted configuration. Recreate or restart the owning
container after editing a Filebeat, Logstash, or Kafka configuration. Examples:

```bash
docker compose -f logstash_port-router/docker-compose.yml up -d --force-recreate
docker compose -f logstash_pipeline/docker-compose.yml up -d --force-recreate
docker compose -f filebeat_zeek/docker-compose.yml up -d --force-recreate
```

Kafka broker configuration changes require a broker restart. A KRaft cluster
ID change additionally requires intentionally deleting `kafka/data`, which
destroys all topics, records, offsets, and broker metadata.

## Stop the manual stack

Stop projects in reverse dependency order. `down` removes containers while
leaving the bind-mounted state directories intact:

```bash
docker compose -f filebeat_suricata/docker-compose.yml down
docker compose -f filebeat_zeek/docker-compose.yml down
docker compose -f logstash_port-router/docker-compose.yml down
docker compose -f logstash_pipeline/docker-compose.yml down
docker compose -f kibana/docker-compose.yml down
docker compose -f kafka/docker-compose.yml down
docker compose -f elasticsearch/docker-compose.yml down
```
