"""
Module: run_sanity_check.py
Author: core-pdm-manager
Date: 2026-03-04
Version: 1.0.0

Description:
    Execute import-based dependency sanity checks and emit a machine-readable report.

Usage:
    python run_sanity_check.py --project-root /workspace --output /workspace/.pdm-manager/reports/dependency-sanity-report.json
"""

from __future__ import annotations

import argparse
import importlib
import json
import platform
import traceback
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from importlib.metadata import packages_distributions
from pathlib import Path
from typing import Dict, List, Set

from dependency_parsing import ParsedRequirement, load_project_dependency_model


KNOWN_IMPORT_NAME_OVERRIDES = {
    "python-dateutil": "dateutil",
    "pyyaml": "yaml",
    "pillow": "PIL",
    "beautifulsoup4": "bs4",
    "scikit-learn": "sklearn",
    "opencv-python": "cv2",
    "mysqlclient": "MySQLdb",
    "python-dotenv": "dotenv",
}


@dataclass
class ImportCheckResult:
    """
    Result for one dependency import probe.

    Attributes:
        requirement: Original requirement string.
        distribution: Distribution name.
        attempted_imports: Candidate import names attempted.
        imported_as: Successfully imported module name.
        success: Whether import probe succeeded.
        error: Error text when probe fails.
    """

    requirement: str
    distribution: str
    attempted_imports: List[str]
    imported_as: str
    success: bool
    error: str


def _normalize_distribution_name(distribution_name: str) -> str:
    """
    Normalize distribution name for matching package metadata indexes.

    Args:
        distribution_name: Original distribution name.

    Returns:
        str: Normalized name.
    """

    return distribution_name.strip().lower().replace("_", "-")


def _build_distribution_import_map() -> Dict[str, Set[str]]:
    """
    Build mapping from distribution names to top-level import packages.

    Returns:
        dict[str, set[str]]: Distribution to import-name candidates map.
    """

    distribution_map: Dict[str, Set[str]] = {}
    metadata_map = packages_distributions()

    for import_name, distributions in metadata_map.items():
        for distribution in distributions:
            normalized = _normalize_distribution_name(distribution)
            distribution_map.setdefault(normalized, set()).add(import_name)

    return distribution_map


def _candidate_imports(requirement: ParsedRequirement, distribution_map: Dict[str, Set[str]]) -> List[str]:
    """
    Build candidate import module names for a requirement.

    Args:
        requirement: Parsed requirement metadata.
        distribution_map: Known package metadata mapping.

    Returns:
        list[str]: Ordered candidate import names.
    """

    candidates: List[str] = []
    normalized_distribution = _normalize_distribution_name(requirement.name)

    if normalized_distribution in distribution_map:
        candidates.extend(sorted(distribution_map[normalized_distribution]))

    override = KNOWN_IMPORT_NAME_OVERRIDES.get(normalized_distribution)
    if override:
        candidates.append(override)

    fallback = requirement.name.replace("-", "_").replace(".", "_")
    candidates.append(fallback)

    deduplicated: List[str] = []
    seen = set()
    for candidate in candidates:
        if candidate not in seen:
            deduplicated.append(candidate)
            seen.add(candidate)

    return deduplicated


def _check_requirement_import(requirement: ParsedRequirement, distribution_map: Dict[str, Set[str]]) -> ImportCheckResult:
    """
    Execute import checks for a single requirement.

    Args:
        requirement: Parsed requirement metadata.
        distribution_map: Distribution to import-name map.

    Returns:
        ImportCheckResult: Probe result details.
    """

    attempts = _candidate_imports(requirement, distribution_map)
    errors: List[str] = []

    for import_name in attempts:
        try:
            importlib.import_module(import_name)
            return ImportCheckResult(
                requirement=requirement.raw,
                distribution=requirement.name,
                attempted_imports=attempts,
                imported_as=import_name,
                success=True,
                error="",
            )
        except Exception as exc:  # pragma: no cover - dependent on environment
            errors.append(f"{import_name}: {exc}")

    return ImportCheckResult(
        requirement=requirement.raw,
        distribution=requirement.name,
        attempted_imports=attempts,
        imported_as="",
        success=False,
        error=" | ".join(errors),
    )


def _write_report(report_path: Path, payload: Dict[str, object]) -> None:
    """
    Write JSON report to disk.

    Args:
        report_path: Target report path.
        payload: Report payload dictionary.
    """

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    """
    Parse script CLI arguments.

    Returns:
        argparse.Namespace: Parsed argument namespace.
    """

    parser = argparse.ArgumentParser(description="Run import sanity checks for pyproject dependencies")
    parser.add_argument("--project-root", required=True, help="Project root containing pyproject.toml")
    parser.add_argument("--output", required=True, help="Path to write JSON report")
    parser.add_argument(
        "--include-dev",
        action="store_true",
        help="Include development dependencies in import checks",
    )
    return parser.parse_args()


def main() -> int:
    """
    Run sanity checks and return process exit code.

    Returns:
        int: 0 on success, 2 when import failures occur, 1 on setup/runtime errors.
    """

    args = parse_args()
    project_root = Path(args.project_root).resolve()
    report_path = Path(args.output).resolve()

    try:
        model = load_project_dependency_model(project_root / "pyproject.toml")
    except Exception as exc:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "status": "error",
            "error": str(exc),
            "traceback": traceback.format_exc(),
        }
        _write_report(report_path, payload)
        return 1

    requirements = list(model.runtime_dependencies)
    if args.include_dev:
        requirements.extend(model.dev_dependencies)

    distribution_map = _build_distribution_import_map()
    results = [_check_requirement_import(requirement, distribution_map) for requirement in requirements]

    failed = [result for result in results if not result.success]
    payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "ok" if not failed else "failed",
        "project_root": str(project_root),
        "python_version": platform.python_version(),
        "checked_runtime_dependencies": len(model.runtime_dependencies),
        "checked_dev_dependencies": len(model.dev_dependencies) if args.include_dev else 0,
        "total_checked": len(results),
        "failed_count": len(failed),
        "results": [asdict(result) for result in results],
    }
    _write_report(report_path, payload)

    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
