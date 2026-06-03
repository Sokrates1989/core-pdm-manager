# Work in Progress

Last updated: 2026-06-03

## Status

WIP snapshot. Core PowerShell helper infrastructure being built out.

## What has been done (uncommitted)

- **`scripts/common.ps1`**: large addition of shared PowerShell helper functions
  - Path resolution helpers: `Resolve-PdmManagerPath`, `Get-PdmManagerAbsolutePath`
  - Config management: `Import-PdmManagerEnvFile`, `Ensure-PdmManagerConfigFile`
  - Docker validation: `Test-PdmManagerDocker`
  - Project layout: `Ensure-PdmManagerProjectLayout`
  - Python version resolution: `Get-PdmManagerPythonVersion`, `Get-PdmManagerPlainPythonVersion`
  - CSV target parsing: `ConvertFrom-PdmManagerCsvTargets`
- **`docker/Dockerfile`**: updated for new helper-function-driven build workflow
- **`scripts/internal/ai_provider_adapter.py`**: new AI provider adapter module
- **`scripts/internal/build_ai_guidance.py`**: new AI guidance builder module

## Remaining TODOs

- [ ] Ensure all new `common.ps1` functions have corresponding Bash equivalents in `scripts/common.sh`
- [ ] Verify Docker build with the updated `Dockerfile`
- [ ] Add integration smoke test for `ai_provider_adapter.py` and `build_ai_guidance.py`
- [ ] Review `scripts/internal/` for any remaining stub functions that need implementation
