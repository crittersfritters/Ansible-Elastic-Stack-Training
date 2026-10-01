# Course map

The course starts with a working manual data path and then replaces manual
deployment with Ansible. Do not begin the automation phase until the manual
checkpoint works and has been committed.

| Milestone | Build outcome | Evidence to retain |
|---|---|---|
| 00 | Prepared host and local GitLab | Host checks, GitLab persistence, successful local clone |
| 01 | Elasticsearch and Kibana | Persistent test document and explanation of Elastic objects |
| 02 | Zeek and Suricata sources | Fresh records from both sensors and verified read permissions |
| 03 | Direct collection path | One Zeek and one Suricata event traced without Kafka |
| 04 | Kafka transition | Both sensor paths traced through topics while the consumer is stoppable independently |
| 05 | Mission path and Grok | Valid, unmatched, and malformed records reach their required outcomes |
| 06 | Complete manual stack | Seven Compose projects operate together and survive ordinary recreation |
| 07 | First Ansible role | Elasticsearch can be rebuilt and a second run is idempotent |
| 08 | Full Ansible conversion | Ansible reconstructs all seven projects without touching GitLab |
| 09 | Vault progression | The working credential flow is encrypted, verified manually, and prepared for CI |
| 10 | Learner-authored pipeline | Runner evidence and a push that changes the stack through GitLab and Ansible |

## Suggested learner checkpoints

Use your own commit messages, but preserve these meaningful states:

- host and local GitLab ready;
- Elastic foundation working;
- direct sensor flow working;
- Kafka sensor flow working;
- mission parsing working;
- complete manual stack;
- first idempotent role;
- full Ansible deployment;
- Vault enabled; and
- CI deployment working.

The protected reference branches contain equivalent major-phase checkpoints.
A checkpoint is a place to compare observable behavior, not an instruction to
copy its files.

## Completion evidence

Evidence may include API output, a selected log excerpt, a Kibana observation,
an Ansible recap, or a GitLab job result. Keep it small and explain what it
proves. Screenshots or command output without an explanation are not enough.
