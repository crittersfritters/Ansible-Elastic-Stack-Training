# Curriculum-to-answer traceability

This matrix belongs on the final answer branch. It lets maintainers change the
curriculum or reference implementation without putting implementation paths
into learner instructions.

| Milestone | Contract/evidence | Earliest answer branch | Validation |
|---|---|---|---|
| 00 Host and GitLab | EE 19.4.1, project/container `gitlab`, ports 8929/443/2424, `/var/training/gitlab` persistence, local clone | `answers/01-manual` | semantic Compose check; runtime image, health, UI, and exact port publication |
| 01 Elastic foundation | four distinct object types and durable test document | `answers/01-manual` | exact templates, mappings, indices, aliases, data views |
| 02 Sensors | fresh Zeek JSON and Suricata EVE records | `answers/01-manual` | readable valid source records |
| 03 Direct path | one event per sensor at the intended index/data view | `answers/01-manual` | native configs and direct end-to-end observation |
| 04 Kafka transition | three topics, repeatable initialization, retained records | `answers/01-manual` | topic list, consumer path, broker persistence |
| 05 Mission and Grok | all files under `samples/mission`; expected outcomes YAML | `answers/01-manual` | matching, full, unmatched, and bad-date assertions |
| 06 Manual checkpoint | seven independent projects; GitLab untouched | `answers/01-manual` | complete runtime suite on target host |
| 07 First role | SSH identity, Elasticsearch rebuild, second-run no change | `answers/02-first-role` | syntax, reconstruction, drift, idempotence evidence |
| 08 Full conversion | all seven projects and three paths | `answers/03-full-ansible` | full deploy, native config tests, second-run recap |
| 09 Vault | ignored plaintext then tracked ciphertext | `answers/04-vault` | correct/wrong password tests; history secret audit |
| 10 GitLab CI | protected shell runner applies a pushed change | `answers/05-gitlab-ci` | path-selection matrix, failure, retry, resource lock |
| Final hardening | operations guidance and static/runtime validation | `answer-sheet` | complete validation suite and publication audit |

Before publication, verify that every training criterion still has one
observable answer behavior, that the branch chain remains ordered, and that no
answer implementation is reachable from `training`.
