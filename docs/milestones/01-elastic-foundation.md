# Milestone 01: Elasticsearch and Kibana

## Goal

Build the first two Training Lab Compose projects and learn how Elastic
storage objects differ from Kibana discovery objects.

## Behavioral requirements

- Elasticsearch is a persistent, single-host lab service.
- Kibana connects to that Elasticsearch service by the agreed logical name.
- Both services start without undocumented interactive repair steps.
- Create an index, an index template, an alias, and a Kibana data view as
  distinct objects.

## Completion criteria

- Elasticsearch reports a usable state through its API.
- A test document remains after the Elasticsearch container is recreated.
- Kibana reconnects after ordinary service recreation.
- A newly created matching index receives the intended template behavior.
- An alias resolves to the intended backing index or indices.
- A data view can discover the intended documents without being mistaken for
  a storage location.
- You can explain, in your own words, when each of the four object types is
  evaluated and what it contains.

## Research prompts

- What is stored in a container layer, a bind mount, and a named volume?
- Which Elasticsearch host settings can prevent startup?
- What makes an index template apply to a future index?
- What can an alias do that a Kibana data view cannot?
- How would you prove which backing index holds a displayed document?
