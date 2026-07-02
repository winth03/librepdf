# Optimization plan

Goals, approach, and testing status for each candidate saving beyond the
current strip script.

## Immediate strip-script additions (no rebuild)

### Remove `libwps-0.4-lo.so.4` (~2.5 MB)
- **Why safe:** Only consumer was `libwpftwriterlo.so` (WordPerfect→Writer filter), already removed.
- **Ldd check:** Zero dependents confirmed.
- **Testing:** smoke-test + local test docx→PDF after removal.

### Remove stray `libxml2.so.2` (~1.5 MB)
- **Why safe:** LO builds its own `libxml2.so.16` (1.3 MB). The `.so.2` copy is pulled in as transitive dep of bundled `libxslt`/`libexslt`/`libfontconfig`. AL2023 Lambda ships system `libxml2.so.2`, so those bundled system libs resolve against the system copy at runtime.
- **Note:** Add to the bundling exclusion list, or `rm` it after copy.

## Build-time changes (next rebuild)

### ICU data tree exclusions via `resourceFilters`
`libicudata.so.78` is currently 13.3 MB (en+th locale only). ICU data trees
that may be unnecessary for Writer→PDF:

| Tree | Uncompressed | Risk | Exclusion approach |
|---|---|---|---|
| `zoneinfo` | ~10 MB | **Medium** — date/time rendering in docx may need timezone DB |
| `translit` | ~1 MB | **Low** — transliteration rarely used in conversion |
| `confusables` | ~2 MB | **Very low** — security feature for confusable character detection |
| `dict` | ~2 MB | **Low** — spellcheck dictionary data |
| `unames` | ~1 MB | **Very low** — Unicode name lookup |
| `coll` | ~1 MB | **Low** — collation/sorting rules |
| `rbnf` | ~300 KB | **Low** — rule-based number formatting |
| `sprep` / `nq` | small | **Very low** — IDNA/name queries |

**Plan:** Test incrementally — exclude zero-risk trees first
(`confusables`, `unames`, `sprep`, `nq`, `dict`), build, test conversion.
If passing, add `translit`, `rbnf`, `coll`. Finally try `zoneinfo`.

**Syntax** (`scripts/icu-data-filter.json`):
```json
{
  "localeFilter": {
    "filterType": "locale",
    "includelist": ["en", "th"]
  },
  "resourceFilters": [
    {
      "categories": ["zoneinfo", "translit", "confusables", "dict", "unames", "sprep", "nq", "rbnf"],
      "filterType": "namespace",
      "whitelist": []
    }
  ]
}
```

**Note:** Need to verify the exact tree names ICU 78 uses — may differ from
this projection.

### `libpdfiumlo.so` (5.6 MB) — ❌ cannot remove via strip script
- `soffice.bin` has `DT_NEEDED` for `libpdfiumlo.so` — hard-linked at compile time.
- Conversion fails immediately at startup (`error while loading shared libraries`).
- **Only option:** Rebuild with a hypothetical `--disable-pdfium` flag (does not currently exist in LO configure).

### `libcurl.so.4` (5.8 MB) — ❌ cannot remove via strip script
- `soffice.bin` has `DT_NEEDED` for `libcurl.so.4`.
- txt→PDF and docx→PDF both work without the bundled copy **if** the system provides it (dev machine has `/usr/lib/x86_64-linux-gnu/libcurl.so.4`).
- **On Lambda:** If `libcurl.so.4` is absent, `soffice.bin` would fail at startup.
- **Best option:** Switch to `--with-system-curl` in Dockerfile after verifying Lambda runtime has libcurl. Saves ~5.8 MB + build time for LO's bundled curl.

## Rejected / already done

- **Expat:** Already `--without-system-expat` in Dockerfile. LO statically links its built expat into consumer libs. No standalone `libexpat.so` in bundle.

## Measurement

| Change | Uncompressed | Compressed (est.) |
|---|---|---|
| Remove `libwps-0.4` | −2.5 MB | −~700 KB |
| Remove `libxml2.so.2` | −1.5 MB | −~400 KB |
| ICU: `confusables+unames+dict+sprep+nq+coll` | −~5 MB | −~1.5 MB |
| ICU: `zoneinfo+translit+rbnf` | −~11 MB | −~3 MB |
| **Best case total** | **−20.0 MB** | **−~5.6 MB** |
