#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="Radio.app"
VOLUME_NAME="Radio"
WINDOW_WIDTH=640
WINDOW_HEIGHT=420
APP_ICON_X=170
APP_ICON_Y=190
APPLICATIONS_ICON_X=470
APPLICATIONS_ICON_Y=190
ICON_SIZE=104
TEXT_SIZE=14
OUTPUT_PATH="${PROJECT_ROOT}/dist/Radio.dmg"
BACKGROUND_SOURCE=""
APP_PATH=""
SKIP_WINDOW_CUSTOMIZATION=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --app PATH           Path to Radio.app. If omitted, the script searches common build locations.
  --output PATH        Output DMG path. Default: ${OUTPUT_PATH}
  --background PATH    Optional PNG/JPG background image.
  --volume-name NAME   Mounted DMG volume name. Default: ${VOLUME_NAME}
  --skip-window-customization  Disable Finder window customization for headless CI.
  --help               Show this message.
EOF
}

log() {
    printf '[build_dmg] %s\n' "$1"
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

find_app() {
    local candidate
    local -a candidates=(
        "${PROJECT_ROOT}/Radio/Products/${APP_NAME}"
        "${PROJECT_ROOT}/Products/${APP_NAME}"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -d "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    candidate="$(find "${HOME}/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/*/${APP_NAME}" -type d -print 2>/dev/null | tail -n 1 || true)"
    if [[ -n "$candidate" && -d "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    return 1
}

generate_background() {
    local destination="$1"

    swift - "$destination" <<'EOF'
import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 640, height: 420)

let image = NSImage(size: size)
image.lockFocus()

NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.85, alpha: 1.0).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.44, alpha: 1.0),
    NSColor(calibratedRed: 0.91, green: 0.53, blue: 0.24, alpha: 1.0)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height), angle: 18)

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 12
NSColor.white.withAlphaComponent(0.92).setStroke()
arrowPath.move(to: NSPoint(x: 286, y: 172))
arrowPath.curve(to: NSPoint(x: 390, y: 172), controlPoint1: NSPoint(x: 318, y: 172), controlPoint2: NSPoint(x: 358, y: 172))
arrowPath.stroke()

let head = NSBezierPath()
head.lineWidth = 12
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: NSPoint(x: 362, y: 198))
head.line(to: NSPoint(x: 390, y: 172))
head.line(to: NSPoint(x: 362, y: 146))
head.stroke()

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to generate DMG background image.\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
EOF
}

configure_dmg_window() {
    local volume_name="$1"
    local app_name="$2"

    osascript <<EOF
tell application "Finder"
    tell disk "${volume_name}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {120, 120, $((120 + WINDOW_WIDTH)), $((120 + WINDOW_HEIGHT))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to ${ICON_SIZE}
        set text size of viewOptions to ${TEXT_SIZE}
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${app_name}" of container window to {${APP_ICON_X}, ${APP_ICON_Y}}
        set position of item "Applications" of container window to {${APPLICATIONS_ICON_X}, ${APPLICATIONS_ICON_Y}}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            APP_PATH="$(resolve_absolute_path "$2")"
            shift 2
            ;;
        --output)
            OUTPUT_PATH="$(resolve_absolute_path "$2")"
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

require_tool hdiutil
require_tool swift

if [[ "${SKIP_WINDOW_CUSTOMIZATION}" -eq 0 ]]; then
    require_tool osascript
fi

if [[ -z "${APP_PATH}" ]]; then
    APP_PATH="$(find_app || true)"
fi

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
    printf 'Could not find %s. Pass it explicitly with --app.\n' "${APP_NAME}" >&2
    exit 1
fi

if [[ -n "${BACKGROUND_SOURCE}" && ! -f "${BACKGROUND_SOURCE}" ]]; then
    printf 'Background image not found: %s\n' "${BACKGROUND_SOURCE}" >&2
    exit 1
fi

APP_BUNDLE_NAME="$(basename "${APP_PATH}")"
DIST_DIR="$(dirname "${OUTPUT_PATH}")"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/radio-dmg-staging.XXXXXX")"
RW_DMG_PATH="$(mktemp "${TMPDIR:-/tmp}/radio-temp.XXXXXX.dmg")"
BACKGROUND_DIR="${STAGING_DIR}/.background"
BACKGROUND_PATH="${BACKGROUND_DIR}/background.png"
VOLUME_PATH="/Volumes/${VOLUME_NAME}"
DEVICE=""

cleanup() {
    if [[ -n "${DEVICE}" ]]; then
        hdiutil detach "${DEVICE}" -quiet || true
    fi
    rm -rf "${STAGING_DIR}" "${RW_DMG_PATH}"
}

trap cleanup EXIT

if [[ -d "${VOLUME_PATH}" ]]; then
    log "Detaching existing mounted volume at ${VOLUME_PATH}"
    hdiutil detach "${VOLUME_PATH}" -force -quiet || true
    sleep 1
fi

mkdir -p "${DIST_DIR}" "${BACKGROUND_DIR}"
rm -f "${OUTPUT_PATH}"

if [[ -n "${BACKGROUND_SOURCE}" ]]; then
    cp "${BACKGROUND_SOURCE}" "${BACKGROUND_PATH}"
else
    generate_background "${BACKGROUND_PATH}"
fi

cp -R "${APP_PATH}" "${STAGING_DIR}/${APP_BUNDLE_NAME}"
ln -s /Applications "${STAGING_DIR}/Applications"

log "Creating read-write disk image"
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "${RW_DMG_PATH}" >/dev/null

log "Mounting disk image"
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG_PATH}" | awk '/\/Volumes\// { print $1; exit }')"

if [[ -z "${DEVICE}" ]]; then
    printf 'Failed to mount temporary disk image.\n' >&2
    exit 1
fi

if [[ ! -d "${VOLUME_PATH}" ]]; then
    printf 'Mounted volume not found at %s\n' "${VOLUME_PATH}" >&2
    exit 1
fi

if [[ "${SKIP_WINDOW_CUSTOMIZATION}" -eq 0 ]]; then
    log "Configuring Finder window"
    configure_dmg_window "${VOLUME_NAME}" "${APP_BUNDLE_NAME}"
else
    log "Skipping Finder window customization"
fi

log "Finalizing disk image"
sync
hdiutil detach "${DEVICE}" -quiet
DEVICE=""

hdiutil convert "${RW_DMG_PATH}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "${OUTPUT_PATH}" >/dev/null

log "DMG created at ${OUTPUT_PATH}"
