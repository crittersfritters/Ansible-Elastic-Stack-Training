# Milestone 02: Zeek and Suricata sources

## Goal

Install Zeek and Suricata on the host and produce source records that later
collectors can read.

## Behavioral requirements

- Both sensors are installed using a method appropriate to the chosen Linux
  distribution.
- Each sensor observes a deliberate interface or approved offline input.
- Zeek emits line-delimited JSON under `/opt/zeek/logs/current`; Suricata emits
  EVE JSON at `/var/log/suricata/eve.json`.
- Permissions allow the future Filebeat containers to read the required logs
  without making unrelated host data broadly writable.

## Completion criteria

- Zeek produces fresh records when suitable traffic is generated.
- Suricata produces fresh event records when suitable traffic is generated.
- You can distinguish sensor inactivity from a file-permission problem.
- Log rotation or file replacement does not silently invalidate the planned
  collection path.
- You can identify which source records will prove each later data path.

## Research prompts

- Which network interface actually carries the traffic you intend to observe?
- How do Zeek and Suricata output formats differ?
- How will a container reach host-generated files?
- Which user or group needs read access, and what is the narrowest reasonable
  permission change?
- What happens to a follower when a log file rotates?
