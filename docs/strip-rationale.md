# Strip rationale

This document explains *why* each patch is needed and *why* each file/directory is
removed from the stripped LibreOffice bundle. All this reasoning was previously
scattered in inline comments and has been centralized here so that the code can
state only what it does.

## Build configure flags

| Flag | Rationale |
|---|---|
| `--disable-avahi` | mDNS service discovery – unused in headless server mode |
| `--disable-cairo-canvas` | Cairo canvas rendering – GUI-only |
| `--disable-coinmp` | CoinMP linear programming solver – unused in PDF conversion |
| `--disable-cups` | CUPS printing – headless mode does not print |
| `--disable-cve-tests` | CVE test suite – not needed in production artifact |
| `--disable-dbus` | D-Bus IPC – no desktop bus available in headless/serverless |
| `--disable-dconf` | dconf configuration – desktop-only |
| `--disable-dependency-tracking` | Speeds up configure; build is one-shot, no incremental deps needed |
| `--disable-dbgutil` | Debug utilities – unused in production build |

| `--disable-extensions` | Extension system – unused in headless server mode |
| `--disable-gen` | Generic (X11) VCL plugin – replaced by headless VCL |
| `--disable-gio` | GIO (GLib I/O) – unused |
| `--disable-gstreamer-1-0` | GStreamer media framework – unused in headless mode |
| `--disable-gtk3` | GTK3 UI – headless mode needs no UI toolkit |
| `--disable-gui` | Strips all GUI code, VCL headless plugin only |
| `--disable-introspection` | GObject introspection – unused |
| `--disable-kf5` / `--disable-kf6` | KDE Plasma integration – unused in headless server |
| `--disable-largefile` | 64-bit file offsets not needed for ephemeral /tmp I/O |
| `--disable-ldap` | LDAP directory access – unused |
| `--disable-lotuswordpro` | Lotus Word Pro import filter – unused |
| `--disable-lpsolve` | lp_solve linear programming – unused |
| `--disable-odk` | Office Development Kit – unused |
| `--disable-ooenv` | OpenOffice environment helpers – unused |
| `--disable-opencl` | OpenCL GPU compute – unused in headless mode |
| `--disable-pch` | Precompiled headers – saves disk space (cost: slower build) |
| `--disable-qt5` / `--disable-qt6` | Qt UI integration – headless mode needs no UI toolkit |
| `--disable-randr` | X RandR screen resize – headless mode has no display |
| `--disable-sdremote` | SlideShow remote control – unused |
| `--disable-sdremote-bluetooth` | SlideShow Bluetooth remote – unused |
| `--disable-skia` | Skia GPU rendering – eliminates libskialo.so (~5 MB) |
| `--disable-mergelibs` | Keep libraries as separate .so files, lets strip script remove dead components individually |
| `--with-galleries=no` | Gallery images – unused in headless |
| `--without-system-curl` | Use bundled libcurl for portability (avoids system ABI mismatch at runtime) |
| `--without-system-expat` | Use bundled expat for portability |
| `--without-system-nss` | Use bundled NSS for portability |
| `--without-system-openssl` | Use bundled OpenSSL for portability (avoids system ABI mismatch at runtime) |
| `--with-theme=no` | UI themes – unused in headless |
| `--without-export-validation` | Export validation tool – unused |
| `--without-fonts` | Do not install Liberation fonts into instdir (replaced by custom fonts) |
| `--without-system-freetype` | Use bundled freetype to avoid version conflicts at runtime on AL2023 |
| `--without-helppack-integration` | Help packs – unused in headless mode |
| `--without-java` | Java runtime support – eliminates JRE dependency |
| `--without-junit` | Java unit tests – unused in production |
| `--without-krb5` | Kerberos auth – unused |
| `--without-myspell-dicts` | Spellcheck dictionaries – unused |
| `--without-system-dicts` | System dictionary integration – unused |
| `--without-webdav` | WebDAV protocol – unused in headless |

## Patch rationales

All seven patches fix crashes (SIGABRT / exit 134) that occur when LibreOffice
is built with `--disable-gui` and no configuration backend. LO normally expects
a config backend (e.g. `org.openoffice.Office`) provided by the installation
UI setup — in a headless, serverless build this backend is absent.

### `th-localedata.patch`

**Problem:** The Thai locale data (`th_TH`) is compiled into
`liblocaledata_others.so`, which is removed during stripping (only `en` and `th`
locales are kept). This would discard Thai support.

**Fix:** Extracts Thai locale data into its own `liblocaledata_th.so` library
by registering it in `Repository.mk` and creating a new makefile
`Library_localedata_th.mk`. The Thai data is removed from `localedata_others`
so the stripped build keeps only `liblocaledata_en.so` + `liblocaledata_th.so`.

### `backupfilehelper-crash.patch`

**Problem:** LO crashes with SIGABRT (exit 134) on shutdown after PDF
conversion. The PDF is written to disk correctly before the crash — it is
purely a cleanup-phase abort.

**Root cause:** `backupfilehelper.cxx:388` calls
`deployment::ExtensionManager::get(xContext)` outside a try-catch. When the
extension manager is unavailable during shutdown, it throws
`DeploymentException` which propagates through a `noexcept` boundary →
`std::terminate` → SIGABRT.

**Fix:** Wraps `ExtensionManager::get()` in an inner try-catch and returns
early on failure. Also wraps `tryPushExtensionInfo()` in a try-catch since
it calls into the same path.

### `officecfg-startup-crash.patch`

**Problem:** LO crashes on startup before any conversion. The
`Desktop::Init()` method calls `OfficeRestartInProgress::get()` and
`langselect::prepareLocale()` which pull values from the config backend.
When the backend is absent, `officecfg::*::get()` throws, which
`SetBootstrapError(BE_OFFICECONFIG_BROKEN, ...)` catches — but
setting `BE_OFFICECONFIG_BROKEN` triggers a re-entrant call into
`Translate::Create` via `DpResId`, causing a second crash.

**Fix:** Wraps both `OfficeRestartInProgress::get()` and
`langselect::prepareLocale()` in try-catch blocks. On config failure,
it simply skips the restart check and locale preparation instead of
escalating to `BE_OFFICECONFIG_BROKEN`.

### `configwrapper-nullsafe.patch`

**Problem:** `comphelper::detail::ConfigurationWrapper` and
`ConfigurationChanges` constructors call
`css::configuration::ReadWriteAccess::create()` directly, which throws
when there is no config backend. These are used by the synchronous config
path (`officecfg::xxx::get()/set()`) called from `Desktop::Init`,
`SvtPathOptions`, etc.

**Fix:** Wraps the constructor bodies in try-catch, leaving `access_` as
a null reference when config is unavailable. All subsequent method calls
(`commit()`, `setPropertyValue()`, `getGroup()`, `getSet()`,
`getPropertyValue()`, `getLocalizedPropertyValue()`, `isReadOnly()`,
`getGroupReadOnly()`, `getSetReadOnly()`) check `access_.is()` before
dereferencing and return default/empty values when null.

### `configitem-nullsafe.patch`

**Problem:** `utl::ConfigItem::ConfigItem()` constructor calls
`ConfigManager::getConfigManager().addConfigItem(*this)` which calls
`acquireTree()`, which calls
`getConfigurationProvider()->createInstanceWithArguments(...)` — all
outside try-catch. When the config backend is absent, this throws
`DeploymentException` that propagates through `SvtSysLocaleOptions`
constructor → `Translate::Create` → SIGABRT.

**Fix:** Wraps `ConfigItem` constructor, `GetTree()`,
`ConfigManager::acquireTree()` (both overloads),
`ConfigManager::addConfigItem()`, and five
`ConfigManager::get*Locale/getProductVersion/getDefaultCurrency/
getAboutBoxProductVersionSuffix` accessors in try-catch. All return
null/default values on failure. Downstream callers (`GetProperties`,
`GetReadOnlyStates`) already null-check the returned reference.

### `localedatawrapper-nullsafe.patch`

**Problem:** `LocaleDataWrapper` constructor calls
`LocaleData2::create(rxContext)`, `loadData()`, and
`loadDateAcceptancePatterns()` — all outside try-catch. When the config
backend is absent, `NumberFormatMapper::create()` inside `loadData()`
throws, propagating through `SvtSysLocale` → `DpResId` → SIGABORT.

**Fix:** Wraps the entire constructor body in try-catch. `loadData()` and
`loadDateAcceptancePatterns()` are null-guarded to skip processing when
`xLD` was not created. On failure, the wrapper is left in a degraded
state with a null `LocaleData2` reference.

### `headless-error-dialog.patch`

**Problem:** When LO bootstraps in a headless/serverless environment and
encounters an error (e.g. IPC failure, bootstrap path error), it calls
`Application::ShowNativeErrorBox()` or `Application::CreateMessageDialog()`
to show a GUI dialog. In a `--disable-gui` build there is no windowing
system, so these calls throw and crash the process.

**Fix:** Wraps both `FatalError()` and `HandleBootstrapPathErrors()` dialog
creation calls in try-catch. The error message is already logged to stderr
before the dialog call, so suppressing the dialog is safe.

## Strip operations

### Gallery, images, macros, XSLT, xpdfimport, docs, extensions, templates, wizards

These are runtime resources not needed for server-side PDF conversion:
- `share/gallery/` — clipart and gallery images
- `share/config/images_*.zip` — UI toolbar/button images
- `share/basic/` — LibreOffice Basic macros
- `share/xslt/` — XSLT stylesheets for document transformations
- `share/xpdfimport/` — XPDF import filter data
- `readmes/`, `CREDITS.fodt`, `LICENSE*`, `NOTICE`, `THIRDPARTYLICENSE*` — documentation
- `share/extensions/` — pre-installed extensions (e.g. PDF import, Report Builder)
- `share/template/` — document templates
- `share/config/wizard/` — document wizards

### Java, Python, LibreLogo scripting

- `program/classes/` — Java JAR files (no JRE shipped, Java disabled at configure)
- `program/python/` — Python runtime (unused in Node.js wrapper)
- `share/Scripts/` — LibreLogo Python scripting

### Math module

- `program/smath` — Math formula editor wrapper binary

### Help, man pages, palette, SDK

- `share/help/` — offline help content
- `share/man/` — man pages
- `share/palette` — color palettes (GUI-only)
- `sdk/` — LibreOffice SDK for extension development

### VBA support

- `libvba*.so` — VBA macro support (documents are converted, not macro-enabled)

### Slide show, media, animation, DB UI

| Library | Reason |
|---|---|
| `libslideshowlo.so` | Impress slide show rendering |
| `libavmedialo.so` | Audio/video media player |
| `libOGLTranslo.so` | OpenGL slide transitions |
| `libPresentationMinimizerlo.so` | Presentation minimizer tool |
| `libanimcorelo.so` | Animation core |
| `libcrashextensionlo.so` | Crash reporting extension UI |
| `libupdatefeedlo.so` | Update feed reader UI |
| `libdbulo.so` | Database UI library (form designer) |

### Calc, Draw, Impress UI libraries

| Library | Reason |
|---|---|
| `libsclo.so` | Calc core (spreadsheet) |
| `libscfiltlo.so` | Calc import/export filters |
| `libscuilo.so` | Calc UI (toolbars, dialogs) |
| `libsdlo.so` | Draw core |
| `libsduilo.so` | Draw UI |
| `libwpftcalc.so` | Calc filter (WordPerfect) |
| `libwpftdrawlo.so` | Draw filter (WordPerfect) |
| `libwpftimpresslo.so` | Impress filter (WordPerfect) |
| `libwpftqahelper.so` | WordPerfect QA helper |
| `libcuilo.so` | Common UI library (shared UI components for non-Writer modules) |

The Writer core library (`libswlo.so`) is **kept** — it is required for
Writer-to-PDF conversion. Only Writer UI (`libswuilo.so`, UI config)
is removed.

### Database libraries

| Library | Reason |
|---|---|
| `libdbalo.so` | Database abstraction layer |
| `libfbclient.so.2` | Firebird embedded client |
| `libpostgresql-sdbc-impllo.so` | PostgreSQL SDBC driver |
| `libmysqlclo.so` | MySQL connector/C |
| `libdbaxmllo.so` | Database XML config |
| `libpostgresql-sdbclo.so` | PostgreSQL SDBC driver (service) |
| `libdbahsqllo.so` | HSQLDB driver |
| `libdbaselo.so` | Database selection UI |
| `libmysql_jdbclo.so` | MySQL JDBC bridge |
| `libfirebird_sdbclo.so` | Firebird SDBC driver |
| `libEngine12.so` | Firebird engine |
| `libodbclo.so` | ODB connector (Base) |
| `libsdbc2lo.so` | SDBC level 2 |
| `libsdbtlo.so` | SDBC table |
| `libdbplo.so` | Database publication |
| `libdbpool2lo.so` | DB connection pooling |
| `libfbintllo.so` | Firebird internationalization |

Also removes `postgresql.xcd` registry, `dbapp/` UI config,
and `postgresql-sdbc.rdb` service registration.

### libclucene.so — hard link, cannot remove

CLucene full-text search library — a hard dependency of `soffice.bin`
(linked at compile time, `DT_NEEDED`). Cannot be removed without
rebuilding LO without search support. Size impact: ~3 MB.

### CMIS, Math editor, Report builder

| Library | Reason |
|---|---|
| `libucpcmis1lo.so` | CMIS content management protocol (Alfresco, SharePoint) |
| `libsmlo.so` | Math formula editor library |
| `librptlo.so` / `librptuilo.so` | Report builder core + UI |
| `xpdfimport` | XPDF import command-line tool |

### Import filters

| Library | Format |
|---|---|
| `libmwaw-0.3-lo.so.3` | Legacy Mac formats (ClarisWorks, MS Works) |
| `libetonyek-0.1-lo.so.1` | Apple iWork (Pages, Numbers, Keynote) |
| `libstaroffice-0.0-lo.so.0` | StarOffice legacy formats |
| `libwps-0.4-lo.so.4` | Microsoft Works word processor |
| `libwpd-0.10-lo.so.10` | WordPerfect document |
| `libwpftwriterlo.so` | WordPerfect writer filter |

These are import-only filters for legacy/mac formats — not needed when
converting modern `.docx`, `.txt`, and `.html` to PDF.

### Locale data

Only `en` (English) and `th` (Thai) locale data is kept. The kept libs
(`liblocaledata_en.so` and `liblocaledata_th.so`) are loaded via `dlopen` at
runtime — they are **not** linked at compile time by any `.so`, but
docx→PDF export fails without them (`SfxBaseModel::impl_store` error 0xc10).

Removed:

| File | Locale coverage |
|---|---|
| `liblocaledata_euro.so` | European locales (de, fr, it, es, etc.) |
| `liblocaledata_es.so` | Spanish locale data |
| `liblocaledata_others.so` | All remaining locales (ar, ja, zh, ru, etc.) |
| `share/autocorr/` | Auto-correction rules per locale |
| `share/numbertext/` | Number-to-text conversion per locale |

Total saving: ~31 MB → ~15 MB (after ICU data strip, partial due to `pool.res`).

### UI configuration for removed modules

```
scalc/         — Calc UI
simpress/      — Impress UI
sdraw/         — Draw UI
schart/        — Chart UI
smath/         — Math UI
dbaccess/      — Base UI (database access)
dbreport/      — Report designer
dbapp/         — Database application
BasicIDE/      — Basic IDE (editor)
sbibliography/ — Bibliography
sabpilot/      — Auto-pilot wizards
swform/        — Form design
sweb/          — Web document view
swxform/       — XML form
swreport/      — Report writer
sglobal/       — Global document
```

These are configuration directories (`menubar/`, `toolbar/`, `statusbar/`,
`popupmenu/`, `ui/`) for modules that have been either fully removed or
whose UI is not needed in headless mode.

### Filter libraries

| Library | Reason |
|---|---|
| `libsvgfilterlo.so` | SVG export filter |
| `libswuilo.so` | Writer UI library (menus, dialogs, toolbars — not needed in headless) |

### Rare/unused modules

| Library | Reason |
|---|---|
| `libhwplo.so` | HWP (Hancom) import filter |
| `libwpftcalclo.so` | WordPerfect Calc filter |
| `libwriterperfectlo.so` | WriterPerfect umbrella library (individual filters already removed) |
| `libt602filterlo.so` | T602 (Czech) text import |
| `libpdfimportlo.so` | PDF import filter (not needed for export-to-PDF) |
| `libucpchelp1.so` | Help content URL provider |
| `libdeploymentgui.so` | Extension deployment GUI |
| `libbiblo.so` | Bibliography module |
| `libcalclo.so` | Calc module (Calc core/filter already removed) |
| `libpricinglo.so` | Pricing module |
| `libsolverlo.so` | Solver module (Goal Seek, Solver) |
| `libpyuno.so` | Python-UNO bridge (Python removed) |
| `libscriptframe.so` | Scripting framework (Dialog) |
| `libtextconversiondlgslo.so` | Text conversion dialogs |
| `libloglo.so` | Logging framework |
| `libscnlo.so` | Scanner module |
| `librptxmllo.so` | Report XML config |
| `libabplo.so` | AutoCorrect/word-completion UI |
| `libmozbootstraplo.so` | Mozilla bootstrap (address-book import) |
| `libcmdmaillo.so` | Mail merge UI |
| `libunopkgapplo.so` | Extension manager GUI |
| `libanalysislo.so` | Data analysis (pivot, statistics) |
| `libmigrationoo2lo.so` / `libmigrationoo3lo.so` | Migration tools from OOo 2.x/3.x |

### libpdfiumlo.so — hard link, cannot remove

PDFium PDF rendering library — used by both PDF import (removed) and
PDF export (kept). The same `.so` is linked for both; removing it
would break PDF export. Size impact: ~4 MB.

### Writer UI config removal

```
swriter/ui/        — Dialog layouts (Notebookbar, sidebar, dialogs)
swriter/menubar/   — Menu bar definitions
swriter/popupmenu/ — Context menu definitions
swriter/statusbar/ — Status bar definitions
swriter/toolbar/   — Toolbar definitions
```

Not needed in headless mode — conversion is via `--convert-to` arguments,
not through the GUI.

### Custom fonts injection

`./fonts/` is a tracked directory where users place `.ttf`/`.otf` files
before building. These are copied into `share/fonts/` in the stripped instdir.
At runtime, the `convert()` `fonts` option allows injecting additional font
files or directories on the fly — they are copied into `share/fonts/custom/`
before each conversion.
A `fonts.conf` is generated that registers this directory with fontconfig
using `prefix="relative"`, resolving `.` relative to the config file's
directory. At runtime, `FONTCONFIG_FILE=<instdir>/share/fonts/fonts.conf`
is set in the process environment — no file copying or `fc-cache`.

### System library bundling

LO does not bundle `libfontconfig.so.1` or `libxslt.so.1` — these are
expected to come from the system. To make the artifact self-contained,
they are copied from the build container along with their transitive
dependencies. Core C libraries (`libc.so`, `libm.so`, `ld-linux-x86-64.so`,
etc.) are **excluded** to avoid GLIBC version conflicts — the host's
libc must be used.
