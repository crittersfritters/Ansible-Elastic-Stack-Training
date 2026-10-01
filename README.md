# Ansible Elastic Stack Training Lab — Vault checkpoint

This answer-sheet checkpoint adds the credential transition to the complete seven-project Ansible deployment. The reference first proves the automation with a local plaintext variable file, then encrypts that file with Ansible Vault before CI is introduced.

The manual, first-role, and complete pre-Vault states remain available on
`answers/01-manual`, `answers/02-first-role`, and
`answers/03-full-ansible`. GitLab remains a separate Compose project outside
Ansible ownership.

## Manual-to-Vault progression

Follow [the identity and Vault guide](docs/identity-and-vault.md) to create the dedicated `ansible` account, SSH trust, privilege boundary, and later runner identity. For the first local run:

```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
chmod 0600 group_vars/all/vault.yml
${EDITOR:-vi} group_vars/all/vault.yml
ansible-playbook roles-all.yml
```

After that run and an unchanged idempotence run succeed, encrypt the whole variable file:

```bash
ansible-vault encrypt group_vars/all/vault.yml
git add -f group_vars/all/vault.yml
```

The plaintext path is ignored; deliberately track only the encrypted result. `vault_password.sh` reads the password from `ANSIBLE_VAULT_PASSWORD` and never stores it in the repository.

Use [the first-deployment checklist](docs/first-deployment.md) to collect evidence. The following checkpoint adds the protected GitLab deployment path; do not give the runner Docker-group membership or unrestricted passwordless root.
