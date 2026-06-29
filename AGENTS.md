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
- LibreOffice 25.8 (Still/LTS branch) — source from `core/libreoffice-25.8.6.tar.gz`.
- `make` (~30 min – 2 hr on a beefy machine).
- ICU data (`libicudata.so`) stripped post-build via `icupkg + pkgdata` in `strip-libreoffice.sh` — rebuilds `.so` with only `en` + `th` locale data, shrinking from 31 MB to ~2 MB.
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
- All post-build stripping logic lives in `scripts/strip-libreoffice.sh` — changes to this file do NOT invalidate Docker build caches (only the script → smoke → tar → br layers rebuild, ~30s).
- Changes to Dockerfile will invalidate caches and trigger a full or partial rebuild.
- To extract the fresh tar: `docker compose run --rm build` (copies `lo.tar.br` to the repo root)

## Scripts & tooling
| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage build (AL2023 → compile → strip → brotli) |
| `docker-compose.yml` | `docker compose build --progress=plain 2>&1 > /tmp/build.log` to build. `docker compose run --rm build` to extract `lo.tar.br` |
| `scripts/strip-libreoffice.sh` | Post-build pruning commands (fast-iteration — Dockerfile only COPYs this script) |
| `test/local-test.js` / `npm run test:local` | End-to-end test using the Node.js library (decompress → convert docx/txt → verify PDF) |
| `scripts/smoke-test.sh` | Quick PDF-existence check (non-fatal, ignores exit code) |
| `src/index.ts` | Library entry point |

## Current size progress
| Iteration | Uncompressed | brotli--best | Target |
|---|---|---|---|
| Baseline | 383 MB | ~93 MB | 50 MB |
| After R1 (DB/search/Math/Report libs) | 315 MB | ~77 MB | 50 MB |
| After R2 (import filters) | 288 MB | ~70 MB | 50 MB |
| After R3 (UI config, locale, fonts, Writer UI) | 260 MB | ~63 MB | 50 MB |
| After ICU strip (en+th only, 31 MB→2.1 MB) | 233 MB | ~59 MB | 50 MB |
| After R4 (aggressive strip — DB, UI, locale, Skia, Thai patch, ICU strip) | 207 MB | ~55 MB | 50 MB |
| After R5 (all 7 crash patches applied, clean exit 0) | 218 MB | ~59 MB | 50 MB |

## Known safe removals in strip-libreoffice.sh
- ICU data: `libicudata.so` rebuilt via `icupkg + pkgdata` keeping only `en` + `th` locale data (31 MB → ~2 MB)
- DB libs: libdbalo, libfbclient, all postgres/mysql/firebird/hsqldb connectors, plus odbclo, fbintl, sdbc2, sdbtlo, dbplo, dbpool2
- Search: libclucene (HARD LINKED — cannot remove)
- CMIS, Math, Report builder, Personalization libs
- Import filters: mwaw (Mac), etonyek (iWork), staroffice, wps, wpd, wpftwriter, hwp, writerperfect, t602, pdfimport
- Writer UI lib: libswuilo (headless safe)
- PDFium lib: libpdfiumlo (HARD LINKED — cannot remove, used by export too)
- Non-essential filters: libsvgfilterlo, libfilelo
- Rare/unused modules: biblo, calclo, pricinglo, solverlo, scnlo, loglo, textconversiondlgslo, deploymentgui, ucpchelp1, scriptframe, pyuno, migrationoo2/3, rptxmllo, abplo, mozbootstraplo, cmdmaillo, unopkgapp, analysislo
- Writer UI config (notebookbar, menus, toolbars, statusbar) — not needed in headless
- UI config modules: scalc, simpess, sdraw, schart, smath, dbaccess+dbreport+dbapp, BasicIDE, sbibliography, sabpilot, swform, sweb, swxform, swreport, sglobal
- Locale: liblocaledata_euro.so, liblocaledata_others.so, liblocaledata_es.so (only en/th kept), autocorr/, numbertext/
- Skia: --disable-skia at configure time (eliminates libskialo.so entirely)
- Thai locale: separate liblocaledata_th.so extracted via build-time patch (th-localedata.patch)
- Fonts: bundled Liberation fonts removed, THSarabunNew bundled as default
- Python scripting: LibreLogo removed
- Math: smath wrapper removed

## Known crashes (startup + shutdown)

LO built with `--disable-gui` and no config backend crashes in two phases, both fixed by source patches applied before `./configure`. All six patches in the table below are mandatory — the build's smoke test fails at exit 134 without them.

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

## Verification
- `npm run test:local` converts test.docx and .txt → valid PDF.
- Compressed bundle ≤ 50 MB.
- Cold-start unpack ≤ 3 seconds.
