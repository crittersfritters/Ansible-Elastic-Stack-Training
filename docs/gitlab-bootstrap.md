# Build the local GitLab environment

## Why this milestone is more explicit

GitLab is the entry point for the rest of the course. You cannot use a local
GitLab project until the service exists, so this milestone provides a firmer
contract than later Training Lab exercises.

You will still write the Compose file yourself. This document identifies the
required pieces and the result to prove; it does not provide completed YAML.

GitLab is bootstrap infrastructure. Keep its Compose project, configuration,
and persistent state separate from the seven Training Lab Compose projects.
Later Ansible work must not manage or remove this project.

## Starting point and required capabilities

Obtain the `training` branch from the maintainer's Git account by cloning it or
copying the branch archive. At this point, the authoritative copy is upstream;
your local GitLab does not exist yet.

Use a maintained Linux host that can provide the following capabilities:

- Git;
- Docker Engine with the Docker Compose v2 plugin;
- an SSH client and host SSH service;
- Python 3 with YAML and HTTP client libraries;
- Ansible Core and `ansible-galaxy`; and
- ordinary network, process, storage, and text-inspection tools.

Install them using current documentation for the selected host and each
upstream project. The course intentionally does not translate package names,
repositories, service units, or upgrade commands for a particular
distribution. Those are host-administration decisions, not Training Lab
contracts.

Verify the resulting capabilities rather than assuming that installation
completed correctly:

```bash
git --version
docker version
docker compose version
docker run --rm hello-world
ssh -V
python3 --version
ansible-playbook --version
ansible-galaxy --version
python3 -c 'import yaml, requests; print(yaml.__version__, requests.__version__)'
```

Use the host's intended administrative model if Docker requires privilege
escalation. Membership in Docker's control group is root-equivalent; grant it
deliberately rather than treating it as an ordinary convenience group.

A host-wide Ansible installation is intentional. The later shell runner must
execute the same tools without inheriting the learner's interactive shell
configuration.

Install Zeek and Suricata later in Milestone 02, not as hidden containers
during this bootstrap.

Before proceeding, the host must have these capabilities:

- Docker Engine and the Docker Compose plugin;
- Git;
- an SSH client and server;
- a hostname entry that resolves `gitlab.local` to the local host; and
- enough available CPU, memory, and disk for GitLab plus the later training
  stack.

Do not continue until an ordinary test container and a small test Compose
project both run successfully.

## Reserve non-conflicting endpoints

The complete course runs GitLab and Training Lab on the same machine. Before
writing the GitLab project, inventory the ports already listening on the host
and verify that the fixed course ports `8929` for HTTP, the preserved port
`443` publication, and `2424` for Git SSH are free. Do not bind the container's
SSH service to host port `22`; that port belongs to the host SSH server used by
Ansible. Publish all three course ports only on `127.0.0.1`; the
unauthenticated training instance must not be reachable from another host.

Add `127.0.0.1 gitlab.local` to `/etc/hosts` with an administrative editor and
prove that `getent hosts gitlab.local` returns loopback before starting GitLab.

Because the web listener is loopback-only, open it in a browser on the training
host. For a headless host, use an authenticated SSH local-forward from the
administrative workstation, for example `-L 8929:127.0.0.1:8929`. Map
`gitlab.local` to `127.0.0.1` on that workstation and browse
`http://gitlab.local:8929` so GitLab's canonical external URL still agrees
with the browser request. Do not solve access by changing the publication to
`0.0.0.0`.

## Create the Compose project

Create the dedicated GitLab project at `/var/training/gitlab`, with its Compose
file directly in that directory. Its contents must not be nested inside a
Training Lab service directory.

Write a Compose file with one GitLab service. It must satisfy every item in
this table.

| Area | Requirement |
|---|---|
| Image | Use the exact course baseline `gitlab/gitlab-ee:19.4.1-ee.0`. Do not substitute CE, `latest`, or another release. |
| Project identity | Use `gitlab` as the Compose project, service, and container name. |
| Hostname | Configure GitLab to identify itself as `gitlab.local`. |
| Network mode | Use ordinary Compose port publishing rather than host networking. GitLab's internal SSH listener must remain distinct from the host SSH listener. |
| External web URL | Set GitLab's `external_url` to `http://gitlab.local:8929`. |
| Advertised SSH port | Set `gitlab_rails['gitlab_shell_ssh_port']` to `2424`. |
| Published ports | Publish exactly `127.0.0.1:8929` to container port `8929`, `127.0.0.1:443` to container port `443`, and `127.0.0.1:2424` to container port `22`. |
| Persistence | Bind-mount `/var/training/gitlab/config`, `/var/training/gitlab/logs`, and `/var/training/gitlab/data` to `/etc/gitlab`, `/var/log/gitlab`, and `/var/opt/gitlab`, respectively. Account for SELinux labeling. |
| Restart behavior | Configure GitLab to return after an ordinary host or Docker restart. |
| Shared memory | Allocate at least 256 MiB of shared memory to the GitLab service. |
| Secrets | Do not commit a root password, runner authentication token, personal access token, or SSH private key in the Compose file. |

The GitLab image supports embedded configuration through its documented
environment setting. Use it to keep the external URL and advertised SSH port
consistent with the ports you publish. The port `443` publication preserves a
course endpoint; it does not enable TLS while the external URL remains HTTP.
Investigate the relationship among the
external URL, the internal listener, the published host port, and the clone URL
before starting the service.

The pinned EE 19.4.1 image records the existing course environment. Treat an
edition or version change as a maintainer-led contract revision that requires
an upgrade plan and complete revalidation, not as a learner-selected bootstrap
variation.

The three persistent locations have different purposes:

- configuration is needed to reproduce how the instance is configured;
- logs are needed to diagnose startup and application failures; and
- application data contains repositories and database state.

Use the required `/var/training/gitlab` host paths so they cannot be swept up
by a Training Lab reset. Account for the host's file permissions and any
active mandatory-access-control mechanism.

## Start and initialize GitLab

Run Compose from `/var/training/gitlab` and render the configuration before
starting it. Resolve syntax errors, unexpanded variables, invalid mounts, and
port collisions before proceeding.

Start the project and observe its logs. GitLab takes longer to initialize than
a small single-process container. A running container is not sufficient proof
that the application is ready.

When the web interface responds:

1. obtain or reset the initial administrator credential without placing it in
   the repository;
2. sign in and replace any temporary credential;
3. create the learner's normal account;
4. decide whether routine work needs administrator privileges rather than
   using the root account by default; and
5. add a public SSH key or create a narrowly scoped access token if your chosen
   Git workflow requires one.

Keep credentials outside tracked files.

## Create the local training project

Create a blank project named **Ansible Elastic Stack Training Lab**. Avoid initializing it
with a second README if the imported repository already has commits.

Transfer the course repository into the project by either:

- adding the local GitLab project as a remote and pushing the existing branch;
  or
- using an import mechanism that preserves the existing commits.

The resulting project must contain the course history, not a single commit made
from an extracted working tree. Set `training` as the default branch. You may
work in a personal branch while keeping the imported branch unchanged.

Prove both a fetch and a push from the host. An SSH clone URL must have the
form `ssh://git@gitlab.local:2424/<namespace>/ansible-elastic-stack-training.git`; an
HTTP URL must have the form
`http://gitlab.local:8929/<namespace>/ansible-elastic-stack-training.git`. Substitute
your actual namespace without changing the course ports.

Clone the project back from local GitLab into a separate course working
directory. Confirm that the clone checks out `training` by default and retains
the supplied history. Use this local-GitLab clone for the remaining milestones.

## Defer the runner until the CI milestone

A runner is not required to create GitLab, transfer the repository, or build
the manual stack. Install, register, and prove the host shell runner in
Milestone 10, after the manual deployment, Ansible conversion, and Vault
progression are understood.

## Completion criteria

This milestone is complete only when all of the following are true:

- `gitlab.local` resolves on the host;
- the active Compose project, service, and container are all named `gitlab`;
- the active image is exactly `gitlab/gitlab-ee:19.4.1-ee.0`;
- the Compose configuration renders without error;
- the GitLab container becomes healthy and the sign-in page responds at
  `http://gitlab.local:8929/users/sign_in`;
- only loopback publishes `8929:8929`, `443:443`, and `2424:22`;
- the web and Git SSH ports do not displace host SSH or a Training Lab port;
- `/var/training/gitlab/config`, `/var/training/gitlab/logs`, and
  `/var/training/gitlab/data` remain after container recreation;
- the **Ansible Elastic Stack Training Lab** project preserves the imported history;
- the learner can fetch and push through the chosen Git transport;
- a fresh clone from local GitLab checks out `training` and retains history;
- stopping or recreating GitLab does not stop or delete an unrelated test
  Compose project.

Record the evidence used for each assertion. Screenshots alone are not enough
when a command, log, API response, or repeatable action can demonstrate the
behavior.

## Questions to investigate

- Why is the GitLab image pinned, and what must be evaluated before the course
  changes its edition or version?
- Why must GitLab's advertised external URL agree with its published port?
- Why does publishing port `443` not, by itself, enable HTTPS?
- Why is the container's SSH port mapped away from host port `22`?
- What state is lost if only GitLab's configuration directory is persistent?
- Which Git operations prove that the repository was transferred intact?

## Vendor references

- [Docker Engine installation](https://docs.docker.com/engine/install/)
- [GitLab in a Docker container](https://docs.gitlab.com/install/docker/installation/)
