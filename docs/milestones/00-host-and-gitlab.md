# Milestone 00: Host and GitLab bootstrap

## Goal

Prepare one Linux host, run GitLab as an independent Compose project, and make
the training repository usable from that instance.

## Behavioral requirements

- The host can run Compose projects and act as an Ansible controller.
- SSH is available for the later dedicated Ansible account.
- GitLab has a stable local hostname and does not take the host's normal SSH
  port away from system administration.
- GitLab configuration, logs, and application data persist outside a disposable
  container layer.
- The training repository can be pushed to and cloned from local GitLab.

## Create the GitLab Compose project

This bootstrap is the only course area that provides configuration-level
guidance. Write the Compose file yourself; a finished file is not supplied.
Follow [the GitLab bootstrap guide](../gitlab-bootstrap.md) for the new-host
procedure. The checklist below is the milestone summary.

1. Create `/var/training/gitlab` for this Compose project and keep its Compose
   file at that root.
2. Define the project, service, and container as `gitlab`, using the exact
   image `gitlab/gitlab-ee:19.4.1-ee.0`.
3. Configure GitLab's external URL as `http://gitlab.local:8929` and its
   advertised Git SSH port as `2424`.
4. Publish `8929:8929`, `443:443`, and `2424:22` only on `127.0.0.1`. Keep the
   host's existing SSH service on port `22` reachable. Port `443` is preserved
   by the course contract but is not evidence that HTTPS works.
5. Bind-mount `/var/training/gitlab/config`,
   `/var/training/gitlab/logs`, and `/var/training/gitlab/data` to
   `/etc/gitlab`, `/var/log/gitlab`, and `/var/opt/gitlab`, respectively.
6. Add a restart policy and account for GitLab's startup time and resource use.
7. Render or validate the Compose model before starting it.
8. Start GitLab, follow its startup state, obtain the initial administrator
   credential through the documented image procedure, and sign in.
9. Recreate the GitLab container and prove that the project and account remain.
10. Create a blank **Ansible Elastic Stack Training Lab** project, push the
    supplied `training` branch, make it the default, and clone it back from
    local GitLab. Maintainer distributions can publish the protected reference
    branches separately.

Do not place Training Lab services in this Compose project. Do not make the
future Training Lab Ansible playbooks responsible for GitLab.

## Completion criteria

- Docker and Compose can start and inspect a test workload.
- GitLab runs as project/service/container `gitlab` from the pinned EE 19.4.1
  image.
- GitLab is healthy, and
  `http://gitlab.local:8929/users/sign_in` responds.
- its three required publications exist only on loopback;
- GitLab data survives container recreation.
- Git push and clone work against the local instance.
- The local project uses `training` as its default branch.
- You can identify the GitLab project directory and the future
  Training Lab work directory as separate administrative boundaries.

## Research prompts

- Why is the course image pinned, and what upgrade, migration, and validation
  questions must be answered before changing its edition or version?
- Why must the external URL agree with how clients reach GitLab?
- What survives a container recreation, and why?
- Which host resources does GitLab require before the rest of the stack starts?
