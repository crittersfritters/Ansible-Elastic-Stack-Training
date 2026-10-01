# Ansible Elastic Stack Training Lab maintainer publication guide

The course is maintained in one canonical repository and mirrored to the
public repository. The learner curriculum is the default branch. Major answer
phases are branches, not release tags. A published course release consists of
a recorded branch-to-commit manifest plus verified bundle and archive
artifacts.

## Canonical branch chain

| Branch | Role |
|---|---|
| `training` | Default learner curriculum, samples, contracts, and observable completion criteria without working stack code |
| `answers/01-manual` | Complete manual seven-project data stack |
| `answers/02-first-role` | First idempotent Ansible role and transition boundary |
| `answers/03-full-ansible` | All seven projects reconstructed through Ansible |
| `answers/04-vault` | Plaintext-to-Ansible-Vault credential progression |
| `answers/05-gitlab-ci` | Protected dependency-aware GitLab deployment phase |
| `answer-sheet` | Final hardened reference, validation harness, and operations guidance |

The required ancestry is:

```text
training
  -> answers/01-manual
  -> answers/02-first-role
  -> answers/03-full-ansible
  -> answers/04-vault
  -> answers/05-gitlab-ci
  -> answer-sheet
```

Keep `training` as the default branch. Protect every branch in the table from
deletion and force pushes. Require maintainer-level direct pushes or reviewed
merge requests according to the local administration model.

The `answers/*` branches are reference snapshots, not deployment refs. Their
CI workflow explicitly refuses to create a deployment pipeline on an
`answers/*` branch. To exercise the CI phase, create and deliberately protect a
personal integration branch from `answers/05-gitlab-ci`. The final
`answer-sheet` branch remains eligible for the validated protected deployment
path.

The answer implementation is not an access boundary. Anyone who can read the
repository can inspect the reference branches. Use a separate private
distribution mechanism only if a future delivery must delay solution access.

## Clean-history construction

Never create `training` by committing an answer tree and later deleting its
files. Deleted solutions remain readable in history.

For a clean publication:

1. Start a new repository with no imported objects, tags, alternate object
   directories, replace refs, or grafts.
2. Commit the reviewed learner snapshot as the root and point `training` to
   that commit.
3. Replace the complete tree with each reviewed phase snapshot in the order
   listed above, committing one meaningful phase at a time.
4. Point each `answers/*` branch at its corresponding commit and point
   `answer-sheet` at the final commit.
5. Scan every reachable commit, tree, blob, branch name, commit subject, commit
   body, author field, committer field, and configuration file for retired
   identifiers and secrets before publication.
6. Confirm that no answer implementation is reachable from `training`.

The learner root is an ancestor of the reference chain, but the answer commits
are descendants and therefore are not reachable by walking backward from
`training`.

## Maintaining zero-behind ancestry

Do not advance `training` and leave the answer branches on the old lineage.
That creates a diverged comparison and makes the reference branches appear
behind the default branch.

When `training` changes:

1. merge the reviewed learner change forward into `answers/01-manual`;
2. reconcile that phase without copying answer content back into `training`;
3. merge `answers/01-manual` forward into `answers/02-first-role`;
4. continue through every later phase and finally `answer-sheet`; and
5. rerun ancestry, leakage, and branch-specific validation before publishing.

When an answer phase changes without a learner-contract change, update that
phase and merge it forward through every downstream reference branch. Do not
merge an answer branch into `training`.

Use ordinary forward commits and merges after publication. Do not rebase or
force-update the protected branch chain merely to make its graph linear. If a
future redesign cannot preserve the published ancestry safely, build and
validate a new clean course generation rather than rewriting clones already in
use.

Before publication, all of these commands must succeed:

```bash
git merge-base --is-ancestor training answers/01-manual
git merge-base --is-ancestor answers/01-manual answers/02-first-role
git merge-base --is-ancestor answers/02-first-role answers/03-full-ansible
git merge-base --is-ancestor answers/03-full-ansible answers/04-vault
git merge-base --is-ancestor answers/04-vault answers/05-gitlab-ci
git merge-base --is-ancestor answers/05-gitlab-ci answer-sheet
```

## Curriculum-to-answer traceability

Maintain the final-branch traceability matrix with one row per training
milestone:

| Field | Meaning |
|---|---|
| Milestone identifier | Stable curriculum label |
| Training document | Goal and completion-criteria location |
| Required sample | Input used to prove behavior |
| Interface contract | Names, ports, topics, fields, or destinations that must agree |
| Earliest answer branch | First phase snapshot satisfying the milestone |
| Automated answer test | Validation proving the reference remains correct |

This mapping is for course maintenance. Do not copy implementation paths into
learner instructions when they would reveal the solution more directly than
intended.

## Validation gates

Do not publish a release manifest or distribution artifact until every
applicable gate passes. A candidate may be distributed for target-host testing
only when all deferred runtime gates are listed explicitly.

### Static answer validation

- All YAML and structured configuration parses.
- All seven Compose projects render without unresolved variables.
- The GitLab Compose project renders independently with the pinned image and
  exact loopback publications.
- Secret-silent inventory validation confirms one host in every intended group
  without logging or saving resolved host variables.
- Ansible playbooks pass syntax checks.
- Required roles and collections resolve at pinned versions.
- Logstash and Filebeat configurations pass their native configuration tests.
- CI configuration passes validation for the pinned GitLab version.

### Runtime answer validation

- GitLab and its runner remain operational while the Training Lab stack is
  deployed, updated, and reset.
- Elasticsearch, Kafka, processing Logstash, the port router, Kibana, and both
  Filebeat projects reach their intended states.
- The one-shot Kafka topic initializer exits successfully and all required
  topics exist.
- Zeek and Suricata create fresh readable events.
- Zeek, Suricata, and mission events traverse their complete paths.
- Valid mission samples receive required fields, parser identity, source-event
  time, and destination routing.
- Unmatched, timed-out, and malformed samples follow their specified failure
  behavior.
- Persistent state survives documented ordinary container recreation.

### Ansible answer validation

- A clean `/var/docker` deployment tree can be reconstructed.
- Host preparation executes once against the one physical host.
- A second unchanged run is idempotent.
- Deliberate drift is corrected.
- A changed bind-mounted configuration becomes active without an undocumented
  manual restart.
- Deployment never removes, recreates, or changes the GitLab Compose project.
- A correct Vault password permits a secret-silent decryption check, while a
  deliberate incorrect password fails without exposing credential material.

### GitLab answer validation

- A non-mutating preflight uses the expected protected shell runner.
- The runner reaches `ansible@training-lab.local` through SSH.
- Dependency installation is reproducible from the pinned manifest.
- Every job that evaluates Ansible inventory or syntax prepares the encrypted
  Vault password client and pinned collections first.
- Parent validation never logs or saves decrypted Vault content or raw
  resolved inventory.
- The changed-path acceptance cases select the expected jobs and order.
- Selected failures stop later stages and remain visible.
- `training-lab-pipeline` and `training-lab-deployment` prevent overlapping
  mutations without deadlocking the parent and child pipelines.
- A successful CI change is observable in the running service.
- The protected `answers/*` branches do not create deployment pipelines.

### Training-branch validation

- Instructions contain goals, contracts, completion criteria, and research
  prompts rather than completed implementation.
- All seven Compose projects remain learner-created.
- No working Ansible playbook, role, Filebeat configuration, Logstash pipeline,
  Grok pattern, Kafka configuration, or deployment pipeline is present.
- Supplied expected outcomes reveal document behavior, not implementation
  syntax.
- GitLab bootstrap guidance does not include completed Compose YAML.
- Every milestone is achievable using the corresponding answer phase.
- Links, filenames, samples, and terminology are internally consistent.

### Leakage and history audit

Search the `training` tree and every commit reachable from it for:

- answer-only filenames;
- complete Compose service definitions;
- Ansible module invocations and finished task sequences;
- complete Grok expressions;
- Filebeat and Logstash output blocks;
- Kafka listener configuration;
- the dependency-aware CI map;
- credentials, tokens, private keys, and Vault passwords; and
- archived or generated files containing any of the above.

Review matches manually. Absence of one keyword is not proof that a solution
did not leak.

## Publication procedure

1. Freeze the intended tips of all seven canonical branches.
2. Record every branch name and full commit ID.
3. Verify the six required ancestor relationships.
4. Complete all applicable validation gates and retain only secret-safe
   evidence.
5. Confirm `training` is the default branch and every canonical branch has the
   intended protection.
6. Create and verify the complete Git bundle.
7. Create branch archives from the recorded commit IDs rather than mutable
   names.
8. Generate checksums and a release manifest containing the branch map,
   validation date, and relevant tool versions.
9. Clone or extract every artifact into a temporary location and verify it
   independently.
10. Confirm the public mirror has the same branch heads, default branch, and no
    unexpected refs.

## Git bundle export

A Git bundle preserves the clean history and all canonical branches. From a
clean repository with `training` checked out:

```bash
git status --short
git bundle create ansible-elastic-stack-training-course-1.0.bundle \
  HEAD \
  refs/heads/training \
  refs/heads/answers/01-manual \
  refs/heads/answers/02-first-role \
  refs/heads/answers/03-full-ansible \
  refs/heads/answers/04-vault \
  refs/heads/answers/05-gitlab-ci \
  refs/heads/answer-sheet
git bundle verify ansible-elastic-stack-training-course-1.0.bundle
```

Verify that the advertised refs contain exactly the intended branch set. A
normal clone of this bundle selects `training` because the bundle's `HEAD`
points to the learner branch.

The bundle contains all answers. Do not use it if a future delivery must hide
the reference implementation.

Branch protection, default-branch selection, runners, CI/CD variables, mirror
configuration, and other hosted settings are not stored in a Git bundle and
must be recreated separately.

## Branch archive exports

ZIP exports are convenience snapshots and do not contain Git history. Resolve
each branch once and archive that frozen commit ID:

```bash
while IFS='|' read -r artifact branch; do
  commit=$(git rev-parse "refs/heads/$branch")
  git archive \
    --format=zip \
    --output="ansible-elastic-stack-training-course-1.0-${artifact}.zip" \
    "$commit"
  printf '%s %s\n' "$branch" "$commit"
done <<'EOF'
training|training
answers-01-manual|answers/01-manual
answers-02-first-role|answers/02-first-role
answers-03-full-ansible|answers/03-full-ansible
answers-04-vault|answers/04-vault
answers-05-gitlab-ci|answers/05-gitlab-ci
answer-sheet|answer-sheet
EOF
```

Inspect and independently extract every archive. Run the applicable static
checks and confirm the learner archive contains no answer-only material.

Generate checksums only after all artifacts are final:

```bash
sha256sum \
  ansible-elastic-stack-training-course-1.0.bundle \
  ansible-elastic-stack-training-course-1.0-*.zip \
  > ansible-elastic-stack-training-course-1.0.sha256
```

Checksums prove that downloaded bytes match the published artifacts; they do
not replace signature verification or repository access controls.

## Release manifest

Publish a small text or Markdown manifest containing:

- course version and publication date;
- every canonical branch and its full commit ID;
- results of all six ancestry checks;
- artifact filenames, byte sizes, and SHA-256 checksums;
- pinned GitLab, Elastic Stack, Kafka, Ansible, role, and collection versions;
- host platform used for runtime validation;
- validation gates completed and any explicitly deferred tests;
- GitLab and public-mirror default branches and head verification; and
- known disposable-lab limitations.

Never claim runtime validation for a check performed only by parsing or static
inspection.

## Updating a published course

For a learner-contract correction, update `training` and merge the change
forward through every reference branch before publishing. For an answer-only
correction, begin at the earliest affected answer branch and merge forward
through `answer-sheet`.

For new milestones, service contracts, sample formats, version changes, or
different expected output, publish a new course version in the manifest and
artifact filenames. Preserve already distributed bundles and manifests so an
active learner can finish against the version they started.

At each update, ask two separate questions:

1. Does the answer implementation still work on the tested host?
2. Does `training` still require the learner to discover the answer?

A course publication is incomplete if only one of those is true.
