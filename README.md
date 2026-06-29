# librepdf

Stripped LibreOffice for Node.js — convert `.docx`, `.xlsx`, `.pptx` to PDF.

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
const pdf = await convert(input, { from: 'xlsx' });
```

The `from` option overrides automatic format detection. Supported: `docx`, `xlsx`, `pptx`, `html`, `txt`.

## How it works

The package bundles a stripped LibreOffice installation (~59 MB brotli-compressed, targeting 50 MB). On first call, it decompresses to `/tmp/instdir` and spawns `soffice --headless --convert-to pdf`. The PDF buffer is returned; temp files are cleaned up.

## Caveats

- **Shutdown crash is fixed** (as of R5). Previous builds had a benign SIGABRT on exit — the PDF was always written. All crash patches are now applied upstream at build time.
- **Fonts**: Liberation fonts are excluded (`--without-fonts`). Drop `.ttf`/`.otf` files in `./fonts/` before building to bundle custom fonts. Thai THSarabunIT9 is included as a default.
- **Locales**: Only English (US) and Thai (`th_TH`) locale data is bundled. ICU data, locale libraries, autocorrect, and numbering rules for all other locales have been stripped. This saves ~35 MB but means locale-sensitive date/number formatting for other regions may not work.
- **Size**: The compressed bundle is ~59 MB (brotli), down from the stock 383 MB. Target is 50 MB; ongoing stripping is in progress.

## Build from source

```sh
git clone https://github.com/winth03/librepdf
cd librepdf
docker compose run --rm build   # produces lo.tar.br
npm run build                   # compiles src/ → dist/
```

## License

MIT
