# Mission parsing reference

The port-router pipeline is intentionally the course's Grok laboratory. It
receives one plaintext record per line on loopback TCP/4444 and applies ordered,
anchored patterns before publishing JSON to `mission-group`.

## Event invariants

Before parser selection, the pipeline copies the exact `message` into
`event.original` and the first Logstash timestamp into `event.created`. Parser
captures may change the event, but neither diagnostic value should be lost.

Every successful parser supplies:

- a temporary authoritative timestamp;
- visible `_parser.id` and `_parser.version` fields; and
- a destination alias in Logstash metadata.

The Date filter runs only after a parser claims the record. The destination is
`active-unparsed` when every parser misses, Grok times out, a successful
structure supplies no time, or the Date filter rejects the value. A
structurally successful invalid-date record retains that parser's identity;
this distinction is useful when diagnosing format drift.

Backend control tags are removed before output. The destination itself crosses
Kafka in the record header `target_index`, because Logstash metadata is not
part of the JSON body. The consumer restores decorated Kafka headers under
metadata and writes through the selected alias.

## Ordered parsers

`pan_full` is deliberately first because its 61-field format is more specific.
`pan_simple` runs only when the previous parser left `_grokparsefailure` and no
Grok timeout occurred. Anchors require the expression to claim the complete
record instead of a convenient substring.

The exact source-to-field contract for the large parser is documented in
[full PAN field map](pan-full-field-map.md). The expected outcomes for both
valid formats, a total
nonmatch, and an invalid date are machine-readable in
`samples/mission/expected-outcomes.yml`.

## Adding a parser

1. Add sanitized matching, near-miss, malformed-time, and overlap samples.
2. State required fields, types, source time, identity, and destination before
   writing the pattern.
3. Put the new parser before any more permissive expression.
4. Gate it on the previous parser's normal failure and absence of timeout.
5. Keep parser-specific captures in the parser block and reuse the shared date
   and failure-routing section.
6. Test every earlier sample for regression and false-positive claiming.

Do not make a pattern more permissive merely to make a fixture green. First
identify whether the source format, delimiter rules, optional fields, or
expected contract is wrong.

## Outcome matrix

| Input | Visible identity | Destination | Timestamp behavior |
|---|---|---|---|
| Full PAN sample | `pan_full` / `1` | `active-grok-match` | Generated Time becomes `@timestamp` |
| Simple PAN sample | `pan_simple` / `1` | `active-grok-match` | First field becomes `@timestamp` |
| Unsupported record | `unmatched` / `1` | `active-unparsed` | First-seen time remains |
| Structurally valid, bad date | matching parser / `1` | `active-unparsed` | Conversion failure does not masquerade as success |

Kafka uses broker append time for retention, so an intentionally historical
source timestamp remains searchable rather than making the record immediately
eligible for age-based topic deletion.
