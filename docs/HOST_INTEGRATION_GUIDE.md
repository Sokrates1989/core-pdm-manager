# Host Integration Guide (Git Submodule)

This guide explains how to consume `core-pdm-manager` from a host repository.

## 1) Add as submodule

From host repository root:

```bash
git submodule add <repo-url-or-relative-path> tools/core-pdm-manager
```

Initialize on fresh clone:

```bash
git submodule update --init --recursive
```

## 2) Recommended host wrappers

Create thin wrappers in the host repo so existing scripts/menu entries remain stable.

Example Bash wrapper (`python-dependency-management/scripts/manage-python-project-dependencies.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
exec ./tools/core-pdm-manager/scripts/pdm-manager.sh --project-root . "$@"
```

Example PowerShell wrapper (`python-dependency-management/scripts/manage-python-project-dependencies.ps1`):

```powershell
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

& .\tools\core-pdm-manager\scripts\pdm-manager.ps1 -ProjectRoot . @RemainingArgs
exit $LASTEXITCODE
```

## 3) Menu handler integration

### Option A: direct action calls

- Bash: `./tools/core-pdm-manager/scripts/pdm-manager.sh --project-root .`
- PowerShell: `.\tools\core-pdm-manager\scripts\pdm-manager.ps1 -ProjectRoot .`

### Option B: call submodule menu (DRY)

- Bash: `./tools/core-pdm-manager/menu/menu.sh --project-root .`
- PowerShell: `.\tools\core-pdm-manager\menu\menu.ps1 -ProjectRoot .`

## 4) First-run automation in host quick-start

For initial setup flow:

- Bash:
  ```bash
  ./tools/core-pdm-manager/scripts/pdm-manager.sh --project-root . --initial-run --non-interactive
  ```
- PowerShell:
  ```powershell
  .\tools\core-pdm-manager\scripts\pdm-manager.ps1 -ProjectRoot . -InitialRun -NonInteractive
  ```

## 5) Submodule health checks

Before invoking tool scripts, host wrappers should verify:

- `tools/core-pdm-manager` exists
- `tools/core-pdm-manager/scripts/pdm-manager.sh` or `.ps1` exists

If missing, print remediation:

```bash
git submodule update --init --recursive
```
