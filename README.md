# librepdf

Stripped LibreOffice for Node.js — convert `.docx`, `.html`, `.txt` to PDF.

## Install

```sh
npm install librepdf
```

Requires Node.js 20+ on **Linux x86_64**.

## Usage

```ts
import { convert } from 'librepdf';
import { readFileSync } from 'fs';

const docx = readFileSync('report.docx');
const pdf = await convert(docx);
// pdf is a Buffer — save it, stream it, etc.
```

### Options

```ts
const pdf = await convert(input, { from: 'html' });

// Inject custom fonts at runtime (paths to .ttf/.otf files or directories):
const pdf = await convert(input, { fonts: '/path/to/fonts/' });
const pdf = await convert(input, { fonts: ['/path/to/fonts/', '/path/to/custom.ttf'] });
```

The `from` option overrides automatic format detection. Supported: `docx`, `html`, `txt`.

The `fonts` option accepts one or more paths to font files (`.ttf`/`.otf`) or directories. They are copied into the bundled LibreOffice's font directory before conversion, making them available to fontconfig automatically.

## How it works

The package bundles a stripped LibreOffice 26.2.4.2 installation (~56 MB brotli-compressed, targeting 50 MB). On first call, it decompresses to `/tmp/instdir` and spawns `soffice --headless --convert-to pdf`. The PDF buffer is returned; temp files are cleaned up. Only Writer (`.docx`, `.html`, `.txt`) conversion is supported — Calc and Impress modules have been stripped.

## Caveats

- **Shutdown crash is fixed.** Previous builds had a benign SIGABRT on exit — the PDF was always written. Crash patches are applied at build time.
- **Fonts**: Liberation fonts are excluded (`--without-fonts`). THSarabunNew (GPL 2.0 + font exception) is bundled. Drop additional `.ttf`/`.otf` files in `./fonts/` before building to bundle custom fonts. At runtime, pass the `fonts` option to inject font files or directories on the fly — they are copied into LO's font directory and discovered by fontconfig automatically.
- **Locales**: Only English (US) and Thai (`th_TH`) locale data is bundled. ICU data, locale libraries, autocorrect, and numbering rules for all other locales have been stripped. This saves ~35 MB but means locale-sensitive date/number formatting for other regions may not work.
- **Size**: The compressed bundle is ~56 MB (brotli), down from the stock 383 MB. Target is 50 MB; ongoing stripping is in progress.

## Build from source

```sh
git clone https://github.com/winth03/librepdf
cd librepdf
docker compose run --rm build   # produces lo.tar.br
npm run build                   # compiles src/ → dist/
```

## License

MIT
