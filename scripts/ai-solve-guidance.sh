#!/usr/bin/env bash
# Build AI troubleshooting guidance from sanity report artifacts.

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

show_help() {
    cat <<'EOF'
Usage: ai-solve-guidance.sh [options]

Options:
  --project-root <path>    Target host project root.
  --config-file <path>     Config env file.
  --report-file <path>     Optional custom sanity report path.
  --use-external-ai        Opt in to external AI provider invocation.
  --provider-endpoint <v>  OpenAI-compatible endpoint URL.
  --provider-model <v>     Provider model name.
  --provider-api-key-env <v> Environment variable containing API key.
  --provider-timeout-seconds <v> HTTP timeout for provider calls.
  --print-prompt           Print generated external AI prompt to stdout.
  -h, --help               Show this help.
EOF
}

PROJECT_ROOT_ARG=""
CONFIG_FILE_ARG="${PDM_MANAGER_DEFAULT_CONFIG_FILE}"
REPORT_FILE_ARG=""
PRINT_PROMPT=false
USE_EXTERNAL_AI=false
PROVIDER_ENDPOINT_ARG=""
PROVIDER_MODEL_ARG=""
PROVIDER_API_KEY_ENV_ARG=""
PROVIDER_TIMEOUT_SECONDS_ARG=""

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
        --report-file)
            REPORT_FILE_ARG="$2"
            shift 2
            ;;
        --use-external-ai)
            USE_EXTERNAL_AI=true
            shift
            ;;
        --provider-endpoint)
            PROVIDER_ENDPOINT_ARG="$2"
            shift 2
            ;;
        --provider-model)
            PROVIDER_MODEL_ARG="$2"
            shift 2
            ;;
        --provider-api-key-env)
            PROVIDER_API_KEY_ENV_ARG="$2"
            shift 2
            ;;
        --provider-timeout-seconds)
            PROVIDER_TIMEOUT_SECONDS_ARG="$2"
            shift 2
            ;;
        --print-prompt)
            PRINT_PROMPT=true
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

if [[ -z "${REPORT_FILE_ARG}" ]]; then
    REPORT_FILE="${PROJECT_ROOT}/.pdm-manager/reports/dependency-sanity-report.json"
else
    REPORT_FILE="$(pdm_manager_absolutize_path "${REPORT_FILE_ARG}" "$(pwd)")"
fi

GUIDANCE_FILE="${PROJECT_ROOT}/.pdm-manager/reports/ai-solve-guidance.md"
PROMPT_FILE="${PROJECT_ROOT}/.pdm-manager/reports/ai-solve-prompt.txt"
PROVIDER_OUTPUT_FILE="${PROJECT_ROOT}/.pdm-manager/reports/ai-provider-response.txt"

if [[ "${REPORT_FILE}" != "${PROJECT_ROOT}"* ]]; then
    pdm_manager_error "[ERROR] Report file must be inside project root: ${PROJECT_ROOT}"
    exit 1
fi

REPORT_CONTAINER_PATH="/workspace/${REPORT_FILE#"${PROJECT_ROOT}/"}"

if [[ ! -f "${REPORT_FILE}" ]]; then
    pdm_manager_error "[ERROR] Sanity report not found: ${REPORT_FILE}"
    pdm_manager_warn "Run sanity-check.sh first."
    exit 1
fi

pdm_manager_check_docker
pdm_manager_ensure_config_file "${CONFIG_FILE}"

provider_mode="none"
provider_endpoint="${PROVIDER_ENDPOINT_ARG:-${PDM_MANAGER_AI_PROVIDER_ENDPOINT:-}}"
provider_model="${PROVIDER_MODEL_ARG:-${PDM_MANAGER_AI_PROVIDER_MODEL:-}}"
provider_api_key_env="${PROVIDER_API_KEY_ENV_ARG:-${PDM_MANAGER_AI_PROVIDER_API_KEY_ENV:-OPENAI_API_KEY}}"
provider_timeout_seconds="${PROVIDER_TIMEOUT_SECONDS_ARG:-${PDM_MANAGER_AI_PROVIDER_TIMEOUT_SECONDS:-45}}"

if [[ "${USE_EXTERNAL_AI}" == true ]]; then
    provider_mode="openai_compatible"
    if [[ -z "${provider_endpoint}" ]]; then
        pdm_manager_error "[ERROR] Missing provider endpoint. Set --provider-endpoint or PDM_MANAGER_AI_PROVIDER_ENDPOINT."
        exit 1
    fi
    if [[ -z "${provider_model}" ]]; then
        pdm_manager_error "[ERROR] Missing provider model. Set --provider-model or PDM_MANAGER_AI_PROVIDER_MODEL."
        exit 1
    fi
    pdm_manager_warn "[WARN] External AI mode enabled. Network call will be attempted."
fi

pdm_manager_info "[core-pdm-manager] Generating AI guidance markdown and prompt artifacts..."

declare -a GUIDANCE_CMD=(
    run --rm dev python /opt/core-pdm-manager/internal/build_ai_guidance.py
    --report "${REPORT_CONTAINER_PATH}"
    --output /workspace/.pdm-manager/reports/ai-solve-guidance.md
    --prompt-output /workspace/.pdm-manager/reports/ai-solve-prompt.txt
    --provider-mode "${provider_mode}"
)

if [[ "${provider_mode}" != "none" ]]; then
    GUIDANCE_CMD+=(--provider-endpoint "${provider_endpoint}")
    GUIDANCE_CMD+=(--provider-model "${provider_model}")
    GUIDANCE_CMD+=(--provider-api-key-env "${provider_api_key_env}")
    GUIDANCE_CMD+=(--provider-timeout-seconds "${provider_timeout_seconds}")
    GUIDANCE_CMD+=(--provider-output /workspace/.pdm-manager/reports/ai-provider-response.txt)
fi

pdm_manager_run_compose "${PROJECT_ROOT}" "${CONFIG_FILE}" "${GUIDANCE_CMD[@]}"

pdm_manager_success "[OK] Guidance file: ${GUIDANCE_FILE}"
pdm_manager_success "[OK] Prompt file: ${PROMPT_FILE}"
if [[ "${USE_EXTERNAL_AI}" == true ]]; then
    pdm_manager_success "[OK] Provider output file: ${PROVIDER_OUTPUT_FILE}"
fi

if [[ "${PRINT_PROMPT}" == true ]]; then
    echo ""
    pdm_manager_info "========== AI SOLVE PROMPT =========="
    cat "${PROMPT_FILE}"
    pdm_manager_info "====================================="
fi
