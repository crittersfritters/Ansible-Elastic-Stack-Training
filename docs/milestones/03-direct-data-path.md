# Milestone 03: Direct sensor data path

## Goal

Build the two Filebeat projects and the processing Logstash project, then send
Zeek and Suricata events directly to Logstash before introducing Kafka.

## Behavioral requirements

- Zeek Filebeat and Suricata Filebeat are independent Compose projects.
- Each collector reads only its intended source and can identify its event
  type downstream.
- Processing Logstash has distinguishable paths for both sources.
- Processed events reach intentional Elasticsearch destinations and are
  discoverable in Kibana.
- Configuration remains inspectable on the host.

## Completion criteria

- Each Filebeat configuration passes its own configuration check.
- Processing Logstash accepts its complete configuration.
- A newly generated Zeek record can be traced from its source file to its
  Elasticsearch backing index.
- A newly generated Suricata record can be traced through the same boundaries.
- The intended Kibana data views expose both event families.
- Stopping one collector does not falsely appear as a Logstash or
  Elasticsearch failure.

## Research prompts

- What evidence distinguishes read, send, receive, transform, and index
  failures?
- What state does Filebeat keep while following a file?
- Which parts of a Filebeat module are collection behavior and which are
  optional downstream setup?
- Why use separate Logstash pipeline identities?
- Which fields let you trace one known event without relying only on time?
