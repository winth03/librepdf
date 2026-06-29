const path = require('path');
const { convert } = require(path.join(__dirname, '..', 'dist', 'index.js'));
const { readFileSync, writeFileSync } = require('fs');

const FIXTURES = path.join(__dirname, 'fixtures');

async function main() {
  const docx = readFileSync(path.join(FIXTURES, 'test.docx'));
  console.log('Converting test.docx (%d bytes)...', docx.length);

  const pdf = await convert(docx, { fonts: path.join(FIXTURES, 'fonts') });
  console.log('Got PDF: %d bytes', pdf.length);

  writeFileSync('/tmp/test-output.pdf', pdf);
  console.log('Written to /tmp/test-output.pdf');

  // Also test TXT conversion
  const txt = Buffer.from('Hello World from librepdf!');
  const pdf2 = await convert(txt, { from: 'txt' });
  console.log('TXT→PDF: %d bytes', pdf2.length);
  writeFileSync('/tmp/test-output-txt.pdf', pdf2);
  console.log('Written to /tmp/test-output-txt.pdf');

  console.log('All tests passed!');
}

main().catch(console.error);
