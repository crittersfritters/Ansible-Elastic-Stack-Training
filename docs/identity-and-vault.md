# Answer sheet: localhost Ansible account and GitLab shell runner

## Reference model

The reference implementation keeps three identities separate even though all
services run on one Linux host.

| Identity | Responsibility | Must not become |
|---|---|---|
| Learner account | Interactive administration and course work | The CI service identity |
| `ansible` | SSH target and privileged configuration-management identity | A GitLab login or an interactive learner identity |
| `gitlab-runner` | Executes checked-out CI job scripts | A second unrestricted root account |

The shell runner invokes Ansible from its GitLab checkout. Ansible then makes
an SSH connection from `gitlab-runner` to `ansible@training-lab.local`, even
though that name resolves to the same machine. Privileged tasks use Ansible
become behavior under the `ansible` account.

This apparently indirect route is intentional. It preserves the account,
authentication, inventory, SSH, and privilege-escalation mechanics that the
learner will see when a controller manages remote hosts.

## Inventory shape

Use one inventory host, `training-lab.local`, and place that same host in all
six functional groups:

- `elasticsearch_nodes`;
- `web_servers`;
- `queue_nodes`;
- `logstash_nodes`;
- `port_router_nodes`; and
- `network_sensors`.

Resolve `training-lab.local` to `127.0.0.1` for the host-side SSH connection.
Keep application aliases such as `elasticsearch.local`, `queue-server.local`,
and `web.local` conceptually separate from the inventory target. They identify
services; they are not six pretend machines.

Do not create six inventory hosts that all point at `127.0.0.1`. A play against
`all` would then run host-scoped tasks six times against the same machine and
could produce false changes or conflicting Compose operations.

The same inventory hostname is a member of the host-preparation group and each
child service group. Set the connection to SSH and the remote user to
`ansible` in group variables. Do not set `ansible_host` to loopback: resolving
the inventory name is part of the exercise. Set any private-key path in an
environment-appropriate location rather than embedding key material in YAML.

## Configure the `ansible` identity

The exact account-management commands differ by distribution. The completed
state must satisfy these requirements:

1. `ansible` is a normal host account with a home directory and login shell.
2. Its `.ssh` directory and files are owned by `ansible` and have restrictive
   modes accepted by OpenSSH.
3. A dedicated public key is present in its `authorized_keys` file.
4. The account can use privilege escalation for the tasks the playbooks own.
5. The required become credential is stored in Ansible variables, begins as
   ignored plaintext for the learning progression, and is later encrypted with
   Ansible Vault.
6. Direct root SSH login is not enabled for the course.

The original training deliberately used an `ansible` account, SSH keys, an
inventory connection set to SSH, and a later Vault step. The localhost version
retains those mechanics rather than replacing them with
`ansible_connection: local`.

Verify the account outside Ansible first. From both the learner account and the
`gitlab-runner` account, establish an SSH session to
`ansible@training-lab.local` using the intended key. Then verify the intended
privilege escalation in a way that does not leave a root shell open.

## Host-key trust

Maintain a `known_hosts` entry for `training-lab.local` in the home directory
of every identity that initiates SSH. Verify the server fingerprint through a
trusted local method before accepting it.

The answer sheet does not solve host-key failures by disabling host-key
checking globally. A changed host key stops deployment until the cause is
understood. If the host SSH key is intentionally regenerated, update the
stored entry as a deliberate maintenance action.

## Runner installation and registration

Install GitLab Runner on the Linux host and run its service as
`gitlab-runner`. Do not install the runner inside the GitLab container.

Register it with these reference properties:

| Property | Reference value |
|---|---|
| GitLab URL | `http://gitlab.local:8929` |
| Executor | `shell` |
| Scope | Project runner for **Ansible Elastic Stack Training Lab** |
| Tag | `training-lab-local` |
| Run untagged jobs | Disabled when the reference jobs use the tag |
| Protected | Enabled; the reference pipeline also rejects unprotected refs |

Use the runner authentication token supplied by GitLab's current registration
workflow. Tokens belong in the runner's host configuration, not the repository
or project variables.

The `gitlab-runner` account needs:

- access to the GitLab working and cache directories;
- `git`, `ssh`, `ansible-playbook`, `ansible-galaxy`, and required validation
  programs in its noninteractive `PATH`;
- a private deployment key accepted by the local `ansible` account;
- a verified `known_hosts` entry for `training-lab.local`; and
- network access to GitLab and the local SSH listener.

It does not need direct ownership of Training Lab's runtime directories or
membership in a privileged Docker group when every host change is performed by
Ansible through the `ansible` account.

Treat membership in the Docker group as root-equivalent. Do not add
`gitlab-runner` merely to bypass a permission error.

## Deployment key handling

The reference lab uses a dedicated key pair for runner-to-Ansible SSH. Generate
it as `gitlab-runner` with no interactive passphrase because unattended CI must
use it. Limit the key to this disposable local training environment.

The private key stays in `gitlab-runner`'s protected home directory. It is not
stored as a repository file, echoed into job logs, or copied into GitLab's
container. The corresponding public key is appended to the `ansible` account's
`authorized_keys` file.

For a future shared or production-like system, prefer a key supplied through a
protected secret mechanism, constrain it using account and SSH policy, and use
a runner isolated for the target environment. The simple host-held key is a
course-specific choice.

## Ansible and Vault progression

At the manual-Ansible transition, the reference begins with a local ignored
plaintext `group_vars/all/vault.yml` so the learner can separate ordinary SSH
or playbook failures from encryption failures. The file holds only values that
must be secret, including the become credential if one is required. Do not
display, copy into a transcript, or otherwise log its plaintext content during
the transition.

Before enabling CI deployment:

1. confirm a manual playbook succeeds using the plaintext variables;
2. configure an executable Vault password client that emits the value of
   `ANSIBLE_VAULT_PASSWORD` without printing anything else;
3. encrypt the complete Vault variable file;
4. confirm only the encrypted Vault header, without displaying the file;
5. test successful decryption and a deliberate wrong-password failure with
   both command streams discarded;
6. add `ANSIBLE_VAULT_PASSWORD` as a normal GitLab CI/CD variable, not a File
   variable, and mark it masked and protected; and
7. confirm every branch allowed to use that protected variable is itself
   protected.

Run the transition from a shell with command tracing disabled. Encrypt the
working file in place, then inspect only its header:

```bash
(
  set -euo pipefail
  set +x
  ansible-vault encrypt group_vars/all/vault.yml

  vault_header=
  IFS= read -r vault_header < group_vars/all/vault.yml || true
  if [[ "$vault_header" == '$ANSIBLE_VAULT;'* ]]; then
    printf '%s\n' 'Vault header check: PASS'
  else
    printf '%s\n' 'Vault header check: FAIL' >&2
    exit 1
  fi
)
```

Do not use `cat`, `head`, `ansible-vault view` without redirection, or an
inventory command that serializes resolved host variables to prove the
transition. Once Ansible loads an encrypted variable file, commands such as
`ansible-inventory --list`, `ansible-inventory --host`, and
`ansible-inventory --graph --vars` can disclose decrypted values. Use the
plain `ansible-inventory --graph` view or repository validation, which emits
only the expected inventory contract.

Verify the real password without exposing decrypted content. The prompt below
does not echo input, and both output streams from the decryption operation are
discarded:

```bash
(
  set -euo pipefail
  set +x
  read -rsp 'Vault password: ' ANSIBLE_VAULT_PASSWORD
  printf '\n'
  export ANSIBLE_VAULT_PASSWORD
  export ANSIBLE_VAULT_PASSWORD_FILE="$PWD/vault_password.sh"

  if ansible-vault view group_vars/all/vault.yml >/dev/null 2>&1; then
    printf '%s\n' 'Correct-password test: PASS'
  else
    printf '%s\n' 'Correct-password test: FAIL' >&2
    exit 1
  fi
)
```

Then prove that a deliberately incorrect value is rejected, again without
displaying either stream:

```bash
(
  set -euo pipefail
  set +x
  if ANSIBLE_VAULT_PASSWORD='intentionally-wrong-course-test-value' \
     ANSIBLE_VAULT_PASSWORD_FILE="$PWD/vault_password.sh" \
     ansible-vault view group_vars/all/vault.yml >/dev/null 2>&1
  then
    printf '%s\n' 'Wrong-password test: FAIL' >&2
    exit 1
  else
    printf '%s\n' 'Wrong-password test: PASS'
  fi
)
```

`vault_password.sh` is a password client, not a diagnostic command. Never run
it directly, source it, or invoke it under `bash -x` or shell `set -x`; each of
those actions can print the secret. Keep GitLab's `CI_DEBUG_TRACE` disabled for
jobs that receive the Vault variable, and do not place the password or an
`ANSIBLE_VAULT_PASSWORD` assignment in `/etc/environment`, a profile, or any
tracked file.

The pipeline checks the file header before requiring the CI variable. This
allows the answer history to demonstrate both the plaintext teaching stage and
the encrypted final stage without two variable-file paths.

Masking protects ordinary log display; it is not an authorization boundary.
Branch protection, runner protection, job review, and repository permissions
must agree with the variable's protection setting.

In this localhost design, the runner holds an SSH key accepted by the
privileged `ansible` account and can receive the Vault become credential.
Anyone who can change deployable CI code on a protected ref can therefore gain
root-equivalent control of the lab host. Protect every ref allowed to deploy,
keep the `answers/*` phase branches excluded from deployment, restrict who may
merge or push deployable changes, require review for CI and Ansible changes,
and dedicate this runner to the training project.

## Verification sequence

Run each check as the identity named in the first column.

| Identity | Check | Expected evidence |
|---|---|---|
| Learner | Resolve `training-lab.local` | It resolves to the local loopback address. |
| Learner | SSH to `ansible@training-lab.local` | Key authentication succeeds and the remote identity is `ansible`. |
| `ansible` | Perform the intended become operation | The task succeeds using the configured credential or policy. |
| `gitlab-runner` | Resolve and SSH to the inventory host | The same account boundary works noninteractively. |
| `gitlab-runner` | Run `ansible-inventory --graph` from a checkout | One host appears in every required functional group. |
| `gitlab-runner` | Run an Ansible ping module through the repository configuration | The SSH transport succeeds without prompting. |
| GitLab job | Execute a non-mutating preflight job | The runner tag selects the expected shell runner. |
| GitLab job | Run the secret-silent static preflight | Correct Vault input and pinned dependencies allow validation without resolved variables in the log. |

Do not proceed to a mutating CI deployment until all non-mutating checks pass.

## Common failure distinctions

| Symptom | Investigate first |
|---|---|
| Runner remains pending | Job tag, runner tag, runner scope, protected-runner setting, and runner service status |
| GitLab clone fails over SSH | Advertised port, published port, user key, and clone URL |
| Ansible reports host unreachable | Name resolution, host SSH service, deployment key, file modes, and `known_hosts` |
| SSH works but become fails | `ansible` account privilege policy and Vault variable loading |
| Manual playbook works but CI fails | Runner `PATH`, runner home, checkout-relative paths, environment variables, and key ownership |
| Vault works manually but not in CI | Variable scope/protection, password client executable bit, and branch protection |
