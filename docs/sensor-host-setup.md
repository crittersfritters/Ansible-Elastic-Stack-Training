# Answer sheet: native Zeek and Suricata setup

## Purpose and portability boundary

This document defines the sensor state required by the reference data path. It
does not select a Linux distribution, package manager, repository, service
manager, or host-package version. Install maintained Zeek and Suricata builds
using the selected host's documentation and the projects' vendor guidance.

Record the host platform, package source, and installed versions as validation
evidence. Those facts make a test repeatable; they do not become learner host
requirements.

The reference implementation consumes these course-facing paths:

| Source | Required path | Required format |
|---|---|---|
| Zeek | `/opt/zeek/logs/current/*.log` | One JSON object per line |
| Suricata | `/var/log/suricata/eve.json` | EVE JSON, one object per line |

These are interoperability contracts, not claims about a package's default
layout. If an installation uses different paths, either configure its output
to meet the contract or change all consumers together: the manual Compose
mounts, `group_vars/all/network-sensors.yml`, Filebeat inputs, validation
configuration, and supporting documentation.

## Select the capture source

Identify which interface actually carries the traffic used for course
evidence. Do not copy an interface name from another host. Useful observations
include the available links, the default route, and the path selected for a
representative destination:

```bash
ip -brief link
ip route show default
ip route get 1.1.1.1
```

For a completely local exercise, capturing loopback may be deliberate. For
traffic leaving the host, the routed interface may be the useful source. An
approved packet capture can also establish configuration behavior before live
capture is enabled. Record the choice and what traffic it is expected to see.

## Install the sensor capabilities

The host must provide these capabilities before configuration begins:

- the Zeek engine and its control utility;
- Suricata and its rule-update utility;
- packet-capture permission for the selected source; and
- a host mechanism for starting and supervising each sensor.

Confirm the installed commands and versions. If a vendor package installs
outside the interactive `PATH`, use and record its absolute command path.

```bash
command -v zeek
command -v zeekctl
command -v suricata
command -v suricata-update

zeek --version
suricata --build-info
```

The command locations are observations, not course-prescribed installation
paths.

## Configure and prove Zeek

Configure a standalone Zeek node for the selected capture source. Load Zeek's
JSON logging policy in the installation's site policy:

```zeek
@load policy/tuning/json-logs
```

Configure its active logs to satisfy the course-facing Zeek path. Resolve the
installed control utility before invoking `sudo` so the commands do not depend
on the administrator account's `secure_path`. If `command -v` does not find it,
assign the variable to the absolute path recorded during installation.

```bash
zeekctl_command=$(command -v zeekctl)

sudo "$zeekctl_command" check
sudo "$zeekctl_command" deploy
sudo "$zeekctl_command" status
sudo find /opt/zeek/logs/current \
  -maxdepth 1 \
  -type f \
  -name '*.log' \
  -size +0c \
  -printf '%TY-%Tm-%TdT%TH:%TM:%TS %p\n'
```

Validate at least one complete, nonempty record as JSON:

```bash
sudo python3 - <<'PY'
from pathlib import Path
import json

root = Path("/opt/zeek/logs/current")

for path in sorted(root.glob("*.log")):
    with path.open(encoding="utf-8", errors="strict") as stream:
        for line in stream:
            if line.strip():
                json.loads(line)
                print(f"valid Zeek JSON: {path}")
                raise SystemExit(0)

raise SystemExit("no nonempty Zeek JSON record found")
PY
```

A successful syntax check or a running process is not enough. Generate traffic
that should cross the chosen source and show that a relevant log receives a
fresh record.

The visible `current` path can be a symbolic link whose canonical target lies
outside `/opt/zeek/logs`. Record both canonical paths instead of assuming the
directory layout from the spelling of the link:

```bash
sudo readlink --canonicalize-existing -- /opt/zeek/logs
sudo readlink --canonicalize-existing -- /opt/zeek/logs/current
```

The answer role discovers those paths on every run. It mounts the canonical
stable root read-only and, when the active target is outside that root, adds an
exact second read-only bind for the active directory. Filebeat reads the
canonical active path. Ordinary ZeekControl rotation replaces files within the
active directory and does not require a redeployment. If an administrator
changes `SpoolDir` or otherwise retargets `current`, rerun
`roles-network_sensors.yml` so Ansible regenerates the Filebeat input and
Compose mounts.

## Configure and prove Suricata

In the installed Suricata configuration:

1. set `HOME_NET` deliberately for the lab;
2. configure the selected live interface or approved offline input;
3. keep EVE output enabled;
4. set the EVE filename so the final path is
   `/var/log/suricata/eve.json`; and
5. install or update a ruleset appropriate for the exercise.

Locate and record the active configuration file rather than assuming a
distribution-specific path. Resolve the installed commands before invoking
`sudo`; if either command is not in `PATH`, assign its variable to the absolute
path recorded during installation. Update the rules first, then validate the
resulting configuration and rule set before starting the sensor through the
host's service mechanism:

```bash
suricata_command=$(command -v suricata)
suricata_update_command=$(command -v suricata-update)
suricata_config=/path/to/suricata.yaml

sudo "$suricata_update_command"
sudo "$suricata_command" -T -c "$suricata_config"
```

Validate a complete EVE record without requiring an additional JSON utility:

```bash
sudo python3 - <<'PY'
from pathlib import Path
import json

path = Path("/var/log/suricata/eve.json")

with path.open(encoding="utf-8", errors="strict") as stream:
    for line in stream:
        if line.strip():
            json.loads(line)
            print(f"valid Suricata EVE JSON: {path}")
            raise SystemExit(0)

raise SystemExit("no nonempty Suricata EVE record found")
PY
```

Generate traffic expected to produce an event and show that `eve.json` gains a
fresh record. A valid but stale file does not prove the active capture path.

## Preserve the collection boundary

The manual and Ansible Filebeat projects mount the sensor log roots read-only.
The sensors retain ownership of their live logs; Filebeat only consumes them.

Native sensor mounts use plain `ro`, never `:z` or `:Z`. Private relabeling is
appropriate for the collector-owned configuration and registry mounts, but it
must not convert host-service logs into container-owned data.

Do not make the trees broadly writable to bypass a permission error. Confirm
ordinary file traversal and read permissions, then account for the host's
mandatory-access-control mechanism when one is active. Container root does not
bypass that policy. Use a narrow, documented read-only policy and prove access
from the actual Filebeat container instead of weakening unrelated host data.

On an SELinux-enabled host, Docker must itself participate in SELinux
confinement before these projects are deployed. The answer keeps Zeek
Filebeat in the ordinary `container_t` domain and runs only Suricata Filebeat
as `container_logreader_t`. The Suricata tree retains its native host-log
label (`var_log_t` on the validated Fedora reference host). Do not relabel
`/var/log/suricata` as `container_file_t`, add a persistent container fcontext
rule, disable enforcement, or generate an `audit2allow` module for this known
read boundary. If the selected host policy does not provide
`container_logreader_t`, stop and resolve that prerequisite rather than
silently weakening the host log policy.

Log rotation must preserve the stable roots and active filenames consumed by
Filebeat. Recheck the mount after rotation or sensor restart rather than
assuming an earlier read proves future files will remain accessible.

## Completion evidence

Retain evidence showing:

- the installed Zeek and Suricata versions and their package sources;
- the chosen capture source and why it sees the test traffic;
- successful native configuration validation;
- a fresh, valid JSON record from each sensor at the course-facing path;
- the canonical Zeek active target and every bind required to reach it;
- byte-level read access from each corresponding Filebeat container;
- read-only, non-relabeling native-log mounts;
- effective collector confinement and unchanged native sensor labels when
  mandatory access control is active; and
- permissions and host security controls that remain no broader than needed.

Consult current vendor guidance before installing or changing a sensor:

- [Zeek installation](https://docs.zeek.org/en/current/install.html)
- [Zeek JSON logs](https://docs.zeek.org/en/current/log-formats.html)
- [Suricata installation](https://docs.suricata.io/en/latest/install.html)
- [Suricata quickstart](https://docs.suricata.io/en/latest/quickstart.html)
