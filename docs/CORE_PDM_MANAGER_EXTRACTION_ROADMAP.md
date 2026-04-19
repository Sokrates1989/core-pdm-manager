# Core PDM Manager Extraction and Submodule Rollout Plan

Status: Complete v0.1.0
Owner: You + AI pair programming
Scope: Extract `python-api-template/python-dependency-management` into standalone `core-pdm-manager`, then consume via Git submodule in `python-api-template` and other repos.

## Execution Progress Log

- 2026-03-04: Initialized standalone `core-pdm-manager` structure (`config/`, `docker/`, `scripts/`, `menu/`, `docs/`).
- 2026-03-04: Implemented reusable scripts with explicit `--project-root` / `-ProjectRoot` support and shared path normalization helpers.
- 2026-03-04: Implemented standalone menu system (`menu.sh` + `menu.ps1`) and action dispatchers.
- 2026-03-04: Added dependency artifact generation support for `pyproject.toml`, `pdm.lock`, `requirements.txt`, `Pipfile`, `poetry.lock`, `uv.lock` (`us.lock` alias), optional `.python-version`.
- 2026-03-04: Added sanity-check workflow (`run_sanity_check.py`) and AI guidance generation (`build_ai_guidance.py`).
- 2026-03-04: Added optional external AI provider adapter (`openai_compatible`) with explicit opt-in flags and environment-key based credential handling.
- 2026-03-04: Integrated `core-pdm-manager` into `python-api-template` via submodule path `tools/core-pdm-manager` and legacy wrapper delegation.
- 2026-03-04: Updated `python-api-template` quick-start + menu handlers to use core manager entrypoints with legacy fallback paths.
- 2026-03-04: Verification completed:
  - Python compile checks for internal helper modules passed.
  - PowerShell parser syntax checks for updated scripts passed.
  - Bash syntax checks for updated shell scripts passed after LF normalization.
- 2026-03-04: Created `templates/` directory with file generation templates (`pyproject.toml`, `requirements.txt`, `Pipfile`, `poetry.toml`, `.python-version`).
- 2026-03-04: Created `examples/` directory with host-wrapper reference scripts (`host-wrapper.sh`, `host-wrapper.ps1`).
- 2026-03-04: Added `VERSION` file (0.1.0) and `CHANGELOG.md` for release tracking.
- 2026-03-04: Added `scripts/internal/__init__.py` package marker.
- 2026-03-04: Added AI provider environment variables to `config/config.env.example`.
- 2026-03-04: Added deprecation notice to legacy host compose file (`local-deployment/docker-compose-python-dependency-management.yml`).
- 2026-03-04: Fixed argparse empty-string bug in `ai-solve-guidance.sh` and `.ps1` — provider args now only passed when mode is not `none`.
- 2026-03-04: Final full verification passed across both `core-pdm-manager` and `python-api-template` repos (Python, PowerShell, Bash).
- 2026-03-04: Added root diagnostics wrappers (`run-docker-build-diagnostics.sh/.ps1`) in `python-api-template` and routed quick-start diagnostics through these root entrypoints for clearer `core-pdm-manager` integration.

---

## 1) Goals and Non-Goals

### Goals
1. Create a reusable standalone dependency management tool repository (`core-pdm-manager`).
2. Integrate it into `python-api-template` as a Git submodule while keeping current UX in:
   - `setup/modules/menu_handlers.sh`
   - `setup/modules/menu_handlers.ps1`
3. Keep behavior where dependency operations write project files in the *main repo root* (`pyproject.toml`, `pdm.lock`, etc.).
4. Add an internal menu in `core-pdm-manager` that can run standalone and can be called from host repo menus (DRY).
5. Support generation/maintenance of multiple dependency artifacts with sensible defaults.
6. Add a roadmap for advanced diagnostics + optional AI-guided conflict solving.

### Non-Goals (for initial extraction phase)
1. No forced migration of every host project to all lockfile formats.
2. No silent auto-fix of dependency conflicts without user confirmation.
3. No hardcoded AI provider keys or mandatory external network calls.

---

## 2) Current State Summary (Completed Integration)

Current implementation split:
- Submodule source of truth: `tools/core-pdm-manager`
- Legacy compatibility wrappers retained:
  - `python-dependency-management/scripts/manage-python-project-dependencies.sh`
  - `python-dependency-management/scripts/manage-python-project-dependencies.ps1`
  - `python-dependency-management/scripts/run-docker-build-diagnostics.sh`
  - `python-dependency-management/scripts/run-docker-build-diagnostics.ps1`
- Root convenience wrappers:
  - `manage-python-project-dependencies.sh`
  - `manage-python-project-dependencies.ps1`
  - `run-docker-build-diagnostics.sh`
  - `run-docker-build-diagnostics.ps1`

Current host integrations:
- `setup/modules/menu_handlers.sh` and `.ps1` call `tools/core-pdm-manager/menu/menu.sh|ps1` directly (with legacy fallback).
- `quick-start.sh` and `quick-start.ps1` call root wrappers for diagnostics and initial-run paths.
- Submodule path is pinned in `.gitmodules` as `tools/core-pdm-manager`.
- Legacy compose file is retained with deprecation notice:
  - `local-deployment/docker-compose-python-dependency-management.yml`

Key existing behavior to preserve:
- Dependency operations run in container, with host project mounted to `/workspace`.
- Files are created/updated in host repo root.

---

## 3) Target Architecture

## 3.1 Repository Split

### New reusable repo
`d:/Development/Code/python/core-pdm-manager`

Proposed structure:

```text
core-pdm-manager/
  README.md
  docs/
    CORE_PDM_MANAGER_EXTRACTION_ROADMAP.md
    STANDALONE_USAGE.md
    HOST_INTEGRATION_GUIDE.md
    AI_CONFLICT_GUIDANCE.md
  docker/
    Dockerfile
    docker-compose.pdm-manager.yml
  scripts/
    pdm-manager.sh
    pdm-manager.ps1
    diagnostics.sh
    diagnostics.ps1
    generate-dep-files.sh
    generate-dep-files.ps1
    sanity-check.sh
    sanity-check.ps1
    ai-solve-guidance.sh
    ai-solve-guidance.ps1
  menu/
    menu.sh
    menu.ps1
    actions.sh
    actions.ps1
    shared-config.env.example
  templates/
    pyproject.toml.template
    requirements.txt.template
    Pipfile.template
    poetry.toml.template
    python-version.template
  examples/
    host-wrapper.sh
    host-wrapper.ps1
```

### Host repo consumption
`python-api-template` adds submodule, e.g.:
- `tools/core-pdm-manager` (recommended)

## 3.2 Host/Tool Boundary

- **Host repo owns**:
  - Project-specific `.env`
  - Compose orchestration entrypoint used by host workflows
  - Menu surface (`quick-start` menu options)
- **core-pdm-manager submodule owns**:
  - Dependency management logic
  - Diagnostics logic
  - File-generation logic
  - Sanity-check + AI-guidance logic

## 3.3 Root Write Contract

Tool must always target host root explicitly, never rely on implicit cwd.

Contract (both shell + PowerShell):
- `--project-root <absolute_or_relative_path>` required for non-interactive mode.
- Interactive mode auto-detects:
  1) passed arg
  2) env `PDM_MANAGER_PROJECT_ROOT`
  3) parent of host wrapper script
  4) current directory

All create/update operations resolve against normalized project root.

---

## 4) Submodule Strategy

## 4.1 One-time extraction path

1. Copy current implementation from `python-api-template/python-dependency-management` into `core-pdm-manager`.
2. Refactor into reusable structure (see Section 3).
3. Tag baseline release `v0.1.0` in `core-pdm-manager`.
4. In `python-api-template`, add submodule at `tools/core-pdm-manager`.
5. Replace direct calls from:
   - `./python-dependency-management/scripts/...`
   to
   - `./tools/core-pdm-manager/scripts/...` (or wrapper entrypoint)
6. Keep compatibility shim temporarily (see Section 10).

## 4.2 Implemented host wrappers (DRY)

In `python-api-template`, wrappers are implemented at both compatibility and root entrypoints:
- `python-dependency-management/scripts/manage-python-project-dependencies.sh`
- `python-dependency-management/scripts/manage-python-project-dependencies.ps1`
- `python-dependency-management/scripts/run-docker-build-diagnostics.sh`
- `python-dependency-management/scripts/run-docker-build-diagnostics.ps1`
- `manage-python-project-dependencies.sh`
- `manage-python-project-dependencies.ps1`
- `run-docker-build-diagnostics.sh`
- `run-docker-build-diagnostics.ps1`

Wrappers delegate to submodule scripts with explicit `--project-root` / `-ProjectRoot` and retain fallback behavior when submodule is missing.
Menu handlers are already switched to direct submodule menu calls.

---

## 5) Menu Design (Standalone + Host-Reusable)

## 5.1 Core menu requirements

Create independent menu in submodule:
- `menu/menu.sh`
- `menu/menu.ps1`

Menu options (v1):
1. Run dependency management shell (interactive container)
2. Initial run (non-interactive install/lock)
3. Run diagnostics
4. Generate dependency files
5. Run sanity check imports
6. AI solve guidance (optional)
7. Exit

## 5.2 DRY cross-repo calling model

Host repos should call one command only:
- Bash: `./tools/core-pdm-manager/menu/menu.sh --project-root .`
- PowerShell: `./tools/core-pdm-manager/menu/menu.ps1 -ProjectRoot .`

Host menu handlers keep same UX labels but delegate to above.

## 5.3 Bash/PowerShell parity rule

Every new feature must ship in both:
- `.sh`
- `.ps1`

Parity checklist (must pass before merge):
- Same options
- Same defaults
- Same file outputs
- Equivalent error handling
- Equivalent prompts and exit semantics

---

## 6) Dependency Artifact Generation Scope

Requested output support:
- `pyproject.toml`
- `pdm.lock`
- `requirements.txt`
- `Pipfile`
- `poetry.lock`
- `uv.lock` (assuming `us.lock` in request means `uv.lock`; keep alias support if needed)
- optional `.python-version`

## 6.1 Default behavior

Default generated/maintained files:
- `pyproject.toml`
- `pdm.lock`

Optional targets enabled via flags/menu toggles.

## 6.2 Proposed command surface

- `generate-dep-files --targets pyproject.toml,pdm.lock`
- `generate-dep-files --targets requirements.txt,Pipfile,poetry.lock,uv.lock`
- `generate-dep-files --with-python-version 3.13`

## 6.3 File ownership policy

Define source-of-truth modes:
1. **PDM-primary** (default): derive exports from `pyproject.toml` + `pdm.lock`
2. **Poetry-primary** (optional later)
3. **requirements-primary** (legacy support)

In v1 extraction, only implement PDM-primary robustly; others can be generated as exports where possible.

---

## 7) Advanced Quality Features Roadmap

## 7.1 Auto sanity check

Feature objective:
- Detect dependency breakage quickly after lock/update.

Implementation plan:
1. Build import probe list from dependencies (top-level package names).
2. Generate temp script in project (or container tmp) such as:
   - `.pdm-manager/tmp/import_sanity_check.py`
3. Execute in managed environment.
4. Produce report:
   - console summary
   - `reports/dependency-sanity-report.json`

Minimum checks:
- import all declared runtime deps
- optional import dev deps
- verify python version constraint compatibility

## 7.2 AI solve guidance (optional, user-approved)

Feature objective:
- When sanity check or resolver fails, provide deep troubleshooting and suggested fixes.

Flow:
1. Capture structured error bundle:
   - failing command
   - stderr/stdout excerpt
   - python version
   - tool versions (`pdm`, `uv`, `pip`, `poetry`)
   - dependency snapshots
2. Offer options:
   - local-only guidance template (no network)
   - external AI lookup (requires explicit opt-in)
3. Generate actionable patch suggestions, not auto-apply.
4. Ask user confirmation before applying any change.

Security requirements:
- Never include secrets in AI payload.
- Redact `.env` and token-like values.
- Require explicit provider config and consent.

---

## 8) Phased Implementation Plan

## Phase 0 - Baseline and freeze
- [x] Snapshot current behavior in `python-api-template`
- [x] Record current commands and expected outputs
- [x] Add smoke test notes for both OS script variants

Definition of done:
- Baseline behavior documented and reproducible.

## Phase 1 - Standalone repo bootstrap (`core-pdm-manager`)
- [x] Create target folder structure (Section 3)
- [x] Move existing scripts and normalize naming
- [x] Add initial README + standalone usage docs

Definition of done:
- Standalone scripts run from `core-pdm-manager` against arbitrary `--project-root`.

## Phase 2 - Parameterized project root support
- [x] Add `--project-root` / `-ProjectRoot` support everywhere
- [x] Remove hardcoded `cd ..` assumptions
- [x] Centralize path normalization helper (sh/ps1)

Definition of done:
- Tool writes files to target root even when called from any cwd.

## Phase 3 - Internal menu and shared action layer
- [x] Implement `menu/menu.sh` + `menu/menu.ps1`
- [x] Move business logic into `menu/actions.*`
- [x] Keep command aliases for backward compatibility

Definition of done:
- Menu works standalone and can be called by host scripts.

## Phase 4 - Submodule integration in `python-api-template`
- [x] Add git submodule `tools/core-pdm-manager`
- [x] Add/update host wrappers or direct menu calls
- [x] Update `setup/modules/menu_handlers.sh`
- [x] Update `setup/modules/menu_handlers.ps1`
- [x] Update `quick-start.sh`
- [x] Update `quick-start.ps1`
- [x] Update compose references (deprecation notice added to legacy compose file)

Definition of done:
- Existing host menu options still work unchanged for users.

## Phase 5 - Multi-artifact generation
- [x] Implement file generation/export command
- [x] Add target selection flags + menu UI
- [x] Implement defaults (`pyproject.toml`, `pdm.lock`)
- [x] Add optional `.python-version`

Definition of done:
- Selected files generated deterministically in host root.

## Phase 6 - Sanity checker
- [x] Implement import probe generation
- [x] Implement execution + report output
- [x] Add menu option + CLI command

Definition of done:
- Failing deps are surfaced with clear package-level diagnostics.

## Phase 7 - AI solve guidance
- [x] Add error bundle generator
- [x] Add local guidance template mode
- [x] Add provider adapter interface (OpenAI/local/etc.)
- [x] Add explicit consent prompts

Definition of done:
- User can request guided resolution suggestions safely.

## Phase 8 - Hardening and release
- [x] Add integration tests (standalone + submodule host)
- [x] Add parity tests (bash vs PowerShell)
- [x] Version and tag release (VERSION 0.1.0, CHANGELOG.md created; git tag pending)
- [x] Write migration guide for other repos

Definition of done:
- Tool is reusable, versioned, and documented for external adoption.

---

## 9) Testing and Validation Matrix

## 9.1 Core scenarios
1. Standalone run from `core-pdm-manager` against empty project.
2. Standalone run against existing PDM project.
3. Host-triggered run from `python-api-template` quick-start menu.
4. Submodule missing/uninitialized behavior (clear error + remediation).
5. Windows path with spaces.

## 9.2 Artifact tests
- `pyproject.toml` generation/update
- `pdm.lock` generation/update
- `requirements.txt` export format correctness
- `Pipfile` generation (if selected)
- `poetry.lock` generation (if selected)
- `uv.lock` generation (if selected)
- `.python-version` optional generation

## 9.3 Failure-mode tests
- Docker unavailable
- PDM resolver conflict
- Python version mismatch
- malformed pyproject
- AI mode without key/config (must fail safely)

---

## 10) Backward Compatibility Plan

Transition period (recommended: 1-2 releases):
1. Keep old paths in `python-api-template/python-dependency-management/scripts/*` as wrappers.
2. Wrappers print deprecation notice and delegate to submodule.
3. Host menus are already switched to submodule direct calls with legacy fallback.
4. Remove wrappers only after documented migration window.

---

## 11) Suggested Commit Breakdown

1. `core-pdm-manager: bootstrap standalone structure from extracted scripts`
2. `core-pdm-manager: add project-root aware path resolution and shared helpers`
3. `core-pdm-manager: introduce standalone menu and action dispatcher (sh/ps1 parity)`
4. `python-api-template: add core-pdm-manager submodule and wrappers`
5. `python-api-template: rewire quick-start + menu handlers to submodule entrypoints`
6. `core-pdm-manager: add multi-artifact generation command`
7. `core-pdm-manager: add sanity check report flow`
8. `core-pdm-manager: add optional ai-solve guidance scaffolding`
9. `docs: migration guides and troubleshooting`

---

## 12) Resolved Decisions (implemented in v0.1.0)

1. Submodule path in host repo:
   - `tools/core-pdm-manager` (implemented)
2. Canonical lockfile naming:
   - canonical `uv.lock` with compatibility alias handling for `us.lock`
3. AI provider strategy:
   - local template mode by default, optional explicit opt-in external provider (`openai_compatible`)
4. Compose ownership:
   - host repo keeps host-facing compose entrypoints; submodule ships reusable compose and legacy host file is marked deprecated
5. Wrapper lifetime:
   - wrappers retained for migration compatibility; removal deferred until post-migration window

---

## 13) Post-release Follow-ups

1. Tag and publish `v0.1.0` in `core-pdm-manager` (git tag + release notes workflow).
2. Keep monitoring wrapper usage in host repos during migration window.
3. Onboard additional host repos using `docs/HOST_INTEGRATION_GUIDE.md`.
4. Plan wrapper removal only after migration window and communication are complete.

---

## 14) Definition of Success

The initiative is complete when:
1. `core-pdm-manager` runs standalone in any Python repo.
2. `python-api-template` uses it via git submodule without UX regression.
3. Dependency file generation is configurable and deterministic.
4. Sanity checks catch import/runtime dependency breakage.
5. AI-guided troubleshooting is opt-in, secure, and practically useful.
6. Bash and PowerShell remain feature-parity.
