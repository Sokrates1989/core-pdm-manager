"""
Module: build_pipfile.py
Author: core-pdm-manager
Date: 2026-03-04
Version: 1.0.0

Description:
    Generate a Pipfile from pyproject.toml dependency metadata.

Usage:
    python build_pipfile.py --project-root /workspace --output /workspace/Pipfile
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable, List

from dependency_parsing import ParsedRequirement, load_project_dependency_model


def _render_requirement_line(requirement: ParsedRequirement) -> str:
    """
    Render a ParsedRequirement entry for Pipfile TOML syntax.

    Args:
        requirement: Parsed dependency requirement.

    Returns:
        str: TOML assignment line for Pipfile package sections.
    """

    if requirement.url:
        return f'"{requirement.name}" = {{url = "{requirement.url}"}}'

    if not requirement.specifier and not requirement.markers and not requirement.extras:
        return f'"{requirement.name}" = "*"'

    fields: List[str] = []
    version_value = requirement.specifier or "*"
    fields.append(f'version = "{version_value}"')

    if requirement.markers:
        fields.append(f'markers = "{requirement.markers}"')

    if requirement.extras:
        extras = ", ".join(f'"{extra}"' for extra in requirement.extras)
        fields.append(f"extras = [{extras}]")

    field_text = ", ".join(fields)
    return f'"{requirement.name}" = {{{field_text}}}'


def _render_section_lines(section_name: str, requirements: Iterable[ParsedRequirement]) -> List[str]:
    """
    Render a Pipfile section for a dependency group.

    Args:
        section_name: Pipfile section name.
        requirements: Requirement entries to include.

    Returns:
        list[str]: Lines for the section.
    """

    lines = [f"[{section_name}]"]
    requirement_list = list(requirements)
    if not requirement_list:
        lines.append("# no dependencies detected")
    else:
        for requirement in requirement_list:
            lines.append(_render_requirement_line(requirement))
    lines.append("")
    return lines


def build_pipfile(project_root: Path, output_path: Path) -> None:
    """
    Generate Pipfile content from pyproject.toml.

    Args:
        project_root: Project root containing pyproject.toml.
        output_path: Output path for generated Pipfile.
    """

    model = load_project_dependency_model(project_root / "pyproject.toml")

    python_version = model.python_requires.replace(">=", "").replace("<", "").split(",", 1)[0].strip()
    if not python_version:
        python_version = "3.11"

    lines: List[str] = [
        '[[source]]',
        'url = "https://pypi.org/simple"',
        'verify_ssl = true',
        'name = "pypi"',
        "",
        *(_render_section_lines("packages", model.runtime_dependencies)),
        *(_render_section_lines("dev-packages", model.dev_dependencies)),
        "[requires]",
        f'python_version = "{python_version}"',
        "",
    ]

    output_path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    """
    Parse command line arguments.

    Returns:
        argparse.Namespace: Parsed CLI namespace.
    """

    parser = argparse.ArgumentParser(description="Generate Pipfile from pyproject.toml")
    parser.add_argument("--project-root", required=True, help="Project root path")
    parser.add_argument("--output", required=True, help="Pipfile output path")
    return parser.parse_args()


def main() -> int:
    """
    Execute Pipfile generation workflow.

    Returns:
        int: Process exit code.
    """

    args = parse_args()
    project_root = Path(args.project_root).resolve()
    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    build_pipfile(project_root=project_root, output_path=output_path)
    print(f"Generated Pipfile: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
