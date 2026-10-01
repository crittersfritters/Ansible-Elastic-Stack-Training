# Ansible Elastic Stack Training Lab

Ansible Elastic Stack Training Lab is a self-paced construction lab. You will build a
localhost data path with Docker Compose, Zeek, Suricata, Filebeat, Kafka,
Logstash, Elasticsearch, Kibana, Ansible, and GitLab CI.

This branch describes outcomes, not recipes. It intentionally omits working
service definitions, parser patterns, Ansible roles, and deployment jobs. You
are expected to research unfamiliar concepts, test your assumptions, and ask
questions when you cannot identify the next useful question.

The final `answer-sheet` branch is a reference implementation, not the only
valid implementation. Major construction phases are preserved on the
`answers/01-manual` through `answers/05-gitlab-ci` branches. Consult a reference
branch when you are blocked; do not assume every design choice there is
mandatory unless this branch labels it as a course contract.

## Learning objectives

By completing the course, you should be able to:

- explain what each Elastic Stack component contributes to the data path;
- follow an event across Filebeat, Kafka, Logstash, Elasticsearch, and Kibana;
- configure and troubleshoot Filebeat inputs, state, and outputs;
- distinguish an index, index template, alias, and Kibana data view;
- develop, order, and test Grok parsers against known input;
- build and troubleshoot separate Docker Compose projects;
- convert a working manual deployment into idempotent Ansible automation; and
- use a learner-authored GitLab pipeline to apply a repository change.

GitLab is included so that you experience the change path used by the larger
environment. Designing advanced GitLab CI is not a course objective.

## Lab boundaries

- Run the entire lab on one Linux host.
- Use a normal learner account, a separate `ansible` account introduced at
  Milestone 07, and the `gitlab-runner` account introduced with CI at
  Milestone 10.
- Have Ansible reach the host through SSH as the `ansible` account, even though
  the target resolves to localhost.
- Treat GitLab as a separate bootstrap Compose project. Training Lab
  automation must not manage or remove it.
- Build seven Training Lab Compose projects: Elasticsearch, Kibana, Kafka,
  processing Logstash, port-router Logstash, Zeek Filebeat, and Suricata
  Filebeat.
- Install Zeek and Suricata on the host; the Filebeat projects collect their
  output.
- Keep the lab isolated. Its simplified networking and security choices are
  training constraints, not production guidance.
- Bind every unauthenticated application listener to loopback. Do not expose
  Elasticsearch, Kibana, Kafka, Logstash, or GitLab to another network.
- Treat membership in the Docker group as root-equivalent access.
- Preserve the course's required service interfaces and observable data
  behavior. Repository layout and implementation details are yours to design.

## How to work

Complete the milestones in order. For each milestone:

1. Read its goal and behavioral requirements.
2. Record the questions you need to answer.
3. Build the smallest version that satisfies the requirements.
4. Prove every completion criterion by direct observation.
5. Commit the working state before proceeding.
6. Record what failed, what evidence identified the cause, and what changed.

There is no supplied grader on this branch. A container listed as running is
not sufficient proof that a data path works. Completion means you can produce
and explain the requested evidence.

## Starting from a new Linux installation

Use a maintained Linux host with at least 4 CPU cores, 16 GiB RAM, and 80 GiB
free disk. More memory is useful when GitLab and the full stack run together.
The Linux distribution, package manager, and host-package versions are not
course contracts. Use current distribution and vendor guidance to provide the
required capabilities, then prove each capability directly.

Obtain the learner branch from the public
[GitHub mirror](https://github.com/crittersfritters/ansible-elastic-stack-training).
Clone only `training` so the reference implementation is not fetched into the
learner workspace:

```bash
git clone --branch training --single-branch \
  https://github.com/crittersfritters/ansible-elastic-stack-training.git
cd ansible-elastic-stack-training
```

A training-branch archive from the same mirror can be used instead. Then:

1. Provide Git, Docker Engine, the Docker Compose v2 plugin, Python 3, Ansible,
   an SSH client and server, and ordinary troubleshooting tools.
2. Ensure your normal account can operate Docker using your host's intended
   administrative model.
3. Configure a local hostname for GitLab and confirm it resolves to the local
   host.
4. Complete the GitLab bootstrap milestone.
5. Create a blank **Ansible Elastic Stack Training Lab** project in your local GitLab.
6. Add the local project as a Git remote, push the `training` branch, and leave
   it as the default branch. A maintainer publishing the complete course can
   add the protected reference branches separately; they are not required to
   begin the learner path.
7. Clone the project back from local GitLab into the location where you will
   do the course work. This verifies that the local instance, repository, and
   Git transport are usable before the stack is involved.

The host shell runner is intentionally deferred until Milestone 10. It is not
required to create GitLab, transfer the repository, or begin the manual stack.

Do not copy implementation files from a reference branch into the training
branch. When you consult a reference, return to your own design and explain
why your chosen implementation satisfies the requirement.

## Course files

- [Course map](docs/course-map.md) — milestone sequence and expected evidence
- [Working contract](docs/working-contract.md) — decisions that must remain
  consistent across components
- [Milestones](docs/milestones/) — goals, requirements, completion criteria,
  and research prompts
- [Sample manifest](samples/MANIFEST.md) — input and expected-outcome fixtures
  that the maintainer will publish with the course

Begin with [Host and GitLab bootstrap](docs/milestones/00-host-and-gitlab.md).
The detailed path from a new host through the local clone is in
[GitLab bootstrap](docs/gitlab-bootstrap.md); later milestones intentionally
return to outcome-based guidance.
