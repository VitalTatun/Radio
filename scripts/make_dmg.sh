#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_PATH="${PROJECT_ROOT}/Radio.xcodeproj"
SCHEME_NAME="Radio"
CONFIGURATION="Release"
BUILD_ROOT="${PROJECT_ROOT}/dist/build"
OUTPUT_PATH="${PROJECT_ROOT}/dist/Radio.dmg"
OUTPUT_PATH_EXPLICIT=0
BACKGROUND_SOURCE=""
VOLUME_NAME="Radio"
SKIP_WINDOW_CUSTOMIZATION=0
VERSION=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --configuration NAME  Xcode build configuration. Default: ${CONFIGURATION}
  --output PATH         Output DMG path. Default: ${OUTPUT_PATH}
  --background PATH     Optional PNG/JPG background image passed to build_dmg.sh
  --volume-name NAME    DMG volume name. Default: ${VOLUME_NAME}
  --version VALUE       Version suffix for DMG name, e.g. v1.2.0 -> Radio-v1.2.0.dmg
  --skip-window-customization  Disable Finder window customization for headless CI
  --help                Show this message.
EOF
}

log() {
    printf '[make_dmg] %s\n' "$1"
}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Missing required tool: %s\n' "$1" >&2
        exit 1
    fi
}

resolve_absolute_path() {
    local path="$1"
    if [[ "$path" = /* ]]; then
        printf '%s\n' "$path"
    else
        printf '%s\n' "${PROJECT_ROOT}/${path}"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_PATH="$(resolve_absolute_path "$2")"
            OUTPUT_PATH_EXPLICIT=1
            shift 2
            ;;
        --background)
            BACKGROUND_SOURCE="$(resolve_absolute_path "$2")"
            shift 2
            ;;
        --volume-name)
            VOLUME_NAME="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --skip-window-customization)
            SKIP_WINDOW_CUSTOMIZATION=1
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

require_tool xcodebuild
require_tool bash

if [[ ! -d "${PROJECT_PATH}" ]]; then
    printf 'Xcode project not found: %s\n' "${PROJECT_PATH}" >&2
    exit 1
fi

if [[ -n "${BACKGROUND_SOURCE}" && ! -f "${BACKGROUND_SOURCE}" ]]; then
    printf 'Background image not found: %s\n' "${BACKGROUND_SOURCE}" >&2
    exit 1
fi

if [[ -n "${VERSION}" && "${OUTPUT_PATH_EXPLICIT}" -eq 0 ]]; then
    OUTPUT_PATH="${PROJECT_ROOT}/dist/Radio-${VERSION}.dmg"
fi

mkdir -p "${BUILD_ROOT}" "$(dirname "${OUTPUT_PATH}")"

log "Building ${SCHEME_NAME} (${CONFIGURATION})"
xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_ROOT}" \
    build

APP_PATH="${BUILD_ROOT}/Build/Products/${CONFIGURATION}/Radio.app"

if [[ ! -d "${APP_PATH}" ]]; then
    printf 'Built app not found: %s\n' "${APP_PATH}" >&2
    exit 1
fi

BUILD_DMG_ARGS=(
    "${SCRIPT_DIR}/build_dmg.sh"
    --app "${APP_PATH}"
    --output "${OUTPUT_PATH}"
    --volume-name "${VOLUME_NAME}"
)

if [[ -n "${BACKGROUND_SOURCE}" ]]; then
    BUILD_DMG_ARGS+=(--background "${BACKGROUND_SOURCE}")
fi

if [[ "${SKIP_WINDOW_CUSTOMIZATION}" -eq 1 ]]; then
    BUILD_DMG_ARGS+=(--skip-window-customization)
fi

log "Packaging DMG"
bash "${BUILD_DMG_ARGS[@]}"

log "Finished: ${OUTPUT_PATH}"
