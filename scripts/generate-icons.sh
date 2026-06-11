#!/usr/bin/env bash
#
# generate-icons.sh
#
# Regenerates GenyDL's canonical icon assets under resources/icons/ from the
# authoritative root logo (GenyDL.png). This does NOT redesign the logo; it only
# derives copies and the macOS menu-bar template (mask) variants.
#
# Outputs:
#   resources/icons/app/GenyDL.png      - canonical colored app icon (copy)
#   resources/icons/app/GenyDL.icns     - canonical macOS icon (copy)
#   resources/icons/app/GenyDL.ico      - canonical Windows icon (copy)
#   resources/icons/tray/GenyDL.png     - colored tray fallback (Windows/Linux)
#   resources/icons/tray/GenyDLTemplate.png      - macOS template mask, 22x22
#   resources/icons/tray/GenyDLTemplate@2x.png   - macOS template mask, 44x44
#   resources/icons/tray/GenyDLTemplate@3x.png   - macOS template mask, 66x66
#
# Requirements: ImageMagick (the `magick` command).
#
# Usage:
#   ./scripts/generate-icons.sh
#
set -euo pipefail

# Resolve repository root from this script's location, so the script works
# regardless of the current working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Authoritative source logo (kept at repository root for packaging).
SRC_PNG="GenyDL.png"
SRC_ICNS="GenyDL.icns"
SRC_ICO="GenyDL.ico"

APP_DIR="resources/icons/app"
TRAY_DIR="resources/icons/tray"

# Validate ImageMagick availability.
if ! command -v magick >/dev/null 2>&1; then
    echo "error: ImageMagick ('magick') is required but was not found in PATH." >&2
    exit 1
fi

# Validate source files exist before doing any work.
for f in "${SRC_PNG}" "${SRC_ICNS}" "${SRC_ICO}"; do
    if [[ ! -f "${f}" ]]; then
        echo "error: required source file is missing: ${f}" >&2
        exit 1
    fi
done

# Create destination folders.
mkdir -p "${APP_DIR}" "${TRAY_DIR}"

# Track generated files for the final report.
GENERATED=()

# 1) Canonical app icon copies (colored, unchanged).
cp -f "${SRC_PNG}"  "${APP_DIR}/GenyDL.png";  GENERATED+=("${APP_DIR}/GenyDL.png")
cp -f "${SRC_ICNS}" "${APP_DIR}/GenyDL.icns"; GENERATED+=("${APP_DIR}/GenyDL.icns")
cp -f "${SRC_ICO}"  "${APP_DIR}/GenyDL.ico";  GENERATED+=("${APP_DIR}/GenyDL.ico")

# 2) Colored tray fallback for Windows/Linux: trim the surrounding white canvas
#    so the rounded icon fills the frame, fit into a 128x128 box, then pad to an
#    exact 128x128 square with transparent margins.
magick "${SRC_PNG}" -fuzz 6% -trim +repage -resize 128x128 \
    -background none -gravity center -extent 128x128 \
    "${TRAY_DIR}/GenyDL.png"
GENERATED+=("${TRAY_DIR}/GenyDL.png")

# 3) macOS template (mask) glyph.
#    The source is a colored rounded square (white glyph on a colored gradient,
#    sitting on a white canvas). To obtain a clean monochrome glyph silhouette:
#      a. Trim the outer white canvas.
#      b. Reduce to a white-on-black whiteness mask (glyph + rounded corners).
#      c. Flood-fill the border-connected white (canvas/corners) to black,
#         leaving only the centered glyph, which is not connected to the border.
#      d. Compose a black plate whose alpha channel is the glyph mask, producing
#         a transparent-background, black, alpha-mask template image.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

magick "${SRC_PNG}" -fuzz 6% -trim +repage "${TMP_DIR}/sq.png"

magick "${TMP_DIR}/sq.png" \
    -fuzz 35% -fill black +opaque white -fill white -opaque white \
    -colorspace Gray "${TMP_DIR}/mask_raw.png"

magick "${TMP_DIR}/mask_raw.png" \
    -bordercolor white -border 1 \
    -fill black -fuzz 20% -draw "color 0,0 floodfill" \
    -shave 1x1 +repage "${TMP_DIR}/mask_glyph.png"

# Black plate + glyph-as-alpha => transparent-background template at full size.
magick "${TMP_DIR}/mask_glyph.png" -colorspace Gray \
    \( +clone -fill black -colorize 100 \) \
    +swap -compose CopyOpacity -composite \
    "${TMP_DIR}/template_full.png"

# Emit the three template sizes expected by macOS Retina scaling.
magick "${TMP_DIR}/template_full.png" -resize 22x22 "${TRAY_DIR}/GenyDLTemplate.png"
GENERATED+=("${TRAY_DIR}/GenyDLTemplate.png")

magick "${TMP_DIR}/template_full.png" -resize 44x44 "${TRAY_DIR}/GenyDLTemplate@2x.png"
GENERATED+=("${TRAY_DIR}/GenyDLTemplate@2x.png")

magick "${TMP_DIR}/template_full.png" -resize 66x66 "${TRAY_DIR}/GenyDLTemplate@3x.png"
GENERATED+=("${TRAY_DIR}/GenyDLTemplate@3x.png")

# Report.
echo "Generated icon assets:"
for f in "${GENERATED[@]}"; do
    printf '  %s\n' "${f}"
done
