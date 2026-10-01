# PAN full traffic-record field map

This project supports the first 61 comma-separated fields of the standard
PAN-OS Traffic log format, ending with **Tunnel Type**. The parser is intended
for the repository's pre-generated dummy data; it does not claim to accept
newer PAN-OS columns that follow Tunnel Type.

The source order is based on Palo Alto Networks' published Traffic Log Fields
reference. ECS names are used only when the source value has a close semantic
match. PAN-specific values are kept under `paloalto.*` rather than being forced
into a misleading ECS field.

## Timestamp policy

- **Receive Time** is column 2. It is validated by the Grok pattern but
  intentionally discarded.
- **Generated Time** is column 7. It is captured temporarily in
  `[@metadata][timestamps][event]`, parsed by the shared Date filter, and used
  to replace `@timestamp`.
- `event.created` preserves the time the port-router Logstash pipeline first
  saw the event.
- **Start Time** and **Parent Start Time** are retained as PAN-specific source
  strings. They are not promoted to ECS date fields in this introductory
  parser.

## Positional map

| # | PAN-OS field | Destination | Type/handling | Reason |
|---:|---|---|---|---|
| 1 | FUTURE_USE | Discarded | Validated as one CSV slot | Placeholder reserved by PAN-OS. |
| 2 | Receive Time | Discarded | `PAN_TIMESTAMP` | The lab uses Generated Time as `@timestamp`. |
| 3 | Serial Number | `observer.serial_number` | Keyword/string | Exact observer-device meaning. |
| 4 | Type | `paloalto.type` | Keyword/string | `TRAFFIC` is a vendor log type, not a severity. |
| 5 | Threat/Content Type (Subtype) | `paloalto.subtype` | Keyword/string | Vendor traffic subtype such as `start`, `end`, `drop`, or `deny`. |
| 6 | FUTURE_USE | Discarded | Validated as one CSV slot | Placeholder reserved by PAN-OS. |
| 7 | Generated Time | `@timestamp` | Parsed Date through metadata | Time the dataplane generated the event. |
| 8 | Source Address | `source.ip` | IP | Exact ECS network-source meaning. |
| 9 | Destination Address | `destination.ip` | IP | Exact ECS network-destination meaning. |
| 10 | NAT Source IP | `source.nat.ip` | IP | Exact ECS translated-source meaning. |
| 11 | NAT Destination IP | `destination.nat.ip` | IP | Exact ECS translated-destination meaning. |
| 12 | Rule Name | `rule.name` | Keyword/string | Exact ECS rule name. |
| 13 | Source User | `source.user.name` | Keyword/string | ECS user field reused under source. |
| 14 | Destination User | `destination.user.name` | Keyword/string | ECS user field reused under destination. |
| 15 | Application | `network.application` | Keyword/string | Application identified from the flow. |
| 16 | Virtual System | `paloalto.virtual_system.id` | Keyword/string | PAN-specific virtual-system identifier. |
| 17 | Source Zone | `observer.ingress.zone` | Keyword/string | Zone observed on ingress. |
| 18 | Destination Zone | `observer.egress.zone` | Keyword/string | Zone observed on egress. |
| 19 | Inbound Interface | `observer.ingress.interface.name` | Keyword/string | ECS interface fields reused under observer ingress. |
| 20 | Outbound Interface | `observer.egress.interface.name` | Keyword/string | ECS interface fields reused under observer egress. |
| 21 | Log Action | `paloalto.log_forwarding_profile` | Keyword/string | PAN log-forwarding profile; not an ECS event action. |
| 22 | FUTURE_USE | Discarded | Validated as one CSV slot | Placeholder reserved by PAN-OS. |
| 23 | Session ID | `paloalto.session.id` | Identifier string | PAN internal session identifier; ECS has no exact `network.session_id`. |
| 24 | Repeat Count | `paloalto.repeat_count` | Integer | PAN aggregation count; ECS has no `event.count` field. |
| 25 | Source Port | `source.port` | Integer | Exact ECS source-port meaning. |
| 26 | Destination Port | `destination.port` | Integer | Exact ECS destination-port meaning. |
| 27 | NAT Source Port | `source.nat.port` | Integer | Exact ECS translated-source-port meaning. |
| 28 | NAT Destination Port | `destination.nat.port` | Integer | Exact ECS translated-destination-port meaning. |
| 29 | Flags | `paloalto.session.flags` | Keyword/string | PAN bit field; no direct ECS transport-flags field. |
| 30 | Protocol | `network.transport` | Keyword/string | Transport-layer protocol such as TCP or UDP. |
| 31 | Action | `event.action` | Keyword/string | Original action reported by the firewall. |
| 32 | Bytes | `network.bytes` | Integer | Total bytes in both directions. |
| 33 | Bytes Sent | `source.bytes` | Integer | Client/source-to-destination bytes. |
| 34 | Bytes Received | `destination.bytes` | Integer | Destination-to-client/source bytes. |
| 35 | Packets | `network.packets` | Integer | Total packets in both directions. |
| 36 | Start Time | `paloalto.session.start_time` | Source timestamp string | Retained without adding another Date-processing branch. |
| 37 | Elapsed Time | `paloalto.elapsed_seconds` | Integer seconds | ECS `event.duration` requires nanoseconds, so the source unit remains explicit. |
| 38 | Category | `paloalto.url.category` | Keyword/string | PAN URL category, not the category of the firewall rule. |
| 39 | FUTURE_USE | Discarded | Validated as one CSV slot | Placeholder reserved by PAN-OS. |
| 40 | Sequence Number | `event.sequence` | Integer | Exact ECS event-ordering meaning. |
| 41 | Action Flags | `paloalto.action.flags` | Keyword/string | PAN forwarding/action bit field. |
| 42 | Source Country | `source.geo.country_name` | Keyword/string | Source geography as reported by PAN-OS. |
| 43 | Destination Country | `destination.geo.country_name` | Keyword/string | Destination geography as reported by PAN-OS. |
| 44 | FUTURE_USE | Discarded | Validated as one CSV slot | Placeholder reserved by PAN-OS. |
| 45 | Packets Sent | `source.packets` | Integer | Source-to-destination packet count. |
| 46 | Packets Received | `destination.packets` | Integer | Destination-to-source packet count. |
| 47 | Session End Reason | `paloalto.session.end_reason` | Keyword/string | Reason the PAN session ended; not an ECS success/failure outcome. |
| 48 | Device Group Hierarchy Level 1 | `paloalto.device_group.level_1` | Identifier string | PAN-specific hierarchy identifier. |
| 49 | Device Group Hierarchy Level 2 | `paloalto.device_group.level_2` | Identifier string | PAN-specific hierarchy identifier. |
| 50 | Device Group Hierarchy Level 3 | `paloalto.device_group.level_3` | Identifier string | PAN-specific hierarchy identifier. |
| 51 | Device Group Hierarchy Level 4 | `paloalto.device_group.level_4` | Identifier string | PAN-specific hierarchy identifier. |
| 52 | Virtual System Name | `paloalto.virtual_system.name` | Keyword/string | PAN-specific virtual-system name. |
| 53 | Device Name | `observer.hostname` | Keyword/string | Hostname of the observing firewall. |
| 54 | Action Source | `paloalto.action_source` | Keyword/string | PAN-specific source of the allow/block action. |
| 55 | Source VM UUID | `paloalto.source.vm_uuid` | Keyword/string | PAN/VMware-specific source UUID. |
| 56 | Destination VM UUID | `paloalto.destination.vm_uuid` | Keyword/string | PAN/VMware-specific destination UUID. |
| 57 | Tunnel ID/IMSI | `paloalto.tunnel_id_or_imsi` | Keyword/string | PAN dual-purpose field; not a VLAN ID. |
| 58 | Monitor Tag/IMEI | `paloalto.monitor_tag_or_imei` | Keyword/string | PAN dual-purpose field. |
| 59 | Parent Session ID | `paloalto.parent_session.id` | Identifier string | PAN tunnel/content parent-session relationship. |
| 60 | Parent Start Time | `paloalto.parent_session.start_time` | Source timestamp string | Retained without another Date-processing branch. |
| 61 | Tunnel Type | `paloalto.tunnel.type` | Keyword/string | PAN tunnel type such as GRE or IPSec. |

## Added fields outside the positional record

The input and parser add a small set of fields that are not separate PAN-OS
columns:

| Field | Value | Purpose |
|---|---|---|
| `log_source` | `Mission-Agg-HC2` | Identifies the external aggregate feeding TCP/4444. |
| `system` | `mission_system_3` | Visible mission-system identifier. |
| `_parser.id` | `pan_full`, `pan_simple`, or `unmatched` | Identifies the successful parser or an unparsed record. |
| `_parser.version` | `1` | Identifies the parser revision. |
| `event.original` | Original `message` value | Preserves the source record for comparison with parsed fields. |
| `event.created` | Initial Logstash `@timestamp` | Preserves when the port router first saw the event. |

`_parser.*` is stored in the event. The leading underscore is a display and
grouping convention for this lab; it does not make the field Elasticsearch
internal metadata.

`event.outcome` is intentionally not populated. PAN Action remains in
`event.action`, while Session End Reason remains in
`paloalto.session.end_reason`; neither source field is automatically equivalent
to an ECS success/failure outcome.
