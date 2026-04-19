# core-pdm-manager

Reusable, Docker-based Python dependency manager that can run standalone or as a Git submodule in host repositories.

## Key capabilities

- Works against any host project root (`--project-root` / `-ProjectRoot`)
- Keeps dependency writes in host root (`pyproject.toml`, `pdm.lock`, etc.)
- Bash + PowerShell parity
- Standalone interactive menu
- Host-repo integration via wrapper scripts/menu handlers
- Multi-artifact generation:
  - `pyproject.toml`
  - `pdm.lock`
  - `requirements.txt`
  - `Pipfile`
  - `poetry.lock`
  - `uv.lock` (`us.lock` alias supported)
  - optional `.python-version`
- Sanity check workflow with import probes and JSON reporting
- AI guidance artifact generation for failed sanity checks

## Quick start (standalone)

### Bash

```bash
./menu/menu.sh --project-root /path/to/host-repo
```

### PowerShell

```powershell
.\menu\menu.ps1 -ProjectRoot D:\path\to\host-repo
```

## Direct script usage

### Interactive dependency manager

- Bash: `./scripts/pdm-manager.sh --project-root .`
- PowerShell: `.\scripts\pdm-manager.ps1 -ProjectRoot .`

### Initial setup

- Bash: `./scripts/pdm-manager.sh --project-root . --initial-run --non-interactive`
- PowerShell: `.\scripts\pdm-manager.ps1 -ProjectRoot . -InitialRun -NonInteractive`

### Generate dependency files

- Bash: `./scripts/generate-dep-files.sh --project-root . --targets pyproject.toml,pdm.lock,requirements.txt`
- PowerShell: `.\scripts\generate-dep-files.ps1 -ProjectRoot . -Targets "pyproject.toml,pdm.lock,requirements.txt"`

### Run sanity check

- Bash: `./scripts/sanity-check.sh --project-root . --include-dev --auto-ai-guidance`
- PowerShell: `.\scripts\sanity-check.ps1 -ProjectRoot . -IncludeDev -AutoAiGuidance`

## Configuration

Copy template once:

```bash
cp config/config.env.example config/config.env
```

Main options:

- `USE_UV_BACKEND`
- `PDM_INSTALL_CACHE`
- `PDM_PARALLEL_INSTALL`
- `PDM_MANAGER_DEFAULT_TARGETS`
- `PDM_MANAGER_DEFAULT_PYTHON_VERSION`

## Integration docs

- `docs/HOST_INTEGRATION_GUIDE.md`
- `docs/STANDALONE_USAGE.md`
- `docs/AI_CONFLICT_GUIDANCE.md`
- `docs/CORE_PDM_MANAGER_EXTRACTION_ROADMAP.md`