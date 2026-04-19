"""
Module: ai_provider_adapter.py
Author: core-pdm-manager
Date: 2026-03-04
Version: 1.0.0

Description:
    Optional provider adapter for external AI-assisted troubleshooting.
    Supports an OpenAI-compatible chat-completions endpoint.

Security:
    API keys are read from environment variables only.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from typing import Dict, Optional
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


@dataclass
class AiProviderResult:
    """
    Structured result from an AI provider invocation.

    Attributes:
        success: Whether invocation succeeded.
        content: Provider response content.
        error: Error message when invocation fails.
    """

    success: bool
    content: str
    error: str


def _extract_openai_compatible_content(payload: Dict[str, object]) -> Optional[str]:
    """
    Extract response text from OpenAI-compatible payload formats.

    Args:
        payload: Decoded JSON payload.

    Returns:
        str | None: Extracted response content when available.
    """

    choices = payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return None

    first_choice = choices[0]
    if not isinstance(first_choice, dict):
        return None

    message = first_choice.get("message")
    if isinstance(message, dict):
        content = message.get("content")
        if isinstance(content, str):
            return content

    text = first_choice.get("text")
    if isinstance(text, str):
        return text

    return None


def _build_openai_compatible_payload(prompt: str, model: str) -> Dict[str, object]:
    """
    Build request payload for an OpenAI-compatible chat-completions API.

    Args:
        prompt: Prompt text.
        model: Model identifier.

    Returns:
        dict[str, object]: JSON-serializable request payload.
    """

    return {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": "You are a dependency resolution assistant. Provide minimal, safe, reversible fixes.",
            },
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.2,
    }


def _build_openai_compatible_request(endpoint: str, api_key: str, payload: Dict[str, object]) -> Request:
    """
    Build an HTTP request for an OpenAI-compatible provider call.

    Args:
        endpoint: Full HTTP endpoint URL.
        api_key: API key token.
        payload: JSON-serializable request payload.

    Returns:
        Request: Prepared urllib request object.
    """

    body = json.dumps(payload).encode("utf-8")
    return Request(
        endpoint,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )


def _parse_openai_compatible_response(request: Request, timeout_seconds: int) -> AiProviderResult:
    """
    Execute a provider request and normalize the response.

    Args:
        request: Prepared provider request.
        timeout_seconds: HTTP timeout in seconds.

    Returns:
        AiProviderResult: Normalized provider invocation result.
    """

    with urlopen(request, timeout=timeout_seconds) as response:
        raw = response.read().decode("utf-8")
    payload = json.loads(raw)
    content = _extract_openai_compatible_content(payload)
    if not content:
        return AiProviderResult(success=False, content="", error="Provider response had no content field")
    return AiProviderResult(success=True, content=content, error="")


def _build_provider_error_result(exc: Exception) -> AiProviderResult:
    """
    Convert provider exceptions into a structured result.

    Args:
        exc: Raised provider exception.

    Returns:
        AiProviderResult: Structured failure result.
    """

    if isinstance(exc, HTTPError):
        detail = exc.read().decode("utf-8", errors="replace") if hasattr(exc, "read") else str(exc)
        return AiProviderResult(success=False, content="", error=f"HTTPError {exc.code}: {detail}")
    if isinstance(exc, URLError):
        return AiProviderResult(success=False, content="", error=f"URLError: {exc}")
    return AiProviderResult(success=False, content="", error=f"Unexpected provider error: {exc}")


def invoke_openai_compatible(
    prompt: str,
    endpoint: str,
    model: str,
    api_key: str,
    timeout_seconds: int = 45,
) -> AiProviderResult:
    """
    Invoke an OpenAI-compatible chat-completions endpoint.

    Args:
        prompt: Prompt text.
        endpoint: Full HTTP endpoint URL.
        model: Model identifier.
        api_key: API key token.
        timeout_seconds: HTTP timeout in seconds.

    Returns:
        AiProviderResult: Provider invocation result.
    """

    request_payload = _build_openai_compatible_payload(prompt=prompt, model=model)
    request = _build_openai_compatible_request(endpoint=endpoint, api_key=api_key, payload=request_payload)

    try:
        return _parse_openai_compatible_response(request=request, timeout_seconds=timeout_seconds)
    except (HTTPError, URLError) as exc:
        return _build_provider_error_result(exc)
    except Exception as exc:  # pragma: no cover - defensive boundary
        return _build_provider_error_result(exc)


def invoke_provider(
    provider_mode: str,
    prompt: str,
    endpoint: str,
    model: str,
    api_key: str,
    timeout_seconds: int = 45,
) -> AiProviderResult:
    """
    Dispatch provider invocation based on mode.

    Args:
        provider_mode: Provider mode identifier.
        prompt: Prompt text.
        endpoint: Endpoint URL.
        model: Model identifier.
        api_key: API key value.
        timeout_seconds: HTTP timeout.

    Returns:
        AiProviderResult: Provider invocation result.
    """

    if provider_mode == "openai_compatible":
        return invoke_openai_compatible(
            prompt=prompt,
            endpoint=endpoint,
            model=model,
            api_key=api_key,
            timeout_seconds=timeout_seconds,
        )

    return AiProviderResult(success=False, content="", error=f"Unsupported provider mode: {provider_mode}")
