# Milestone 06: Complete manual stack

## Goal

Prove that the complete manually constructed stack works before replacing its
deployment steps with Ansible.

## Behavioral requirements

- All seven Training Lab Compose projects operate together on the host.
- GitLab remains independently managed and available.
- Zeek, Suricata, and mission events each traverse their intended complete
  path.
- Persistent state and configuration survive ordinary service recreation.
- Startup dependencies have observable readiness checks or controlled order.
- Routine operation never relies on removing every host container or deleting
  unrelated state.

## Completion criteria

- Each long-running container reaches its intended usable state.
- One-shot services finish successfully and can be repeated safely.
- One known Zeek event, one known Suricata event, one valid mission record, and
  one invalid mission record reach their expected outcomes.
- Restarting or recreating one project produces understood, bounded effects.
- GitLab and its project remain untouched by Training Lab lifecycle work.
- Every runtime file can be traced back to a committed source file or a
  deliberately persistent data location.
- The working manual state is committed before Ansible work begins.

## Research prompts

- Which dependencies require ordering, and which require retryable readiness?
- What is configuration, what is generated state, and what is durable data?
- Which failure would currently require manual recovery?
- How would another learner reproduce your working state from the repository?
- Which manual steps are candidates for shared automation?
