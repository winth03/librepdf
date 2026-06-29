#!/usr/bin/env bash
set -euo pipefail

# Smoke test: converts sample documents to PDF using a stripped LibreOffice.
# Usage: test/test-convert.sh [path/to/instdir]

INSTRUCTIONS_DIR="${1:-./instdir}"
SOFFICE="$INSTRUCTIONS_DIR/program/soffice"
TMPDIR="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

if [ ! -x "$SOFFICE" ]; then
    echo "Error: soffice not found at $SOFFICE"
    exit 1
fi

export HOME="$TMPDIR"

# Register LO's share/fonts/ with fontconfig so THSarabunIT9 is visible
# (fonts.conf is created by strip-libreoffice.sh at build time)
FONTCONFIG_FILE="$INSTRUCTIONS_DIR/share/fonts/fonts.conf"
export FONTCONFIG_FILE

check_convert() {
    local label="$1"
    local ext="$2"
    local content="$3"

    local input="$TMPDIR/test.$ext"
    local expected="$TMPDIR/test.pdf"

    echo -n "  [$label] $ext -> pdf ... "

    printf '%s' "$content" > "$input"

    "$SOFFICE" --headless --invisible --nodefault --nofirststartwizard \
        --nolockcheck --nologo --norestore \
        --convert-to pdf --outdir "$TMPDIR" "$input" 2>/dev/null

    if [ -f "$expected" ] && [ -s "$expected" ]; then
        local pages
        pages=$(pdfinfo "$expected" 2>/dev/null | grep Pages | awk '{print $2}' || echo "?")
        echo "OK (${pages}p, $(du -h "$expected" | cut -f1))"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== LibreOffice smoke test ==="
echo "Binary: $SOFFICE"
"$SOFFICE" --version

echo ""

check_convert "text"    "txt"  "Hello World from librepdf!"
check_convert "html"    "html" "<html><body><h1>Hello</h1><p>PDF from HTML</p></body></html>"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
exit $FAIL
