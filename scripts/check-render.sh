#!/usr/bin/env bash
# check-render.sh — Issue #54: 見本の寸法・描画を headless Chrome で測る回帰チェック。
# grep では見えない「描画された結果」（スイッチ 36×20・チェック 18 の円・スライダーの枠・スピナー・
# ピル・枠 0・スクロールバー 8px・12px 未満の文字・モバイルの入力欄・コントラスト・reduced-motion・
# 横スクロール・リンク先と id の重複）を、Light / Dark × 1280px / 375px で測る。
#
# 依存: Node 22 以上（組み込みの WebSocket を使う。npm パッケージは不要）と Chrome / Chromium。
#   Chrome の場所: 環境変数 CHROME、なければ google-chrome / google-chrome-stable / chromium / chromium-browser。
#   Node か Chrome が無いときは「SKIP」と表示して exit 0（回帰として測れなかったことを明示する）。
# 使い方: scripts/check-render.sh [リポジトリルート]   例: CHROME=/usr/bin/chromium scripts/check-render.sh
# 外部のフォント・画像は読まない（http(s) を遮断）ので、オフラインでも同じ結果になる。
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"

skip() { printf 'SKIP  check-render: %s（描画の検査は実行していない）\n' "$1"; exit 0; }

command -v node >/dev/null 2>&1 || skip 'node が見つからない'
node -e 'process.exit(typeof WebSocket === "function" && typeof fetch === "function" ? 0 : 1)' 2>/dev/null \
  || skip "node $(node -v) には WebSocket がない（Node 22 以上が必要）"

chrome="${CHROME:-}"
if [ -z "$chrome" ]; then
  for c in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1; then chrome="$(command -v "$c")"; break; fi
  done
fi
[ -n "$chrome" ] && [ -x "$chrome" ] || skip 'Chrome / Chromium が見つからない（CHROME= で指定できる）'
[ -f "$root/tokens-preview.html" ] && [ -f "$root/index.html" ] || { printf 'FAIL  %s に index.html / tokens-preview.html がない\n' "$root"; exit 1; }

exec node - "$root" "$chrome" <<'JS'
'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');

const [root, chrome] = process.argv.slice(2);
let pass = 0, fail = 0;
const t = (name, ok, detail = '') => {
  ok ? pass++ : fail++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  [' + detail + ']' : ''}`);
};

// ---- Chrome を CDP で操作する（自分で起動した 1 プロセスだけを止める） ----
async function launch() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'check-render-'));
  const proc = spawn(chrome, [
    '--headless=new', '--no-sandbox', '--disable-gpu', '--disable-extensions', '--no-first-run',
    '--remote-debugging-port=0', '--user-data-dir=' + dir, 'about:blank',
  ], { stdio: 'ignore' });
  let exited = false;
  proc.once('exit', () => { exited = true; });
  const stop = async () => {
    if (!exited) { proc.kill(); await new Promise(r => proc.once('exit', r)); }
    try { fs.rmSync(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 }); } catch { /* 一時ディレクトリが残るだけ */ }
  };
  try {
    let port = '';
    for (let i = 0; i < 150 && !port; i++) {
      if (exited) throw new Error('Chrome が起動直後に終了した');
      try { port = fs.readFileSync(path.join(dir, 'DevToolsActivePort'), 'utf8').split('\n')[0]; } catch { /* まだ */ }
      if (!port) await new Promise(r => setTimeout(r, 100));
    }
    if (!port) throw new Error('Chrome のデバッグポートが開かない');
    const ver = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
    const ws = new WebSocket(ver.webSocketDebuggerUrl);
    await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('CDP に接続できない')); });
    let id = 0; const pend = new Map();
    ws.onmessage = m => {
      const d = JSON.parse(m.data);
      if (d.id && pend.has(d.id)) { const [res, rej] = pend.get(d.id); pend.delete(d.id); d.error ? rej(new Error(d.error.message)) : res(d.result); }
    };
    const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
      pend.set(++id, [res, rej]); ws.send(JSON.stringify({ id, method, params, sessionId }));
    });
    return { send, stop };
  } catch (e) { await stop(); throw e; }
}

// ---- 1 つの構成（ページ × 幅 × テーマ × reduced-motion）を開く ----
async function open(browser, file, width, theme, reduced) {
  const { targetId } = await browser.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await browser.send('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => browser.send(m, p, sessionId);
  await s('Page.enable');
  await s('Network.enable');
  await s('Network.setBlockedURLs', { urls: ['http://*', 'https://*'] }); // 外部フォントで待たされない・結果が変わらない
  await s('Emulation.setDeviceMetricsOverride', { width, height: 900, deviceScaleFactor: 1, mobile: width < 700 });
  await s('Emulation.setEmulatedMedia', { features: [
    { name: 'prefers-color-scheme', value: theme },
    { name: 'prefers-reduced-motion', value: reduced ? 'reduce' : 'no-preference' },
  ] });
  await s('Page.navigate', { url: 'file://' + path.join(root, file) });
  const ev = async (expression) => {
    const r = await s('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(`${file}: ${r.exceptionDetails.exception?.description || r.exceptionDetails.text}`);
    return r.result.value;
  };
  for (let i = 0; i < 200 && (await ev('document.readyState')) !== 'complete'; i++) await new Promise(r => setTimeout(r, 100));
  await ev('Promise.race([document.fonts.ready, new Promise(r => setTimeout(r, 3000))]).then(() => 1)');
  await new Promise(r => setTimeout(r, 300));
  return { s, ev, close: () => browser.send('Target.closeTarget', { targetId }) };
}

// ---- ページ内で測る関数（文字列として渡す） ----
const PAGE_LIB = String.raw`
const rendered = e => { const r = e.getBoundingClientRect(), c = getComputedStyle(e); return c.visibility !== 'hidden' && c.display !== 'none' && r.width > 1 && r.height > 1; };
const sel = e => e.tagName.toLowerCase() + (e.id ? '#' + e.id : '') + (typeof e.className === 'string' && e.className.trim() ? '.' + e.className.trim().split(/\s+/).join('.') : '');
const lin = c => { c /= 255; return c <= .03928 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4; };
const lum = ([r, g, b]) => .2126 * lin(r) + .7152 * lin(g) + .0722 * lin(b);
const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + .05) / (Math.min(x, y) + .05); };
const rgb = s => { const n = s.match(/-?\d*\.?\d+(?:e-?\d+)?/g).slice(0, 3).map(Number); return s.startsWith('color(') ? n.map(v => v * 255) : n; };
const colorOf = (prop, value) => { const e = document.createElement('i'); e.style[prop] = value; document.body.appendChild(e); const v = getComputedStyle(e)[prop]; e.remove(); return rgb(v); };
`;

// 全ページ共通の測定
const MEASURE_COMMON = `(() => { ${PAGE_LIB}
  const out = {};
  // 12px 未満の文字。.bcnt（通知バッジ数・11px）だけは意図した例外としてスケール外のまま残す。
  const EXEMPT = '.bcnt';
  const small = {}; let exempt = 0;
  const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  for (let n; (n = w.nextNode());) {
    if (!n.nodeValue.trim()) continue;
    const e = n.parentElement;
    if (!e || ['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE'].includes(e.tagName) || !rendered(e)) continue;
    const fs = parseFloat(getComputedStyle(e).fontSize);
    if (fs >= 12) continue;
    if (e.closest(EXEMPT)) { exempt++; continue; }
    const k = sel(e) + ' ' + fs + 'px (#' + (e.closest('section[id]')?.id || '') + ')'; small[k] = (small[k] || 0) + 1;
  }
  out.small = Object.keys(small); out.exempt = exempt;
  // 入力欄（文字入力系）の font-size。モバイルでは 16px 以上（iOS の自動ズームを避ける）
  out.inputs = [...document.querySelectorAll('input,select,textarea')]
    .filter(e => !['checkbox', 'radio', 'range', 'hidden', 'button', 'submit', 'reset', 'file', 'color', 'image'].includes(e.type) && rendered(e))
    .map(e => ({ s: sel(e), fs: parseFloat(getComputedStyle(e).fontSize) }));
  // ページ全体の横スクロール。span 要素ごとの犯人も出す。
  const vw = document.documentElement.clientWidth;
  out.scrollW = document.documentElement.scrollWidth; out.clientW = vw;
  out.over = [];
  for (const e of document.body.querySelectorAll('*')) {
    const c = getComputedStyle(e); if (c.display === 'none' || c.position === 'fixed') continue;
    const r = e.getBoundingClientRect(); if (!r.width && !r.height) continue;
    let p = e.parentElement, clipped = false;
    while (p && p !== document.body) { const pc = getComputedStyle(p); if (pc.overflowX !== 'visible' || pc.position === 'fixed') { clipped = true; break; } p = p.parentElement; }
    if (!clipped && r.right > vw + 1) out.over.push({ s: sel(e) + ' ' + Math.round(r.left) + '-' + Math.round(r.right) + ' (#' + (e.closest('section[id]')?.id || '') + ')', known6: e.tagName === 'INPUT' && !!e.closest('.sw2') });
  }
  // リンク先と id
  const ids = {}; document.querySelectorAll('[id]').forEach(e => { ids[e.id] = (ids[e.id] || 0) + 1; });
  out.ids = Object.keys(ids);
  out.dups = Object.entries(ids).filter(([, n]) => n > 1).map(([k, n]) => k + '×' + n);
  out.hrefs = [...document.querySelectorAll('a[href]')].map(a => a.getAttribute('href')).filter(h => h.includes('#') && !/^(https?:|mailto:)/.test(h));
  out.theme = document.documentElement.getAttribute('data-theme');
  return out;
})()`;

// reduced-motion で 100ms を超える transition / animation が残っていないか
const MEASURE_MOTION = `(() => { ${PAGE_LIB}
  const ms = v => v.split(',').map(x => x.trim()).map(x => x.endsWith('ms') ? parseFloat(x) : parseFloat(x) * 1000);
  const bad = [];
  for (const e of document.querySelectorAll('*')) for (const ps of [null, '::before', '::after']) {
    const c = getComputedStyle(e, ps);
    const props = c.transitionProperty.split(',').map(x => x.trim()), td = ms(c.transitionDuration);
    const tl = td.some((d, i) => d > 100 && props[i % props.length] !== 'none');
    const names = c.animationName.split(',').map(x => x.trim()), ad = ms(c.animationDuration);
    const al = ad.some((d, i) => d > 100 && names[i % names.length] !== 'none');
    if (tl || al) bad.push(sel(e) + (ps || '') + (tl ? ' transition ' + c.transitionDuration : '') + (al ? ' animation ' + c.animationName + ' ' + c.animationDuration : ''));
  }
  return { bad, n: document.querySelectorAll('*').length };
})()`;

// tokens-preview.html の見本
const MEASURE_TOKENS = `(() => { ${PAGE_LIB}
  const out = {}; const cs = (e, p) => getComputedStyle(e, p);
  const px = v => parseFloat(v);
  // スイッチ 36×20・つまみ 14
  out.switches = [...document.querySelectorAll('.sw2 span')].map(e => ({ s: sel(e.parentElement) + '>span', w: e.offsetWidth, h: e.offsetHeight, r: px(cs(e).borderTopLeftRadius), tw: px(cs(e, '::after').width), th: px(cs(e, '::after').height) }));
  // チェック・ラジオ 18×18（ラジオは円）。スイッチの隠し input（opacity 0・絶対配置）は除く
  out.checks = [...document.querySelectorAll('input[type=checkbox],input[type=radio]')]
    .filter(e => !e.closest('.sw2') && rendered(e) && cs(e).position !== 'absolute')
    .map(e => ({ s: sel(e) + ' (#' + (e.closest('section[id]')?.id || '') + ')', type: e.type, w: e.offsetWidth, h: e.offsetHeight, r: px(cs(e).borderTopLeftRadius) }));
  // スピナー 20px・線 2px・0.9s linear。#motion のデモは flex で縮む（#54 の検査で見つけた別件。下の注）
  out.spins = [...document.querySelectorAll('.spin')].filter(e => rendered(e) && !e.closest('#motion'))
    .map(e => ({ s: sel(e) + ' (#' + (e.closest('section[id]')?.id || '') + ')', w: e.offsetWidth, h: e.offsetHeight, bw: cs(e).borderTopWidth, dur: cs(e).animationDuration, tf: cs(e).animationTimingFunction, name: cs(e).animationName }));
  // ピル（角が高さの半分以上）: ボタン・チップ・選択ナビ
  const pillSel = '.btn, .abtn, .pill, .au-chip, .au-nav a';
  out.pills = [...document.querySelectorAll(pillSel)].filter(rendered)
    .map(e => ({ s: sel(e), r: px(cs(e).borderTopLeftRadius), h: e.offsetHeight }));
  // カード・表・バナー: 枠 0・角 16
  const flat = ['#app-ui .au-cards .card', '#app-ui .au-tcard', '#app-ui .au-banner'];
  out.flat = flat.map(q => { const e = document.querySelector(q); if (!e) return { s: q, missing: true };
    return { s: q, bw: ['Top', 'Right', 'Bottom', 'Left'].map(k => cs(e)['border' + k + 'Width']).join(' '), r: cs(e).borderRadius }; });
  out.navBorder = (() => { const e = document.querySelector('#app-ui .au-nav a'); return e ? ['Top', 'Right', 'Bottom', 'Left'].map(k => cs(e)['border' + k + 'Width']).join(' ') : 'missing'; })();
  // スクロールバーの見本（8px）。擬似要素の幅は offset と client の差で測る
  out.sb = ['sb-vertical', 'sb-horizontal', 'sb-both'].map(id => { const e = document.getElementById(id);
    return e ? { id, v: e.offsetWidth - e.clientWidth, h: e.offsetHeight - e.clientHeight, sw: e.scrollWidth > e.clientWidth, sh: e.scrollHeight > e.clientHeight } : { id, missing: true }; });
  // コントラスト（--mute / --mute-on-soft を --surface-sel / --accent-soft の上に置く）
  const bg = n => colorOf('backgroundColor', 'var(' + n + ')'), fg = n => colorOf('color', 'var(' + n + ')');
  out.contrast = {};
  for (const f of ['--mute', '--mute-on-soft', '--ink']) for (const b of ['--bone', '--surface', '--surface-sel', '--accent-soft'])
    out.contrast[f + ' on ' + b] = Math.round(ratio(fg(f), bg(b)) * 100) / 100;
  // スライダーの入力欄そのもの（つまみとトラックは CDP で別に測る）
  const r = document.querySelector('.rng');
  out.rng = r ? { bw: cs(r).borderTopWidth, ow: cs(r).outlineStyle, sh: cs(r).boxShadow, bg: cs(r).backgroundColor, appearance: cs(r).appearance } : null;
  return out;
})()`;

// スライダーのつまみ・トラックは UA の shadow DOM にあり、computed style が取れない。
// DOM.getNodeForLocation（座標はページ左上基準）で当てて、border box と枠線の幅を測る。
async function measureSlider(page) {
  const { s, ev } = page;
  const info = await ev(`(() => { const r = document.querySelector('.rng'); if (!r) return null; r.scrollIntoView({ block: 'center' });
    const b = r.getBoundingClientRect(); return { x: b.x + scrollX, y: b.y + scrollY, w: b.width, h: b.height, v: (r.value - r.min) / (r.max - r.min) }; })()`);
  if (!info) return null;
  await s('DOM.enable'); await s('CSS.enable'); await s('DOM.getDocument', { depth: 0 });
  const out = {};
  for (const [part, x] of [['thumb', info.x + 8 + (info.w - 16) * info.v], ['track', info.x + info.w - 6]]) {
    for (let dy = 0; dy <= info.h && !out[part]; dy++) {
      let n; try { n = await s('DOM.getNodeForLocation', { x: Math.round(x), y: Math.round(info.y + dy), includeUserAgentShadowDOM: true }); } catch { continue; }
      const d = await s('DOM.describeNode', { backendNodeId: n.backendNodeId });
      const a = d.node.attributes || []; const i = a.indexOf('id');
      if (i < 0 || a[i + 1] !== part) continue;
      const bm = (await s('DOM.getBoxModel', { backendNodeId: n.backendNodeId })).model.border;
      const style = Object.fromEntries((await s('CSS.getComputedStyleForNode', { nodeId: n.nodeId })).computedStyle.map(p => [p.name, p.value]));
      out[part] = { w: Math.round((bm[2] - bm[0]) * 100) / 100, h: Math.round((bm[5] - bm[1]) * 100) / 100, bw: style['border-top-width'] };
    }
  }
  return out;
}

const hasPill = x => x.r >= x.h / 2 - 0.5;
const all = (arr, f) => arr.length > 0 && arr.every(f);
const list = (arr, f, n = 4) => arr.filter(x => !f(x)).slice(0, n).map(({ s, ...rest }) => s + ' ' + JSON.stringify(rest)).join(' | ');

(async () => {
  let browser;
  try { browser = await launch(); } catch (e) { console.log(`FAIL  Chrome を起動できない: ${e.message}`); process.exit(1); }
  const idsByPage = {}, hrefsByPage = {};
  try {
    for (const file of ['tokens-preview.html', 'index.html']) {
      for (const width of [1280, 375]) for (const theme of ['light', 'dark']) {
        const tag = `${file} ${width}/${theme}`;
        const page = await open(browser, file, width, theme, false);
        try {
          const c = await page.ev(MEASURE_COMMON);
          t(`${tag}: テーマが ${theme} で描画されている`, c.theme === theme, `data-theme=${c.theme}`);
          t(`${tag}: 文字がすべて 12px 以上（例外は .bcnt の 11px のみ）`, c.small.length === 0, c.small.slice(0, 4).join(' | ') || `例外 .bcnt の文字 ${c.exempt} 件`);
          if (width === 375) {
            t(`${tag}: 文字入力欄が 16px 以上`, all(c.inputs, x => x.fs >= 16) || c.inputs.length === 0, c.inputs.filter(x => x.fs < 16).slice(0, 4).map(x => x.s + ' ' + x.fs + 'px').join(' | ') || `${c.inputs.length} 個`);
          }
          // #6: スイッチ見本の隠し input が絶対配置で幅 100% のため、ページが横に伸びる（別件・未修正）。
          // 他の原因でのはみ出しを見逃さないよう、この 1 要素だけを除いて測る。#6 が直ったらこの除外を消す。
          const others = c.over.filter(e => !e.known6).map(e => e.s);
          t(`${tag}: ページ全体に横スクロールがない（#6 のスイッチ見本の隠し input を除く）`, others.length === 0, others.slice(0, 3).join(' | ') || `scrollWidth ${c.scrollW} / clientWidth ${c.clientW}、#6 分 ${c.over.length - others.length} 件を除外`);
          if (width === 1280 && theme === 'light') { idsByPage[file] = new Set(c.ids); hrefsByPage[file] = c.hrefs; t(`${tag}: id が重複していない`, c.dups.length === 0, c.dups.slice(0, 5).join(' ')); }
          if (file === 'tokens-preview.html') {
            const m = await page.ev(MEASURE_TOKENS);
            t(`${tag}: スイッチ 36×20・つまみ 14・角丸 full`, all(m.switches, x => x.w === 36 && x.h === 20 && x.r >= 10 && x.tw === 14 && x.th === 14), list(m.switches, x => x.w === 36 && x.h === 20 && x.r >= 10 && x.tw === 14 && x.th === 14) || `${m.switches.length} 個`);
            const cb = m.checks.filter(x => x.type === 'checkbox'), rd = m.checks.filter(x => x.type === 'radio');
            t(`${tag}: チェックボックス 18×18（円ではない）`, all(cb, x => x.w === 18 && x.h === 18 && x.r < 9), list(cb, x => x.w === 18 && x.h === 18 && x.r < 9) || `${cb.length} 個`);
            t(`${tag}: ラジオ 18×18 の円`, all(rd, x => x.w === 18 && x.h === 18 && x.r >= 9), list(rd, x => x.w === 18 && x.h === 18 && x.r >= 9) || `${rd.length} 個`);
            const sp = x => x.w === 20 && x.h === 20 && x.bw === '2px' && x.dur === '0.9s' && x.tf === 'linear' && x.name !== 'none';
            t(`${tag}: スピナー 20px・線 2px・0.9s linear（#motion のデモを除く）`, all(m.spins, sp), list(m.spins, sp) || `${m.spins.length} 個`);
            t(`${tag}: ボタン・チップ・選択ナビがピル`, all(m.pills, hasPill), list(m.pills, hasPill) || `${m.pills.length} 個`);
            t(`${tag}: カード・表・バナーの枠 0・角 16、選択ナビの枠 0`, m.flat.every(x => !x.missing && x.bw === '0px 0px 0px 0px' && x.r === '16px') && m.navBorder === '0px 0px 0px 0px', m.flat.map(x => x.missing ? x.s + ' なし' : x.bw + ' ' + x.r).join(' / ') + ' / nav ' + m.navBorder);
            const slider = await measureSlider(page);
            const rg = m.rng;
            const sliderOk = !!(slider && slider.track && slider.thumb && rg
              && slider.track.h === 4 && slider.track.bw === '0px' && slider.thumb.w === 16 && slider.thumb.h === 16
              && rg.bw === '0px' && rg.ow === 'none' && rg.sh === 'none' && rg.bg === 'rgba(0, 0, 0, 0)');
            t(`${tag}: スライダー トラック 4・つまみ 16・入力欄に枠なし`, sliderOk, JSON.stringify({ slider, rg }));
            const ct = m.contrast;
            const need = ['--mute-on-soft on --accent-soft', '--mute-on-soft on --surface-sel', '--mute on --bone', '--mute on --surface', '--ink on --accent-soft', '--ink on --surface-sel'];
            t(`${tag}: --mute-on-soft / --mute / --ink のコントラストが 4.5:1 以上（--mute-on-soft は accent-soft・surface-sel 上、--mute は bone・surface 上。--mute を soft 地に置かない規定どおり）`, need.every(k => ct[k] >= 4.5), need.map(k => k.replace(/--/g, '') + ' ' + ct[k]).join(' | '));
            if (width === 1280) {
              const sb = m.sb;
              const sbOk = sb.every(x => !x.missing) && sb[0].sh && sb[0].v === 8 && sb[1].sw && sb[1].h === 8 && sb[2].sh && sb[2].sw && sb[2].v === 8 && sb[2].h === 8;
              t(`${tag}: スクロールバー見本の幅 8px（縦・横・両方向）`, sbOk, sb.map(x => x.missing ? x.id + ' なし' : `${x.id} 縦${x.v} 横${x.h}${x.sh || x.sw ? '' : '（溢れていない）'}`).join(' / '));
            }
          }
        } finally { await page.close(); }
      }
      // reduced-motion（1280 の Light / Dark）
      for (const theme of ['light', 'dark']) {
        const page = await open(browser, file, 1280, theme, true);
        try {
          const r = await page.ev(MEASURE_MOTION);
          t(`${file} 1280/${theme}: reduced-motion で 100ms を超える transition / animation がない`, r.bad.length === 0, r.bad.slice(0, 4).join(' | ') || `${r.n} 要素を確認`);
        } finally { await page.close(); }
      }
    }
    // ページ内リンク（#…）と、2 ページ間リンク（index.html#… / tokens-preview.html#…）の行き先
    for (const file of Object.keys(hrefsByPage)) {
      const other = file === 'index.html' ? 'tokens-preview.html' : 'index.html';
      const bad = [];
      for (const h of hrefsByPage[file]) {
        const [p, frag] = h.split('#'); if (!frag) continue;
        const target = p === '' || p === file ? file : p === other ? other : null;
        if (target && !idsByPage[target].has(decodeURIComponent(frag))) bad.push(h);
      }
      t(`${file}: href の #… がすべて実在する id を指す`, bad.length === 0, bad.slice(0, 5).join(' ') || `${hrefsByPage[file].length} 本`);
    }
  } catch (e) {
    t('描画の検査が最後まで走った', false, e.message);
  } finally { await browser.stop(); }
  console.log(`PASS ${pass} / FAIL ${fail}`);
  process.exit(fail ? 1 : 0);
})();
JS
