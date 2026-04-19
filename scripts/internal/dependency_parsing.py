"""
Module: dependency_parsing.py
Author: core-pdm-manager
Date: 2026-03-04
Version: 1.0.0

Description:
    Shared parsing helpers for dependency metadata extraction from pyproject.toml.
    The module normalizes requirement strings for downstream Pipfile/Poetry/sanity
    generation flows.

Dependencies:
    - tomllib (stdlib on Python 3.11+)
    - packaging (optional, graceful fallback)
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional

import tomllib

try:
    from packaging.requirements import Requirement
except Exception:  # pragma: no cover - fallback path when packaging is unavailable
    Requirement = None  # type: ignore[assignment]


@dataclass
class ParsedRequirement:
    """
    Structured representation of a dependency requirement.

    Attributes:
        raw: Original requirement string.
        name: Normalized distribution name.
        specifier: Version specifier segment.
        markers: Environment markers if declared.
        extras: Optional extras list.
        url: Optional direct URL requirement.
    """

    raw: str
    name: str
    specifier: str
    markers: str
    extras: List[str]
    url: str


@dataclass
class ProjectDependencyModel:
    """
    Dependency model extracted from pyproject.toml.

    Attributes:
        name: Project name.
        python_requires: Python requirement string.
        runtime_dependencies: Parsed runtime dependencies.
        dev_dependencies: Parsed development dependencies.
    """

    name: str
    python_requires: str
    runtime_dependencies: List[ParsedRequirement]
    dev_dependencies: List[ParsedRequirement]


def _parse_requirement_fallback(requirement_text: str) -> ParsedRequirement:
    """
    Parse requirement string without packaging module support.

    Args:
        requirement_text: Raw requirement declaration.

    Returns:
        ParsedRequirement: Parsed representation using conservative heuristics.
    """

    marker_split = requirement_text.split(";", 1)
    package_segment = marker_split[0].strip()
    markers = marker_split[1].strip() if len(marker_split) > 1 else ""

    name = package_segment
    specifier = ""
    for split_token in ["~=", "==", ">=", "<=", "!=", ">", "<"]:
        if split_token in package_segment:
            before, after = package_segment.split(split_token, 1)
            name = before.strip()
            specifier = f"{split_token}{after.strip()}"
            break

    return ParsedRequirement(
        raw=requirement_text,
        name=name,
        specifier=specifier,
        markers=markers,
        extras=[],
        url="",
    )


def parse_requirement(requirement_text: str) -> ParsedRequirement:
    """
    Parse a PEP 508 requirement string into structured fields.

    Args:
        requirement_text: Raw requirement text from pyproject dependency arrays.

    Returns:
        ParsedRequirement: Structured requirement fields.
    """

    if Requirement is None:
        return _parse_requirement_fallback(requirement_text)

    requirement = Requirement(requirement_text)
    return ParsedRequirement(
        raw=requirement_text,
        name=requirement.name,
        specifier=str(requirement.specifier),
        markers=str(requirement.marker) if requirement.marker else "",
        extras=sorted(requirement.extras),
        url=requirement.url or "",
    )


def _collect_dev_dependencies(pyproject_data: Dict[str, object]) -> List[str]:
    """
    Collect development dependencies across common pyproject conventions.

    Args:
        pyproject_data: Parsed pyproject content.

    Returns:
        list[str]: Raw dev dependency requirement strings.
    """

    dev_dependencies: List[str] = []

    project = pyproject_data.get("project")
    if isinstance(project, dict):
        optional_dependencies = project.get("optional-dependencies")
        if isinstance(optional_dependencies, dict):
            for key in ("dev", "development", "test"):
                value = optional_dependencies.get(key)
                if isinstance(value, list):
                    dev_dependencies.extend(str(item) for item in value)

    tool = pyproject_data.get("tool")
    if isinstance(tool, dict):
        pdm = tool.get("pdm")
        if isinstance(pdm, dict):
            pdm_dev = pdm.get("dev-dependencies")
            if isinstance(pdm_dev, dict):
                for _, entries in pdm_dev.items():
                    if isinstance(entries, list):
                        dev_dependencies.extend(str(item) for item in entries)

    dependency_groups = pyproject_data.get("dependency-groups")
    if isinstance(dependency_groups, dict):
        for key in ("dev", "test", "lint"):
            entries = dependency_groups.get(key)
            if isinstance(entries, list):
                dev_dependencies.extend(str(item) for item in entries)

    deduplicated: List[str] = []
    seen = set()
    for requirement in dev_dependencies:
        if requirement not in seen:
            deduplicated.append(requirement)
            seen.add(requirement)

    return deduplicated


def load_project_dependency_model(pyproject_path: Path) -> ProjectDependencyModel:
    """
    Load project dependency information from pyproject.toml.

    Args:
        pyproject_path: Path to pyproject.toml.

    Returns:
        ProjectDependencyModel: Parsed dependency model.

    Raises:
        FileNotFoundError: If pyproject.toml does not exist.
        ValueError: If the pyproject file does not include expected structures.
    """

    if not pyproject_path.exists():
        raise FileNotFoundError(f"pyproject.toml not found at {pyproject_path}")

    with pyproject_path.open("rb") as file_handle:
        pyproject_data = tomllib.load(file_handle)

    project = pyproject_data.get("project")
    if not isinstance(project, dict):
        raise ValueError("pyproject.toml must define a [project] table for this workflow")

    project_name = str(project.get("name") or pyproject_path.parent.name)
    python_requires = str(project.get("requires-python") or ">=3.11")

    runtime_raw = project.get("dependencies")
    runtime_dependencies = []
    if isinstance(runtime_raw, list):
        runtime_dependencies = [parse_requirement(str(item)) for item in runtime_raw]

    dev_dependencies = [parse_requirement(item) for item in _collect_dev_dependencies(pyproject_data)]

    return ProjectDependencyModel(
        name=project_name,
        python_requires=python_requires,
        runtime_dependencies=runtime_dependencies,
        dev_dependencies=dev_dependencies,
    )
