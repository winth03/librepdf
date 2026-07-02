# librepdf — Stripped LibreOffice for Node.js

## Goal
Strip LibreOffice to a ~50 MB compressed artifact for a Node.js library (`librepdf`) that converts Writer documents (docx, txt, html) to PDF server-side. Calc and Impress conversion is not supported.

## Constraints
- **Size target:** ~50 MB compressed (brotli). Uncompressed must fit 250 MB limit.
- **Platform:** Linux x86_64 — Amazon Linux 2023 (AL2023).
- **No display server:** Use `--headless --norestore --nologo`.
- **Read-only /tmp:** Input lands in `/tmp`, output goes to `/tmp`, config is ephemeral.

## Approach

### Build (compile from source)
- Docker multi-stage build on `amazonlinux:2023` (AL2023).
- LibreOffice 26.2.4.2 — source from `core/libreoffice-26.2.4.2.tar.xz`.
- `make` (~30 min – 2 hr on a beefy machine).
- ICU data (`libicudata.so`) filtered at build time via `ICU_DATA_FILTER_FILE` — only `en` + `th` locale data are compiled, shrinking from 31 MB to ~8 MB. The `no-python.patch` in LO's ICU tarball is removed to enable ICU's Python-based data build tool.
- Post-build: `strip --strip-unneeded` on .so files, run `scripts/strip-libreoffice.sh` which removes DB libs, import filters, Math, Reports, Writer UI, UI config for removed modules, locale data, bundled fonts, etc.
- Brotli-compress the stripped `instdir/` into `lo.tar.br`.

### Node.js library
- `src/index.ts` — exports `convert(input: Buffer, options?): Promise<Buffer>`. Decompresses `lo.tar.br` on cold start, spawns `soffice --headless --convert-to pdf`, returns the PDF buffer. Accepts an optional `fonts` option to inject custom `.ttf`/`.otf` files or directories at runtime.
- `dist/` — compiled output (run `tsc`).
- `HOME=/tmp` and `FONTCONFIG_FILE=<instdir>/share/fonts/fonts.conf` set internally.
- **CRITICAL (font discovery):** fontconfig does NOT scan LO's `share/fonts/` directory on Linux. The `fonts.conf` (created by `strip-libreoffice.sh` at build time) ships inside `lo.tar.br`. No file copying or `fc-cache` needed.
- **Fonts folder (`fonts/`):** Drop your own `.ttf`/`.otf` files here before building. They get bundled into the stripped instdir and registered via the embedded `fonts.conf`. The folder is tracked in git — seed it with any fonts your documents depend on.
- **Runtime font injection (`convert()` `fonts` option):** Pass paths to `.ttf`/`.otf` files or directories to inject at runtime. They are copied into `share/fonts/custom/` before each conversion and discovered by the existing `fonts.conf` automatically.
- **Custom fonts (`./fonts/`):** LibreOffice is built with `--without-fonts`, so its built-in Liberation fonts are never installed into `instdir`. Drop your own `.ttf`/`.otf` files in `fonts/` before building; they are bundled into the stripped instdir and registered via the embedded `fonts.conf` (see "Font discovery quirk" below) — unconditionally.

## Iteration workflow
- **NEVER use `--no-cache`.** If a layer is cached, it is correct — the inputs haven't changed. Don't try to invalidate caches with trivial edits. Verify your verification instead.
- All post-build stripping logic lives in `scripts/strip-libreoffice.sh` — changes to this file invalidate the COPY layer (file hash changed), so the script → smoke → tar → br layers rebuild (~30s).
- Changes to `Dockerfile` will invalidate caches and trigger a full or partial rebuild.
- Changes to `scripts/icu-data-filter.json` will invalidate the layer it's COPY'd into and trigger a rebuild from that point (patches → ICU → configure → make).
- To extract the fresh tar: `docker compose run --rm build` (copies `lo.tar.br` to the repo root)

## Scripts & tooling
| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build (AL2023 → compile → strip → brotli) |
| `docker-compose.yml` | `docker compose build --progress=plain 2>&1 | tee /tmp/build.log` to build. `docker compose run --rm build` to extract `lo.tar.br` |
| `scripts/strip-libreoffice.sh` | Post-build pruning commands (fast-iteration — Dockerfile only COPYs this script) |
| `scripts/icu-data-filter.json` | ICU data filter — only `en` + `th` locale data compiled at build time |
| `test/local-test.js` / `npm run test:local` | End-to-end test using the Node.js library (decompress → convert docx/txt → verify PDF) |
| `scripts/smoke-test.sh` | Quick PDF-existence check (non-fatal, ignores exit code) |
| `src/index.ts` | Library entry point |

## Runtime keep-list (19 libs)
Protected from removal — includes both ldd-linked and dlopen'd libs essential for Writer→PDF:
```
libfilelo, libswlo, libsw_writerfilterlo, libmswordlo, libooxlo,
libpdffilterlo, libfilterconfiglo, liblocaledata_en, liblocaledata_th,
libi18npoollo, libgraphicfilterlo, libmsfilterlo, libfrmlo, libsfxlo,
libsvllo, libsvtlo, libsvxlo, libsvxcorelo
```

## Removals by category

### Scripting (Java, Python, VBA, LibreLogo)
- Java bridge: `libjava_uno.so`, `javaloader`, `javavm`, `jvmaccess`, `jvmfwk`, `cli_uno`, `net_uno`, `net_bootstrap`
- Python bridge: `libpyuno.so`, `libpythonloaderlo.so`, `program/python/`, `share/Scripts/` (LibreLogo)
- VBA: `libvbaswobjlo.so`, `libmsformslo.so`, `libvbaobjlo.so`
- Basic macros: `share/basic/`
- Other: `basprov`, `dlgprov`, `protocolhandler`, `stringresource`

### Database
All DB connectors — `libdbalo`, `libfbclient`, `libpostgresql-sdbc-impllo`, `libpostgresql-sdbclo`, `libmysqlclo`, `libmysql_jdbclo`, `libfirebird_sdbclo`, `libEngine12`, `libdbaxmllo`, `libdbahsqllo`, `libdbaselo`, `libodbclo`, `libsdbc2`, `libsdbtlo`, `libdbplo`, `libdbpool2`, `libdbulo`, `libcalclo`, `libfbintllo`, plus Firebird data (`share/firebird/`)

### Non-Writer Application Modules
- **Calc:** `libsclo.so`, `libscfiltlo.so`, `libscuilo.so`
- **Draw:** `libsdlo.so`, `libsduilo.so`
- **Impress:** `libslideshowlo.so`, `libOGLTranslo.so`, `libPresentationMinimizerlo.so`, `libanimcorelo.so`
- **Math:** `libsmlo.so`, `libsmdlo.so`, `smath` wrapper
- **Chart:** `libchart2lo.so`
- **Report builder:** `librptlo.so`, `librptuilo.so`

### Legacy / Import Filters
- **Mac:** `libmwaw-0.3-lo.so.3` (ClarisWorks)
- **iWork:** `libetonyek-0.1-lo.so.1` (Pages, Numbers)
- **StarOffice:** `libstaroffice-0.0-lo.so.0`
- **WordPerfect:** `libwpd-0.10-lo.so.10`, `libwpftwriterlo.so`, `libwpftdrawlo.so`, `libwpftimpresslo.so`, `libwpftcalclo.so`, `libwriterperfectlo.so`
- **Other:** `libhwplo.so` (HWP), `libt602filterlo.so` (T602), `libpdfimportlo.so` (PDF import)
- **Filter infra:** `librevenge-0.0-lo.so.0`, `libodfgen-0.1-lo.so.1`, `liborcus-0.21.so.0`, `liborcus-parser-0.21.so.0`

### Locale & ICU Data
- Locale .so: keep `liblocaledata_en.so` + `liblocaledata_th.so` (dlopen'd — essential for docx→PDF, not ldd-linked); remove `liblocaledata_euro.so`, `liblocaledata_es.so`, `liblocaledata_others.so`
- ICU: `libicudata.so` filtered via `ICU_DATA_FILTER_FILE` at configure time — only `en` + `th` .res files compiled (31 MB → ~8 MB)
- Autocorrect: `share/autocorr/`
- Numbertext: `share/numbertext/`

### Infrastructure & Platform
- **UCP providers:** `libucpcmis1lo.so`, `libucpimagelo.so`, `libucpexpand1lo.so`, `libucpextlo.so`, `libucphier1.so`, `libucppkg1.so`, `libucptdoc1lo.so`, `libucpchelp1.so`
- **UNO infra:** `libreflectionlo.so`, `libinvocationlo.so`, `libintrospectionlo.so`, `libinvocadaptlo.so`, `libaffine_uno_uno.so`, `liblog_uno_uno.so`, `libsysshlo.so`
- **Storage/IO:** `libstoragefdlo.so`, `libbinaryurplo.so`, `libfsstoragelo.so`, `libiolo.so`, `libsal_textenclo.so`, `liblocalebe1lo.so`
- **Deployment:** `libdeployment.so`, `libdeploymentgui.so`, `libdesktopbe1lo.so`, `libbootstraplo.so`
- **GPU/Crypto/RDF:** `libepoxy.so`, `libgpgmepp.so`, `libraptor2-lo.so`, `librasqal-lo.so`, `librdf-lo.so`, `libclewlo.so`, `libopencllo.so`
- **Other:** `libproxyfaclo.so`, `libscdlo.so`, `libsddlo.so`, `libsrtrs1.so`, `libcached1.so`, `libctllo.so`, `libdatelo.so`, `libbasctllo.so`, `libswuilo.so`, `libswdlo.so`

### Rare / Unused Modules
`biblo`, `pricinglo`, `solverlo`, `scnlo`, `loglo`, `textconversiondlgslo`, `scriptframe`, `migrationoo2lo`, `migrationoo3lo`, `rptxmllo`, `abplo`, `mozbootstraplo`, `cmdmaillo`, `unopkgapplo`, `analysislo`, `LanguageTool`, `guesslang`, `lnth`, `numbertext`, `spell`, `hyphen`, `helplinkerlo`, `namingservicelo`, `svgfilterlo`, `evtattlo`, `fps_officelo`, `flatlo`, `forlo`, `foruilo`, `icglo`, `odfflatxmllo`, `offacclo`, `passwordcontainerlo`, `pcrlo`, `svgiolo`, `i18nsearchlo`, `embobj`, `emboleobj`, `emfiolo`

### Media & UI Resources
Gallery images, toolbar images (`images_*.zip`), color palette, canvas extras (`canvasfactorylo`, `mtfrendererlo`, `simplecanvaslo`)

### Documentation & Content
Help files (`share/help/`), man pages (`share/man/`), readmes, licenses, templates (`share/template/`), wizards (`share/config/wizard/`), pre-installed extensions (`share/extensions/`), SDK (`sdk/`), XSLT (`share/xslt/`), xpdfimport (`program/xpdfimport` + `share/xpdfimport/`)

### UI Configuration
- Config dirs for: Calc, Impress, Draw, Math, Chart, Base, dbreport, dbapp, BasicIDE, bibliography, autopilot, form/web/xml-form/report writer, global document
- Writer UI elements (headless-safe): notebookbar, menus, toolbars, statusbar, popupmenu, dialogs

### Fonts
- Bundled Liberation fonts removed at configure time (`--without-fonts`)
- THSarabunNew bundled as default; additional `.ttf`/`.otf` injectable at build time via `fonts/` directory
- `share/fonts/fonts.conf` generated with `prefix="relative"` for fontconfig discovery

### System Library Bundling
- `libfontconfig.so.1`, `libxslt.so.1`, `libexslt.so.0` + transitive deps; core C libs excluded (GLIBC from host)

### Hard-linked (cannot remove)
- `libclucene.so` — full-text search, built into soffice.bin at link time
- `libpdfiumlo.so` — used by both import (removed) and export (kept), same .so

## Known crashes (startup + shutdown)

LO built with `--disable-gui` and no config backend crashes in two phases, both fixed by source patches applied before `./configure`. All seven patches in the table below are mandatory — the build's smoke test fails at exit 134 without them.

**Startup crash** — `soffice.bin` aborts (SIGABRT, exit 134) on first run before any conversion. Stack: `soffice_main → ImplSVMain → InitVCL → Translate::Create("dkt") → SvtSysLocale → SvtSysLocaleOptions → utl::ConfigItem ctor → utl::ConfigManager::addConfigItem → acquireTree → createInstanceWithArguments` throws `DeploymentException` (no config backend) → `std::terminate`. Root cause: `utl::ConfigItem::ConfigItem` calls `ConfigManager::addConfigItem` outside a try-catch, propagating through the constructor.

Five patches together null-safe this whole path. Apply in this order (the order in Dockerfile is the same):

- `scripts/configwrapper-nullsafe.patch` — wraps `comphelper::detail::ConfigurationWrapper` and `ConfigurationChanges` so `officecfg::xxx::get()/set()` (the synchronous path used by `Desktop::Init`, `langselect::prepareLocale`, SvtPathOptions etc.) returns defaults instead of throwing.
- `scripts/officecfg-startup-crash.patch` — wraps the `OfficeRestartInProgress::get()` and `langselect::prepareLocale()` calls in `Desktop::Init` so a missing config backend doesn't escalate to `BE_OFFICECONFIG_BROKEN` (which would then call `DpResId` and re-enter `Translate::Create` → second crash).
- `scripts/configitem-nullsafe.patch` — the actual root-cause fix. Wraps `utl::ConfigItem::ConfigItem` ctor, `utl::ConfigItem::GetTree`, both `utl::ConfigManager::acquireTree` overloads, `ConfigManager::addConfigItem`, and four `ConfigManager::get*Locale/getProductVersion/getDefaultCurrency/getAboutBoxProductVersionSuffix` accessors so the `SvtSysLocaleOptions → ConfigItem ctor → addConfigItem → acquireTree` path returns a null `XHierarchicalNameAccess` instead of throwing. `GetProperties`/`GetReadOnlyStates` already null-check the returned reference and fall back to default/empty values.
- `scripts/localedatawrapper-nullsafe.patch` — wraps the `LocaleDataWrapper` constructor body in try-catch so that `loadData()` / `loadDateAcceptancePatterns()` exceptions (from `NumberFormatMapper::create()` when no config backend is available) do not propagate up through `SvtSysLocale` → `DpResId` during `InitVCL`.
- `scripts/headless-error-dialog.patch` — wraps `HandleBootstrapPathErrors` dialog creation and `FatalError` `ShowNativeErrorBox` in try-catch so headless builds don't crash when a GUI error dialog cannot be created (triggers e.g. when RequestHandler IPC fails).

**Shutdown crash** — separate root cause, separate fix:

LO crashes with SIGABRT (exit 134) on shutdown after PDF conversion. The PDF is already written to disk before the crash — it is purely a cleanup-phase abort.

**Root cause:** `comphelper/source/misc/backupfilehelper.cxx:388` calls `deployment::ExtensionManager::get(xContext)` outside a try-catch. If the extension manager is unavailable during shutdown, it throws `DeploymentException` which propagates through a `noexcept` boundary → `std::terminate` → SIGABRT.

**Fix (mandatory — shutdown):** Apply `scripts/backupfilehelper-crash.patch` before `./configure` — same approach as `th-localedata.patch`:

```dockerfile
COPY ./scripts/backupfilehelper-crash.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < backupfilehelper-crash.patch && rm backupfilehelper-crash.patch
```

The patch wraps the `ExtensionManager::get()` call in an inner try-catch and returns early on failure. This requires a rebuild (invalidates the `make` cache layer).

## Font discovery quirk (critical)
fontconfig does NOT scan LO's `share/fonts/` directory on Linux. LO relies on fontconfig for font resolution. THSarabunNew fonts are present in the stripped instdir at `share/fonts/THSarabunNew/`, but LO cannot find them unless they are also registered with fontconfig.

**Fix (build-time, `scripts/strip-libreoffice.sh`):** A `share/fonts/fonts.conf` is written into the instdir that registers `share/fonts/` with fontconfig using a relative path:

```xml
<dir prefix="relative">.</dir>
```

`prefix="relative"` resolves `.` relative to the config file's directory, so fontconfig recursively scans `share/fonts/` and discovers all bundled fonts (including any injected at runtime into `share/fonts/custom/`).

**Runtime (src/index.ts):** Set `FONTCONFIG_FILE=<instdir>/share/fonts/fonts.conf` in the soffice process environment. No file copying, no `fc-cache`.

**Why not runtime copy + fc-cache?** The fonts.conf approach is zero file I/O and handles the ephemeral `/tmp` filesystem properly — the config file ships inside `lo.tar.br` and is available as soon as the archive is decompressed.

## Known startup-crash patches (all mandatory)

| Patch file | What it fixes | Touches |
|---|---|---|
| `th-localedata.patch` | Extracts Thai locale data into standalone `liblocaledata_th.so` | `Repository.mk`, `i18npool/*` |
| `backupfilehelper-crash.patch` | Wraps `ExtensionManager::get()` in try-catch at shutdown | `comphelper/source/misc/backupfilehelper.cxx` |
| `officecfg-startup-crash.patch` | Skips `BE_OFFICECONFIG_BROKEN` in `Desktop::Init` | `desktop/source/app/app.cxx` |
| `configwrapper-nullsafe.patch` | Null-safe `ConfigurationWrapper` (synchronous config path) | `comphelper/source/misc/configuration.cxx` |
| `configitem-nullsafe.patch` | Null-safe `ConfigItem`/`ConfigManager` (async config item path) | `unotools/source/config/configitem.cxx`, `configmgr.cxx` |
| `localedatawrapper-nullsafe.patch` | Null-safe `LocaleDataWrapper` constructor | `unotools/source/i18n/localedatawrapper.cxx` |
| `headless-error-dialog.patch` | Wraps `FatalError`/`HandleBootstrapPathErrors` dialog creation in try-catch so headless builds don't crash on GUI error dialogs | `desktop/source/app/app.cxx` |

## Git conventions
- **Commit messages:** Use [Conventional Commits](https://www.conventionalcommits.org/) format: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, etc.
- Scope is optional. Body paragraphs wrapped at 72 chars.
- Commit related changes together; avoid tiny granular commits.
- Never force-push to shared branches.

## Publishing a release

**IMPORTANT — do NOT upload `lo.tar.br` directly.** The GitHub release artifact must be the npm pack tarball (`.tgz`), which includes compiled JS + `lo.tar.br` inside. `npm pack` runs `prepack` which calls `tsc` first.

Exact steps to publish a release:

```bash
# 1. Build the Docker image and extract lo.tar.br
docker compose build --progress=plain 2>&1 | tee /tmp/build.log
docker compose run --rm build

# 2. Build the Node.js library and create the npm pack tarball
npm pack

# 3. Commit, tag, push
git add -A
git commit -m "chore: bump version to X.Y.Z"
git push origin main
git tag vX.Y.Z && git push origin vX.Y.Z

# 4. Create GitHub release with the .tgz — NOT lo.tar.br
gh release create vX.Y.Z librepdf-X.Y.Z.tgz --title "vX.Y.Z" --notes "<notes>"
```

**Never** pass `lo.tar.br` to `gh release create`. Always use the `librepdf-X.Y.Z.tgz` file produced by `npm pack`.

## Verification
- `npm run test:local` converts test.docx and .txt → valid PDF.
- Compressed bundle ~56 MB (brotli).
- Cold-start unpack ≤ 3 seconds.
