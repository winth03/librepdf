import { readFileSync, writeFileSync, unlinkSync, existsSync, mkdirSync, statSync, readdirSync, copyFileSync } from 'fs';
import { spawn } from 'child_process';
import { join, basename } from 'path';
import { brotliDecompressSync } from 'zlib';
import { x as extractTar } from 'tar';

let initialized = false;
const LO_DIR = '/tmp/instdir';
const SOFFICE = join(LO_DIR, 'program', 'soffice.bin');
const LO_PROGRAM = join(LO_DIR, 'program');
const FONTCONFIG = join(LO_DIR, 'share/fonts/fonts.conf');
const SENTINEL = '/tmp/.lo_extracted';

function findTarBr(): string {
  const candidates = [
    join(__dirname, '..', 'lo.tar.br'),
    join(__dirname, '..', '..', 'lo.tar.br'),
    join(process.cwd(), 'lo.tar.br'),
    join(process.cwd(), 'node_modules', 'librepdf', 'lo.tar.br'),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  throw new Error('lo.tar.br not found');
}

async function ensureLO(): Promise<void> {
  if (initialized) return;
  if (existsSync(SENTINEL)) { initialized = true; return; }
  const buf = readFileSync(findTarBr());
  const tmpTar = '/tmp/lo.tar';
  writeFileSync(tmpTar, brotliDecompressSync(buf));
  await extractTar({ file: tmpTar, C: '/tmp' });
  try { unlinkSync(tmpTar); } catch { /* ignore */ }
  if (!existsSync(SOFFICE)) throw new Error('soffice binary not found after extraction');
  try { writeFileSync(SENTINEL, ''); } catch { /* ignore */ }
  initialized = true;
}

function detectExt(input: Buffer): string {
  if (input[0] === 0x25 && input[1] === 0x50 && input[2] === 0x44 && input[3] === 0x46) return '.pdf';
  if (input[0] === 0xFF && input[1] === 0xD8) return '.jpg';
  if (input[0] === 0x89 && input[1] === 0x50) return '.png';
  if (input[0] === 0x50 && input[1] === 0x4B) {
    const header = input.subarray(0, 200).toString();
    if (header.includes('word/')) return '.docx';
    if (header.includes('xl/')) return '.xlsx';
    if (header.includes('ppt/')) return '.pptx';
    return '.docx';
  }
  const txt = input.subarray(0, 1000).toString();
  if (/<html|<head|<body|<div/i.test(txt)) return '.html';
  return '.txt';
}

export interface ConvertOptions {
  from?: 'docx' | 'html' | 'txt';
  fonts?: string | string[];
}

export async function convert(
  input: Buffer | Uint8Array,
  _options?: ConvertOptions
): Promise<Buffer> {
  await ensureLO();

  const buf = Buffer.from(input);
  const ext = _options?.from ? `.${_options.from}` : detectExt(buf);
  const suffix = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const inputPath = join('/tmp', `input_${suffix}${ext}`);
  const outputPath = join('/tmp', `input_${suffix}.pdf`);

  writeFileSync(inputPath, buf);

  if (_options?.fonts) {
    const customDir = join(LO_DIR, 'share/fonts/custom');
    mkdirSync(customDir, { recursive: true });
    const paths = Array.isArray(_options.fonts) ? _options.fonts : [_options.fonts];
    for (const fp of paths) {
      const st = statSync(fp);
      if (st.isDirectory()) {
        for (const f of readdirSync(fp)) {
          if (f.endsWith('.ttf') || f.endsWith('.otf')) {
            copyFileSync(join(fp, f), join(customDir, f));
          }
        }
      } else if (st.isFile()) {
        copyFileSync(fp, join(customDir, basename(fp)));
      }
    }
  }

  return new Promise((resolve, reject) => {
    let stderr = '';
    const proc = spawn(SOFFICE, [
      '--headless', '--invisible', '--nodefault', '--nofirststartwizard',
      '--nolockcheck', '--nologo', '--norestore',
      '-env:UserInstallation=file:///tmp/lo_profile_' + suffix,
      '--convert-to', 'pdf', '--outdir', '/tmp', inputPath,
    ], {
      env: {
        HOME: '/tmp',
        FONTCONFIG_FILE: FONTCONFIG,
        URE_BOOTSTRAP: `file://${LO_PROGRAM}/fundamentalrc`,
        PATH: process.env.PATH || '/usr/bin:/bin',
        LD_LIBRARY_PATH: LO_PROGRAM,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    proc.stderr?.on('data', (chunk: Buffer) => { stderr += chunk.toString(); });

    let settled = false;
    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        proc.kill('SIGKILL');
        reject(new Error('soffice timed out'));
      }
    }, 60_000);
    const finish = (code: number | null, signal: string | null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try {
        if (existsSync(outputPath)) {
          resolve(readFileSync(outputPath));
        } else if (signal) {
          reject(new Error(`soffice killed by signal ${signal}`));
        } else if (code !== 0) {
          const msg = stderr
            ? `soffice exited with code ${code}: ${stderr.trim().split('\n').pop()}`
            : `soffice exited with code ${code}`;
          reject(new Error(msg));
        } else {
          reject(new Error('soffice did not produce an output PDF'));
        }
      } catch (e) {
        reject(e);
      } finally {
        try { unlinkSync(inputPath); } catch { /* ignore */ }
        try { unlinkSync(outputPath); } catch { /* ignore */ }
      }
    };

    proc.on('exit', finish);
    proc.on('error', (err: Error) => { if (!settled) { settled = true; clearTimeout(timer); reject(err); } });
  });
}
