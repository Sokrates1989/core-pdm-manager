#!/usr/bin/env bash
# Example host-repo wrapper script for core-pdm-manager.
#
# Place this in your host repository root and adjust the SUBMODULE_PATH
# to match your submodule location.
#
# Usage:
#   ./manage-dependencies.sh
#   ./manage-dependencies.sh --initial-run

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_PATH="${SCRIPT_DIR}/tools/core-pdm-manager"

if [[ -x "${SUBMODULE_PATH}/menu/menu.sh" ]]; then
    "${SUBMODULE_PATH}/menu/menu.sh" --project-root "${SCRIPT_DIR}" "$@"
else
    echo "[WARN] core-pdm-manager submodule not found at: ${SUBMODULE_PATH}" >&2
    echo "       Run: git submodule update --init --recursive" >&2
    exit 1
fi
