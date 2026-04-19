#!/usr/bin/env bash
# Import-based sanity check runner for dependency integrity.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

show_help() {
    cat <<'EOF'
Usage: sanity-check.sh [options]

Options:
  --project-root <path>    Target host project root.
  --config-file <path>     Config env file.
  --include-dev            Include dev dependencies in checks.
  --skip-build             Skip docker compose build.
  --auto-ai-guidance       Automatically run ai-solve-guidance after failures.
  -h, --help               Show this help.
EOF
}

PROJECT_ROOT_ARG=""
CONFIG_FILE_ARG="${PDM_MANAGER_DEFAULT_CONFIG_FILE}"
INCLUDE_DEV=false
SKIP_BUILD=false
AUTO_AI_GUIDANCE=false

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
        --include-dev)
            INCLUDE_DEV=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --auto-ai-guidance)
            AUTO_AI_GUIDANCE=true
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

REPORT_FILE="${PROJECT_ROOT}/.pdm-manager/reports/dependency-sanity-report.json"

pdm_manager_info "[core-pdm-manager] Running sanity checks for: ${PROJECT_ROOT}"
pdm_manager_check_docker
pdm_manager_ensure_config_file "${CONFIG_FILE}"

if [[ "${SKIP_BUILD}" == false ]]; then
    pdm_manager_info "[core-pdm-manager] Building manager image..."
    pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" build dev
fi

if [[ "${INCLUDE_DEV}" == true ]]; then
    INSTALL_CMD="pdm install --group :all"
    INCLUDE_FLAG="--include-dev"
else
    INSTALL_CMD="pdm install"
    INCLUDE_FLAG=""
fi

pdm_manager_info "[core-pdm-manager] Installing dependencies before sanity import checks..."
pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev /bin/bash -lc "${INSTALL_CMD}"

pdm_manager_info "[core-pdm-manager] Executing import probe suite..."
set +e
if [[ -n "${INCLUDE_FLAG}" ]]; then
    pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev python /opt/core-pdm-manager/internal/run_sanity_check.py --project-root /workspace --output /workspace/.pdm-manager/reports/dependency-sanity-report.json --include-dev
else
    pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" run --rm dev python /opt/core-pdm-manager/internal/run_sanity_check.py --project-root /workspace --output /workspace/.pdm-manager/reports/dependency-sanity-report.json
fi
EXIT_CODE=$?
set -e

if [[ ${EXIT_CODE} -eq 0 ]]; then
    pdm_manager_success "[core-pdm-manager] Sanity check passed."
    pdm_manager_success "Report: ${REPORT_FILE}"
    exit 0
fi

if [[ ${EXIT_CODE} -eq 2 ]]; then
    pdm_manager_warn "[core-pdm-manager] Sanity check found import failures."
    pdm_manager_warn "Report: ${REPORT_FILE}"

    if [[ "${AUTO_AI_GUIDANCE}" == true ]]; then
        pdm_manager_info "[core-pdm-manager] Running AI guidance generator..."
        "${SCRIPT_DIR}/ai-solve-guidance.sh" --project-root "${PROJECT_ROOT}" --config-file "${CONFIG_FILE}" --report-file "${REPORT_FILE}"
    fi

    exit 2
fi

pdm_manager_error "[core-pdm-manager] Sanity check failed unexpectedly. Report may contain traceback details."
exit ${EXIT_CODE}
