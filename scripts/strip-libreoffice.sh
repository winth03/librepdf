#!/usr/bin/env bash
set -euo pipefail

INSTDIR="${1:-./instdir}"

if [ ! -d "$INSTDIR/program" ]; then
    echo "Error: '$INSTDIR' does not look like a LibreOffice instdir/"
    exit 1
fi

echo "=== Stripping debug symbols from shared objects ==="
find "$INSTDIR" \( -name '*.so' -o -name '*.so.*' -o -name '*.o' \) \
    -print0 | xargs -0 -r strip --strip-unneeded 2>/dev/null || true

echo "=== Removing gallery ==="
rm -rf "$INSTDIR/share/gallery"

echo "=== Removing bundled images ==="
rm -f "$INSTDIR/share/config/images_*.zip"

echo "=== Removing basic macros ==="
rm -rf "$INSTDIR/share/basic"

echo "=== Removing xslt ==="
rm -rf "$INSTDIR/share/xslt"

echo "=== Removing xpdfimport ==="
rm -rf "$INSTDIR/share/xpdfimport"

echo "=== Removing readmes and legal docs ==="
rm -rf "$INSTDIR/readmes"
rm -f "$INSTDIR/CREDITS.fodt"
rm -f "$INSTDIR/LICENSE"*
rm -f "$INSTDIR/NOTICE"
rm -f "$INSTDIR/THIRDPARTYLICENSE"*

echo "=== Removing extensions ==="
rm -rf "$INSTDIR/share/extensions/"*

echo "=== Removing templates ==="
rm -rf "$INSTDIR/share/template/"*

echo "=== Removing wizards ==="
rm -rf "$INSTDIR/share/config/wizard/"*

echo "=== Removing Java classes ==="
rm -rf "$INSTDIR/program/classes/"

echo "=== Removing Python ==="
rm -rf "$INSTDIR/program/python/"

echo "=== Removing LibreLogo scripting ==="
rm -rf "$INSTDIR/share/Scripts/"

echo "=== Removing Math module wrapper ==="
rm -f "$INSTDIR/program/smath"

echo "=== Removing help files ==="
rm -rf "$INSTDIR/share/help/"

echo "=== Removing man pages ==="
rm -rf "$INSTDIR/share/man/"

echo "=== Removing palette ==="
rm -rf "$INSTDIR/share/palette"

echo "=== Removing SDK ==="
rm -rf "$INSTDIR/sdk/"

echo "=== Removing VBA libs ==="
rm -f "$INSTDIR/program/libvba"*.so

echo "=== Removing slide show / media / animation / DB UI libs ==="
rm -f \
    "$INSTDIR/program/libslideshowlo.so" \
    "$INSTDIR/program/libavmedialo.so" \
    "$INSTDIR/program/libOGLTranslo.so" \
    "$INSTDIR/program/libPresentationMinimizerlo.so" \
    "$INSTDIR/program/libanimcorelo.so" \
    "$INSTDIR/program/libcrashextensionlo.so" \
    "$INSTDIR/program/libupdatefeedlo.so" \
    "$INSTDIR/program/libdbulo.so"

echo "=== Removing Calc/Writer/Draw/Impress libs ==="
rm -f \
    "$INSTDIR/program/libsclo.so" \
    "$INSTDIR/program/libscfiltlo.so" \
    "$INSTDIR/program/libscuilo.so" \
    "$INSTDIR/program/libsdlo.so" \
    "$INSTDIR/program/libsduilo.so" \
    "$INSTDIR/program/libwpftcalc.so" \
    "$INSTDIR/program/libwpftdrawlo.so" \
    "$INSTDIR/program/libwpftimpresslo.so" \
    "$INSTDIR/program/libwpftqahelper.so" \
    "$INSTDIR/program/libcuilo.so"

echo "=== Removing firebird ==="
rm -rf "$INSTDIR/share/firebird"

echo "=== Removing database libs ==="
rm -f \
    "$INSTDIR/program/libdbalo.so" \
    "$INSTDIR/program/libfbclient.so.2" \
    "$INSTDIR/program/libpostgresql-sdbc-impllo.so" \
    "$INSTDIR/program/libmysqlclo.so" \
    "$INSTDIR/program/libdbaxmllo.so" \
    "$INSTDIR/program/libpostgresql-sdbclo.so" \
    "$INSTDIR/program/libdbahsqllo.so" \
    "$INSTDIR/program/libdbaselo.so" \
    "$INSTDIR/program/libmysql_jdbclo.so" \
    "$INSTDIR/program/libfirebird_sdbclo.so" \
    "$INSTDIR/program/libEngine12.so" \
    "$INSTDIR/program/libodbclo.so" \
    "$INSTDIR/program/libsdbc2lo.so" \
    "$INSTDIR/program/libsdbtlo.so" \
    "$INSTDIR/program/libdbplo.so" \
    "$INSTDIR/program/libdbpool2lo.so" \
    "$INSTDIR/program/libfbintllo.so"
rm -rf \
    "$INSTDIR/share/registry/postgresql.xcd" \
    "$INSTDIR/share/config/soffice.cfg/modules/dbapp/" \
    "$INSTDIR/program/services/postgresql-sdbc.rdb"


echo "=== Removing CMIS content management ==="
rm -f "$INSTDIR/program/libucpcmis1lo.so"

echo "=== Removing Math editor ==="
rm -f "$INSTDIR/program/libsmlo.so"

echo "=== Removing Report builder ==="
rm -f \
    "$INSTDIR/program/librptlo.so" \
    "$INSTDIR/program/librptuilo.so"

echo "=== Removing xpdfimport binary ==="
rm -f "$INSTDIR/program/xpdfimport"

echo "=== Removing import filters ==="
rm -f \
    "$INSTDIR/program/libmwaw-0.3-lo.so.3" \
    "$INSTDIR/program/libetonyek-0.1-lo.so.1" \
    "$INSTDIR/program/libstaroffice-0.0-lo.so.0" \
    "$INSTDIR/program/libwps-0.4-lo.so.4" \
    "$INSTDIR/program/libwpd-0.10-lo.so.10" \
    "$INSTDIR/program/libwpftwriterlo.so"

echo "=== Removing locale data (keeping en + th only) ==="
rm -f \
    "$INSTDIR/program/liblocaledata_euro.so" \
    "$INSTDIR/program/liblocaledata_es.so" \
    "$INSTDIR/program/liblocaledata_others.so"
rm -rf \
    "$INSTDIR/share/autocorr/" \
    "$INSTDIR/share/numbertext/"

echo "=== Removing UI config for removed modules ==="
rm -rf \
    "$INSTDIR/share/config/soffice.cfg/modules/scalc/" \
    "$INSTDIR/share/config/soffice.cfg/modules/simpress/" \
    "$INSTDIR/share/config/soffice.cfg/modules/sdraw/" \
    "$INSTDIR/share/config/soffice.cfg/modules/schart/" \
    "$INSTDIR/share/config/soffice.cfg/modules/smath/" \
    "$INSTDIR/share/config/soffice.cfg/dbaccess/" \
    "$INSTDIR/share/config/soffice.cfg/modules/BasicIDE/" \
    "$INSTDIR/share/config/soffice.cfg/modules/sbibliography/" \
    "$INSTDIR/share/config/soffice.cfg/modules/sabpilot/" \
    "$INSTDIR/share/config/soffice.cfg/modules/dbreport/" \
    "$INSTDIR/share/config/soffice.cfg/modules/dbapp/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swform/" \
    "$INSTDIR/share/config/soffice.cfg/modules/sweb/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swxform/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swreport/" \
    "$INSTDIR/share/config/soffice.cfg/modules/sglobal/"

echo "=== Removing filter libs ==="
rm -f \
    "$INSTDIR/program/libsvgfilterlo.so" \
    "$INSTDIR/program/libfilelo.so" \
    "$INSTDIR/program/libswuilo.so"

echo "=== Removing import filters and modules ==="
rm -f \
    "$INSTDIR/program/libhwplo.so" \
    "$INSTDIR/program/libwpftcalclo.so" \
    "$INSTDIR/program/libwriterperfectlo.so" \
    "$INSTDIR/program/libt602filterlo.so" \
    "$INSTDIR/program/libmigrationoo3lo.so" \
    "$INSTDIR/program/libmigrationoo2lo.so" \
    "$INSTDIR/program/libpdfimportlo.so" \
    "$INSTDIR/program/libucpchelp1.so" \
    "$INSTDIR/program/libdeploymentgui.so" \
    "$INSTDIR/program/libbiblo.so" \
    "$INSTDIR/program/libcalclo.so" \
    "$INSTDIR/program/libpricinglo.so" \
    "$INSTDIR/program/libsolverlo.so" \
    "$INSTDIR/program/libpyuno.so" \
    "$INSTDIR/program/libscriptframe.so" \
    "$INSTDIR/program/libtextconversiondlgslo.so" \
    "$INSTDIR/program/libloglo.so" \
    "$INSTDIR/program/libscnlo.so" \
    "$INSTDIR/program/librptxmllo.so" \
    "$INSTDIR/program/libabplo.so" \
    "$INSTDIR/program/libmozbootstraplo.so" \
    "$INSTDIR/program/libcmdmaillo.so" \
    "$INSTDIR/program/libunopkgapplo.so" \
    "$INSTDIR/program/libanalysislo.so"

echo "=== Removing Writer UI config ==="
rm -rf \
    "$INSTDIR/share/config/soffice.cfg/modules/swriter/ui/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swriter/menubar/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swriter/popupmenu/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swriter/statusbar/" \
    "$INSTDIR/share/config/soffice.cfg/modules/swriter/toolbar/"

echo "=== Injecting custom fonts ==="
mkdir -p "$INSTDIR/share/fonts"
if [ -d /tmp/fonts ] && [ "$(ls -A /tmp/fonts 2>/dev/null)" ]; then
    cp -r /tmp/fonts/* "$INSTDIR/share/fonts/"
    echo "Injected fonts from /tmp/fonts"
else
    echo "No custom fonts found at /tmp/fonts, skipping"
fi

echo "=== Creating fontconfig config for LO share/fonts ==="
cat > "$INSTDIR/share/fonts/fonts.conf" << 'FONTCONF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <!-- Register share/fonts/ with fontconfig -->
  <dir prefix="relative">.</dir>

  <!-- THSarabunNew as default font family -->
  <alias><family>sans-serif</family><prefer><family>THSarabunNew</family></prefer></alias>
  <alias><family>serif</family><prefer><family>THSarabunNew</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>THSarabunNew</family></prefer></alias>

  <!-- Map MS Office font names to THSarabunNew -->
  <match target="pattern">
    <test name="family"><string>Calibri</string></test>
    <edit name="family" mode="prepend"><string>THSarabunNew</string></edit>
  </match>
  <match target="pattern">
    <test name="family"><string>Cambria</string></test>
    <edit name="family" mode="prepend"><string>THSarabunNew</string></edit>
  </match>
  <match target="pattern">
    <test name="family"><string>Arial</string></test>
    <edit name="family" mode="prepend"><string>THSarabunNew</string></edit>
  </match>
  <match target="pattern">
    <test name="family"><string>Times New Roman</string></test>
    <edit name="family" mode="prepend"><string>THSarabunNew</string></edit>
  </match>
</fontconfig>
FONTCONF
echo "  Created $INSTDIR/share/fonts/fonts.conf"

echo "=== Stripping ICU data to en + th only ==="
LO_ROOT=$(dirname "$INSTDIR")
ICU_ROOT="$LO_ROOT/workdir/UnpackedTarball/icu/source"
ICUPKG="$ICU_ROOT/bin/icupkg"
PKGDATA="$ICU_ROOT/bin/pkgdata"
ICUPKG_INC="$ICU_ROOT/data/icupkg.inc"
LIST_FILE="$ICU_ROOT/data/out/tmp/icudata.lst"
BUILDDIR="$ICU_ROOT/data/out/build/icudt77l"
export LD_LIBRARY_PATH="${ICU_ROOT}/lib:${ICU_ROOT}/stubdata"

if [ ! -f "$LIST_FILE" ] || [ ! -d "$BUILDDIR" ]; then
    echo "  ICU build artifacts not found, skipping ICU data strip"
else
    echo "  Found ICU build artifacts, filtering locale data..."
    
    python3 -c "
import re, os, sys

items = open(sys.argv[1]).read().splitlines()

# Identify locale codes in .res files (only keep en* and th*)
locale_codes_to_remove = set()
for item in items:
    parts = item.split('/')
    stem = parts[-1].split('.')[0] if parts else ''
    if re.match(r'^[a-z]{2,3}(_[A-Z]{2,4})?$', stem):
        if not stem.startswith('en') and not stem.startswith('th'):
            locale_codes_to_remove.add(stem)

keep = []
for item in items:
    parts = item.split('/')
    filename = parts[-1] if parts else item
    stem, ext = os.path.splitext(filename)

    # Keep infrastructure files (break rules, normalization, Unicode props)
    if ext in ('.brk', '.nrm', '.icu', '.cnv', '.spp'):
        keep.append(item)
        continue
    if filename in ('pool.res', 'root.res'):
        keep.append(item)
        continue

    # Remove locale-bound .res files for non-en/non-th locales
    if ext == '.res' and stem in locale_codes_to_remove:
        continue

    keep.append(item)

open(sys.argv[2], 'w').write('\n'.join(keep) + '\n')
print(f'  Keep {len(keep)} of {len(items)} items')
" "$LIST_FILE" "${LIST_FILE}.keep"
    
    python3 -c "
import sys, os
keep = set(open(sys.argv[1]).read().splitlines())
builddir = sys.argv[2]
deleted = 0
for root, dirs, files in os.walk(builddir):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), builddir)
        if rel not in keep:
            os.remove(os.path.join(root, f))
            deleted += 1
print(f'  Deleted {deleted} files from build dir')
" "${LIST_FILE}.keep" "$BUILDDIR"
    
    mkdir -p /tmp/icu_so_out /tmp/icu_so_tmp
    # pkgdata resolves list file against CWD, not -s, so cd to ICU source root
    cp "${LIST_FILE}.keep" "$ICU_ROOT/data/out/tmp/icudata_keep.lst"
    (cd "$ICU_ROOT" && \
        "$PKGDATA" -e icudt77 -p icudt77l -m dll \
            -s data/out/build/icudt77l \
            -d /tmp/icu_so_out \
            -T /tmp/icu_so_tmp \
            -r 77.1 \
            -L icudata \
            -q -c \
            -O data/icupkg.inc \
            data/out/tmp/icudata_keep.lst)
    
    SO_TARGET="$INSTDIR/program/libicudata.so.77"
    if [ -f "$SO_TARGET" ]; then
        cp /tmp/icu_so_out/libicudata.so.77.1 "$SO_TARGET"
        ln -sf libicudata.so.77 "$INSTDIR/program/libicudata.so"
        strip --strip-unneeded "$SO_TARGET"
        echo "  Replaced $SO_TARGET ($(du -h "$SO_TARGET" | cut -f1))"
    else
        echo "  WARNING: $SO_TARGET not found in instdir"
    fi
    
    rm -rf /tmp/icu_so_out /tmp/icu_so_tmp
    rm -f "$ICU_ROOT/data/out/tmp/icudata_keep.lst"
fi

echo "=== Bundling required system shared libraries ==="
# Bundle fontconfig and libxslt plus transitive deps (exclude core C libraries)
EXCLUDE_CORE='^(libc\.so|libm\.so|ld-linux|libdl\.so|libpthread\.so|librt\.so|libresolv\.so|libnss_|libnsl\.so|libBrokenLocale|libanl\.so|libcrypt\.so|libutil\.so|libthread_db\.so)'
for lib in libfontconfig.so.1 libxslt.so.1 libexslt.so.0; do
    full="/usr/lib64/$lib"
    if [ -f "$full" ]; then
        cp -a "$full"* "$INSTDIR/program/" 2>/dev/null
        echo "  Bundled $lib ($(du -h "$full" | cut -f1))"
        for dep in $(ldd "$full" 2>/dev/null | grep '=> /' | awk '{print $3}'); do
            depname=$(basename "$dep")
            if echo "$depname" | grep -qE "$EXCLUDE_CORE"; then
                echo "    (skip core) $depname"
                continue
            fi
            if [ ! -f "$INSTDIR/program/$depname" ] && [ ! -f "$INSTDIR/ure/lib/$depname" ]; then
                cp -n "$dep" "$INSTDIR/program/" 2>/dev/null || true
                echo "    (dep) $depname"
            fi
        done
    else
        echo "  WARNING: $lib not found, skipping (may fail at runtime)"
    fi
done

echo "=== Creating soffice wrapper ==="
cat > "$INSTDIR/program/soffice" << 'SOFFWRAP'
#!/bin/sh
sd_prog=$(dirname "$0")
URE_BOOTSTRAP=file://${sd_prog}/fundamentalrc
export URE_BOOTSTRAP
LD_LIBRARY_PATH="${sd_prog}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH
exec "${sd_prog}/soffice.bin" "$@"
SOFFWRAP
chmod +x "$INSTDIR/program/soffice"

echo "=== Done. Checking size ==="
du -sh "$INSTDIR"
