# Changelog

All notable changes to core-pdm-manager will be documented in this file.

## [0.1.0] - 2026-03-04

### Added

- Standalone repository structure with `config/`, `docker/`, `scripts/`, `menu/`, `docs/`, `templates/`, `examples/`.
- Reusable scripts with explicit `--project-root` / `-ProjectRoot` support.
- Shared path normalization helpers for Bash and PowerShell (`common.sh`, `common.ps1`).
- Interactive menu system (`menu/menu.sh`, `menu/menu.ps1`) with action dispatchers.
- Dependency artifact generation for `pyproject.toml`, `pdm.lock`, `requirements.txt`, `Pipfile`, `poetry.lock`, `uv.lock` (`us.lock` alias), optional `.python-version`.
- Import-based sanity check runner with JSON report output (`run_sanity_check.py`).
- AI guidance generation from sanity reports (`build_ai_guidance.py`).
- Optional external AI provider adapter for OpenAI-compatible endpoints (`ai_provider_adapter.py`).
- Explicit opt-in consent prompts for external AI invocation in menu actions.
- Dockerized tooling image with PDM, Poetry, pipenv, uv pre-installed.
- Docker Compose service definition for container-based dependency management.
- Configuration via `config/config.env` with example template.
- File templates for `pyproject.toml`, `requirements.txt`, `Pipfile`, `poetry.toml`, `.python-version`.
- Example host-repo wrapper scripts (`examples/host-wrapper.sh`, `examples/host-wrapper.ps1`).
- Documentation: `README.md`, `STANDALONE_USAGE.md`, `HOST_INTEGRATION_GUIDE.md`, `AI_CONFLICT_GUIDANCE.md`, extraction roadmap.
- Host integration tested with `python-api-template` via Git submodule at `tools/core-pdm-manager`.
- Bash and PowerShell parity across all scripts.
