#!/usr/bin/env bash
set -euo pipefail

INSTDIR="${1:-/tmp/libreoffice/instdir}"
SOFFICE="$INSTDIR/program/soffice.bin"

export LD_LIBRARY_PATH="$INSTDIR/program"
export HOME=/tmp

echo "hello world" > /tmp/smoke.txt

# Candidates that we suspect might be removable
CANDIDATES=(
    libsal_textenclo.so
    libstocserviceslo.so
    libstoragefdlo.so
    libswdlo.so
    libbinaryurplo.so
    libfsstoragelo.so
    libiolo.so
    liblocalebe1lo.so
    libconfigmgrlo.so
    libdeployment.so
    libdesktopbe1lo.so
    libgcc3_uno.so
    libucpfile1.so
    libucphier1.so
    libucppkg1.so
    libucptdoc1lo.so
    libbootstraplo.so
    libpackage2.so
)

SAFE=()
UNSAFE=()

echo "=== Testing each candidate lib ==="

for lib in "${CANDIDATES[@]}"; do
    full="$INSTDIR/program/$lib"
    if [ ! -f "$full" ]; then
        echo "  SKIP $lib (not found)"
        continue
    fi
    
    # Move lib out of the way
    mv "$full" "${full}.bak"
    
    # Test soffice
    set +e
    "$SOFFICE" \
        --headless --invisible --nodefault --nofirststartwizard \
        --nolockcheck --nologo --norestore \
        --convert-to pdf --outdir /tmp /tmp/smoke.txt >/dev/null 2>/dev/null
    rc=$?
    set -e
    
    if [ $rc -eq 0 ] && [ -f /tmp/smoke.pdf ]; then
        echo "  SAFE  $lib (soffice exit $rc)"
        SAFE+=("$lib")
        # Keep removed - it's safe
        rm -f "${full}.bak"
        rm -f /tmp/smoke.pdf
    else
        echo "  NEEDED $lib (soffice exit $rc)"
        UNSAFE+=("$lib")
        # Restore
        mv "${full}.bak" "$full"
    fi
done

echo ""
echo "=== Results ==="
echo ""
echo "Safe to remove (${#SAFE[@]}):"
for lib in "${SAFE[@]}"; do
    echo "  $lib"
done
echo ""
echo "Must keep (${#UNSAFE[@]}):"
for lib in "${UNSAFE[@]}"; do
    echo "  $lib"
done
