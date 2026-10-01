# GitLab bootstrap reference

This project is deliberately outside `/var/docker` and outside Ansible's
ownership. It shares the host Docker daemon with Training Lab, so the stack
playbooks must never install, reconfigure, restart, or prune Docker.

The course contract preserves the existing lab instance exactly: GitLab EE
`19.4.1-ee.0`, Compose project/service/container name `gitlab`, canonical URL
`http://gitlab.local:8929`, and advertised Git SSH port `2424`. This is a
reproducible course baseline, not a recommendation to install an old release
on another system. Changing its version or edition is a separate maintainer-led
upgrade and migration exercise.

## Docker SELinux prerequisite

Complete this host prerequisite before creating GitLab on Fedora or another
SELinux-enforcing host. Install the distribution's container policy and
confirm enforcement remains enabled:

```bash
sudo dnf install container-selinux
rpm -q container-selinux selinux-policy-targeted
getenforce
```

The same policy package must provide the `container_logreader_t` domain used
later by the native Suricata-log collector. The sensor preflight verifies that
domain before it creates either collector project.

Docker must start containers with SELinux separation enabled. If
`/etc/docker/daemon.json` already exists, preserve every existing key and add
`"selinux-enabled": true` to the same JSON object. Do not replace an existing
file with the minimal example below. For a host with no daemon configuration,
create the directory and use this complete file:

```bash
sudo install -d -o root -g root -m 0755 /etc/docker
sudoedit /etc/docker/daemon.json
```

```json
{
  "selinux-enabled": true
}
```

Keep the file owned by root and validate the merged configuration before
touching the daemon:

```bash
sudo chown root:root /etc/docker/daemon.json
sudo chmod 0644 /etc/docker/daemon.json
sudo restorecon -v /etc/docker/daemon.json
sudo dockerd --validate --config-file /etc/docker/daemon.json
```

Restarting Docker interrupts GitLab and every other workload using this host
daemon. Before a controlled restart, inventory the containers and record the
owning Compose project, working directory, and configuration files:

```bash
docker ps -a \
  --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker ps -aq | xargs -r docker inspect \
  --format 'name={{.Name}} project={{index .Config.Labels "com.docker.compose.project"}} workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} files={{index .Config.Labels "com.docker.compose.project.config_files"}}'
```

Schedule the interruption, restart the daemon, and verify that Docker now
reports `name=selinux` in its security options:

```bash
sudo systemctl restart docker
docker info --format '{{json .SecurityOptions}}'
```

SELinux process labels are assigned when a container is created. A daemon
restart or `docker restart` does not retrofit labels onto existing containers.
For each pre-existing Compose project from the inventory, use its recorded
working directory and Compose files to recreate that project deliberately. For
an existing canonical GitLab project, the operation is:

```bash
cd /var/training/gitlab
docker compose config --quiet
docker compose up -d --force-recreate --pull never gitlab
```

Use the original deployment method for containers that are not owned by
Compose. After GitLab is recreated, verify that its process label contains
`container_t`; an empty label or `spc_t` means the daemon setting was not
applied to that container:

```bash
docker inspect \
  --format 'process_label={{.ProcessLabel}} mount_label={{.MountLabel}} security_options={{json .HostConfig.SecurityOpt}}' \
  gitlab
```

Before a fresh installation, make `gitlab.local` resolve to `127.0.0.1` and
confirm ports `8929`, `443`, and `2424` are free. Create the canonical project
root and its three persistent bind-mount directories, then install the
reference Compose file there so Compose records `/var/training/gitlab` as the
project working directory:

```bash
sudo install -d -m 0755 \
  /var/training/gitlab \
  /var/training/gitlab/config \
  /var/training/gitlab/logs \
  /var/training/gitlab/data
sudo install -m 0644 \
  bootstrap/gitlab/docker-compose.yml \
  /var/training/gitlab/docker-compose.yml
cd /var/training/gitlab
docker compose config
docker compose up -d
docker logs -f gitlab
```

On SELinux hosts, the `:Z` mount suffixes assign private container labels to
these directories. Inspect the resulting labels and permissions rather than
disabling enforcement. Bind-path relabeling does not enable SELinux process
separation in Docker; the daemon prerequisite above remains mandatory.

If `/var/training/gitlab` already contains an installation, do not copy the
reference file over it or start a second project. Back up and inspect the live
Compose file, its rendered model, container image, labels, mounts, and port
bindings first. Reconcile only intentional differences and preserve
`config`, `logs`, and `data`; this course does not require a GitLab upgrade or
an EE-to-CE conversion.

GitLab is ready when the container is healthy and
`http://gitlab.local:8929/users/sign_in` responds. Port `443` is a preserved,
loopback-only course publication. Publishing it does not configure TLS while
`external_url` remains HTTP, so HTTPS is not a bootstrap readiness check.

Retrieve the one-time initial administrator password without copying it into
the repository and replace it immediately. If that temporary file is no
longer present, follow GitLab's documented root-password reset procedure.
Creating the host runner is deliberately deferred to Milestone 10; an existing
runner is not changed by this bootstrap.

On a headless host, forward workstation port 8929 to host loopback over SSH,
map `gitlab.local` to `127.0.0.1` on the workstation, and browse the canonical
URL above. Keep all three Compose publications bound to loopback.

This Compose file is shared by the answer reference branches. The `training`
branch specifies the same observable requirements but leaves the YAML to the
learner.
