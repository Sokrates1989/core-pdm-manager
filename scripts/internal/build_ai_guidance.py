"""
Module: build_ai_guidance.py
Author: core-pdm-manager
Date: 2026-03-04
Version: 1.0.0

Description:
    Generate local troubleshooting guidance and AI prompt material from sanity
    check report files.

Usage:
    python build_ai_guidance.py --report /workspace/.pdm-manager/reports/dependency-sanity-report.json --output /workspace/.pdm-manager/reports/ai-solve-guidance.md
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple

from ai_provider_adapter import AiProviderResult, invoke_provider


ERROR_HINTS = {
    "No module named": "Package may not be installed, import name may differ from distribution name, or install failed due marker constraints.",
    "cannot import name": "Package version may be incompatible with another dependency. Try pinning a compatible version range and relocking.",
    "VersionConflict": "Dependency resolver selected incompatible versions. Inspect transitive constraints with `pdm show --graph`.",
}


def _load_json(path: Path) -> Dict[str, object]:
    """
    Load JSON content from file path.

    Args:
        path: JSON file path.

    Returns:
        dict[str, object]: Decoded JSON payload.
    """

    with path.open("r", encoding="utf-8") as file_handle:
        return json.load(file_handle)


def _collect_hint(error_text: str) -> str:
    """
    Resolve a helpful hint for an error text.

    Args:
        error_text: Error text from sanity report.

    Returns:
        str: Guidance hint.
    """

    for needle, hint in ERROR_HINTS.items():
        if needle in error_text:
            return hint
    return "Review resolver output and package metadata. Try pinning direct dependencies and re-running lock generation."


def _build_prompt_body(report_payload: Dict[str, object]) -> str:
    """
    Build reusable AI prompt content from report payload.

    Args:
        report_payload: Sanity report dictionary.

    Returns:
        str: Prompt body text.
    """

    failed_entries = [
        item for item in report_payload.get("results", []) if isinstance(item, dict) and not item.get("success", False)
    ]

    lines: List[str] = [
        "You are an expert Python dependency resolver.",
        "Analyze the following dependency sanity-check failures and provide minimal, safe fixes.",
        "Prioritize root-cause resolution and include exact command sequences.",
        "",
        "Failure summary:",
    ]

    if not failed_entries:
        lines.append("- No failed imports found. Confirm environment consistency and suggest preventive checks.")
    else:
        for entry in failed_entries:
            requirement = entry.get("requirement", "unknown")
            distribution = entry.get("distribution", "unknown")
            attempted = entry.get("attempted_imports", [])
            error = entry.get("error", "unknown")
            lines.append(f"- requirement: {requirement}")
            lines.append(f"  distribution: {distribution}")
            lines.append(f"  attempted_imports: {attempted}")
            lines.append(f"  error: {error}")

    lines.append("")
    lines.append("Required output format:")
    lines.append("1) Root cause per failure")
    lines.append("2) Proposed lock/dependency changes")
    lines.append("3) Verification commands")
    lines.append("4) Rollback steps")

    return "\n".join(lines)


def build_guidance_markdown(
    report_payload: Dict[str, object],
    prompt_text: str,
    provider_response: str,
    provider_error: str,
) -> str:
    """
    Build markdown guidance from sanity report payload.

    Args:
        report_payload: Parsed sanity-check report payload.
        prompt_text: Prebuilt AI prompt body.
        provider_response: Optional external AI response content.
        provider_error: Optional external AI error details.

    Returns:
        str: Markdown guidance content.
    """

    failed_entries = [
        item for item in report_payload.get("results", []) if isinstance(item, dict) and not item.get("success", False)
    ]

    lines: List[str] = [
        "# Dependency AI Solve Guidance",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        f"Report status: {report_payload.get('status', 'unknown')}",
        f"Total checked: {report_payload.get('total_checked', 0)}",
        f"Failed imports: {report_payload.get('failed_count', 0)}",
        "",
        "## Local analysis",
        "",
    ]

    if not failed_entries:
        lines.append("No failed imports were found. Environment appears consistent.")
    else:
        for index, entry in enumerate(failed_entries, start=1):
            requirement = str(entry.get("requirement", "unknown"))
            error_text = str(entry.get("error", "unknown"))
            hint = _collect_hint(error_text)
            lines.extend(
                [
                    f"### Failure {index}: {requirement}",
                    "",
                    f"- Distribution: `{entry.get('distribution', 'unknown')}`",
                    f"- Attempted imports: `{entry.get('attempted_imports', [])}`",
                    f"- Error: `{error_text}`",
                    f"- Hint: {hint}",
                    "",
                ]
            )

    lines.extend(
        [
            "## Suggested command sequence",
            "",
            "```bash",
            "pdm show --graph",
            "pdm lock --refresh",
            "pdm sync --clean",
            "python -m pip check",
            "```",
            "",
            "## External AI prompt",
            "",
            "Use the following prompt in your preferred AI tool if you want deep conflict-solving suggestions:",
            "",
            "```text",
            prompt_text,
            "```",
            "",
        ]
    )

    if provider_response:
        lines.extend(
            [
                "## External AI response",
                "",
                "```text",
                provider_response,
                "```",
                "",
            ]
        )

    if provider_error:
        lines.extend(
            [
                "## External AI invocation error",
                "",
                f"`{provider_error}`",
                "",
            ]
        )

    return "\n".join(lines)


def _resolve_api_key(api_key_env_name: str) -> str:
    """
    Resolve API key value from environment by variable name.

    Args:
        api_key_env_name: Environment variable name.

    Returns:
        str: API key value or empty string.
    """

    if not api_key_env_name:
        return ""
    return os.getenv(api_key_env_name, "").strip()


def _maybe_invoke_external_provider(args: argparse.Namespace, prompt_text: str) -> Tuple[str, str]:
    """
    Optionally invoke external AI provider based on CLI arguments.

    Args:
        args: Parsed command-line arguments.
        prompt_text: Prompt text to send.

    Returns:
        tuple[str, str]: Provider response and provider error text.
    """

    if args.provider_mode == "none":
        return "", ""

    if args.provider_mode == "openai_compatible":
        if not args.provider_endpoint.strip():
            return "", "Missing --provider-endpoint for provider mode openai_compatible"
        if not args.provider_model.strip():
            return "", "Missing --provider-model for provider mode openai_compatible"

    api_key = _resolve_api_key(args.provider_api_key_env)
    if not api_key:
        return "", (
            f"Missing API key in environment variable '{args.provider_api_key_env}'. "
            "External AI call skipped."
        )

    result: AiProviderResult = invoke_provider(
        provider_mode=args.provider_mode,
        prompt=prompt_text,
        endpoint=args.provider_endpoint,
        model=args.provider_model,
        api_key=api_key,
        timeout_seconds=args.provider_timeout_seconds,
    )

    if result.success:
        return result.content, ""
    return "", result.error


def parse_args() -> argparse.Namespace:
    """
    Parse script arguments.

    Returns:
        argparse.Namespace: Parsed argument namespace.
    """

    parser = argparse.ArgumentParser(description="Build AI troubleshooting guidance from sanity report")
    parser.add_argument("--report", required=True, help="Path to dependency-sanity-report.json")
    parser.add_argument("--output", required=True, help="Path to markdown output file")
    parser.add_argument("--prompt-output", required=True, help="Path to plain-text prompt output")
    parser.add_argument(
        "--provider-mode",
        default="none",
        choices=["none", "openai_compatible"],
        help="External provider mode (default: none).",
    )
    parser.add_argument(
        "--provider-endpoint",
        default="",
        help="External provider endpoint URL for openai_compatible mode.",
    )
    parser.add_argument(
        "--provider-model",
        default="",
        help="External provider model name for openai_compatible mode.",
    )
    parser.add_argument(
        "--provider-api-key-env",
        default="OPENAI_API_KEY",
        help="Environment variable name containing external provider API key.",
    )
    parser.add_argument(
        "--provider-timeout-seconds",
        type=int,
        default=45,
        help="External provider HTTP timeout in seconds.",
    )
    parser.add_argument(
        "--provider-output",
        default="",
        help="Optional path to write provider response text output.",
    )
    return parser.parse_args()


def main() -> int:
    """
    Execute guidance generation.

    Returns:
        int: Process exit code.
    """

    args = parse_args()
    report_path = Path(args.report).resolve()
    output_path = Path(args.output).resolve()
    prompt_output_path = Path(args.prompt_output).resolve()

    if not report_path.exists():
        raise FileNotFoundError(f"Sanity report not found: {report_path}")

    report_payload = _load_json(report_path)
    prompt_text = _build_prompt_body(report_payload)
    provider_response, provider_error = _maybe_invoke_external_provider(args, prompt_text)
    markdown = build_guidance_markdown(
        report_payload=report_payload,
        prompt_text=prompt_text,
        provider_response=provider_response,
        provider_error=provider_error,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding="utf-8")
    prompt_output_path.write_text(prompt_text, encoding="utf-8")

    if args.provider_output:
        provider_output_path = Path(args.provider_output).resolve()
        provider_output_path.parent.mkdir(parents=True, exist_ok=True)
        provider_output_path.write_text(provider_response or provider_error, encoding="utf-8")
        print(f"Provider output: {provider_output_path}")

    print(f"Guidance markdown: {output_path}")
    print(f"Prompt text: {prompt_output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""
Module: build_ai_guidance.py
Author: core-pdm-manager
Date: 2026-03-04
Version: 1.0.0

Description:
    Generate local troubleshooting guidance and AI prompt material from sanity
    check report files.

Usage:
    python build_ai_guidance.py --report /workspace/.pdm-manager/reports/dependency-sanity-report.json --output /workspace/.pdm-manager/reports/ai-solve-guidance.md
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple

from ai_provider_adapter import AiProviderResult, invoke_provider


ERROR_HINTS = {
    "No module named": "Package may not be installed, import name may differ from distribution name, or install failed due marker constraints.",
    "cannot import name": "Package version may be incompatible with another dependency. Try pinning a compatible version range and relocking.",
    "VersionConflict": "Dependency resolver selected incompatible versions. Inspect transitive constraints with `pdm show --graph`.",
}


def _load_json(path: Path) -> Dict[str, object]:
    """
    Load JSON content from file path.

    Args:
        path: JSON file path.

    Returns:
        dict[str, object]: Decoded JSON payload.
    """

    with path.open("r", encoding="utf-8") as file_handle:
        return json.load(file_handle)


def _collect_hint(error_text: str) -> str:
    """
    Resolve a helpful hint for an error text.

    Args:
        error_text: Error text from sanity report.

    Returns:
        str: Guidance hint.
    """

    for needle, hint in ERROR_HINTS.items():
        if needle in error_text:
            return hint
    return "Review resolver output and package metadata. Try pinning direct dependencies and re-running lock generation."


def _build_prompt_body(report_payload: Dict[str, object]) -> str:
    """
    Build reusable AI prompt content from report payload.

    Args:
        report_payload: Sanity report dictionary.

    Returns:
        str: Prompt body text.
    """

    failed_entries = [
        item for item in report_payload.get("results", []) if isinstance(item, dict) and not item.get("success", False)
    ]

    lines: List[str] = [
        "You are an expert Python dependency resolver.",
        "Analyze the following dependency sanity-check failures and provide minimal, safe fixes.",
        "Prioritize root-cause resolution and include exact command sequences.",
        "",
        "Failure summary:",
    ]

    if not failed_entries:
        lines.append("- No failed imports found. Confirm environment consistency and suggest preventive checks.")
    else:
        for entry in failed_entries:
            requirement = entry.get("requirement", "unknown")
            distribution = entry.get("distribution", "unknown")
            attempted = entry.get("attempted_imports", [])
            error = entry.get("error", "unknown")
            lines.append(f"- requirement: {requirement}")
            lines.append(f"  distribution: {distribution}")
            lines.append(f"  attempted_imports: {attempted}")
            lines.append(f"  error: {error}")

    lines.append("")
    lines.append("Required output format:")
    lines.append("1) Root cause per failure")
    lines.append("2) Proposed lock/dependency changes")
    lines.append("3) Verification commands")
    lines.append("4) Rollback steps")

    return "\n".join(lines)


def _build_local_analysis_lines(failed_entries: List[Dict[str, object]]) -> List[str]:
    """
    Build markdown lines for local failed-import analysis.

    Args:
        failed_entries: Failed sanity-check result entries.

    Returns:
        list[str]: Markdown lines describing local analysis findings.
    """

    if not failed_entries:
        return ["No failed imports were found. Environment appears consistent."]

    lines: List[str] = []
    for index, entry in enumerate(failed_entries, start=1):
        requirement = str(entry.get("requirement", "unknown"))
        error_text = str(entry.get("error", "unknown"))
        hint = _collect_hint(error_text)
        lines.extend(
            [
                f"### Failure {index}: {requirement}",
                "",
                f"- Distribution: `{entry.get('distribution', 'unknown')}`",
                f"- Attempted imports: `{entry.get('attempted_imports', [])}`",
                f"- Error: `{error_text}`",
                f"- Hint: {hint}",
                "",
            ]
        )
    return lines


def _build_shared_guidance_lines(prompt_text: str) -> List[str]:
    """
    Build markdown lines shared across guidance outputs.

    Args:
        prompt_text: Prebuilt AI prompt body.

    Returns:
        list[str]: Markdown lines for command guidance and prompt output.
    """

    return [
        "## Suggested command sequence",
        "",
        "```bash",
        "pdm show --graph",
        "pdm lock --refresh",
        "pdm sync --clean",
        "python -m pip check",
        "```",
        "",
        "## External AI prompt",
        "",
        "Use the following prompt in your preferred AI tool if you want deep conflict-solving suggestions:",
        "",
        "```text",
        prompt_text,
        "```",
        "",
    ]


def _build_provider_result_lines(provider_response: str, provider_error: str) -> List[str]:
    """
    Build markdown lines for optional provider output sections.

    Args:
        provider_response: Optional external AI response content.
        provider_error: Optional external AI error details.

    Returns:
        list[str]: Markdown lines for provider response and error details.
    """

    lines: List[str] = []
    if provider_response:
        lines.extend(
            [
                "## External AI response",
                "",
                "```text",
                provider_response,
                "```",
                "",
            ]
        )

    if provider_error:
        lines.extend(
            [
                "## External AI invocation error",
                "",
                f"`{provider_error}`",
                "",
            ]
        )

    return lines


def build_guidance_markdown(
    report_payload: Dict[str, object],
    prompt_text: str,
    provider_response: str,
    provider_error: str,
) -> str:
    """
    Build markdown guidance from sanity report payload.

    Args:
        report_payload: Parsed sanity-check report payload.
        prompt_text: Prebuilt AI prompt body.
        provider_response: Optional external AI response content.
        provider_error: Optional external AI error details.

    Returns:
        str: Markdown guidance content.
    """

    failed_entries = [
        item for item in report_payload.get("results", []) if isinstance(item, dict) and not item.get("success", False)
    ]

    lines: List[str] = [
        "# Dependency AI Solve Guidance",
        "",
        f"Generated: {datetime.now(timezone.utc).isoformat()}",
        f"Report status: {report_payload.get('status', 'unknown')}",
        f"Total checked: {report_payload.get('total_checked', 0)}",
        f"Failed imports: {report_payload.get('failed_count', 0)}",
        "",
        "## Local analysis",
        "",
    ]

    lines.extend(_build_local_analysis_lines(failed_entries))
    lines.extend(_build_shared_guidance_lines(prompt_text))
    lines.extend(_build_provider_result_lines(provider_response, provider_error))

    return "\n".join(lines)


def _resolve_api_key(api_key_env_name: str) -> str:
    """
    Resolve API key value from environment by variable name.

    Args:
        api_key_env_name: Environment variable name.

    Returns:
        str: API key value or empty string.
    """

    if not api_key_env_name:
        return ""
    return os.getenv(api_key_env_name, "").strip()


def _maybe_invoke_external_provider(args: argparse.Namespace, prompt_text: str) -> Tuple[str, str]:
    """
    Optionally invoke external AI provider based on CLI arguments.

    Args:
        args: Parsed command-line arguments.
        prompt_text: Prompt text to send.

    Returns:
        tuple[str, str]: Provider response and provider error text.
    """

    if args.provider_mode == "none":
        return "", ""

    if args.provider_mode == "openai_compatible":
        if not args.provider_endpoint.strip():
            return "", "Missing --provider-endpoint for provider mode openai_compatible"
        if not args.provider_model.strip():
            return "", "Missing --provider-model for provider mode openai_compatible"

    api_key = _resolve_api_key(args.provider_api_key_env)
    if not api_key:
        return "", (
            f"Missing API key in environment variable '{args.provider_api_key_env}'. "
            "External AI call skipped."
        )

    result: AiProviderResult = invoke_provider(
        provider_mode=args.provider_mode,
        prompt=prompt_text,
        endpoint=args.provider_endpoint,
        model=args.provider_model,
        api_key=api_key,
        timeout_seconds=args.provider_timeout_seconds,
    )

    if result.success:
        return result.content, ""
    return "", result.error


def parse_args() -> argparse.Namespace:
    """
    Parse script arguments.

    Returns:
        argparse.Namespace: Parsed argument namespace.
    """

    parser = argparse.ArgumentParser(description="Build AI troubleshooting guidance from sanity report")
    parser.add_argument("--report", required=True, help="Path to dependency-sanity-report.json")
    parser.add_argument("--output", required=True, help="Path to markdown output file")
    parser.add_argument("--prompt-output", required=True, help="Path to plain-text prompt output")
    parser.add_argument(
        "--provider-mode",
        default="none",
        choices=["none", "openai_compatible"],
        help="External provider mode (default: none).",
    )
    parser.add_argument(
        "--provider-endpoint",
        default="",
        help="External provider endpoint URL for openai_compatible mode.",
    )
    parser.add_argument(
        "--provider-model",
        default="",
        help="External provider model name for openai_compatible mode.",
    )
    parser.add_argument(
        "--provider-api-key-env",
        default="OPENAI_API_KEY",
        help="Environment variable name containing external provider API key.",
    )
    parser.add_argument(
        "--provider-timeout-seconds",
        type=int,
        default=45,
        help="External provider HTTP timeout in seconds.",
    )
    parser.add_argument(
        "--provider-output",
        default="",
        help="Optional path to write provider response text output.",
    )
    return parser.parse_args()


def main() -> int:
    """
    Execute guidance generation.

    Returns:
        int: Process exit code.
    """

    args = parse_args()
    report_path = Path(args.report).resolve()
    output_path = Path(args.output).resolve()
    prompt_output_path = Path(args.prompt_output).resolve()

    if not report_path.exists():
        raise FileNotFoundError(f"Sanity report not found: {report_path}")

    report_payload = _load_json(report_path)
    prompt_text = _build_prompt_body(report_payload)
    provider_response, provider_error = _maybe_invoke_external_provider(args, prompt_text)
    markdown = build_guidance_markdown(
        report_payload=report_payload,
        prompt_text=prompt_text,
        provider_response=provider_response,
        provider_error=provider_error,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(markdown, encoding="utf-8")
    prompt_output_path.write_text(prompt_text, encoding="utf-8")

    if args.provider_output:
        provider_output_path = Path(args.provider_output).resolve()
        provider_output_path.parent.mkdir(parents=True, exist_ok=True)
        provider_output_path.write_text(provider_response or provider_error, encoding="utf-8")
        print(f"Provider output: {provider_output_path}")

    print(f"Guidance markdown: {output_path}")
    print(f"Prompt text: {prompt_output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
