#!/usr/bin/env bash
# Main entrypoint for interactive and initial-run dependency management.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

show_help() {
    cat <<'EOF'
Usage: pdm-manager.sh [options]

Options:
  --project-root <path>   Target host project root.
  --config-file <path>    Config env file (default: core-pdm-manager/config/config.env).
  --initial-run           Execute non-interactive initial setup + pdm install.
  --non-interactive       Skip confirmation prompts.
  --skip-build            Skip docker compose build step.
  -h, --help              Show this help.

Examples:
  ./scripts/pdm-manager.sh --project-root d:/Code/my-project
  ./scripts/pdm-manager.sh --project-root . --initial-run --non-interactive
EOF
}

PROJECT_ROOT_ARG=""
CONFIG_FILE_ARG="${PDM_MANAGER_DEFAULT_CONFIG_FILE}"
INITIAL_RUN_MODE=false
NON_INTERACTIVE=false
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
        --initial-run)
            INITIAL_RUN_MODE=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
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

pdm_manager_info "[core-pdm-manager] Project root: ${PROJECT_ROOT}"
pdm_manager_info "[core-pdm-manager] Config file: ${CONFIG_FILE}"

pdm_manager_check_docker
pdm_manager_ensure_config_file "${CONFIG_FILE}"

pdm_manager_info "[core-pdm-manager] Effective config values:"
while IFS= read -r config_line || [[ -n "${config_line}" ]]; do
    if [[ -z "${config_line}" ]] || [[ "${config_line}" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    pdm_manager_warn "  ${config_line}"
done < "${CONFIG_FILE}"

if [[ "${INITIAL_RUN_MODE}" == false && "${NON_INTERACTIVE}" == false ]]; then
    read -r -p "Proceed with this configuration? (Y/n): " proceed_choice
    if [[ "${proceed_choice:-Y}" =~ ^[Nn]$ ]]; then
        pdm_manager_warn "Aborted by user."
        exit 0
    fi
fi

export PDM_MANAGER_PYTHON_VERSION="$(pdm_manager_python_version_plain "$(pdm_manager_detect_python_version "${PROJECT_ROOT}")")"

if [[ "${SKIP_BUILD}" == false ]]; then
    pdm_manager_info "[core-pdm-manager] Building dependency-management image..."
    pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" build dev
fi

pdm_manager_info "[core-pdm-manager] Running container-side setup..."
pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev /bin/bash /opt/core-pdm-manager/dev-setup.sh

if [[ "${INITIAL_RUN_MODE}" == true ]]; then
    pdm_manager_info "[core-pdm-manager] Running initial pdm install..."
    pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev pdm install
    pdm_manager_success "[core-pdm-manager] Initial run completed successfully."
    exit 0
fi

pdm_manager_info "[core-pdm-manager] Opening interactive shell in dependency manager container..."
pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev
