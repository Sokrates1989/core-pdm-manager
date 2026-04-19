#!/usr/bin/env bash
# Action handlers for core-pdm-manager menu.

set -o errexit
set -o nounset
set -o pipefail

MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${MENU_DIR}/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"

run_dependency_management_action() {
    local project_root="$1"
    local config_file="$2"
    "${SCRIPTS_DIR}/pdm-manager.sh" --project-root "${project_root}" --config-file "${config_file}"
}

run_initial_setup_action() {
    local project_root="$1"
    local config_file="$2"
    "${SCRIPTS_DIR}/pdm-manager.sh" --project-root "${project_root}" --config-file "${config_file}" --initial-run --non-interactive
}

run_diagnostics_action() {
    local project_root="$1"
    local config_file="$2"
    "${SCRIPTS_DIR}/diagnostics.sh" --project-root "${project_root}" --config-file "${config_file}"
}

run_generate_dep_files_action() {
    local project_root="$1"
    local config_file="$2"

    local default_targets="${PDM_MANAGER_DEFAULT_TARGETS:-pyproject.toml,pdm.lock}"
    echo ""
    read -r -p "Targets (comma-separated) [${default_targets}]: " target_input
    if [[ -z "${target_input}" ]]; then
        target_input="${default_targets}"
    fi

    read -r -p "Write .python-version as well? (y/N): " include_python_version
    if [[ "${include_python_version}" =~ ^[Yy]$ ]]; then
        if [[ "${target_input}" != *".python-version"* ]]; then
            target_input="${target_input},.python-version"
        fi
    fi

    "${SCRIPTS_DIR}/generate-dep-files.sh" --project-root "${project_root}" --config-file "${config_file}" --targets "${target_input}"
}

run_sanity_check_action() {
    local project_root="$1"
    local config_file="$2"

    read -r -p "Include dev dependencies in sanity check? (y/N): " include_dev
    if [[ "${include_dev}" =~ ^[Yy]$ ]]; then
        "${SCRIPTS_DIR}/sanity-check.sh" --project-root "${project_root}" --config-file "${config_file}" --include-dev
    else
        "${SCRIPTS_DIR}/sanity-check.sh" --project-root "${project_root}" --config-file "${config_file}"
    fi
}

run_ai_guidance_action() {
    local project_root="$1"
    local config_file="$2"

    local use_external_ai="false"
    read -r -p "Use external AI provider lookup? (y/N): " use_external_choice
    if [[ "${use_external_choice}" =~ ^[Yy]$ ]]; then
        use_external_ai="true"
    fi

    if [[ "${use_external_ai}" == "true" ]]; then
        local provider_endpoint="${PDM_MANAGER_AI_PROVIDER_ENDPOINT:-}"
        local provider_model="${PDM_MANAGER_AI_PROVIDER_MODEL:-}"
        local provider_api_key_env="${PDM_MANAGER_AI_PROVIDER_API_KEY_ENV:-OPENAI_API_KEY}"
        local provider_timeout="${PDM_MANAGER_AI_PROVIDER_TIMEOUT_SECONDS:-45}"

        read -r -p "Provider endpoint [${provider_endpoint}]: " input_endpoint
        if [[ -n "${input_endpoint}" ]]; then
            provider_endpoint="${input_endpoint}"
        fi

        read -r -p "Provider model [${provider_model}]: " input_model
        if [[ -n "${input_model}" ]]; then
            provider_model="${input_model}"
        fi

        read -r -p "Provider API key env var [${provider_api_key_env}]: " input_api_env
        if [[ -n "${input_api_env}" ]]; then
            provider_api_key_env="${input_api_env}"
        fi

        read -r -p "Provider timeout seconds [${provider_timeout}]: " input_timeout
        if [[ -n "${input_timeout}" ]]; then
            provider_timeout="${input_timeout}"
        fi

        "${SCRIPTS_DIR}/ai-solve-guidance.sh" --project-root "${project_root}" --config-file "${config_file}" --print-prompt --use-external-ai --provider-endpoint "${provider_endpoint}" --provider-model "${provider_model}" --provider-api-key-env "${provider_api_key_env}" --provider-timeout-seconds "${provider_timeout}"
    else
        "${SCRIPTS_DIR}/ai-solve-guidance.sh" --project-root "${project_root}" --config-file "${config_file}" --print-prompt
    fi
}
