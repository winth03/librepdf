# librepdf

LibreOffice, stripped and bundled for Node.js. Converts `.docx`, `.html`, and `.txt` to PDF — no Docker, no Gotenberg, no sidecar process to manage.

> **Note:** Most of this project was done with AI assistance.

## Install

```sh
npm install librepdf
```

Node.js 20+ required. **Linux x86_64 only.**

## Usage

```ts
import { convert } from 'librepdf';
import { readFileSync } from 'fs';

const pdf = await convert(readFileSync('report.docx'));
// returns a Buffer
```

### Options

```ts
// Override format detection
const pdf = await convert(input, { from: 'html' });

// Inject fonts at runtime (.ttf/.otf files or directories)
const pdf = await convert(input, { fonts: '/path/to/fonts/' });
const pdf = await convert(input, { fonts: ['/path/to/fonts/', '/path/to/custom.ttf'] });
```

`from` — one of `docx`, `html`, `txt`. Only needed if auto-detection gets it wrong.

`fonts` — path(s) to `.ttf`/`.otf` files or directories. Copied into LO's font directory before conversion; fontconfig picks them up automatically.

## How it works

A stripped LibreOffice 26.2.4.2 installation is bundled. On the first call it decompresses to `/tmp/instdir`, then subsequent calls reuse that. Conversion runs `soffice --headless --convert-to pdf` and returns the PDF as a Buffer. Calc and Impress are stripped — only Writer is included.

## Caveats

**Fonts** — Liberation fonts are not included (`--without-fonts`). THSarabunNew (GPL 2.0 + font exception) is bundled. To add more fonts permanently, drop `.ttf`/`.otf` files into `./fonts/` before building. For one-off injection, use the `fonts` runtime option.

**Locales** — Only `en_US` and `th_TH` locale data is bundled. ICU data and numbering rules for other locales are stripped (~35 MB savings). Locale-sensitive date/number formatting outside those two regions may not render correctly.

## Build from source

```sh
git clone https://github.com/winth03/librepdf
cd librepdf
docker compose run --rm build   # produces lo.tar.br
npm run build                   # compiles src/ → dist/
```

## License

MIT