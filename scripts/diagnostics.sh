#!/usr/bin/env bash
# Diagnostic entrypoint for validating dependency manager readiness.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

show_help() {
    cat <<'EOF'
Usage: diagnostics.sh [options]

Options:
  --project-root <path>   Target host project root.
  --config-file <path>    Config env file.
  --skip-build            Skip docker compose build.
  -h, --help              Show this help.
EOF
}

PROJECT_ROOT_ARG=""
CONFIG_FILE_ARG="${PDM_MANAGER_DEFAULT_CONFIG_FILE}"
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root)
            PROJECT_ROOT_ARG="$2"
            shift 2
            ;;
        --config-file)
            CONFIG_FILE_ARG="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            pdm_manager_error "[ERROR] Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

PROJECT_ROOT="$(pdm_manager_detect_project_root "${PROJECT_ROOT_ARG}")"
if [[ "${CONFIG_FILE_ARG}" =~ ^[A-Za-z]:[\\/].* ]] || [[ "${CONFIG_FILE_ARG}" == /* ]]; then
    CONFIG_FILE="$(pdm_manager_absolutize_path "${CONFIG_FILE_ARG}" "$(pwd)")"
else
    if [[ -f "${CONFIG_FILE_ARG}" ]]; then
        CONFIG_FILE="$(pdm_manager_absolutize_path "${CONFIG_FILE_ARG}" "$(pwd)")"
    else
        CONFIG_FILE="$(pdm_manager_absolutize_path "${CONFIG_FILE_ARG}" "${PDM_MANAGER_REPO_ROOT}")"
    fi
fi

pdm_manager_info "[core-pdm-manager] Diagnostics project root: ${PROJECT_ROOT}"
pdm_manager_info "[core-pdm-manager] Diagnostics config file: ${CONFIG_FILE}"

pdm_manager_check_docker
pdm_manager_ensure_config_file "${CONFIG_FILE}"

if [[ "${SKIP_BUILD}" == false ]]; then
    pdm_manager_info "[core-pdm-manager] Building manager image for diagnostics..."
    pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" build dev
fi

pdm_manager_info "[core-pdm-manager] Running container toolchain checks..."
pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev /bin/bash -lc "python --version && pdm --version && uv --version && poetry --version && pipenv --version"

if [[ -f "${PROJECT_ROOT}/pyproject.toml" ]]; then
    pdm_manager_info "[core-pdm-manager] pyproject.toml detected; validating lock state..."
    if pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev pdm lock --check; then
        pdm_manager_success "[OK] pdm.lock is up-to-date."
    else
        pdm_manager_warn "[WARN] pdm.lock appears out of date. Run generate-dep-files or pdm lock."
    fi
else
    pdm_manager_warn "[WARN] pyproject.toml missing in project root."
fi

for file_name in "pyproject.toml" "pdm.lock" "requirements.txt" "Pipfile" "poetry.lock" "uv.lock" ".python-version"; do
    if [[ -f "${PROJECT_ROOT}/${file_name}" ]]; then
        pdm_manager_success "[OK] ${file_name} exists"
    else
        pdm_manager_warn "[INFO] ${file_name} not found"
    fi
done

pdm_manager_success "[core-pdm-manager] Diagnostics completed."
