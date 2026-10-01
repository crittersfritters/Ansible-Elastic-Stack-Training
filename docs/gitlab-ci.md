# Answer sheet: dependency-aware GitLab CI on one host

## Purpose

The reference pipeline demonstrates that repository paths can identify the
service configuration they own and the downstream services that depend on
them. This behavior is intentionally more advanced than the learner's minimum
requirement. A learner pipeline may reconcile the complete stack on every
eligible push and still satisfy the course milestone.

The answer implementation uses a parent pipeline for change detection and a
child pipeline for ordered Ansible jobs. Both run through the host shell runner
and ultimately connect by SSH to the single inventory host.

## What localhost changes

The six-VM implementation mapped a component to both a service role and a
physical node. The localhost implementation keeps the service ownership but
removes false physical separation.

| Six-node behavior | Localhost behavior |
|---|---|
| Six inventory hosts | One inventory host in six functional groups |
| Host variables select one VM | Component or group variables select one Compose project |
| System role can run once per changed VM | Host preparation runs once for the physical host |
| Per-node firewall changes | Loopback binding enforced by each local service |
| Jobs may target different Docker daemons | Every selected job targets one Docker daemon |

Do not retain six aliases that all use `ansible_host: 127.0.0.1`. That would
make an all-host play execute repeatedly against the same system.

Component jobs may still use an Ansible group limit. Because every group
contains the same inventory host, the limit expresses role ownership rather
than physical placement.

## Reference pipeline boundary

The parent pipeline is eligible only for branch pushes that change CI mapping
or managed lab state. Documentation-only changes do not deploy the fixed lab.

For an ordinary push, compare against the previous commit on that branch. For
the first push of a new branch, compare against the default branch rather than
the all-zero previous SHA. Supply the resulting comparison reference to the
child pipeline.

The parent trigger mirrors the child status and holds the
`training-lab-pipeline` resource-group lock for the complete deployment. The
child jobs use the separate `training-lab-deployment` lock so that a retried
child job cannot overlap a newer deployment after the parent lock has been
released. The two names must remain distinct so a child never waits on a lock
held by its own parent.

Use a GitLab version that supports the selected child-pipeline status strategy
and variable expansion in `rules:changes:compare_to`. Pin and document that
version in the course release; do not assume an arbitrary older GitLab has the
same behavior.

## Service dependency graph

The reference selection rules encode these runtime dependencies:

- Elasticsearch changes select Elasticsearch, processing Logstash, and
  Kibana.
- Kafka changes select Kafka, processing Logstash, the mission port router,
  and both Filebeat collectors.
- A processing-Logstash-only change selects processing Logstash.
- A port-router-only change selects the port router.
- A Kibana-only change selects Kibana.
- A Filebeat or sensor-collection change selects the sensor collector project
  or projects represented by that job.

An upstream change selects downstream reconciliation because interface or
readiness changes may affect consumers. A downstream change does not redeploy a
healthy upstream service.

The safe selected-job order is:

1. host prerequisites, when required;
2. Elasticsearch;
3. Kafka and topic initialization;
4. processing Logstash;
5. mission port router;
6. Kibana; and
7. sensor collectors.

Empty stages are skipped. Ordering does not mean every push runs every stage.

## Changed-path ownership

Keep the exact repository paths beside the actual answer implementation. The
following ownership categories define the behavior that mapping must preserve.

| Changed concern | Owner and dependent jobs |
|---|---|
| Elasticsearch role, Compose template, variables, or playbook | Elasticsearch; processing Logstash; Kibana |
| Kafka role, broker configuration, topic contract, variables, or playbook | Kafka; processing Logstash; port router; sensor collectors |
| Processing Logstash pipelines, role, variables, or playbook | Processing Logstash |
| Port-router pipelines, Grok patterns, role, variables, or playbook | Port router |
| Kibana role, variables, or playbook | Kibana |
| Zeek Filebeat role or configuration | Zeek collector, or combined sensor job |
| Suricata Filebeat role or configuration | Suricata collector, or combined sensor job |
| Shared Compose deployment task | Every service that calls it |
| Elasticsearch readiness task | Elasticsearch and Elasticsearch dependents |
| Kafka readiness task | Kafka and Kafka dependents |
| Inventory structure, global variables, Vault file, or full-site playbook | Full reconciliation |
| Host preparation, common aliases, or host-port policy | One host-preparation job followed by affected services |
| CI mapping only | Visible planning job; no service deployment solely for this change |
| Documentation or samples only | No deployment |

Whenever a new owned path is introduced, update both the parent list of
deployment-relevant paths and the child ownership rule. An unknown file should
not silently trigger an unrelated component.

## Host preparation on localhost

There is only one host-level state boundary. The host-preparation playbook owns
items such as:

- application hostname aliases;
- deployment directories and shared groups;
- required kernel or service prerequisites;
- the declared local port policy; and
- other state genuinely shared by every Compose project.

A change to that shared role runs it once against `training-lab.local`.
Remove the six host-specific system jobs from the multi-VM pipeline; on one
machine they would repeat the same work under different labels.

Service configuration remains in the owning role. Do not place all seven
Compose deployments in the host-preparation role merely because they share a
host.

## Job template

Every mutating job extends one common deployment template. The template is
responsible for:

- selecting the `training-lab-local` runner;
- making a checkout-relative Ansible temporary directory;
- placing downloaded collections under an ignored checkout-relative dependency
  directory;
- installing the versions pinned in the repository dependency file;
- rejecting a missing or plaintext Vault variable file;
- requiring the masked Vault password for every mutating job; and
- exposing the repository's executable Vault password client to Ansible.

Do not write dependencies into a system Python environment from each job. Do
not assume the shell runner's interactive profile runs in CI. Every required
program must be discoverable in the runner service's noninteractive
environment.

Caching the ignored Ansible dependency directory is an optimization, not the
source of truth. Derive its key from the dependency declaration so a version
change cannot reuse an incompatible cache without reinstallation.

## Full reconciliation versus component jobs

Paths whose impact cannot be assigned safely to one component use the full
playbook and suppress component jobs in that child pipeline. Typical examples
are:

- inventory topology;
- repository-wide Ansible configuration;
- the dependency manifest;
- global variables;
- the encrypted Vault file; and
- the full-site playbook itself.

Component-specific changes run their owning playbooks in dependency order.
Shared configuration selects every actual caller, not necessarily every file
in the repository.

On localhost, full reconciliation must still invoke host preparation only once
and then reconcile the seven projects in the established service order.

## Serialization and branch policy

All deployable branches target the same Docker daemon and persistent data.
They are not isolated environments. Serialize deployments with resource groups
and configure strict first-in-first-out processing when preserving push order
matters.

The published repository protects `training`, `answers/*`, and `answer-sheet`.
The `answers/*` branches are read-only phase references and the workflow
explicitly excludes them from deployment. Learner work should deploy from a
personal protected branch only after the maintainer or learner has deliberately
allowed that branch to access protected variables and the protected runner.
This workflow intentionally creates no pipeline for an unprotected ref.
Validate those branches locally or add a separate non-mutating pipeline on an
unprivileged runner; never expose the shared lab's protected runner or Vault
variables merely to obtain validation.

A manual `ansible-playbook` invocation is outside GitLab's resource-group lock.
Do not run it while a CI deployment is active.

## Failure and retry behavior

The parent status mirrors the child status. A failed selected job prevents
later selected stages from starting.

Retry the failed job within the child pipeline after correcting an incidental
problem. Earlier successful service jobs remain complete and later stages
continue after the retry succeeds. Retrying the parent trigger creates a new
child pipeline and repeats change planning; it is not the component-specific
retry path.

An Ansible or service-health failure must produce a nonzero job status. Avoid
commands that hide failures merely so the pipeline appears green.

## Reference acceptance tests

Validate the pipeline with controlled commits on a disposable integration
branch.

| Test change | Expected selected behavior |
|---|---|
| Documentation only | No deployment pipeline |
| CI mapping only | Planning job, no Ansible mutation |
| Kibana-owned file | Kibana only |
| Processing-Logstash-owned file | Processing Logstash only |
| Elasticsearch-owned file | Elasticsearch, processing Logstash, then Kibana |
| Kafka-owned file | Kafka and topic initialization, processing Logstash, port router, then sensors |
| Shared host-preparation file | One host preparation plus the services its changed contract affects |
| Global variable or full-site entry point | One ordered full reconciliation |
| Intentionally invalid selected configuration | Owning job fails and later stages do not run |
| Retry after correction | Failed stage succeeds without overlapping another deployment |
| Two quick deployable pushes | Resource-group behavior prevents concurrent mutation of the host |

For each test, record the comparison base, changed paths, selected jobs, skipped
jobs, execution order, and final service health. The pipeline graph alone does
not prove the running stack received the intended change.

## Scope limits

The reference automatic deployment path handles eligible protected branch
pushes to the fixed localhost lab. The protected `answers/*` snapshots,
merge-request pipelines, scheduled pipelines, and manually started pipelines
do not deploy unless a later course version explicitly adds and validates that
behavior.

The changed-path map demonstrates one maintainable answer; it is not the only
valid design. The training milestone accepts a simpler full-reconciliation
pipeline when it deploys safely, fails visibly, and leaves GitLab itself
untouched.
