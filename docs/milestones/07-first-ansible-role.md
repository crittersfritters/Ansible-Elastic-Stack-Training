# Milestone 07: First Ansible role

## Goal

Create the dedicated `ansible` account and use one Ansible role to reconstruct
the Elasticsearch project over SSH to localhost.

## Behavioral requirements

- The `ansible` account is distinct from the learner account and the future
  runner service identity.
- Key-based SSH, host-key verification, and privilege escalation work through
  the intended account.
- One inventory host represents the physical host and belongs to all service
  groups it will eventually serve.
- The first role owns Elasticsearch files and lifecycle behavior without
  managing GitLab.
- Configuration changes become active through a documented automated action.

## Completion criteria

- Direct SSH to the inventory hostname succeeds as `ansible` using the
  intended key and host verification.
- Ansible connectivity and privilege escalation succeed without an interactive
  workaround hidden from the repository design.
- Removing the manually deployed Elasticsearch project allows the role to
  reconstruct it from committed content.
- A second unchanged run reports no unnecessary changes.
- A deliberate drift in a managed file is detected and corrected.
- A deliberate source change causes the minimum behavior needed to activate
  that change.
- You can explain inventory, group, play, role, task, variable, template, and
  handler using your implementation.
- You can demonstrate which value wins when the same harmless test variable is
  defined at two scopes, then remove the test override.

## Research prompts

- Why use SSH to localhost instead of an Ansible local connection in this lab?
- How can one inventory host belong to several service groups without running a
  common play several times?
- Which facts belong in defaults, variables, inventory, or encrypted data?
- What makes a task idempotent?
- When is a handler more appropriate than an unconditional restart?
- How can you observe variable precedence instead of memorizing a chart?
