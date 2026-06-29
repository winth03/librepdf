#!/usr/bin/env bash
set -e

INSTDIR="${1:?Usage: $0 <path/to/instdir>}"

echo "=== Smoke test: PDF conversion ==="

echo "hello world" > /tmp/smoke.txt

SOFFICE="$INSTDIR/program/soffice.bin"

export HOME=/tmp
export FONTCONFIG_FILE="$INSTDIR/share/fonts/fonts.conf"
export URE_BOOTSTRAP="file://${INSTDIR}/program/services.rdb"
export LD_LIBRARY_PATH="$INSTDIR/program"

set +e
"$SOFFICE" \
    --headless --invisible --nodefault --nofirststartwizard \
    --nolockcheck --nologo --norestore \
    -env:UserInstallation=file:///tmp/lo_profile_smoke \
    --convert-to pdf --outdir /tmp /tmp/smoke.txt 2>&1

EXIT_CODE=$?
echo ""
echo "=== soffice exit code: $EXIT_CODE ==="

if [ -f /tmp/smoke.pdf ]; then
    echo "=== SUCCESS: PDF produced at /tmp/smoke.pdf ==="
    rm -f /tmp/smoke.txt /tmp/smoke.pdf
    exit 0
else
    echo "=== FAILURE: No PDF produced ==="
    rm -f /tmp/smoke.txt
    exit 1
fi
