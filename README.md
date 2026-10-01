# Ansible Elastic Stack Training Lab — GitLab CI checkpoint

This checkpoint adds the protected, dependency-aware GitLab deployment path to the complete Ansible and Vault implementation. It is intentionally more advanced than the learner's minimum: a learner-authored full reconciliation on an eligible push also satisfies the course objective.

Read [the GitLab CI reference](docs/gitlab-ci.md) together with [the identity and Vault guide](docs/identity-and-vault.md). The parent pipeline performs static validation, computes relevant changes, holds the shared-lab lock, and triggers ordered component reconciliation through the host shell runner. Every mutation still crosses SSH into the dedicated `ansible` account.

Only eligible protected branch pushes with deployment-relevant changes create
this reference pipeline. The published `answers/*` checkpoint branches are
reference-only and are explicitly excluded from deployment. To exercise this
phase, create a personal integration branch from `answers/05-gitlab-ci`,
protect it deliberately, and authorize it to use the protected runner and
variables. Protected variables, runner access, branch permissions, and review
of deployable CI content together form an effective root boundary for the
disposable lab.

Before enabling mutation, prove the runner's noninteractive PATH, repository checkout permissions, SSH host key, Ansible inventory, Vault decryption, and static validation. Then exercise the acceptance matrix in `docs/gitlab-ci.md` and verify the resulting service state, not just a green pipeline graph.

The final `answer-sheet` branch adds the validation harness, operational
guides, traceability matrix, and publication controls.
