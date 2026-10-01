#!/usr/bin/env python3
"""Validate the one-host inventory contract without emitting host variables."""

from __future__ import annotations

import json
import sys


def fail(message: str) -> None:
    print(f"inventory validation failed: {message}")


def main() -> int:
    if len(sys.argv) < 3:
        fail("the expected host and groups were not supplied")
        return 2

    expected_host = sys.argv[1]
    expected_groups = sys.argv[2:]

    try:
        document = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError, UnicodeDecodeError):
        fail("Ansible did not produce valid inventory JSON")
        return 1

    if not isinstance(document, dict):
        fail("the inventory root is not a mapping")
        return 1

    problems: list[str] = []

    for group in expected_groups:
        group_data = document.get(group)
        hosts = group_data.get("hosts") if isinstance(group_data, dict) else None
        if hosts != [expected_host]:
            problems.append(
                f"group {group!r} does not contain only the expected host"
            )

    metadata = document.get("_meta")
    hostvars = metadata.get("hostvars") if isinstance(metadata, dict) else None
    variables = hostvars.get(expected_host) if isinstance(hostvars, dict) else None

    if not isinstance(variables, dict):
        problems.append("the expected host has no resolved host-variable mapping")
    else:
        if variables.get("ansible_connection") != "ssh":
            problems.append("ansible_connection is not the required SSH transport")
        if variables.get("ansible_user") != "ansible":
            problems.append("ansible_user is not the dedicated Ansible account")
        if variables.get("ansible_port") != 22:
            problems.append("ansible_port is not the required SSH port")
        if "ansible_host" in variables:
            problems.append(
                "ansible_host is set instead of resolving the inventory hostname"
            )

    if problems:
        for problem in problems:
            fail(problem)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
