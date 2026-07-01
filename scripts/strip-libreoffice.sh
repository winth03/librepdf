#!/usr/bin/env bash
set -euo pipefail

INSTDIR="${1:-./instdir}"

if [ ! -d "$INSTDIR/program" ]; then
    echo "Error: '$INSTDIR' does not look like a LibreOffice instdir/"
    exit 1
fi

echo "=== Building library protection list ==="
declare -A PROTECTED
# Protect .so files that soffice.bin links against at compile time
while IFS=' => ' read -r name arrow path rest; do
    path="${path// /}"
    if [[ "$path" == "$INSTDIR/program/"* ]]; then
        base=$(basename "$path")
        [[ "$base" == lib*.so* ]] && PROTECTED["$base"]=1
    fi
done < <(ldd "$INSTDIR/program/soffice.bin" 2>/dev/null || true)

# Protect runtime-loaded libs known to be needed for Writer->PDF
# Key modules needed for txt/docx->PDF conversion:
#   Writer core + filters, PDF export, OOXML, locale data, graphics
for keep in \
    libfilelo.so \
    libswlo.so \
    libsw_writerfilterlo.so \
    libmswordlo.so \
    libooxlo.so \
    libpdffilterlo.so \
    libfilterconfiglo.so \
    liblocaledata_en.so \
    liblocaledata_th.so \
    libi18npoollo.so \
    libgraphicfilterlo.so \
    libmsfilterlo.so \
    libfrmlo.so \
    libsfxlo.so \
    libsvllo.so \
    libsvtlo.so \
    libsvxlo.so \
    libsvxcorelo.so; do
    PROTECTED["$keep"]=1
done

echo "  Protected ${#PROTECTED[@]} libs (compile-time + runtime keeps)"

rm_if_not_protected() {
    for f in "$@"; do
        [ -f "$f" ] || continue
        fname=$(basename "$(readlink -f "$f" 2>/dev/null || echo "$f")")
        if [ -z "${PROTECTED[$fname]:-}" ]; then
            rm -f "$f"
            echo "  REMOVED $fname"
        else
            echo "  KEPT $fname (protected)"
        fi
    done
}

echo "=== Categorized .so report ==="
(
declare -A REAL_SEEN
declare -A REAL_PROTECTED
for f in "$INSTDIR/program"/lib*.so*; do
    [ -f "$f" ] || continue
    real=$(readlink -f "$f" 2>/dev/null || echo "$f")
    rbase=$(basename "$real")
    fbase=$(basename "$f")
    if [ -z "${REAL_SEEN[$rbase]:-}" ]; then
        REAL_SEEN["$rbase"]=1
        REAL_PROTECTED["$rbase"]=0
    fi
    if [ -n "${PROTECTED[$fbase]:-}" ]; then
        REAL_PROTECTED["$rbase"]=1
    fi
done

echo "  Total unique .so: ${#REAL_SEEN[@]}"
echo "  == Protected =="
for f in $(printf '%s\n' "${!REAL_PROTECTED[@]}" | sort); do
    [ "${REAL_PROTECTED[$f]}" = "1" ] && echo "    $f" || true
done
echo "  == Candidates =="
for f in $(printf '%s\n' "${!REAL_PROTECTED[@]}" | sort); do
    [ "${REAL_PROTECTED[$f]}" = "0" ] && echo "    $f" || true
done
p=0; c=0
for f in "${!REAL_PROTECTED[@]}"; do
    if [ "${REAL_PROTECTED[$f]}" = "1" ]; then
        p=$((p+1))
    else
        c=$((c+1))
    fi
done
echo "  Summary: $p protected, $c candidates, ${#REAL_SEEN[@]} total"
) || echo "  (report generation failed, continuing)"
echo ""

echo "=== Removing debug symbol files (.o, .gdb.py) ==="
find "$INSTDIR/program" -name '*.o' -exec rm {} \;
find "$INSTDIR/program" -name '*-gdb.py' -exec rm {} \;

echo "=== Phase 1: Removing Java, Python, VBA, GPU, DB, Math, Report builder, CMIS, import filters, rare modules ==="

# Java: entirely unused (--without-java at configure)
rm_if_not_protected \
    "$INSTDIR/program/libjava_uno.so" \
    "$INSTDIR/program/libjavaloaderlo.so" \
    "$INSTDIR/program/libjavavmlo.so" \
    "$INSTDIR/program/libjvmaccesslo.so" \
    "$INSTDIR/program/libjvmfwklo.so" \
    "$INSTDIR/program/libcli_uno.so" \
    "$INSTDIR/program/libnet_uno.so" \
    "$INSTDIR/program/libnet_bootstrap.so"

# Python bridge
rm_if_not_protected \
    "$INSTDIR/program/libpyuno.so" \
    "$INSTDIR/program/libpythonloaderlo.so"

# VBA
rm_if_not_protected \
    "$INSTDIR/program/libvbaswobjlo.so" \
    "$INSTDIR/program/libmsformslo.so"

# GPU/Crypto/RDF
rm_if_not_protected \
    "$INSTDIR/program/libepoxy.so" \
    "$INSTDIR/program/libgpgmepp.so.6" \
    "$INSTDIR/program/libgpgme.so.11" \
    "$INSTDIR/program/libgpg-error-lo.so.0" \
    "$INSTDIR/program/libraptor2-lo.so.0" \
    "$INSTDIR/program/librasqal-lo.so.3" \
    "$INSTDIR/program/librdf-lo.so.0" \
    "$INSTDIR/program/libassuan.so.9"

# Database connectors
rm_if_not_protected \
    "$INSTDIR/program/libdbalo.so" \
    "$INSTDIR/program/libdbaxmllo.so" \
    "$INSTDIR/program/libdbahsqllo.so" \
    "$INSTDIR/program/libdbaselo.so" \
    "$INSTDIR/program/libodbclo.so" \
    "$INSTDIR/program/libsdbc2.so" \
    "$INSTDIR/program/libsdbtlo.so" \
    "$INSTDIR/program/libdbplo.so" \
    "$INSTDIR/program/libdbpool2.so" \
    "$INSTDIR/program/libdbulo.so" \
    "$INSTDIR/program/libpostgresql-sdbc-impllo.so" \
    "$INSTDIR/program/libpostgresql-sdbclo.so" \
    "$INSTDIR/program/libmysqlclo.so" \
    "$INSTDIR/program/libmysql_jdbclo.so" \
    "$INSTDIR/program/libfirebird_sdbclo.so" \
    "$INSTDIR/program/libfbclient.so.2" \
    "$INSTDIR/program/libEngine12.so" \
    "$INSTDIR/program/libcalclo.so"

# Math formula editor
rm_if_not_protected \
    "$INSTDIR/program/libsmlo.so" \
    "$INSTDIR/program/libsmdlo.so"

# Report builder
rm_if_not_protected \
    "$INSTDIR/program/librptlo.so" \
    "$INSTDIR/program/librptuilo.so"

# CMIS content management
rm_if_not_protected "$INSTDIR/program/libucpcmis1lo.so"

# Slide show, media, animation (avmedia is ldd-protected)
rm_if_not_protected \
    "$INSTDIR/program/libslideshowlo.so" \
    "$INSTDIR/program/libOGLTranslo.so" \
    "$INSTDIR/program/libPresentationMinimizerlo.so" \
    "$INSTDIR/program/libanimcorelo.so"

# Canvas extras (core canvas libs are ldd-protected)
rm_if_not_protected \
    "$INSTDIR/program/libcanvasfactorylo.so" \
    "$INSTDIR/program/libmtfrendererlo.so" \
    "$INSTDIR/program/libsimplecanvaslo.so"

# Chart (chart2api is ldd-protected)
rm_if_not_protected \
    "$INSTDIR/program/libchart2lo.so"

# External import filters
rm_if_not_protected \
    "$INSTDIR/program/libmwaw-0.3-lo.so.3" \
    "$INSTDIR/program/libetonyek-0.1-lo.so.1" \
    "$INSTDIR/program/libstaroffice-0.0-lo.so.0" \
    "$INSTDIR/program/libhwplo.so" \
    "$INSTDIR/program/libwpftwriterlo.so" \
    "$INSTDIR/program/libwpftdrawlo.so" \
    "$INSTDIR/program/libwpftimpresslo.so" \
    "$INSTDIR/program/libwpftcalclo.so" \
    "$INSTDIR/program/libwriterperfectlo.so" \
    "$INSTDIR/program/libt602filterlo.so" \
    "$INSTDIR/program/libpdfimportlo.so" \
    "$INSTDIR/program/librevenge-0.0-lo.so.0" \
    "$INSTDIR/program/libodfgen-0.1-lo.so.1" \
    "$INSTDIR/program/liborcus-0.21.so.0" \
    "$INSTDIR/program/liborcus-parser-0.21.so.0"

# Rare/unused modules
rm_if_not_protected \
    "$INSTDIR/program/libbiblo.so" \
    "$INSTDIR/program/libpricinglo.so" \
    "$INSTDIR/program/libsolverlo.so" \
    "$INSTDIR/program/libscnlo.so" \
    "$INSTDIR/program/libloglo.so" \
    "$INSTDIR/program/libdeploymentgui.so" \
    "$INSTDIR/program/libucpchelp1.so" \
    "$INSTDIR/program/libscriptframe.so" \
    "$INSTDIR/program/libmigrationoo2lo.so" \
    "$INSTDIR/program/libmigrationoo3lo.so" \
    "$INSTDIR/program/libabplo.so" \
    "$INSTDIR/program/libmozbootstraplo.so" \
    "$INSTDIR/program/libcmdmaillo.so" \
    "$INSTDIR/program/libanalysislo.so" \
    "$INSTDIR/program/libbasprovlo.so" \
    "$INSTDIR/program/libdlgprovlo.so" \
    "$INSTDIR/program/libprotocolhandlerlo.so" \
    "$INSTDIR/program/libstringresourcelo.so" \
    "$INSTDIR/program/libguesslanglo.so" \
    "$INSTDIR/program/liblnthlo.so" \
    "$INSTDIR/program/libnumbertextlo.so" \
    "$INSTDIR/program/libLanguageToollo.so" \
    "$INSTDIR/program/libhyphenlo.so" \
    "$INSTDIR/program/libspelllo.so" \
    "$INSTDIR/program/libsvgfilterlo.so" \
    "$INSTDIR/program/libhelplinkerlo.so" \
    "$INSTDIR/program/libnamingservicelo.so"

echo "=== Removing locale .so data (keeping en + th only) ==="
rm_if_not_protected \
    "$INSTDIR/program/liblocaledata_euro.so" \
    "$INSTDIR/program/liblocaledata_es.so" \
    "$INSTDIR/program/liblocaledata_others.so"

echo "=== Removing Calc, Draw, Impress core libs ==="
rm_if_not_protected \
    "$INSTDIR/program/libsclo.so" \
    "$INSTDIR/program/libscfiltlo.so" \
    "$INSTDIR/program/libscuilo.so" \
    "$INSTDIR/program/libsdlo.so" \
    "$INSTDIR/program/libsduilo.so" \
    "$INSTDIR/program/libcuilo.so"

echo "=== Phase 2a: Additional safe removals ==="
rm_if_not_protected \
    "$INSTDIR/program/libaffine_uno_uno.so" \
    "$INSTDIR/program/libemfiolo.so" \
    "$INSTDIR/program/libembobj.so" \
    "$INSTDIR/program/libemboleobj.so" \
    "$INSTDIR/program/libevtattlo.so" \
    "$INSTDIR/program/libfps_officelo.so" \
    "$INSTDIR/program/libflatlo.so" \
    "$INSTDIR/program/libforlo.so" \
    "$INSTDIR/program/libforuilo.so" \
    "$INSTDIR/program/libicglo.so" \
    "$INSTDIR/program/liblog_uno_uno.so" \
    "$INSTDIR/program/libodfflatxmllo.so" \
    "$INSTDIR/program/liboffacclo.so" \
    "$INSTDIR/program/libpasswordcontainerlo.so" \
    "$INSTDIR/program/libpcrlo.so" \
    "$INSTDIR/program/libsvgiolo.so" \
    "$INSTDIR/program/libsysshlo.so" \
    "$INSTDIR/program/libi18nsearchlo.so" \
    "$INSTDIR/program/libintrospectionlo.so" \
    "$INSTDIR/program/libinvocadaptlo.so" \
    "$INSTDIR/program/libinvocationlo.so" \
    "$INSTDIR/program/libreflectionlo.so"

echo "=== Phase 2b: Application-level (non-infrastructure) removals ==="
rm_if_not_protected \
    "$INSTDIR/program/libproxyfaclo.so" \
    "$INSTDIR/program/libscdlo.so" \
    "$INSTDIR/program/libsddlo.so" \
    "$INSTDIR/program/libsrtrs1.so" \
    "$INSTDIR/program/libcached1.so" \
    "$INSTDIR/program/libctllo.so" \
    "$INSTDIR/program/libdatelo.so" \
    "$INSTDIR/program/libucpimagelo.so" \
    "$INSTDIR/program/libucpexpand1lo.so" \
    "$INSTDIR/program/libucpextlo.so" \
    "$INSTDIR/program/libbasctllo.so" \
    "$INSTDIR/program/libsal_textenclo.so" \
    "$INSTDIR/program/libstoragefdlo.so" \
    "$INSTDIR/program/libswdlo.so" \
    "$INSTDIR/program/libbinaryurplo.so" \
    "$INSTDIR/program/libfsstoragelo.so" \
    "$INSTDIR/program/libswuilo.so" \
    "$INSTDIR/program/libiolo.so" \
    "$INSTDIR/program/liblocalebe1lo.so" \
    "$INSTDIR/program/libdeployment.so" \
    "$INSTDIR/program/libdesktopbe1lo.so" \
    "$INSTDIR/program/libucphier1.so" \
    "$INSTDIR/program/libucppkg1.so" \
    "$INSTDIR/program/libucptdoc1lo.so" \
    "$INSTDIR/program/libbootstraplo.so"

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
rm -rf "$INSTDIR/program/xpdfimport"

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

echo "=== Removing firebird ==="
rm -rf "$INSTDIR/share/firebird"


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

# Search for ICU build artifacts (locations vary by LO version)
ICUPKG=$(find "$LO_ROOT" -name icupkg -type f 2>/dev/null | head -1)
PKGDATA=$(find "$LO_ROOT" -name pkgdata -type f 2>/dev/null | head -1)
LIST_FILE=$(find "$LO_ROOT" -name "icudata.lst" -type f 2>/dev/null | head -1)
BUILDDIR=$(find "$LO_ROOT" -type d -name "icudt7[0-9][a-z]" 2>/dev/null | head -1)
ICUPKG_INC=$(find "$LO_ROOT" -name "icupkg.inc" -type f 2>/dev/null | head -1)

if [ -z "$ICUPKG" ] || [ -z "$LIST_FILE" ] || [ -z "$BUILDDIR" ]; then
    echo "  ICU build artifacts not found, skipping ICU data strip"
    echo "  (icupkg=$ICUPKG list=$LIST_FILE dir=$BUILDDIR)"
else
    echo "  Found ICU build artifacts"
    echo "    icupkg=$ICUPKG"
    echo "    list=$LIST_FILE"
    echo "    dir=$BUILDDIR"

    # ICU source root: icupkg is at $ICU_SOURCE/bin/icupkg
    ICU_SOURCE=$(dirname "$(dirname "$ICUPKG")")

    # Detect ICU version from build dir name (e.g. icudt78l → 78)
    ICU_BASE=$(basename "$BUILDDIR")
    ICU_VER=$(echo "$ICU_BASE" | sed 's/icudt//; s/[a-z]//')
    ICU_TAG=$(echo "$ICU_BASE" | sed "s/icudt${ICU_VER}//")
    ICU_SHORT="icudt${ICU_VER}"
    echo "  Detected ICU version $ICU_VER (tag=$ICU_TAG, source=$ICU_SOURCE)"

    ICU_PARENT=$(dirname "$BUILDDIR")      # data/out/build
    ICU_ROOT=$(dirname "$ICU_PARENT")       # data/out

    export LD_LIBRARY_PATH="${ICU_SOURCE}/lib:${ICU_SOURCE}/stubdata"

    echo "  Filtering locale data..."
    
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
    cp "${LIST_FILE}.keep" "${ICU_ROOT}/tmp/icudata_keep.lst"
    (cd "$ICU_SOURCE" && \
        "$PKGDATA" -e "$ICU_SHORT" -p "${ICU_BASE}" -m dll \
            -s "data/out/build/${ICU_BASE}" \
            -d /tmp/icu_so_out \
            -T /tmp/icu_so_tmp \
            -r "${ICU_VER}.1" \
            -L icudata \
            -q -c \
            -O "data/icupkg.inc" \
            "data/out/tmp/icudata_keep.lst")

    SO_TARGET="$INSTDIR/program/libicudata.so.${ICU_VER}"
    if [ -f "$SO_TARGET" ]; then
        cp /tmp/icu_so_out/libicudata.so.${ICU_VER}.1 "$SO_TARGET"
        ln -sf "libicudata.so.${ICU_VER}" "$INSTDIR/program/libicudata.so"
        strip --strip-unneeded "$SO_TARGET"
        echo "  Replaced $SO_TARGET ($(du -h "$SO_TARGET" | cut -f1))"
    else
        echo "  WARNING: $SO_TARGET not found in instdir"
    fi

    rm -rf /tmp/icu_so_out /tmp/icu_so_tmp
    rm -f "${ICU_ROOT}/tmp/icudata_keep.lst"
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

echo "=== Post-removal .so listing ==="
for f in "$INSTDIR/program"/lib*.so*; do
    [ -f "$f" ] || continue
    if [ ! -L "$f" ]; then
        echo "  $(basename "$f") ($(du -h "$f" | cut -f1))"
    fi
done | sort

echo "=== Done. Checking size ==="
du -sh "$INSTDIR"
