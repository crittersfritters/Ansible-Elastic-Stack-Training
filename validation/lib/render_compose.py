#!/usr/bin/env python3
"""Render the deliberately small Jinja subset used by reference templates."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import yaml


VARIABLE = re.compile(r"{{\s*([A-Za-z_][A-Za-z0-9_]*)\s*}}")
LOOP = re.compile(
    r"{%\s*for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)\s*%}(.*?){%\s*endfor\s*%}",
    re.DOTALL,
)


def load_yaml_mapping(path: Path) -> dict:
    if not path.is_file():
        return {}
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    return value if isinstance(value, dict) else {}


def resolve_scalars(values: dict) -> dict:
    resolved = dict(values)
    for _ in range(20):
        changed = False
        for key, value in list(resolved.items()):
            if not isinstance(value, str):
                continue
            rendered = VARIABLE.sub(lambda m: str(resolved.get(m.group(1), m.group(0))), value)
            if rendered != value:
                resolved[key] = rendered
                changed = True
        if not changed:
            return resolved
    raise ValueError("variable resolution did not converge")


def render(template: str, values: dict) -> str:
    def expand_loop(match: re.Match) -> str:
        local_name, collection_name, body = match.groups()
        collection = values.get(collection_name)
        if not isinstance(collection, list):
            raise ValueError(f"{collection_name} is not a list")
        return "".join(
            VARIABLE.sub(
                lambda variable: str(item)
                if variable.group(1) == local_name
                else str(values.get(variable.group(1), variable.group(0))),
                body,
            )
            for item in collection
        )

    while LOOP.search(template):
        template = LOOP.sub(expand_loop, template)
    template = VARIABLE.sub(lambda m: str(values.get(m.group(1), m.group(0))), template)
    if "{{" in template or "{%" in template:
        raise ValueError("unresolved Jinja expression remains")
    return template


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    root = args.project_root.resolve()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    common = {"playbook_dir": "/tmp/training-lab-reference"}
    for path in sorted((root / "group_vars" / "all").glob("*.yml")):
        # Compose rendering never needs secret variables. Do not open the
        # credential file even during the initial ignored-plaintext phase.
        if path.name == "vault.yml":
            continue
        if path.read_text(encoding="utf-8").startswith("$ANSIBLE_VAULT;"):
            continue
        common.update(load_yaml_mapping(path))

    compose_templates = sorted(
        (root / "roles").glob("*/templates/docker-compose.yml.j2")
    )
    if len(compose_templates) != 7:
        raise SystemExit(
            f"expected 7 Compose templates, found {len(compose_templates)}"
        )

    filebeat_templates = sorted((root / "roles").glob("filebeat_*/templates/filebeat.yml.j2"))
    if len(filebeat_templates) != 2:
        raise SystemExit(
            f"expected 2 Filebeat templates, found {len(filebeat_templates)}"
        )

    for path in compose_templates:
        role_root = path.parents[1]
        values = dict(common)
        values.update(load_yaml_mapping(role_root / "defaults" / "main.yml"))
        values.update(load_yaml_mapping(role_root / "vars" / "main.yml"))
        values = resolve_scalars(values)
        rendered = render(path.read_text(encoding="utf-8"), values)
        yaml.safe_load(rendered)
        destination = args.output_dir / f"compose-{role_root.name}.yml"
        destination.write_text(rendered, encoding="utf-8")
        print(destination)

    for path in filebeat_templates:
        role_root = path.parents[1]
        values = dict(common)
        values.update(load_yaml_mapping(role_root / "defaults" / "main.yml"))
        values.update(load_yaml_mapping(role_root / "vars" / "main.yml"))
        values = resolve_scalars(values)
        rendered = render(path.read_text(encoding="utf-8"), values)
        yaml.safe_load(rendered)
        destination = args.output_dir / f"filebeat-{role_root.name}.yml"
        destination.write_text(rendered, encoding="utf-8")
        print(destination)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
