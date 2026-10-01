# Milestone 05: Mission path and Grok

## Goal

Build the port-router Logstash project, accept complete plaintext mission
records, create ordered Grok parsers, and route parsed results through Kafka to
Elasticsearch.

## Behavioral requirements

- The port router receives one complete logical record per input event.
- The raw source remains available in the resulting event for diagnosis.
- More specific parsers are evaluated before more permissive parsers.
- A successful parser writes visible parser identity and selects its intended
  destination.
- Source event time replaces the processing time used for `@timestamp`.
- Shared timestamp and routing behavior remains understandable as parsers are
  added.
- Unmatched, timed-out, missing-timestamp, and invalid-timestamp records follow
  the declared failure behavior.
- Backend routing details do not become analyst-facing document clutter.

## Completion criteria

- Every supplied valid sample matches the intended parser and no other outcome.
- Required extracted values have their declared names and data types.
- The stored parser identity identifies the pattern family and version.
- The stored `@timestamp` reflects the source record's authoritative time.
- At least two parsers emit explicit routing metadata selected independently
  by each parser, even when two samples intentionally share a destination.
- Supplied unmatched and malformed samples reach their required failure
  destination without being mislabeled as successful.
- You can identify which behavior is parser-specific and which behavior should
  remain consistent across every parser.
- One record can be traced across input, Kafka, processing Logstash,
  Elasticsearch, and Kibana.

## Research prompts

- How does a Grok nonmatch differ from a timeout or a date-conversion failure?
- How can later parsers run only when earlier parsers did not succeed?
- Which captures should be typed during parsing rather than corrected later?
- Which timestamp in a source format is authoritative, and why?
- Which fields belong in the stored document and which exist only to move the
  event between processing stages?
- How will a permissive early pattern affect every pattern after it?

## Optional design challenge

Refactor the working chain so adding a third parser requires one
parser-specific block and no copied timestamp or failure-routing logic. Prove
that the refactor preserves every sample outcome before treating it as an
improvement.
