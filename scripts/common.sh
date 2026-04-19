#!/usr/bin/env bash
# Shared helper functions for core-pdm-manager shell scripts.

set -o errexit
set -o nounset
set -o pipefail

PDM_MANAGER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PDM_MANAGER_REPO_ROOT="$(cd "${PDM_MANAGER_SCRIPT_DIR}/.." && pwd)"
PDM_MANAGER_DOCKER_COMPOSE_FILE="${PDM_MANAGER_REPO_ROOT}/docker/docker-compose.pdm-manager.yml"
PDM_MANAGER_DEFAULT_CONFIG_FILE="${PDM_MANAGER_REPO_ROOT}/config/config.env"

pdm_manager_print() {
    local color="$1"
    local message="$2"
    local reset='\033[0m'
    echo -e "${color}${message}${reset}"
}

pdm_manager_info() {
    pdm_manager_print '\033[0;36m' "$1"
}

pdm_manager_success() {
    pdm_manager_print '\033[0;32m' "$1"
}

pdm_manager_warn() {
    pdm_manager_print '\033[1;33m' "$1"
}

pdm_manager_error() {
    pdm_manager_print '\033[0;31m' "$1"
}

pdm_manager_usage_project_root() {
    cat <<'EOF'
Project root resolution order:
  1) --project-root argument
  2) PDM_MANAGER_PROJECT_ROOT environment variable
  3) Current working directory
EOF
}

pdm_manager_resolve_abs_path() {
    local path_value="$1"
    if [[ -z "${path_value}" ]]; then
        return 1
    fi

    if [[ -d "${path_value}" ]]; then
        (cd "${path_value}" && pwd)
        return 0
    fi

    if [[ -f "${path_value}" ]]; then
        local parent_dir
        parent_dir="$(cd "$(dirname "${path_value}")" && pwd)"
        echo "${parent_dir}/$(basename "${path_value}")"
        return 0
    fi

    return 1
}

pdm_manager_absolutize_path() {
    local path_value="$1"
    local base_path="${2:-$(pwd)}"

    if [[ -z "${path_value}" ]]; then
        return 1
    fi

    if pdm_manager_resolve_abs_path "${path_value}" >/dev/null 2>&1; then
        pdm_manager_resolve_abs_path "${path_value}"
        return 0
    fi

    if [[ "${path_value}" =~ ^[A-Za-z]:[\\/].* ]] || [[ "${path_value}" == /* ]]; then
        echo "${path_value}"
        return 0
    fi

    local normalized_base
    normalized_base="$(cd "${base_path}" && pwd)"
    echo "${normalized_base}/${path_value}"
}

pdm_manager_detect_project_root() {
    local provided_root="${1:-}"
    local resolved_root=""

    if [[ -n "${provided_root}" ]]; then
        resolved_root="$(pdm_manager_resolve_abs_path "${provided_root}")" || {
            pdm_manager_error "[ERROR] Could not resolve provided --project-root: ${provided_root}"
            return 1
        }
        echo "${resolved_root}"
        return 0
    fi

    if [[ -n "${PDM_MANAGER_PROJECT_ROOT:-}" ]]; then
        resolved_root="$(pdm_manager_resolve_abs_path "${PDM_MANAGER_PROJECT_ROOT}")" || {
            pdm_manager_error "[ERROR] Could not resolve PDM_MANAGER_PROJECT_ROOT=${PDM_MANAGER_PROJECT_ROOT}"
            return 1
        }
        echo "${resolved_root}"
        return 0
    fi

    resolved_root="$(pwd)"
    echo "${resolved_root}"
}

pdm_manager_detect_python_version() {
    local project_root="$1"
    local env_file="${project_root}/.env"

    if [[ -n "${PYTHON_VERSION:-}" ]]; then
        echo "${PYTHON_VERSION}"
        return 0
    fi

    if [[ -f "${env_file}" ]]; then
        local python_line
        python_line="$(grep -E '^PYTHON_VERSION=' "${env_file}" | tail -n 1 || true)"
        if [[ -n "${python_line}" ]]; then
            echo "${python_line#PYTHON_VERSION=}"
            return 0
        fi
    fi

    if [[ -n "${PDM_MANAGER_DEFAULT_PYTHON_VERSION:-}" ]]; then
        echo "${PDM_MANAGER_DEFAULT_PYTHON_VERSION}"
        return 0
    fi

    echo "3.13-slim"
}

pdm_manager_python_version_plain() {
    local python_version="$1"
    echo "${python_version}" | sed 's/-slim$//'
}

pdm_manager_load_env_file() {
    local env_file_path="$1"
    if [[ ! -f "${env_file_path}" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%$'\r'}"
        if [[ -z "${line}" ]] || [[ "${line}" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        if [[ "${line}" != *=* ]]; then
            continue
        fi
        local key="${line%%=*}"
        local value="${line#*=}"
        key="$(echo "${key}" | xargs)"
        value="$(echo "${value}" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
        export "${key}=${value}"
    done < "${env_file_path}"
}

pdm_manager_ensure_config_file() {
    local config_file_path="$1"
    if [[ -f "${config_file_path}" ]]; then
        return 0
    fi

    local example_file="${PDM_MANAGER_REPO_ROOT}/config/config.env.example"
    if [[ -f "${example_file}" ]]; then
        mkdir -p "$(dirname "${config_file_path}")"
        cp "${example_file}" "${config_file_path}"
        pdm_manager_warn "[core-pdm-manager] Created missing config file from template: ${config_file_path}"
        return 0
    fi

    pdm_manager_error "[ERROR] Missing config file: ${config_file_path}"
    return 1
}

pdm_manager_check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        pdm_manager_error "[ERROR] Docker CLI not found. Install Docker Desktop first."
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        pdm_manager_error "[ERROR] Docker daemon is not running."
        return 1
    fi

    if ! docker compose version >/dev/null 2>&1; then
        pdm_manager_error "[ERROR] docker compose command is unavailable."
        return 1
    fi

    pdm_manager_success "[OK] Docker and docker compose are available."
}

pdm_manager_ensure_project_layout() {
    local project_root="$1"
    if [[ ! -d "${project_root}" ]]; then
        pdm_manager_error "[ERROR] Project root does not exist: ${project_root}"
        return 1
    fi

    mkdir -p "${project_root}/.pdm-manager/tmp"
    mkdir -p "${project_root}/.pdm-manager/reports"
}

pdm_manager_infer_uid() {
    if command -v id >/dev/null 2>&1; then
        id -u
    else
        echo "1000"
    fi
}

pdm_manager_infer_gid() {
    if command -v id >/dev/null 2>&1; then
        id -g
    else
        echo "1000"
    fi
}

pdm_manager_run_compose() {
    local project_root="$1"
    local config_file_path="$2"
    shift 2

    pdm_manager_ensure_project_layout "${project_root}"
    pdm_manager_ensure_config_file "${config_file_path}"
    pdm_manager_load_env_file "${config_file_path}"

    export PDM_MANAGER_PROJECT_ROOT="${project_root}"
    export PDM_MANAGER_UID="$(pdm_manager_infer_uid)"
    export PDM_MANAGER_GID="$(pdm_manager_infer_gid)"
    export PYTHON_VERSION="$(pdm_manager_detect_python_version "${project_root}")"

    docker compose -f "${PDM_MANAGER_DOCKER_COMPOSE_FILE}" "$@"
}

pdm_manager_parse_csv_targets() {
    local csv_targets="$1"
    local -n output_array_ref=$2
    output_array_ref=()

    IFS=',' read -r -a raw_targets <<< "${csv_targets}"
    for raw_target in "${raw_targets[@]}"; do
        local cleaned_target
        cleaned_target="$(echo "${raw_target}" | xargs)"
        if [[ -n "${cleaned_target}" ]]; then
            output_array_ref+=("${cleaned_target}")
        fi
    done
}
