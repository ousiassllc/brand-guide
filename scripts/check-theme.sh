#!/usr/bin/env bash
# check-theme.sh — Issue #53（テーマ切替の規定を theme.js で実際に動かして確かめる）の回帰チェック。
# headless Chrome を CDP（Chrome DevTools Protocol）で操作する。npm 不要（Node 22 以降の標準 WebSocket を使う）。
# 前提: Chrome（google-chrome / chromium）と Node 22 以降。Chrome のパスは環境変数 CHROME で指定できる。
#       どちらかが無いときは SKIP を表示して exit 0（検査は実行されない）。
# 使い方: scripts/check-theme.sh [リポジトリルート]
#   ルートの index.html・tokens-preview.html を、ルートの theme.js ごと一時の HTTP サーバから開いて確かめる。
#   理由: file:// では localStorage の扱いが環境で変わるため。プロファイルは毎回一時ディレクトリ（終了時に削除）。
# 確かめる規定（index.html #theme）:
#   初期値 system・OS の配色に従う / light・dark だけ保存し system で消す / 保存済みの間は OS の変化で動かない・
#   system のときだけ追従 / リロードなし・スクロール維持・切替の瞬間は transition を止める /
#   描画前（<body> が現れる時点）に data-theme が決まっている / aria-pressed がちょうど 1 つ true /
#   ←→↑↓・Home・End でフォーカス移動
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

chrome=""
for c in "${CHROME:-}" google-chrome google-chrome-stable chromium chromium-browser /usr/bin/google-chrome; do
  [ -n "$c" ] || continue
  if p=$(command -v "$c" 2>/dev/null); then chrome="$p"; break; fi
done
if [ -z "$chrome" ]; then
  echo 'SKIP  Chrome（google-chrome / chromium。CHROME 環境変数でも指定可）が見つからないため、テーマ切替の実行検査を行わない'
  exit 0
fi
if ! command -v node >/dev/null 2>&1 || [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -lt 22 ]; then
  echo 'SKIP  Node 22 以降が見つからないため、テーマ切替の実行検査を行わない'
  exit 0
fi
[ -f "$root/theme.js" ] || { echo 'FAIL  theme.js がない'; echo 'PASS 0 / FAIL 1'; exit 1; }

node --input-type=module - "$root" "$chrome" <<'NODE'
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn } from 'node:child_process';

process.stdout.on('error', () => {}); // 出力先（head など）が先に閉じても後始末を続ける
const root = path.resolve(process.argv[2]);
const chromePath = process.argv[3];
const pages = ['index.html', 'tokens-preview.html'];
const KEY = 'ousiass-theme';
let pass = 0, fail = 0;
const ok = (m) => { pass++; console.log(`PASS  ${m}`); };
const ng = (m) => { fail++; console.log(`FAIL  ${m}`); };
const check = (cond, m, detail) => (cond ? ok(m) : ng(detail === undefined ? m : `${m}（${detail}）`));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- 一時 HTTP サーバ（ルート直下のファイルだけ配る） ----
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css', '.woff2': 'font/woff2', '.svg': 'image/svg+xml' };
const server = http.createServer((req, res) => {
  const p = path.normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^([/\\])+/, '');
  const f = path.join(root, p);
  if (!f.startsWith(root + path.sep) || !fs.existsSync(f) || !fs.statSync(f).isFile()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'content-type': types[path.extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' });
  res.end(fs.readFileSync(f));
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const origin = `http://127.0.0.1:${server.address().port}`;

// ---- Chrome 起動 ----
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'check-theme-'));
const args = ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check',
  '--disable-extensions', '--disable-gpu', '--window-size=1280,900', 'about:blank'];
if (process.getuid && process.getuid() === 0) args.push('--no-sandbox');
// DBUS_SESSION_BUS_ADDRESS が壊れている環境（セッションバスが無い）では、Chrome のネットワークが止まったままになるため外す
const env = { ...process.env };
delete env.DBUS_SESSION_BUS_ADDRESS;
const chrome = spawn(chromePath, args, { stdio: 'ignore', env });
let cleaned = false;
const cleanup = () => {
  if (cleaned) return; cleaned = true;
  try { chrome.kill('SIGKILL'); } catch {}
  try { server.close(); } catch {}
  try { fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5 }); } catch {}
};
process.on('exit', cleanup);
for (const s of ['SIGINT', 'SIGTERM']) process.on(s, () => { cleanup(); process.exit(130); });

async function main() {
  // DevToolsActivePort（1 行目 = ポート、2 行目 = ブラウザの WebSocket パス）を待つ
  const portFile = path.join(profile, 'DevToolsActivePort');
  let info = null;
  for (let i = 0; i < 300 && !info; i++) {
    if (fs.existsSync(portFile)) { const l = fs.readFileSync(portFile, 'utf8').split('\n'); if (l[1]) info = l; }
    if (!info) await sleep(50);
  }
  if (!info) throw new Error('Chrome の DevTools ポートが開かない');
  const ws = new WebSocket(`ws://127.0.0.1:${info[0]}${info[1]}`);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP に接続できない')); });

  let seq = 0;
  const waiting = new Map();
  const listeners = [];
  ws.onmessage = (m) => {
    const d = JSON.parse(m.data);
    if (d.id && waiting.has(d.id)) { const w = waiting.get(d.id); waiting.delete(d.id); d.error ? w.rej(new Error(`${w.method}: ${d.error.message}`)) : w.res(d.result); }
    else if (d.method) listeners.slice().forEach((f) => f(d));
  };
  const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const id = ++seq; waiting.set(id, { res, rej, method });
    ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
  });

  const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
  const cdp = (method, params) => send(method, params, sessionId);
  await cdp('Page.enable');
  // Web フォントなど外部への取得で load が止まらないよう、一時サーバ以外への通信は止める（検査に不要）
  await cdp('Network.enable');
  await cdp('Network.setBlockedURLs', { urls: ['https://*'] });
  await cdp('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 1, mobile: false });
  // 描画前の値を記録する（theme.js より前に走る）。<body> が現れた時点の data-theme と、themechange の回数
  await cdp('Page.addScriptToEvaluateOnNewDocument', { source: `(function(){
    // この時点では documentElement がまだ無いので、document の子の追加を見て、<body> が現れた瞬間の値を残す
    window.__t={body:null,events:0};
    new MutationObserver(function(_,o){if(document.body){var r=document.documentElement;window.__t.body=r.dataset.theme+'|'+r.dataset.themeMode;o.disconnect();}}).observe(document,{childList:true,subtree:true});
    document.addEventListener('themechange',function(){window.__t.events++;});
  })();` });

  const ev = async (expression) => {
    const r = await cdp('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(`評価エラー: ${r.exceptionDetails.exception?.description || r.exceptionDetails.text}`);
    return r.result.value;
  };
  const waitFor = async (expr, ms = 3000) => {
    const end = Date.now() + ms;
    for (;;) { if (await ev(expr)) return true; if (Date.now() > end) return false; await sleep(20); }
  };
  const load = (url, reload = false) => new Promise(async (res, rej) => {
    const timer = setTimeout(() => rej(new Error(`${url} の load が 15 秒で終わらない`)), 15000);
    const f = (d) => { if (d.sessionId === sessionId && d.method === 'Page.loadEventFired') { listeners.splice(listeners.indexOf(f), 1); clearTimeout(timer); res(); } };
    listeners.push(f);
    try { await (reload ? cdp('Page.reload') : cdp('Page.navigate', { url })); } catch (e) { rej(e); }
  });
  const emulate = (scheme) => cdp('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: scheme }] });
  // OS の配色を変え、matchMedia の change が届くのを待つ（theme.js のリスナーは先に登録済みなので、届いた時点で反映済み）
  const flipOS = async (scheme) => {
    await ev(`window.__mqp=new Promise(function(r){matchMedia('(prefers-color-scheme: dark)').addEventListener('change',function(){r(true)},{once:true})});1`);
    await emulate(scheme);
    return ev(`Promise.race([window.__mqp,new Promise(function(r){setTimeout(function(){r(false)},3000)})])`);
  };
  const state = () => ev(`(function(){var r=document.documentElement,g=[].slice.call(document.querySelectorAll('[data-theme-control]'));
    return {theme:r.dataset.theme||null,mode:r.dataset.themeMode||null,ls:localStorage.getItem(${JSON.stringify(KEY)}),events:window.__t.events,
      switching:r.hasAttribute('data-theme-switching'),pre:window.__t,
      groups:g.map(function(c){return [].slice.call(c.querySelectorAll('[data-set-theme]')).map(function(b){return [b.dataset.setTheme,b.getAttribute('aria-pressed')];});})};})()`);
  const click = (m) => ev(`(function(){var b=document.querySelector('[data-set-theme="${m}"]');b.click();return document.documentElement.hasAttribute('data-theme-switching');})()`);
  const resolved = (scheme) => (scheme === 'dark' ? 'dark' : 'light');
  const pressedOk = (s, mode) => s.groups.length > 0 && s.groups.every((g) => g.length > 0
    && g.every(([, p]) => p === 'true' || p === 'false') && g.filter(([, p]) => p === 'true').length === 1
    && g.find(([, p]) => p === 'true')[0] === mode);

  for (const name of pages) {
    const url = `${origin}/${name}`;
    const L = (m) => `${name}: ${m}`;
    if (!fs.existsSync(path.join(root, name))) { ng(L(`${name} がない`)); continue; }

    // 1. 初期値: 保存なし → system・OS の配色に従う（描画前に決まる）
    await emulate('light');
    await load(url);
    await ev('localStorage.clear()');
    for (const scheme of ['light', 'dark']) {
      await emulate(scheme);
      await load(url, true);
      const s = await state();
      check(s.mode === 'system' && s.theme === resolved(scheme) && s.ls === null,
        L(`初期（保存なし・OS ${scheme}）: data-theme-mode=system・data-theme=${resolved(scheme)}`), `mode=${s.mode} theme=${s.theme} ls=${s.ls}`);
      check(s.pre.body === `${resolved(scheme)}|system`,
        L(`初期（OS ${scheme}）: <body> が現れる時点（描画前）で data-theme が決まっている`), `body 時点=${s.pre.body}`);
      check(pressedOk(s, 'system'), L(`初期（OS ${scheme}）: aria-pressed がコントロールごとにちょうど 1 つ true（system）`), JSON.stringify(s.groups));
    }

    // 2. system のときは OS の変化に追従する
    await emulate('light'); await load(url, true);
    for (const scheme of ['dark', 'light']) {
      await ev('window.__t.events=0');
      const fired = await flipOS(scheme);
      const s = await state();
      check(fired && s.theme === scheme && s.mode === 'system' && s.events >= 1,
        L(`system: OS が ${scheme} になると data-theme=${scheme} に追従する`), `fired=${fired} theme=${s.theme} events=${s.events}`);
    }

    // 3. light / dark を選ぶ: 即時反映・保存・リロードなし・スクロール維持・transition 停止・リロード後も維持
    for (const pick of ['dark', 'light']) {
      const osScheme = pick === 'dark' ? 'light' : 'dark'; // 選んだ値と OS を逆にして、保存が効いていることを見分ける
      await emulate(osScheme); await load(url, true);
      await ev(`window.__marker='same-document';window.scrollTo({top:400,behavior:'instant'});1`);
      await waitFor('window.scrollY===400');
      const switching = await click(pick);
      const s = await state();
      check(s.theme === pick && s.mode === pick, L(`${pick} をクリック: data-theme=${pick}・data-theme-mode=${pick}`), `theme=${s.theme} mode=${s.mode}`);
      check(s.ls === pick, L(`${pick} をクリック: localStorage ${KEY}=${pick} を保存`), `ls=${s.ls}`);
      check(pressedOk(s, pick), L(`${pick} をクリック: aria-pressed がコントロールごとにちょうど 1 つ true（${pick}）`), JSON.stringify(s.groups));
      check(switching, L(`${pick} をクリック: 切替の瞬間は data-theme-switching で transition を止める`));
      check(await waitFor('!document.documentElement.hasAttribute("data-theme-switching")'), L(`${pick} をクリック: 切替後に data-theme-switching が外れる`));
      check((await ev('window.__marker')) === 'same-document' && (await ev('scrollY')) === 400, L(`${pick} をクリック: リロードなし・スクロール位置を維持`));

      await load(url, true);
      const r = await state();
      check(r.theme === pick && r.mode === pick && r.ls === pick, L(`${pick} 保存後のリロード（OS ${osScheme}）: ${pick} を復元`), `theme=${r.theme} mode=${r.mode} ls=${r.ls}`);
      check(r.pre.body === `${pick}|${pick}`, L(`${pick} 保存後のリロード: <body> が現れる時点（描画前）で保存値の data-theme が決まっている`), `body 時点=${r.pre.body}`);
      check(pressedOk(r, pick), L(`${pick} 保存後のリロード: aria-pressed がコントロールごとにちょうど 1 つ true（${pick}）`), JSON.stringify(r.groups));

      // 4. 保存済みの間は OS の変化で動かない（themechange も出ない・transition 停止も起きない）
      await ev('window.__t.events=0');
      for (const scheme of [pick, osScheme]) {
        const fired = await flipOS(scheme);
        const t = await state();
        check(fired && t.theme === pick && t.mode === pick && t.events === 0 && !t.switching && t.ls === pick,
          L(`${pick} 保存済み: OS が ${scheme} に変わっても data-theme=${pick} のまま（再適用しない）`), `fired=${fired} theme=${t.theme} events=${t.events} switching=${t.switching}`);
      }

      // 5. system を選ぶと保存が消え、リロード後も system。OS の変化に再び追従する
      await click('system');
      const sy = await state();
      check(sy.ls === null && sy.mode === 'system', L(`${pick} → system: localStorage ${KEY} が消え data-theme-mode=system`), `ls=${sy.ls} mode=${sy.mode}`);
      check(pressedOk(sy, 'system'), L(`${pick} → system: aria-pressed がコントロールごとにちょうど 1 つ true（system）`), JSON.stringify(sy.groups));
      await load(url, true);
      const sr = await state();
      check(sr.ls === null && sr.mode === 'system', L(`${pick} → system 後のリロード: system のまま・保存なし`), `ls=${sr.ls} mode=${sr.mode}`);
      await ev('window.__t.events=0');
      const target = (await ev(`matchMedia('(prefers-color-scheme: dark)').matches`)) ? 'light' : 'dark';
      const fired = await flipOS(target);
      const sf = await state();
      check(fired && sf.theme === target && sf.events >= 1, L(`${pick} → system: OS が ${target} になると再び追従する`), `fired=${fired} theme=${sf.theme} events=${sf.events}`);
    }

    // 6. キーボード: ←→↑↓ / Home / End でコントロール内のフォーカスが動く（選択は変えない）
    await emulate('light'); await load(url, true);
    await ev('localStorage.clear();1');
    const keys = { ArrowRight: [39, 'ArrowRight'], ArrowLeft: [37, 'ArrowLeft'], ArrowDown: [40, 'ArrowDown'], ArrowUp: [38, 'ArrowUp'], Home: [36, 'Home'], End: [35, 'End'] };
    const press = async (k, modifiers = 0) => {
      const [code, key] = keys[k];
      await cdp('Input.dispatchKeyEvent', { type: 'rawKeyDown', key, code: key, windowsVirtualKeyCode: code, modifiers });
      await cdp('Input.dispatchKeyEvent', { type: 'keyUp', key, code: key, windowsVirtualKeyCode: code, modifiers });
    };
    const focusIndex = (g) => ev(`(function(){var c=document.querySelectorAll('[data-theme-control]')[${g}];return [].indexOf.call(c.querySelectorAll('[data-set-theme]'),document.activeElement);})()`);
    const n = await ev(`document.querySelectorAll('[data-theme-control]').length`);
    check(n > 0, L(`[data-theme-control] がある（${n} 個）`));
    for (let g = 0; g < n; g++) {
      const len = await ev(`document.querySelectorAll('[data-theme-control]')[${g}].querySelectorAll('[data-set-theme]').length`);
      await ev(`(function(){var b=document.querySelectorAll('[data-theme-control]')[${g}].querySelector('[data-set-theme]');b.scrollIntoView({block:'center'});b.focus();})()`);
      let i = await focusIndex(g);
      if (i !== 0) { ng(L(`コントロール ${g + 1}: 先頭のボタンにフォーカスできない`)); continue; }
      const steps = [['ArrowRight', 1 % len], ['ArrowLeft', 0], ['ArrowLeft', len - 1], ['ArrowRight', 0], ['End', len - 1], ['Home', 0], ['ArrowDown', 1 % len], ['ArrowUp', 0]];
      const bad = [];
      for (const [k, want] of steps) {
        await press(k);
        const got = await focusIndex(g);
        if (got !== want) bad.push(`${k}: ${want} のはずが ${got}`);
      }
      check(bad.length === 0, L(`コントロール ${g + 1}（${len} ボタン）: ←→↑↓・Home・End でフォーカスが動く（端は反対側へ回る）`), bad.join(' / '));
      // 修飾キー付き（Alt=1・Ctrl=2・Meta=4・Shift=8）は、ブラウザや OS の操作（Alt+← の戻るなど）を奪わず、フォーカスも動かさない
      await ev(`(function(){var b=document.querySelectorAll('[data-theme-control]')[${g}].querySelector('[data-set-theme]');b.focus();})()`);
      const moved = [];
      for (const [name, m] of [['Alt', 1], ['Ctrl', 2], ['Meta', 4], ['Shift', 8]]) {
        await press('ArrowRight', m);
        const got = await focusIndex(g);
        if (got !== 0) moved.push(`${name}+→ でフォーカスが ${got} へ動いた`);
      }
      check(moved.length === 0, L(`コントロール ${g + 1}: 修飾キー（Alt・Ctrl・Meta・Shift）付きの矢印キーではフォーカスを動かさない`), moved.join(' / '));
    }
    const ks = await state();
    check(ks.mode === 'system' && ks.ls === null, L('矢印キー・Home・End ではモードを変えない（選択は Space / Enter / クリックだけ）'), `mode=${ks.mode} ls=${ks.ls}`);
  }
  await cdp('Page.close').catch(() => {});
  ws.close();
}

try {
  await main();
} catch (e) {
  ng(`検査を最後まで実行できない: ${e.message}`);
} finally {
  cleanup();
}
console.log(`PASS ${pass} / FAIL ${fail}`);
process.exit(fail ? 1 : 0);
NODE
