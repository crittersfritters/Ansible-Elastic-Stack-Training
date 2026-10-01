# Answer sheet: native Zeek and Suricata setup

This reference uses native host sensors and containerized collectors. Choose
the interface that actually observes the training traffic; do not copy an
example interface name without checking `ip link` and the host's routing.

## Zeek on Ubuntu 24.04

The Zeek project publishes Ubuntu packages through the openSUSE Build Service.
The course reference uses the current 8.0 LTS package line rather than a
floating feature-release package:

```bash
sudo apt install -y curl gpg
echo 'deb https://download.opensuse.org/repositories/security:/zeek/xUbuntu_24.04/ /' \
  | sudo tee /etc/apt/sources.list.d/security:zeek.list
curl -fsSL \
  https://download.opensuse.org/repositories/security:zeek/xUbuntu_24.04/Release.key \
  | gpg --dearmor \
  | sudo tee /etc/apt/trusted.gpg.d/security_zeek.gpg >/dev/null
sudo apt update
sudo apt install -y zeek-8.0
/opt/zeek/bin/zeek --version
```

In `/opt/zeek/etc/node.cfg`, configure the standalone node to use the chosen
interface. In `/opt/zeek/share/zeek/site/local.zeek`, enable JSON logs:

```zeek
@load policy/tuning/json-logs.zeek
```

Validate and deploy the configuration:

```bash
sudo /opt/zeek/bin/zeekctl check
sudo /opt/zeek/bin/zeekctl deploy
sudo /opt/zeek/bin/zeekctl status
sudo find /opt/zeek/logs/current -maxdepth 1 -type f -name '*.log' -size +0c
```

Inspect a new line and confirm it is one JSON object. The Filebeat project
mounts the stable `/opt/zeek/logs` root because `current` can be a rotating
symlink.

## Suricata on Ubuntu 24.04

Install the stable package stream documented by the OISF project:

```bash
sudo apt install -y software-properties-common jq
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt update
sudo apt install -y suricata
sudo suricata --build-info
```

Set `HOME_NET` and the capture interface deliberately in
`/etc/suricata/suricata.yaml`. Keep the `eve-log` output enabled with the
filename `eve.json`, then validate and start it:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
sudo suricata-update
sudo systemctl enable --now suricata
sudo systemctl restart suricata
sudo systemctl --no-pager --full status suricata
sudo tail -n 1 /var/log/suricata/eve.json | jq -e .
```

Generate traffic that crosses the selected interface and confirm both source
files receive fresh timestamps before starting Filebeat. A running service
with a stale file is not sufficient evidence.

## Ownership boundary

The answer roles verify these paths and mount them read-only; they do not
install, configure, restart, or relabel either sensor. Sensor configuration is
host preparation owned by the learner. The reference assumes rootful Docker;
do not make the live log trees broadly writable merely to fix collection.

Consult the vendor guides before changing package lines or capture settings:

- [Zeek installation](https://docs.zeek.org/en/current/install.html)
- [Suricata quickstart](https://docs.suricata.io/en/suricata-8.0.5/quickstart.html)
