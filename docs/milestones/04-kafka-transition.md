# Milestone 04: Kafka transition

## Goal

Insert Kafka between the two Filebeat collectors and processing Logstash while
preserving the outcomes already proven in the direct path.

## Behavioral requirements

- The Kafka Compose project includes the broker, a way to inspect it, and a
  repeatable one-shot topic initialization step.
- Broker state persists through ordinary container recreation.
- Zeek and Suricata use distinct agreed topics.
- Processing Logstash consumes each event family from the correct topic and
  retains distinguishable pipeline behavior.
- Topic creation and readiness rely on observable broker behavior, not only a
  fixed delay.

## Completion criteria

- Required topics exist after a fresh Kafka project start.
- Repeating topic initialization is safe.
- A known event can be observed at its source, in its Kafka topic, and in its
  Elasticsearch destination.
- Stopping processing Logstash does not prevent the producer side from being
  investigated.
- After the consumer resumes, you can explain what was and was not retained.
- Recreating the broker does not silently create incompatible persistent state.

## Research prompts

- What roles do a broker, topic, partition, producer, consumer, and consumer
  group play?
- Why can a listening socket exist before a broker is ready for useful work?
- Which listener address must be usable from the processes that connect?
- What does an offset prove, and what does it not prove?
- What is the difference between service readiness and topic readiness?
