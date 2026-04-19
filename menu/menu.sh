#!/usr/bin/env bash
# Interactive menu entrypoint for core-pdm-manager.

set -o errexit
set -o nounset
set -o pipefail

MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${MENU_DIR}/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"

# shellcheck source=../scripts/common.sh
source "${SCRIPTS_DIR}/common.sh"
# shellcheck source=actions.sh
source "${MENU_DIR}/actions.sh"

show_help() {
    cat <<'EOF'
Usage: menu.sh [options]

Options:
  --project-root <path>   Target host project root.
  --config-file <path>    Config env file.
  --action <name>         Run non-interactive action and exit.
  -h, --help              Show this help.

Actions:
  dependency-management
  initial-run
  diagnostics
  generate-files
  sanity-check
  ai-guidance
EOF
}

PROJECT_ROOT_ARG=""
CONFIG_FILE_ARG="${PDM_MANAGER_DEFAULT_CONFIG_FILE}"
ACTION_ARG=""

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
        --action)
            ACTION_ARG="$2"
            shift 2
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
if [[ "${CONFIG_FILE_ARG}" != /* && "${CONFIG_FILE_ARG}" != [A-Za-z]:* ]]; then
    if [[ -f "${CONFIG_FILE_ARG}" ]]; then
        CONFIG_FILE="$(pdm_manager_resolve_abs_path "${CONFIG_FILE_ARG}")"
    else
        CONFIG_FILE="${REPO_ROOT}/${CONFIG_FILE_ARG}"
    fi
else
    CONFIG_FILE="${CONFIG_FILE_ARG}"
fi

run_action_by_name() {
    local action_name="$1"

    case "${action_name}" in
        dependency-management)
            run_dependency_management_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        initial-run)
            run_initial_setup_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        diagnostics)
            run_diagnostics_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        generate-files)
            run_generate_dep_files_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        sanity-check)
            run_sanity_check_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        ai-guidance)
            run_ai_guidance_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        *)
            pdm_manager_error "[ERROR] Unsupported action: ${action_name}"
            exit 1
            ;;
    esac
}

if [[ -n "${ACTION_ARG}" ]]; then
    run_action_by_name "${ACTION_ARG}"
    exit 0
fi

while true; do
    echo ""
    echo "========== Core PDM Manager Menu =========="
    echo "Project root: ${PROJECT_ROOT}"
    echo "Config file : ${CONFIG_FILE}"
    echo ""
    echo "1) Open dependency management shell"
    echo "2) Initial setup (non-interactive install)"
    echo "3) Run diagnostics"
    echo "4) Generate dependency files"
    echo "5) Run sanity check"
    echo "6) Build AI solve guidance"
    echo "7) Exit"
    echo ""
    read -r -p "Choose option (1-7): " choice

    case "${choice}" in
        1)
            run_dependency_management_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        2)
            run_initial_setup_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        3)
            run_diagnostics_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        4)
            run_generate_dep_files_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        5)
            run_sanity_check_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        6)
            run_ai_guidance_action "${PROJECT_ROOT}" "${CONFIG_FILE}"
            ;;
        7)
            echo "Exiting core-pdm-manager menu."
            exit 0
            ;;
        *)
            pdm_manager_warn "Invalid selection. Please choose 1-7."
            ;;
    esac

done
