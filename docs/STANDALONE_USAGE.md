# Standalone Usage

This guide explains how to use `core-pdm-manager` directly in any Python repository.

## 1) Prerequisites

- Docker CLI + daemon
- Docker Compose plugin (`docker compose`)

No local PDM/Poetry/pipenv installation is required.

## 2) Basic flow

### Open interactive dependency manager

#### Bash

```bash
./scripts/pdm-manager.sh --project-root /absolute/path/to/your-project
```

#### PowerShell

```powershell
.\scripts\pdm-manager.ps1 -ProjectRoot D:\absolute\path\to\your-project
```

### Initial non-interactive setup

#### Bash

```bash
./scripts/pdm-manager.sh --project-root /absolute/path/to/your-project --initial-run --non-interactive
```

#### PowerShell

```powershell
.\scripts\pdm-manager.ps1 -ProjectRoot D:\absolute\path\to\your-project -InitialRun -NonInteractive
```

## 3) Generate dependency files

### Default targets (`pyproject.toml`, `pdm.lock`)

#### Bash

```bash
./scripts/generate-dep-files.sh --project-root /absolute/path/to/your-project
```

#### PowerShell

```powershell
.\scripts\generate-dep-files.ps1 -ProjectRoot D:\absolute\path\to\your-project
```

### Custom targets

#### Bash

```bash
./scripts/generate-dep-files.sh \
  --project-root /absolute/path/to/your-project \
  --targets pyproject.toml,pdm.lock,requirements.txt,Pipfile,poetry.lock,uv.lock,.python-version
```

#### PowerShell

```powershell
.\scripts\generate-dep-files.ps1 \
  -ProjectRoot D:\absolute\path\to\your-project \
  -Targets "pyproject.toml,pdm.lock,requirements.txt,Pipfile,poetry.lock,uv.lock,.python-version"
```

## 4) Run sanity checks + AI guidance

### Sanity check only

#### Bash

```bash
./scripts/sanity-check.sh --project-root /absolute/path/to/your-project --include-dev
```

#### PowerShell

```powershell
.\scripts\sanity-check.ps1 -ProjectRoot D:\absolute\path\to\your-project -IncludeDev
```

### Auto-generate AI guidance on failure

#### Bash

```bash
./scripts/sanity-check.sh --project-root /absolute/path/to/your-project --include-dev --auto-ai-guidance
```

#### PowerShell

```powershell
.\scripts\sanity-check.ps1 -ProjectRoot D:\absolute\path\to\your-project -IncludeDev -AutoAiGuidance
```

## 5) Menu mode

#### Bash

```bash
./menu/menu.sh --project-root /absolute/path/to/your-project
```

#### PowerShell

```powershell
.\menu\menu.ps1 -ProjectRoot D:\absolute\path\to\your-project
```
