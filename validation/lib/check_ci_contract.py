#!/usr/bin/env python3
"""Validate the security-sensitive parent and child CI contract."""

from __future__ import annotations

from pathlib import Path
import sys

import yaml


DOCKER_SELINUX_CONTRACT = "roles/common/tasks/verify_docker_selinux.yml"
EXPECTED_DOCKER_SELINUX_JOBS = {
    "preflightDeployment",
    "configureLocalHost",
    "deployNetworkSensors",
}
VAULT_VIEW = "ansible-vault view group_vars/all/vault.yml >/dev/null 2>&1"
VAULT_HEADER_READ = "IFS= read -r vault_header < group_vars/all/vault.yml"
EXPECTED_CACHE_PATHS = {
    ".ansible/roles/",
    ".ansible/collections/",
}
PHASE_BRANCH_GUARD = "$CI_COMMIT_BRANCH !~ /^answers\\//"
PARENT_RESOURCE_GROUP = "training-lab-pipeline"
CHILD_RESOURCE_GROUP = "training-lab-deployment"


def contains(commands: object, fragment: str) -> bool:
    return isinstance(commands, list) and any(
        fragment in str(command) for command in commands
    )


def main() -> int:
    if len(sys.argv) != 3:
        print("CI contract validation requires parent and child configuration paths")
        return 2

    try:
        parent = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8"))
        child = yaml.safe_load(Path(sys.argv[2]).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError):
        print("CI contract configuration could not be loaded")
        return 1

    if not isinstance(parent, dict) or not isinstance(child, dict):
        print("CI contract configuration roots must be mappings")
        return 1

    problems: list[str] = []

    workflow_rules = parent.get("workflow", {}).get("rules", [])
    deployment_path_lists = [
        rule.get("changes", {}).get("paths", [])
        for rule in workflow_rules
        if isinstance(rule, dict) and isinstance(rule.get("changes"), dict)
    ]
    if not deployment_path_lists or any(
        DOCKER_SELINUX_CONTRACT not in paths for paths in deployment_path_lists
    ):
        problems.append(
            "the parent pipeline must treat the Docker SELinux contract as "
            "deployment-relevant"
        )

    deployment_rules = [
        rule
        for rule in workflow_rules
        if isinstance(rule, dict) and isinstance(rule.get("changes"), dict)
    ]
    if not deployment_rules or any(
        PHASE_BRANCH_GUARD not in str(rule.get("if", ""))
        for rule in deployment_rules
    ):
        problems.append(
            "the parent pipeline must exclude protected answers/* phase branches"
        )

    selected_jobs: set[str] = set()
    for job_name, job in child.items():
        if not isinstance(job, dict) or job_name.startswith("."):
            continue

        for rule in job.get("rules", []):
            if not isinstance(rule, dict):
                continue

            paths = rule.get("changes", {}).get("paths", [])
            if DOCKER_SELINUX_CONTRACT in paths:
                selected_jobs.add(job_name)

    if selected_jobs != EXPECTED_DOCKER_SELINUX_JOBS:
        problems.append(
            "the Docker SELinux contract must select exactly preflightDeployment, "
            "configureLocalHost, and deployNetworkSensors"
        )

    parent_job = parent.get("validateAnswerSheet", {})
    parent_trigger = parent.get("deployTrainingLabChanges", {})
    child_template = child.get(".training_lab_deploy_job", {})

    if not isinstance(parent_trigger, dict) or (
        parent_trigger.get("resource_group") != PARENT_RESOURCE_GROUP
    ):
        problems.append(
            f"the parent deployment trigger must use {PARENT_RESOURCE_GROUP}"
        )

    if not isinstance(child_template, dict) or (
        child_template.get("resource_group") != CHILD_RESOURCE_GROUP
    ):
        problems.append(
            f"the child deployment template must use {CHILD_RESOURCE_GROUP}"
        )

    if PARENT_RESOURCE_GROUP == CHILD_RESOURCE_GROUP:
        problems.append("parent and child deployment locks must remain distinct")

    for name, job in (
        ("parent validation", parent_job),
        ("child deployment template", child_template),
    ):
        if not isinstance(job, dict):
            problems.append(f"{name} is not a job mapping")
            continue

        before_script = job.get("before_script", [])
        if not contains(before_script, VAULT_VIEW):
            problems.append(
                f"{name} must verify Vault decryption without logging plaintext"
            )
        if not contains(before_script, VAULT_HEADER_READ):
            problems.append(
                f"{name} must validate the Vault marker on the first line"
            )

        cache_paths = set(job.get("cache", {}).get("paths", []))
        if cache_paths != EXPECTED_CACHE_PATHS:
            problems.append(
                f"{name} must cache only dependency directories, not Ansible temp data"
            )

    if problems:
        print("\n".join(problems))
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
