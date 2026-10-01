# Milestone 10: Learner-authored GitLab pipeline

## Goal

Make a committed configuration change reach the running Training Lab stack
through the local GitLab runner and your Ansible implementation.

## Behavioral requirements

- GitLab Runner is installed on the Linux host as its own service identity.
- The runner is registered deliberately for the training project and uses the
  shell executor.
- Its tags, protected status, and untagged-job behavior agree with the jobs it
  is allowed to execute.
- The runner reaches `ansible@training-lab.local` with its own SSH key and a
  verified host-key entry rather than direct root access.
- A push to the intended branch creates a pipeline.
- The shell runner prepares any required Ansible dependencies and invokes the
  committed deployment entry point.
- Deployment failure makes the job fail visibly.
- A failed deployment can be diagnosed and retried without manually copying
  repository content after every commit.
- A full-stack deployment is acceptable. Dependency-aware selection is an
  optional extension, not a completion requirement.

Install and register the runner using current GitLab guidance and the host's
administrative model. Do not copy a package-manager recipe from another
distribution. Do not add the runner to the Docker group or grant unrestricted
passwordless sudo merely to make deployment pass; the course boundary is SSH
to the separate `ansible` account.

## Completion criteria

- The runner service executes as the dedicated `gitlab-runner` identity.
- A non-mutating job proves the selected scope, executor, tags, and protected
  behavior before a deployment job is enabled.
- The runner can resolve and authenticate to the inventory host without an
  interactive prompt.
- A harmless repository change produces a successful pipeline.
- A deliberate managed configuration change becomes active on the running
  stack through the pipeline.
- A deliberate deployment error produces a failed job with useful evidence.
- Correcting the error and retrying or pushing again succeeds.
- Vault-protected inputs are available without appearing in logs or repository
  plaintext.
- Training Lab deployment does not modify the GitLab Compose project.
- You can identify the runner user, working directory, SSH identity, Ansible
  configuration, and dependency locations used by the job.

## Research prompts

- Which assumptions from an interactive shell do not exist in a runner job?
- Which runner scope, tags, and protected settings match the intended
  deployment branches?
- Which permissions does the runner actually need, and which broad
  permissions merely hide an incomplete design?
- Should a job deploy from its checkout or copy content elsewhere, and what are
  the consequences?
- How can concurrent deployments interfere with one another?
- Which file changes truly require a full deployment?
- What would be required to make jobs ordered, serialized, or dependency
  aware?

## Vendor references

- [Install GitLab Runner](https://docs.gitlab.com/runner/install/)
- [Register a runner](https://docs.gitlab.com/runner/register/)
