#!/usr/bin/env node
'use strict';
// ============================================================================
// monaco-diff : show a git diff in the browser using Monaco's diff editor.
// ----------------------------------------------------------------------------
// Usage:
//   node server.js --repo <dir> --mode worktree            uncommitted changes
//   node server.js --repo <dir> --mode branch [--base master]   branch vs base
//   node server.js --repo <dir> --mode commit --sha <sha>  one commit
//   (add --no-open to skip launching the browser)
//
// It starts a tiny HTTP server on 127.0.0.1 (random port, random token), opens
// the page with xdg-open, and exits on its own once the tab is closed.
// No npm dependencies. Monaco is served from vendor/monaco/ when present
// (run install.sh once), otherwise it is loaded from the jsDelivr CDN.
//
// Exit codes: 0 normal, 1 error, 3 nothing to show.
// ============================================================================
const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execFile, spawn } = require('child_process');

const MONACO_VERSION = '0.52.2';
const CDN = `https://cdn.jsdelivr.net/npm/monaco-editor@${MONACO_VERSION}/min`;
const VENDOR = path.join(__dirname, 'vendor', 'monaco');
const useLocal = fs.existsSync(path.join(VENDOR, 'vs', 'loader.js'));
const MIME = {
  '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json', '.map': 'application/json', '.ttf': 'font/ttf',
  '.svg': 'image/svg+xml', '.txt': 'text/plain; charset=utf-8',
};
const EMPTY_TREE = '4b825dc642cb6eb9a060e54bf8d69288fbee4904';
const MAX_BYTES = 2 * 1024 * 1024; // per side; bigger files are not sent

// ---- args -------------------------------------------------------------------
const opt = { mode: 'worktree', repo: process.cwd(), base: 'master', sha: null, open: true };
{
  const a = process.argv.slice(2);
  for (let i = 0; i < a.length; i++) {
    if (a[i] === '--mode') opt.mode = a[++i];
    else if (a[i] === '--repo') opt.repo = a[++i];
    else if (a[i] === '--sha') opt.sha = a[++i];
    else if (a[i] === '--base') opt.base = a[++i];
    else if (a[i] === '--no-open') opt.open = false;
  }
}

function fail(msg, code = 1) {
  process.stderr.write(msg.trim() + '\n');
  process.exit(code);
}

// ---- git helpers ------------------------------------------------------------
let root = null;

function gitIn(cwd, args, { allowFail = false } = {}) {
  return new Promise((resolve, reject) => {
    execFile('git', ['-C', cwd, ...args], { maxBuffer: 256 * 1024 * 1024, encoding: 'buffer' },
      (err, stdout, stderr) => {
        if (err) {
          if (allowFail) return resolve(null);
          return reject(new Error((stderr && stderr.toString().trim()) || err.message));
        }
        resolve(stdout);
      });
  });
}
const git = (args, o) => gitIn(root, args, o);
const gitText = async (args, o) => {
  const b = await git(args, o);
  return b === null ? null : b.toString('utf8').trim();
};

function parseNameStatus(text) {
  const parts = text.split('\0');
  const out = [];
  let i = 0;
  while (i < parts.length && parts[i] !== '') {
    const code = parts[i++][0];
    if (code === 'R' || code === 'C') {
      const from = parts[i++];
      const to = parts[i++];
      out.push({ status: code, oldPath: from, path: to });
    } else {
      const p = parts[i++];
      out.push({ status: code, oldPath: p, path: p });
    }
  }
  return out;
}

// ---- diff setup -------------------------------------------------------------
let oldRef = null;   // git ref for the "before" side
let newRef = null;   // git ref for the "after" side; null = working tree
let title = '';
let subtitle = '';
let files = [];

async function setup() {
  root = (await gitIn(opt.repo, ['rev-parse', '--show-toplevel'])).toString().trim();
  const repoName = path.basename(root);

  if (opt.mode === 'worktree') {
    const hasHead = await gitText(['rev-parse', '--verify', '--quiet', 'HEAD'], { allowFail: true });
    oldRef = hasHead ? 'HEAD' : EMPTY_TREE;
    newRef = null;
    title = 'Uncommitted changes';
    subtitle = repoName + ' · working tree vs HEAD';
    const tracked = parseNameStatus((await git(['diff', '--name-status', '-z', '-M', oldRef])).toString('utf8'));
    const untrackedRaw = (await git(['ls-files', '--others', '--exclude-standard', '-z'])).toString('utf8');
    const untracked = untrackedRaw.split('\0').filter(Boolean).map((p) => ({ status: 'U', oldPath: p, path: p }));
    files = tracked.concat(untracked);
  } else if (opt.mode === 'branch') {
    let base = null;
    for (const cand of [opt.base, 'master', 'main', 'origin/master', 'origin/main']) {
      if (await gitText(['rev-parse', '--verify', '--quiet', cand], { allowFail: true })) { base = cand; break; }
    }
    if (!base) fail('Could not find a base branch (tried master, main, origin/master, origin/main).');
    const mergeBase = await gitText(['merge-base', base, 'HEAD']);
    const branch = (await gitText(['rev-parse', '--abbrev-ref', 'HEAD'])) || 'HEAD';
    oldRef = mergeBase;
    newRef = 'HEAD';
    title = `${branch} vs ${base}`;
    subtitle = repoName + ' · changes since merge-base ' + mergeBase.slice(0, 8);
    files = parseNameStatus((await git(['diff', '--name-status', '-z', '-M', oldRef, newRef])).toString('utf8'));
  } else if (opt.mode === 'commit') {
    if (!opt.sha) fail('--sha is required for --mode commit');
    const full = await gitText(['rev-parse', '--verify', opt.sha + '^{commit}']);
    const parent = await gitText(['rev-parse', '--verify', '--quiet', full + '^'], { allowFail: true });
    oldRef = parent || EMPTY_TREE;
    newRef = full;
    const subject = await gitText(['show', '-s', '--format=%s', full]);
    const meta = await gitText(['show', '-s', '--format=%an · %ad', '--date=short', full]);
    title = subject;
    subtitle = `${repoName} · ${full.slice(0, 10)} · ${meta}`;
    files = parseNameStatus((await git(['diff', '--name-status', '-z', '-M', oldRef, newRef])).toString('utf8'));
  } else {
    fail('Unknown --mode: ' + opt.mode);
  }
  files.sort((a, b) => a.path.localeCompare(b.path));
  if (files.length === 0) fail('No changes to show (' + title + ').', 3);
}

function isBinary(buf) {
  const n = Math.min(buf.length, 8000);
  for (let i = 0; i < n; i++) if (buf[i] === 0) return true;
  return false;
}

async function readOld(f) {
  if (f.status === 'A' || f.status === 'U') return Buffer.alloc(0);
  const b = await git(['show', `${oldRef}:${f.oldPath}`], { allowFail: true });
  return b || Buffer.alloc(0);
}

async function readNew(f) {
  if (f.status === 'D') return Buffer.alloc(0);
  if (newRef === null) {
    const full = path.join(root, f.path);
    try {
      const st = fs.lstatSync(full);
      if (st.isSymbolicLink()) return Buffer.from('[symlink] -> ' + fs.readlinkSync(full));
      if (st.isDirectory()) return Buffer.from('[directory or submodule]');
      return fs.readFileSync(full);
    } catch (e) {
      return Buffer.alloc(0);
    }
  }
  const b = await git(['show', `${newRef}:${f.path}`], { allowFail: true });
  return b || Buffer.alloc(0);
}

async function fileDetail(i) {
  const f = files[i];
  const [o, n] = await Promise.all([readOld(f), readNew(f)]);
  const base = { path: f.path, oldPath: f.oldPath, status: f.status, binary: false, tooLarge: false, old: '', new: '' };
  if (isBinary(o) || isBinary(n)) return { ...base, binary: true };
  if (o.length > MAX_BYTES || n.length > MAX_BYTES) return { ...base, tooLarge: true };
  return { ...base, old: o.toString('utf8'), new: n.toString('utf8') };
}

// ---- page -------------------------------------------------------------------
function page(token) {
  const meta = JSON.stringify({ token, title, subtitle, count: files.length })
    .replace(/</g, '\\u003c');
  // Local copy is served under /m/<token>/ ; otherwise fall back to the CDN.
  const assets = useLocal ? '/m/' + token : CDN;
  return `<!doctype html>
<html><head><meta charset="utf-8">
<title>${title.replace(/[<&>]/g, '')} - diff</title>
<style>
  html,body{margin:0;height:100%;background:#1e1e1e;color:#cccccc;font:13px -apple-system,"Segoe UI",Roboto,sans-serif}
  #app{display:flex;height:100%}
  #side{width:320px;min-width:200px;display:flex;flex-direction:column;border-right:1px solid #333;background:#252526}
  #hdr{padding:12px;border-bottom:1px solid #333}
  #hdr .t{font-weight:600;color:#fff;font-size:14px;word-break:break-word}
  #hdr .s{opacity:.65;margin-top:4px;font-size:12px;word-break:break-word}
  #list{overflow:auto;flex:1}
  .f{padding:4px 12px;cursor:pointer;display:flex;gap:8px;align-items:baseline;white-space:nowrap;overflow:hidden}
  .f:hover{background:#2a2d2e}
  .f.sel{background:#37373d}
  .b{font:700 11px monospace;width:14px;text-align:center;flex:none}
  .b.A,.b.U{color:#73c991}.b.M{color:#e2c08d}.b.D{color:#c74e39}.b.R,.b.C{color:#6c9ef8}
  .nm{overflow:hidden;text-overflow:ellipsis}.dir{opacity:.5;margin-left:6px;font-size:12px}
  #main{flex:1;display:flex;flex-direction:column;min-width:0}
  #bar{display:flex;gap:8px;align-items:center;padding:6px 10px;border-bottom:1px solid #333;background:#252526}
  #cur{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#fff}
  button{background:#3a3d41;color:#ddd;border:1px solid #4a4d51;border-radius:3px;padding:3px 9px;cursor:pointer;font:12px inherit}
  button:hover{background:#45494e}
  #hint{opacity:.5;font-size:12px}
  #ed{flex:1;min-height:0}
  #msg{display:none;padding:40px;text-align:center;opacity:.7}
</style></head>
<body><div id="app">
  <div id="side"><div id="hdr"><div class="t" id="t"></div><div class="s" id="s"></div></div><div id="list"></div></div>
  <div id="main">
    <div id="bar"><span id="cur"></span>
      <span id="hint">n/p file · [ ] change</span>
      <button id="bPrev">&#9650; Prev change</button><button id="bNext">&#9660; Next change</button>
      <button id="bInline">Inline</button><button id="bFold">Show all lines</button></div>
    <div id="msg"></div><div id="ed"></div>
  </div>
</div>
<script src="${assets}/vs/loader.js"></script>
<script>
const META = ${meta};
const ASSETS = new URL(${JSON.stringify(assets)}, location.origin).href;
const q = (p) => p + (p.includes('?') ? '&' : '?') + 't=' + META.token;
document.getElementById('t').textContent = META.title;
document.getElementById('s').textContent = META.subtitle;
let FILES = [], cur = -1, editor = null, models = [], sideBySide = true, fold = true;

// keep-alive: the server exits when the tab is gone
setInterval(() => fetch(q('/api/ping')).catch(() => {}), 5000);
addEventListener('pagehide', () => navigator.sendBeacon(q('/api/bye')));

function renderList() {
  const el = document.getElementById('list'); el.textContent = '';
  FILES.forEach((f, i) => {
    const d = document.createElement('div'); d.className = 'f'; d.title = f.path + (f.status === 'R' ? '  (was ' + f.oldPath + ')' : '');
    const b = document.createElement('span'); b.className = 'b ' + f.status; b.textContent = f.status;
    const n = document.createElement('span'); n.className = 'nm';
    const parts = f.path.split('/'); n.textContent = parts.pop();
    const dir = document.createElement('span'); dir.className = 'dir'; dir.textContent = parts.join('/');
    n.appendChild(dir);
    d.append(b, n); d.onclick = () => show(i); el.appendChild(d);
  });
}

function langFor(p) {
  const base = p.split('/').pop().toLowerCase();
  const ext = base.includes('.') ? '.' + base.split('.').pop() : '';
  for (const l of monaco.languages.getLanguages()) {
    if ((l.filenames || []).map((x) => x.toLowerCase()).includes(base) || (l.extensions || []).includes(ext)) return l.id;
  }
  return 'plaintext';
}

async function show(i) {
  if (i < 0 || i >= FILES.length) return;
  cur = i;
  [...document.querySelectorAll('.f')].forEach((e, k) => e.classList.toggle('sel', k === i));
  const sel = document.querySelectorAll('.f')[i]; if (sel) sel.scrollIntoView({ block: 'nearest' });
  const d = await (await fetch(q('/api/file?i=' + i))).json();
  document.getElementById('cur').textContent = d.path + (d.status === 'R' ? '   (renamed from ' + d.oldPath + ')' : '') + '   [' + (i + 1) + '/' + FILES.length + ']';
  let o = d.old, n = d.new, lang = langFor(d.path);
  if (d.binary) { o = n = '[binary file - not shown]'; lang = 'plaintext'; }
  if (d.tooLarge) { o = n = '[file larger than 2 MB - not shown]'; lang = 'plaintext'; }
  const prev = models;
  models = [monaco.editor.createModel(o, lang), monaco.editor.createModel(n, lang)];
  editor.setModel({ original: models[0], modified: models[1] });
  prev.forEach((m) => m.dispose());
}

require.config({ paths: { vs: ASSETS + '/vs' } });
window.MonacoEnvironment = {
  getWorkerUrl() {
    return 'data:text/javascript;charset=utf-8,' + encodeURIComponent(
      "self.MonacoEnvironment={baseUrl:'" + ASSETS + "/'};importScripts('" + ASSETS + "/vs/base/worker/workerMain.js');");
  },
};
require(['vs/editor/editor.main'], async () => {
  editor = monaco.editor.createDiffEditor(document.getElementById('ed'), {
    theme: 'vs-dark', readOnly: true, originalEditable: false, automaticLayout: true,
    renderSideBySide: sideBySide, ignoreTrimWhitespace: false, renderOverviewRuler: true,
    hideUnchangedRegions: { enabled: true, contextLineCount: 4, minimumLineCount: 6 },
    scrollBeyondLastLine: false, fontSize: 13,
  });
  FILES = await (await fetch(q('/api/files'))).json();
  renderList();
  show(0);
});

const go = (dir) => { if (editor && typeof editor.goToDiff === 'function') editor.goToDiff(dir); };
document.getElementById('bNext').onclick = () => go('next');
document.getElementById('bPrev').onclick = () => go('previous');
document.getElementById('bInline').onclick = (e) => {
  sideBySide = !sideBySide; editor.updateOptions({ renderSideBySide: sideBySide });
  e.target.textContent = sideBySide ? 'Inline' : 'Side by side';
};
document.getElementById('bFold').onclick = (e) => {
  fold = !fold; editor.updateOptions({ hideUnchangedRegions: { enabled: fold, contextLineCount: 4, minimumLineCount: 6 } });
  e.target.textContent = fold ? 'Show all lines' : 'Fold unchanged';
};
addEventListener('keydown', (e) => {
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key === 'n') show(cur + 1);
  else if (e.key === 'p') show(cur - 1);
  else if (e.key === ']') go('next');
  else if (e.key === '[') go('previous');
});
</script></body></html>`;
}

// ---- server -----------------------------------------------------------------
async function main() {
  await setup();
  const token = crypto.randomBytes(16).toString('hex');
  let port = 0;
  let lastSeen = Date.now();
  let everSeen = false;
  let byeTimer = null;
  let connectedAnnounced = false;

  const shutdown = () => { server.close(); setTimeout(() => process.exit(0), 100); };

  const server = http.createServer(async (req, res) => {
    const send = (code, type, body) => { res.writeHead(code, { 'Content-Type': type, 'Cache-Control': 'no-store' }); res.end(body); };
    try {
      // Only answer requests addressed to our own loopback address (blocks DNS rebinding).
      const host = (req.headers.host || '').toLowerCase();
      if (host !== `127.0.0.1:${port}` && host !== `localhost:${port}`) return send(403, 'text/plain', 'forbidden');
      const u = new URL(req.url, 'http://127.0.0.1');

      // Static Monaco files from vendor/monaco, addressed as /m/<token>/<path>.
      const sm = u.pathname.match(/^\/m\/([0-9a-f]{32})\/(.+)$/);
      if (sm) {
        if (!useLocal || sm[1] !== token) return send(403, 'text/plain', 'forbidden');
        let rel;
        try { rel = decodeURIComponent(sm[2]); } catch (e) { return send(400, 'text/plain', 'bad path'); }
        const file = path.resolve(VENDOR, rel);
        if (file !== VENDOR && !file.startsWith(VENDOR + path.sep)) return send(403, 'text/plain', 'forbidden');
        let st;
        try { st = fs.statSync(file); } catch (e) { return send(404, 'text/plain', 'not found'); }
        if (!st.isFile()) return send(404, 'text/plain', 'not found');
        lastSeen = Date.now();
        return send(200, MIME[path.extname(file).toLowerCase()] || 'application/octet-stream', fs.readFileSync(file));
      }

      if (u.searchParams.get('t') !== token) return send(403, 'text/plain', 'forbidden');

      lastSeen = Date.now(); everSeen = true;
      if (byeTimer) { clearTimeout(byeTimer); byeTimer = null; }
      // Tell the caller (Neovim) a browser really loaded the page.
      if (u.pathname === '/' && !connectedAnnounced) {
        connectedAnnounced = true;
        process.stdout.write('MONACO_DIFF_CONNECTED\n');
      }

      if (u.pathname === '/') return send(200, 'text/html; charset=utf-8', page(token));
      if (u.pathname === '/api/ping') return send(200, 'text/plain', 'ok');
      if (u.pathname === '/api/bye') {
        // tab closed or reloading: give a reload a few seconds to come back
        byeTimer = setTimeout(shutdown, 4000);
        return send(200, 'text/plain', 'bye');
      }
      if (u.pathname === '/api/files') {
        return send(200, 'application/json', JSON.stringify(files.map((f) => ({ status: f.status, path: f.path, oldPath: f.oldPath }))));
      }
      if (u.pathname === '/api/file') {
        const i = Number(u.searchParams.get('i'));
        if (!Number.isInteger(i) || i < 0 || i >= files.length) return send(404, 'text/plain', 'no such file');
        return send(200, 'application/json', JSON.stringify(await fileDetail(i)));
      }
      send(404, 'text/plain', 'not found');
    } catch (e) {
      send(500, 'text/plain', String(e && e.message || e));
    }
  });

  // Safety net: exit if the page never connected, or has been silent for 5 minutes
  // (hidden tabs can be throttled, so the threshold is generous).
  setInterval(() => {
    const idle = Date.now() - lastSeen;
    if ((!everSeen && idle > 90 * 1000) || (everSeen && idle > 5 * 60 * 1000)) shutdown();
  }, 5000).unref();

  server.listen(0, '127.0.0.1', () => {
    port = server.address().port;
    const url = `http://127.0.0.1:${port}/?t=${token}`;
    process.stdout.write('MONACO_DIFF_URL ' + url + '\n');
    if (opt.open) {
      const p = spawn('xdg-open', [url], { detached: true, stdio: ['ignore', 'ignore', 'pipe'] });
      let err = '';
      p.stderr.on('data', (d) => { if (err.length < 400) err += d; });
      const failed = (why) => process.stdout.write('MONACO_DIFF_OPEN_FAILED ' + why.replace(/\s+/g, ' ').trim() + '\n');
      p.on('error', (e) => failed('could not run xdg-open: ' + e.message));
      p.on('exit', (code) => { if (code !== 0) failed('xdg-open exited with ' + code + (err ? ': ' + err : '')); });
      p.unref();
    }
  });
}

main().catch((e) => fail('monaco-diff: ' + (e && e.message || e)));
