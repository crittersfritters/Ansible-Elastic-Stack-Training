# Answer phase branches

The reference implementation is published as a protected branch chain. Each
branch captures the first complete state for one major construction phase.
Later phase branches descend from earlier ones, and every reference branch
descends from the learner `training` branch.

| Course phase | Reference branch |
|---|---|
| Learner curriculum and observable contracts | `training` |
| Complete seven-project manual stack | `answers/01-manual` |
| First idempotent Ansible role | `answers/02-first-role` |
| All seven projects managed through Ansible | `answers/03-full-ansible` |
| Plaintext-to-Ansible-Vault transition | `answers/04-vault` |
| Protected dependency-aware GitLab deployment | `answers/05-gitlab-ci` |
| Hardened reference, validation, and operations guidance | `answer-sheet` |

The reference branches replace the former checkpoint-tag model. Do not create
or move answer checkpoint tags. Protect every listed branch from deletion and
force pushes, keep `training` as the default branch, and publish branch updates
through reviewed forward history.

The manual branch contains concrete Compose projects and setup scripts. Later
branches progressively replace manual deployment with Ansible, Vault, and CI.
The final branch contains the maintained validation and operations material.

To inspect a phase without disturbing the current worktree:

```bash
git fetch origin \
  training \
  answers/01-manual \
  answers/02-first-role \
  answers/03-full-ansible \
  answers/04-vault \
  answers/05-gitlab-ci \
  answer-sheet

git worktree add --detach \
  ../ansible-elastic-stack-manual \
  origin/answers/01-manual
```

Remove the detached worktree with `git worktree remove` after comparison. A
branch archive is only a tree snapshot; use the release bundle when branch
ancestry and the complete phase progression must be preserved.

Before publication, prove the required ancestry explicitly:

```bash
git merge-base --is-ancestor training answers/01-manual
git merge-base --is-ancestor answers/01-manual answers/02-first-role
git merge-base --is-ancestor answers/02-first-role answers/03-full-ansible
git merge-base --is-ancestor answers/03-full-ansible answers/04-vault
git merge-base --is-ancestor answers/04-vault answers/05-gitlab-ci
git merge-base --is-ancestor answers/05-gitlab-ci answer-sheet
```

All six commands must succeed. This ancestry prevents a phase branch from
appearing behind `training` while retaining the intended learner-to-reference
progression.
