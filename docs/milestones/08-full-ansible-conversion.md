# Milestone 08: Full Ansible conversion

## Goal

Convert all seven Training Lab projects to an idempotent Ansible deployment
and factor repeated behavior only where it is genuinely shared.

## Behavioral requirements

- Every project has clear automation ownership.
- Reusable behavior is separated from service-specific configuration.
- Repeated deployment mechanics use at least one reusable include or equivalent
  composition mechanism whose inputs are explicit.
- Deployment order and readiness reflect real dependencies.
- Host directories, permissions, configuration changes, and service lifecycle
  are managed deliberately.
- The automation can construct Training Lab from a clean deployment location
  while leaving GitLab untouched.

## Completion criteria

- A clean run builds all seven projects and the three end-to-end data paths.
- A second complete run is idempotent.
- Altering a managed file or ownership setting is repaired by the next run.
- A changed external configuration becomes active without an undocumented
  manual restart.
- Re-running topic setup is safe.
- Automation stops with useful failure evidence when a required service never
  becomes ready.
- GitLab containers, files, and persistent state are unchanged by the run.
- The manual checkpoint can still be inspected through Git history.

## Research prompts

- Which actions are common deployment mechanics and which express service
  behavior?
- How should readiness be represented when a container health state is absent
  or insufficient?
- When should a role use a file, template, variable, or default?
- How can automation avoid broad container or firewall reconciliation?
- Which downstream services actually depend on a changed component?
