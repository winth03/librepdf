#!/usr/bin/env bash
set -euo pipefail

DOCX="${1:?Usage: $0 <path/to/docx>}"
INSTRUCTIONS_DIR="${2:-/tmp/libreoffice/instdir}"
SOFFICE="$INSTRUCTIONS_DIR/program/soffice"
TMPDIR="$(mktemp -d)"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

echo "=== Thai text conversion test ==="
echo "Input:  $DOCX"
echo "Binary: $SOFFICE"
"$SOFFICE" --version 2>&1 | head -1

cp "$DOCX" "$TMPDIR/input.docx"

# fonts.conf registers LO's share/fonts/ with fontconfig (no file copy needed)
export HOME="$TMPDIR"
export FONTCONFIG_FILE="$INSTRUCTIONS_DIR/share/fonts/fonts.conf"

set +e
"$SOFFICE" --headless --invisible --nodefault --nofirststartwizard \
    --nolockcheck --nologo --norestore \
    --convert-to pdf --outdir "$TMPDIR" "$TMPDIR/input.docx" 2>&1
EXIT_CODE=$?
echo "soffice exit code: $EXIT_CODE"

PDF="$TMPDIR/input.pdf"
if [ ! -f "$PDF" ] || [ ! -s "$PDF" ]; then
    echo "FAIL: PDF not produced"
    exit 1
fi

echo "PDF: $(du -h "$PDF" | cut -f1)"
echo ""

# Extract text using python3 + pypdf
echo "--- Extracted text (first 500 chars) ---"
python3 -c "
from pypdf import PdfReader
import re

r = PdfReader('$PDF')
full = ''
for p in r.pages:
    full += p.extract_text() + '\\n'

print(full[:500])

thai = bool(re.search(r'[\u0E00-\u0E7F]', full))
print()
print('Thai characters found:', thai)
if thai:
    count = len(re.findall(r'[\u0E00-\u0E7F]', full))
    print(f'Thai text present ✓ ({count} characters)')
else:
    print('WARNING: No Thai characters detected in PDF output')
    print('Full text repr:', repr(full[:200]))
"

echo ""
echo "=== Thai test complete ==="
