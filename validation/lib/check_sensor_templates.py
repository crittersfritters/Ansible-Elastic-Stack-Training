#!/usr/bin/env python3
"""Exercise the security-sensitive sensor template branches."""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path

import yaml


def load_renderer(path: Path):
    spec = importlib.util.spec_from_file_location("render_compose", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load renderer: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", type=Path)
    args = parser.parse_args()

    root = args.project_root.resolve()
    renderer = load_renderer(root / "validation/lib/render_compose.py")

    common: dict = {"playbook_dir": "/tmp/training-lab-reference"}
    for path in sorted((root / "group_vars/all").glob("*.yml")):
        # Sensor template checks do not consume credentials. Never read the
        # ignored plaintext or encrypted Vault working file here.
        if path.name == "vault.yml":
            continue
        if path.read_text(encoding="utf-8").startswith("$ANSIBLE_VAULT;"):
            continue
        common.update(renderer.load_yaml_mapping(path))

    require(
        common.get("sensor_log_bind_options") == "ro",
        "sensor_log_bind_options must be exactly 'ro'",
    )

    def role_values(role_name: str) -> dict:
        role_root = root / "roles" / role_name
        values = dict(common)
        values.update(renderer.load_yaml_mapping(role_root / "defaults/main.yml"))
        values.update(renderer.load_yaml_mapping(role_root / "vars/main.yml"))
        return renderer.resolve_scalars(values)

    zeek_defaults = renderer.load_yaml_mapping(
        root / "roles/filebeat_zeek/defaults/main.yml"
    )
    expected_zeek_defaults = {
        "filebeat_zeek_resolved_logs_root": "{{ zeek_logs_root }}",
        "filebeat_zeek_resolved_logs_dir": "{{ zeek_logs_dir }}",
        "filebeat_zeek_external_log_mounts": [],
    }
    for name, expected in expected_zeek_defaults.items():
        require(
            zeek_defaults.get(name) == expected,
            f"Zeek offline default {name} does not match the portable contract",
        )

    suricata_defaults = renderer.load_yaml_mapping(
        root / "roles/filebeat_suricata/defaults/main.yml"
    )
    require(
        suricata_defaults.get("filebeat_suricata_security_options") == [],
        "Suricata offline security options must default to an empty list",
    )

    zeek_values = role_values("filebeat_zeek")
    zeek_values.update(
        {
            "filebeat_zeek_resolved_logs_root": "/opt/zeek/logs",
            "filebeat_zeek_resolved_logs_dir": "/opt/zeek/spool/zeek",
            "filebeat_zeek_external_log_mounts": ["/opt/zeek/spool/zeek"],
        }
    )
    zeek_compose = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_zeek/templates/docker-compose.yml.j2")
            .read_text(encoding="utf-8"),
            zeek_values,
        )
    )
    zeek_service = zeek_compose["services"]["filebeat_zeek"]
    zeek_volumes = set(zeek_service.get("volumes") or [])
    require(
        zeek_service.get("labels")
        == {
            "org.training-lab.sensor": "zeek",
            "org.training-lab.zeek.logs-root": "/opt/zeek/logs",
            "org.training-lab.zeek.logs-active": "/opt/zeek/spool/zeek",
        },
        "Zeek deployment labels do not publish its canonical source paths",
    )
    require(
        "/opt/zeek/logs:/opt/zeek/logs:ro" in zeek_volumes,
        "Zeek stable root is not mounted read-only without relabeling",
    )
    require(
        "/opt/zeek/spool/zeek:/opt/zeek/spool/zeek:ro" in zeek_volumes,
        "external Zeek active target is not mounted read-only",
    )

    zeek_filebeat = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_zeek/templates/filebeat.yml.j2")
            .read_text(encoding="utf-8"),
            zeek_values,
        )
    )
    require(
        zeek_filebeat["filebeat.inputs"][0]["paths"]
        == ["/opt/zeek/spool/zeek/*.log"],
        "Zeek Filebeat does not read the canonical active directory",
    )

    zeek_inside_values = role_values("filebeat_zeek")
    zeek_inside_values.update(
        {
            "filebeat_zeek_resolved_logs_root": "/opt/zeek/logs",
            "filebeat_zeek_resolved_logs_dir": "/opt/zeek/logs/current",
            "filebeat_zeek_external_log_mounts": [],
        }
    )
    zeek_inside_compose = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_zeek/templates/docker-compose.yml.j2")
            .read_text(encoding="utf-8"),
            zeek_inside_values,
        )
    )
    zeek_inside_volumes = set(
        zeek_inside_compose["services"]["filebeat_zeek"].get("volumes") or []
    )
    require(
        zeek_inside_compose["services"]["filebeat_zeek"].get("labels")
        == {
            "org.training-lab.sensor": "zeek",
            "org.training-lab.zeek.logs-root": "/opt/zeek/logs",
            "org.training-lab.zeek.logs-active": "/opt/zeek/logs/current",
        },
        "inside-root Zeek fixture publishes incorrect source-path labels",
    )
    require(
        "/opt/zeek/logs:/opt/zeek/logs:ro" in zeek_inside_volumes,
        "inside-root Zeek fixture lacks the stable read-only root bind",
    )
    require(
        not any(
            volume.startswith("/opt/zeek/logs/current:")
            for volume in zeek_inside_volumes
        ),
        "inside-root Zeek fixture must not add a redundant active-directory bind",
    )
    zeek_inside_filebeat = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_zeek/templates/filebeat.yml.j2")
            .read_text(encoding="utf-8"),
            zeek_inside_values,
        )
    )
    require(
        zeek_inside_filebeat["filebeat.inputs"][0]["paths"]
        == ["/opt/zeek/logs/current/*.log"],
        "inside-root Zeek fixture does not retain the canonical input path",
    )

    suricata_values = role_values("filebeat_suricata")
    suricata_values["filebeat_suricata_security_options"] = [
        "label=type:container_logreader_t"
    ]
    suricata_compose = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_suricata/templates/docker-compose.yml.j2")
            .read_text(encoding="utf-8"),
            suricata_values,
        )
    )
    suricata_service = suricata_compose["services"]["filebeat_suricata"]
    require(
        suricata_service.get("labels")
        == {
            "org.training-lab.sensor": "suricata",
            "org.training-lab.suricata.logs-root": "/var/log/suricata",
            "org.training-lab.suricata.events": "/var/log/suricata/eve.json",
        },
        "Suricata deployment labels do not publish its native source paths",
    )
    require(
        suricata_service.get("security_opt")
        == ["label=type:container_logreader_t"],
        "Suricata SELinux fixture lacks the dedicated log-reader type",
    )
    require(
        "/var/log/suricata:/var/log/suricata:ro"
        in set(suricata_service.get("volumes") or []),
        "Suricata logs are not mounted read-only without relabeling",
    )

    suricata_filebeat = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_suricata/templates/filebeat.yml.j2")
            .read_text(encoding="utf-8"),
            suricata_values,
        )
    )
    require(
        suricata_filebeat["filebeat.inputs"][0]["paths"]
        == ["/var/log/suricata/eve.json"],
        "Suricata Filebeat does not read the EVE contract path",
    )

    portable_values = role_values("filebeat_suricata")
    portable_compose = yaml.safe_load(
        renderer.render(
            (root / "roles/filebeat_suricata/templates/docker-compose.yml.j2")
            .read_text(encoding="utf-8"),
            portable_values,
        )
    )
    require(
        portable_compose["services"]["filebeat_suricata"].get("security_opt")
        == [],
        "non-SELinux Suricata fixture must retain empty security options",
    )

    for name, service in (
        ("Zeek", zeek_service),
        ("Suricata", suricata_service),
    ):
        health_command = " ".join(service["healthcheck"]["test"])
        require(
            "filebeat test config" in health_command,
            f"{name} health check does not test Filebeat configuration",
        )
        require(
            "filebeat test output" in health_command,
            f"{name} health check does not test the Kafka output",
        )
        require(
            "--path.data /tmp/filebeat-health" in health_command,
            f"{name} health check does not isolate Filebeat path.data",
        )

    print("sensor template contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
