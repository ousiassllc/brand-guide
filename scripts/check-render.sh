#!/usr/bin/env bash
# check-render.sh — Issue #54: 見本の寸法・描画を headless Chrome で測る回帰チェック。
# grep では見えない「描画された結果」（スイッチ 36×20・チェック 18 の円・スライダーの枠・スピナー・
# ピル・枠 0・スクロールバー 8px・12px 未満の文字・モバイルの入力欄・コントラスト・reduced-motion・
# 横スクロール・リンク先と id の重複）を、Light / Dark × 1280px / 375px で測る。
# あわせて、Tab 巡回のフォーカスリング（実際のキー操作で止まる要素の幅・色・offset）、#toast の a11y ツリーと本文の出し入れ、
# index.html の可視テキストのウェイト・サイズの全走査、一部選択（indeterminate）の描画を測る。
# 狭い幅（360px・320px）での文字付き .seg のカードからのはみ出しと、forced-colors での描画も測る。
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

const [rootArg, chrome] = process.argv.slice(2);
const root = path.resolve(rootArg); // 相対パスでも file:// が壊れないように絶対パスへ
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
  ], { stdio: 'ignore', detached: true }); // detached: Chrome をプロセスグループのリーダーにし、子（zygote・renderer・GPU）ごと落とせるようにする
  let exited = false;
  proc.once('exit', () => { exited = true; });
  // 後始末（Chrome の kill と一時プロファイルの削除）は 1 回だけ走る同期関数。通常終了の stop() のほか、
  // exit・SIGINT・SIGTERM（Ctrl-C や timeout）からも呼ぶ。finally だけでは中断時に走らない
  // 本体だけ落とすと子が一時プロファイルを書き戻して check-render-* が残る（#77）ので、グループ全体へ SIGKILL を送る
  const killGroup = () => { try { process.kill(-proc.pid, 'SIGKILL'); } catch { /* すでに終了している */ } };
  let cleaned = false;
  const cleanup = () => {
    if (cleaned) return; cleaned = true;
    killGroup();
    try { fs.rmSync(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 }); } catch { /* 一時ディレクトリが残るだけ */ }
  };
  process.on('exit', cleanup);
  for (const s of ['SIGINT', 'SIGTERM']) process.on(s, () => { cleanup(); process.exit(130); });
  const stop = async () => {
    if (!exited) {
      killGroup();
      await Promise.race([new Promise(r => proc.once('exit', r)), new Promise(r => setTimeout(r, 3000))]); // 終了待ちには上限を付ける
    }
    cleanup();
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
    if (!clipped && r.right > vw + 1) out.over.push({ s: sel(e) + ' ' + Math.round(r.left) + '-' + Math.round(r.right) + ' (#' + (e.closest('section[id]')?.id || '') + ')' });
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

// 文字付き .seg（約 298px 幅）がカードの外へはみ出さないか。.seg とカードの間に overflow-x の祖先（.scr）があれば、その箱の右端で測る。
const MEASURE_SEG = `(() => { ${PAGE_LIB}
  const bad = []; let n = 0;
  for (const e of document.querySelectorAll('.seg')) {
    const card = e.closest('.card'); if (!card || !rendered(e)) continue;
    n++;
    let clip = null;
    for (let p = e.parentElement; p && p !== card; p = p.parentElement) if (getComputedStyle(p).overflowX !== 'visible') { clip = p; break; }
    const right = (clip || e).getBoundingClientRect().right, cardRight = card.getBoundingClientRect().right;
    if (right > cardRight + 1) bad.push(sel(e) + ' 右端 ' + Math.round(right) + ' > カード ' + Math.round(cardRight) + ' (#' + (e.closest('section[id]')?.id || '') + ')');
  }
  return { bad, n };
})()`;

// データテーブルの「すべて選択」（#p2-check-all）を、未選択・一部選択（行を 1 つ選ぶ）・全選択の 3 状態で測る。測ったあとは未選択に戻す。
const MEASURE_INDET = `(() => { ${PAGE_LIB}
  const all = document.getElementById('p2-check-all'), row = document.querySelector('#p2-atable .p2-row');
  if (!all || !row) return null;
  const snap = () => { const c = getComputedStyle(all), a = getComputedStyle(all, '::after');
    return { ind: all.indeterminate, checked: all.checked, bg: c.backgroundColor, bd: c.borderTopColor, aw: a.width, ah: a.height, abg: a.backgroundColor }; };
  const none = snap();
  row.click(); const part = snap(); row.click();
  all.click(); const full = snap(); all.click();
  const css = v => 'rgb(' + colorOf('backgroundColor', v).join(', ') + ')';
  return { none, part, all: full, accent: css('var(--accent)'), bone: css('var(--bone)') };
})()`;

// index.html の文字サイズ・ウェイト（#65・#66）。可視テキストの親要素の font-size / font-weight が、規定の集合だけであること。
// サイズ: スケール 12 / 14 / 16 / 18 / 24 / 32 / 40 と、見本の 13・15、見出し h2 の 28、h1 の clamp（375px で 32・1280px で 56）。ウェイト: 300 / 400 / 600（700 は tokens-preview の .au-title だけ）。
const MEASURE_INDEX = `(() => { ${PAGE_LIB}
  const SIZES = [12, 13, 14, 15, 16, 18, 24, 28, 32, 40, 56], WEIGHTS = [300, 400, 600];
  const badSize = {}, badWeight = {};
  const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  for (let n; (n = w.nextNode());) {
    if (!n.nodeValue.trim()) continue;
    const e = n.parentElement;
    if (!e || ['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE'].includes(e.tagName) || !rendered(e)) continue;
    const c = getComputedStyle(e), fs = parseFloat(c.fontSize), fw = Number(c.fontWeight), at = ' (#' + (e.closest('section[id]')?.id || '') + ')';
    if (!SIZES.includes(fs)) { const k = sel(e) + ' ' + fs + 'px' + at; badSize[k] = (badSize[k] || 0) + 1; }
    if (!WEIGHTS.includes(fw)) { const k = sel(e) + ' ' + fw + at; badWeight[k] = (badWeight[k] || 0) + 1; }
  }
  return { badSize: Object.keys(badSize), badWeight: Object.keys(badWeight) };
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
  // スピナー 20px・線 2px・0.9s linear。#motion のデモも含む（flex で縮まないよう .spin に flex:none が要る。#60）
  out.spins = [...document.querySelectorAll('.spin')].filter(rendered)
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
  // 見本のラベル・ナビ・表は規定の Regular(400)。body の Light(300) をそのまま受けると、見本を写した製品が Light になる（#61）。ドロワーの項目は閉じていても computed を測る
  out.weights = ['.sw2', '.chk', '#p0 .mnav-panel a', '#p0 .bc a', '#states td', '#p2 .atable td'].map(q => { const es = [...document.querySelectorAll(q)];
    return { q, n: es.length, bad: es.filter(e => cs(e).fontWeight !== '400').slice(0, 3).map(sel) }; });
  // 可視テキストのウェイトは 300・400・600 のどれか。700 は .au-title / .au-t1（アプリのページタイトル 28px とその書体見本）だけ。900 や既定の bold(700) を残さない（#66）
  out.wts = (() => { const bad = {}; const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let n; (n = w.nextNode());) {
      if (!n.nodeValue.trim()) continue;
      const e = n.parentElement; if (!e || ['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE'].includes(e.tagName) || !rendered(e)) continue;
      const fw = cs(e).fontWeight; if (['300', '400', '600'].includes(fw) || (fw === '700' && e.closest('.au-title, .au-t1'))) continue;
      const k = sel(e) + ' ' + fw + ' (#' + (e.closest('section[id]')?.id || '') + ')'; bad[k] = 1;
    }
    return Object.keys(bad); })();
  // 可視テキストの font-size は規定のサイズスケール（12 / 14 / 16 / 18 / 24 / 32 / 40）と、ガイドが使う 13・15・28・56（h1 の clamp）だけ。h3 などのブラウザ既定（18.72px）を残さない（#65）。.bcnt（通知バッジ数 11px）だけ例外
  out.sizes = (() => { const OK = [12, 13, 14, 15, 16, 18, 24, 28, 32, 40], bad = {}; const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (let n; (n = w.nextNode());) {
      if (!n.nodeValue.trim()) continue;
      const e = n.parentElement; if (!e || ['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE'].includes(e.tagName) || !rendered(e) || e.closest('.bcnt')) continue;
      const fs = px(cs(e).fontSize); if (OK.includes(fs) || (e.tagName === 'H1' && fs >= 32 && fs <= 56)) continue;
      const k = sel(e) + ' ' + fs + 'px (#' + (e.closest('section[id]')?.id || '') + ')'; bad[k] = 1;
    }
    return Object.keys(bad); })();
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

// Tab で巡回して止まる要素のフォーカスリング（#64）。実際のキー操作（:focus-visible が付く）で最大 400 回進め、outline が --focus の実線・offset 2px で、幅は要素の種類で決まること（離散コントロール＝button・checkbox・radio・range は 3px、リンク・pre など既定は 2px）。
async function measureFocusRings(page, allow = '', max = 400, only = '') {
  const { s, ev } = page;
  const focus = await ev(`(() => { const e = document.createElement('i'); e.style.color = 'var(--focus)'; document.body.appendChild(e); const v = getComputedStyle(e).color; e.remove(); return v; })()`);
  await ev('document.activeElement && document.activeElement.blur(); window.scrollTo(0, 0); 1');
  const bad = {}; let stops = 0, first = null;
  for (let i = 0; i < max; i++) {
    await s('Input.dispatchKeyEvent', { type: 'rawKeyDown', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
    await s('Input.dispatchKeyEvent', { type: 'keyUp', key: 'Tab', code: 'Tab', windowsVirtualKeyCode: 9 });
    const r = await ev(`(() => { const e = document.activeElement; if (!e || e === document.body || e === document.documentElement) return null;
      const c = getComputedStyle(e); return { s: e.tagName.toLowerCase() + (e.id ? '#' + e.id : '') + (typeof e.className === 'string' && e.className.trim() ? '.' + e.className.trim().split(/\\s+/).join('.') : ''), st: c.outlineStyle, w: c.outlineWidth, c: c.outlineColor, off: c.outlineOffset, skip: (${JSON.stringify(only)} !== '' && !e.matches(${JSON.stringify(only)})) || (${JSON.stringify(allow)} !== '' && e.matches(${JSON.stringify(allow)})), want: (e.tagName === 'BUTTON' || (e.tagName === 'INPUT' && ['checkbox', 'radio', 'range'].includes(e.type))) ? '3px' : '2px', key: e.tagName + '|' + e.id + '|' + e.className + '|' + (e.textContent || '').slice(0, 20) }; })()`);
    if (!r) break;
    if (first === null) first = r.key; else if (r.key === first) break; // 1 周した
    stops++;
    if (r.skip) continue; // only 以外の種類と許容リスト（規定が別の幅・offset を持つ要素）
    if (!(r.st === 'solid' && r.w === r.want && r.off === '2px' && r.c === focus)) bad[r.s + ' ' + r.st + ' ' + r.w + '（期待 ' + r.want + '）offset ' + r.off + ' ' + r.c] = 1;
  }
  return { stops, focus, bad: Object.keys(bad) };
}

// #toast が待機中も a11y ツリーに残ること（#69）。ライブリージョンは「ツリーにある要素の本文が変わる」ことで通知される。
// 待機中: role=status・ignored でない・opacity 0・pointer-events none（クリックを塞がない）・本文が空。showToast の後: 本文が入る。hideToast の後: 本文が空に戻る。
async function measureToast(page) {
  const { s, ev } = page;
  await s('DOM.enable'); await s('Accessibility.enable');
  const ax = async () => {
    const { root } = await s('DOM.getDocument', { depth: 0 });
    const { nodeId } = await s('DOM.querySelector', { nodeId: root.nodeId, selector: '#toast' });
    const n = (await s('Accessibility.getPartialAXTree', { nodeId, fetchRelatives: false })).nodes[0];
    return { role: n.role && n.role.value, ignored: !!n.ignored };
  };
  const state = () => ev(`(() => { const e = document.getElementById('toast'), c = getComputedStyle(e), r = e.getBoundingClientRect(), hit = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2);
    return { op: c.opacity, pe: c.pointerEvents, vis: c.visibility, text: e.textContent, hit: !!hit && (hit === e || e.contains(hit)), focusable: e.querySelectorAll('button,a[href],[tabindex]').length }; })()`);
  const until = async (pred) => { let v; for (let i = 0; i < 60; i++) { v = await state(); if (pred(v)) return v; await new Promise(r => setTimeout(r, 50)); } return v; };
  const idle = { ax: await ax(), ...(await state()) };
  await ev(`showToast('テスト'); 1`);
  const shown = { ax: await ax(), ...(await until(v => v.op === '1')) };
  await ev(`hideToast(); 1`);
  const hidden = { ax: await ax(), ...(await until(v => v.text === '' && v.op === '0')) };
  return { idle, shown, hidden };
}

// #79〜#82 ARIA・キーボード到達の測定（ここから 1 つの塊）。
// A11Y_STATIC: aria-hidden の中のフォーカス可能要素・名前の欠け・属性と role の組み合わせ・tabindex のない pre / overflow-x:auto。
// A11Y_SCROLL: 溢れて実際にスクロールする要素が、自身か子でキーボードに届く（axe scrollable-region-focusable）。
const A11Y_LIB = String.raw`
const FOCUSABLE = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[tabindex]';
const isFocusable = e => e.tabIndex >= 0 && !e.disabled && !e.closest('[inert]') && e.getClientRects().length > 0;
`;
const A11Y_STATIC = `(() => { ${PAGE_LIB} ${A11Y_LIB}
  const out = {};
  out.hiddenFocus = [...document.querySelectorAll(FOCUSABLE)].filter(e => e.closest('[aria-hidden=true]') && isFocusable(e)).map(e => sel(e) + ' (#' + (e.closest('section[id]')?.id || '') + ')');
  out.noRoleLabel = [...document.querySelectorAll('div[aria-label],span[aria-label],div[aria-labelledby],span[aria-labelledby]')].filter(e => !e.hasAttribute('role')).map(sel);
  const named = e => { const l = e.getAttribute('aria-labelledby'); return !!(e.getAttribute('aria-label') || '').trim() || (!!l && l.split(/\s+/).some(id => (document.getElementById(id)?.textContent || '').trim())); };
  out.unnamed = [...document.querySelectorAll('[role=progressbar],[role=listbox]')].filter(e => !named(e)).map(sel);
  const SEL_ROLES = ['tab', 'option', 'row', 'gridcell', 'columnheader', 'rowheader', 'treeitem'];
  out.badSelected = [...document.querySelectorAll('[aria-selected]')].filter(e => !SEL_ROLES.includes(e.getAttribute('role') || (e.tagName === 'OPTION' ? 'option' : ''))).map(sel);
  out.badPressed = [...document.querySelectorAll('[aria-pressed]')].filter(e => !(e.tagName === 'BUTTON' || e.getAttribute('role') === 'button')).map(sel);
  out.asideRole = [...document.querySelectorAll('aside[role]')].map(sel);
  out.noTabindex = [...document.querySelectorAll('pre,[style*="overflow-x:auto"]')].filter(e => !e.hasAttribute('tabindex') && !e.querySelector(FOCUSABLE)).map(sel);
  return out;
})()`;
const A11Y_SCROLL = `(() => { ${PAGE_LIB} ${A11Y_LIB}
  const bad = [];
  for (const e of document.body.querySelectorAll('*')) {
    const c = getComputedStyle(e);
    const sx = /auto|scroll/.test(c.overflowX) && e.scrollWidth > e.clientWidth + 1, sy = /auto|scroll/.test(c.overflowY) && e.scrollHeight > e.clientHeight + 1;
    if (!(sx || sy) || !rendered(e)) continue;
    if (isFocusable(e) || [...e.querySelectorAll(FOCUSABLE)].some(isFocusable)) continue;
    bad.push(sel(e) + ' ' + e.scrollWidth + 'x' + e.scrollHeight + ' > ' + e.clientWidth + 'x' + e.clientHeight + ' (#' + (e.closest('section[id]')?.id || '') + ')');
  }
  return { bad };
})()`;
// #p2 .tree の閉じた details の開閉シェブロンを、実際のマウスで押して開くか
async function measureTreeClick(page) {
  const { s, ev } = page;
  const pos = await ev(`(() => { const d = document.querySelector('#p2 .tree details:not([open])'); if (!d) return null;
    d.dataset.probe = '1'; const tw = d.querySelector(':scope > summary .tw'); tw.scrollIntoView({ block: 'center' }); const r = tw.getBoundingClientRect();
    const x = r.x + r.width / 2, y = r.y + r.height / 2, hit = document.elementFromPoint(x, y); return { x, y, hit: !!hit && (hit === tw || tw.contains(hit)) }; })()`);
  if (!pos) return null;
  await s('Input.dispatchMouseEvent', { type: 'mousePressed', x: pos.x, y: pos.y, button: 'left', clickCount: 1 });
  await s('Input.dispatchMouseEvent', { type: 'mouseReleased', x: pos.x, y: pos.y, button: 'left', clickCount: 1 });
  return { ...pos, open: await ev(`document.querySelector('#p2 .tree details[data-probe]').open`) };
}
// ここまで

// #85 / #90: tokens-preview.html のコントラスト。.z-stack の文字が実効 opacity 1 で 4.5:1 以上、ホバー中の行の文字が accent-soft 地で 4.5:1 以上。
// ホバーは CDP の mouseMoved で実際に当てる（:hover が付いたことと、地が accent-soft になったことも確かめる）。
const MEASURE_ZSTACK = `(() => { ${PAGE_LIB}
  const solid = e => { for (let p = e; p; p = p.parentElement) { const b = getComputedStyle(p).backgroundColor; if (!/rgba\\(.*, 0\\)$|transparent/.test(b)) return rgb(b); } return rgb(getComputedStyle(document.body).backgroundColor); };
  const opacity = e => { let o = 1; for (let p = e; p; p = p.parentElement) o *= parseFloat(getComputedStyle(p).opacity); return o; };
  const rows = [...document.querySelectorAll('.z-stack span')].filter(e => e.textContent.trim() && rendered(e));
  return rows.map(e => ({ s: e.textContent.trim(), op: Math.round(opacity(e) * 100) / 100, cr: Math.round(ratio(rgb(getComputedStyle(e).color), solid(e)) * 100) / 100 }));
})()`;
async function measureHoverContrast(page, targets) {
  const { s, ev } = page;
  const out = [];
  for (const { name, sel: q, text } of targets) {
    const pos = await ev(`(() => { const e = document.querySelector(${JSON.stringify(q)}); if (!e) return null; e.scrollIntoView({ block: 'center' }); const r = e.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; })()`);
    if (!pos) { out.push({ name, missing: true }); continue; }
    await s('Input.dispatchMouseEvent', { type: 'mouseMoved', x: pos.x, y: pos.y });
    await new Promise(r => setTimeout(r, 400)); // transition の終わりを待つ
    out.push({ name, ...(await ev(`(() => { ${PAGE_LIB}
      const e = document.querySelector(${JSON.stringify(q)}), t = ${JSON.stringify(text)} ? e.querySelector(${JSON.stringify(text)}) : e;
      const bg = rgb(getComputedStyle(e).backgroundColor), soft = colorOf('backgroundColor', 'var(--accent-soft)');
      return { hover: e.matches(':hover'), onSoft: bg.every((v, i) => Math.abs(v - soft[i]) < 1), cr: Math.round(ratio(rgb(getComputedStyle(t).color), bg) * 100) / 100 };
    })()`)) });
  }
  await s('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 0, y: 0 });
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
          // #6: スイッチ見本の隠し input（絶対配置・幅 100%）も除外せず、scrollWidth が viewport と一致することを測る
          t(`${tag}: ページ全体に横スクロールがない（scrollWidth == viewport。除外なし）`, c.over.length === 0 && c.scrollW === c.clientW, c.over.slice(0, 3).map(e => e.s).join(' | ') || `scrollWidth ${c.scrollW} / clientWidth ${c.clientW}`);
          if (width === 1280 && theme === 'light') { idsByPage[file] = new Set(c.ids); hrefsByPage[file] = c.hrefs; t(`${tag}: id が重複していない`, c.dups.length === 0, c.dups.slice(0, 5).join(' ')); }
          if (file === 'tokens-preview.html') {
            const m = await page.ev(MEASURE_TOKENS);
            t(`${tag}: スイッチ 36×20・つまみ 14・角丸 full`, all(m.switches, x => x.w === 36 && x.h === 20 && x.r >= 10 && x.tw === 14 && x.th === 14), list(m.switches, x => x.w === 36 && x.h === 20 && x.r >= 10 && x.tw === 14 && x.th === 14) || `${m.switches.length} 個`);
            const cb = m.checks.filter(x => x.type === 'checkbox'), rd = m.checks.filter(x => x.type === 'radio');
            t(`${tag}: チェックボックス 18×18（円ではない）`, all(cb, x => x.w === 18 && x.h === 18 && x.r < 9), list(cb, x => x.w === 18 && x.h === 18 && x.r < 9) || `${cb.length} 個`);
            t(`${tag}: ラジオ 18×18 の円`, all(rd, x => x.w === 18 && x.h === 18 && x.r >= 9), list(rd, x => x.w === 18 && x.h === 18 && x.r >= 9) || `${rd.length} 個`);
            const ind = await page.ev(MEASURE_INDET), pt = ind && ind.part;
            t(`${tag}: 一部選択の「すべて選択」が indeterminate で、accent 地・accent 枠・bone の横線 9×2（未選択と区別できる）`, !!pt && pt.ind && !pt.checked && pt.bg === ind.accent && pt.bd === ind.accent && pt.abg === ind.bone && pt.aw === '9px' && pt.ah === '2px' && pt.bg !== ind.none.bg, JSON.stringify(ind));
            const sp = x => x.w === 20 && x.h === 20 && x.bw === '2px' && x.dur === '0.9s' && x.tf === 'linear' && x.name !== 'none';
            t(`${tag}: スピナー 20px・線 2px・0.9s linear`, all(m.spins, sp), list(m.spins, sp) || `${m.spins.length} 個`);
            t(`${tag}: ボタン・チップ・選択ナビがピル`, all(m.pills, hasPill), list(m.pills, hasPill) || `${m.pills.length} 個`);
            t(`${tag}: カード・表・バナーの枠 0・角 16、選択ナビの枠 0`, m.flat.every(x => !x.missing && x.bw === '0px 0px 0px 0px' && x.r === '16px') && m.navBorder === '0px 0px 0px 0px', m.flat.map(x => x.missing ? x.s + ' なし' : x.bw + ' ' + x.r).join(' / ') + ' / nav ' + m.navBorder);
            t(`${tag}: ラベル・ナビ・表のセルが規定の Regular(400)（Light の 300 を受けない）`, m.weights.every(x => x.n > 0 && x.bad.length === 0), m.weights.map(x => x.q + ' ' + x.n + ' 個' + (x.bad.length ? ' 400 でない: ' + x.bad.join(',') : '')).join(' | '));
            t(`${tag}: 可視テキストのウェイトが 300・400・600 のどれか（700 はアプリのページタイトル .au-title / .au-t1 だけ）`, m.wts.length === 0, m.wts.slice(0, 4).join(' | '));
            t(`${tag}: 可視テキストのサイズが許容値 12・13・14・15・16・18・24・28・32・40・56（h1 の clamp）だけ（ブラウザ既定の h3 18.72px を残さない。例外は .bcnt の 11px）`, m.sizes.length === 0, m.sizes.slice(0, 4).join(' | '));
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
          if (file === 'index.html') {
            const m = await page.ev(MEASURE_INDEX);
            t(`${tag}: #65 可視テキストの font-size がスケールと規定の例外だけ（12〜16・18・24・28・32・40・56。18.72px の既定の h3 を残さない）`, m.badSize.length === 0, m.badSize.slice(0, 4).join(' | '));
            t(`${tag}: #66 可視テキストの font-weight が 300・400・600 だけ（700 の既定の th・h3 を残さない）`, m.badWeight.length === 0, m.badWeight.slice(0, 4).join(' | '));
            // #84: 状態色の見本（.st span）は、文字色（状態色）を、地の混色（currentColor の薄い地）の上に置いた実際の見た目で AA 4.5:1 以上
            const st = await page.ev(`(() => { ${PAGE_LIB}
              const rgba = s => { const n = s.match(/-?\\d*\\.?\\d+(?:e-?\\d+)?/g).map(Number), k = s.startsWith('color(') ? 255 : 1; return { c: n.slice(0, 3).map(v => v * k), a: n.length > 3 ? n[3] : 1 }; };
              const under = e => { for (let p = e.parentElement; p; p = p.parentElement) { const b = rgba(getComputedStyle(p).backgroundColor); if (b.a > 0) return b.c; } return rgb(getComputedStyle(document.body).backgroundColor); };
              return [...document.querySelectorAll('.st span')].filter(rendered).map(e => { const cs = getComputedStyle(e), b = rgba(cs.backgroundColor), u = under(e);
                const bg = b.c.map((v, i) => v * b.a + u[i] * (1 - b.a));
                return { s: e.textContent, r: Math.round(ratio(rgb(cs.color), bg) * 100) / 100, fs: parseFloat(cs.fontSize) }; });
            })()`);
            t(`${tag}: #84 状態色の見本（.st span）の文字が地の混色込みで 4.5:1 以上`, st.length === 4 && st.every(x => x.r >= 4.5), st.map(x => x.s + ' ' + x.r).join(' | '));
            if (width === 1280) {
              const fr = await measureFocusRings(page);
              t(`${tag}: #64 Tab で止まるすべての要素のフォーカスリングが --focus の実線・offset 2px で、離散コントロール（button・checkbox・radio・range）は 3px、リンク・pre などは 2px（ブラウザ既定のリングにしない）`, fr.stops >= 100 && fr.bad.length === 0, fr.bad.slice(0, 4).join(' | ') || `${fr.stops} 要素（${fr.focus}）`);
            }
          }
          if (file === 'tokens-preview.html') {
            // #85: z-index 見本（.z-stack）の文字が opacity で薄くならず 4.5:1 以上
            const zs = await page.ev(MEASURE_ZSTACK);
            t(`${tag}: #85 .z-stack の文字がすべて実効 opacity 1・コントラスト 4.5:1 以上（base の行を薄くしない）`, zs.length >= 14 && zs.every(x => x.op === 1 && x.cr >= 4.5), zs.filter(x => !(x.op === 1 && x.cr >= 4.5)).slice(0, 4).map(x => x.s + ' opacity ' + x.op + ' ' + x.cr + ':1').join(' | ') || `${zs.length} 件、最小 ${Math.min(...zs.map(x => x.cr))}:1`);
            if (width === 1280) {
              // #90: accent-soft 地にホバーした行の文字（--mute を載せない）
              const hv = await measureHoverContrast(page, [
                { name: 'カレンダーの前後月の日 .cal button.d.mute', sel: '#p1 .cal button.d.mute', text: '' },
                { name: 'ドロップダウン項目の kbd', sel: '#states .dpn button:not(.hl):not(:disabled)', text: 'kbd' },
              ]);
              t(`${tag}: #90 ホバー中の行（accent-soft 地）の文字が 4.5:1 以上`, hv.every(x => !x.missing && x.hover && x.onSoft && x.cr >= 4.5), hv.map(x => x.missing ? x.name + ' なし' : `${x.name} hover ${x.hover} 地が accent-soft ${x.onSoft} ${x.cr}:1`).join(' | '));
              // #89: Tab 巡回のフォーカスリング。button は 3px。許容リスト: ドロップダウン項目（2px 規定）・tb40 のタブ（offset が別）
              const fr = await measureFocusRings(page, '#states .dpn button, .tb40 button', 1500, 'button');
              t(`${tag}: #89 Tab で止まるすべての button のフォーカスリングが --focus の実線・offset 2px・幅 3px（許容: #states .dpn button・.tb40 button。入力欄・range は対象外）`, fr.stops >= 100 && fr.bad.length === 0, fr.bad.slice(0, 4).join(' | ') || `${fr.stops} 要素（${fr.focus}）`);
            }
          }
          if (width === 1280 && theme === 'light') {
            const tt = await measureToast(page);
            const idleOk = tt.idle.ax.role === 'status' && !tt.idle.ax.ignored && tt.idle.op === '0' && tt.idle.pe === 'none' && tt.idle.vis !== 'hidden' && tt.idle.text === '' && !tt.idle.hit && tt.idle.focusable === 0;
            t(`${tag}: #69 待機中の #toast が a11y ツリーにあり（role=status・ignored でない）、見えず・クリックを塞がず（#35）・読み上げる本文もない`, idleOk, JSON.stringify(tt.idle));
            t(`${tag}: #69 showToast で表示され本文が入り、hideToast の後は本文が空に戻っても a11y ツリーに残る`, tt.shown.op === '1' && tt.shown.text === 'テスト' && !tt.shown.ax.ignored && tt.hidden.text === '' && tt.hidden.op === '0' && tt.hidden.ax.role === 'status' && !tt.hidden.ax.ignored, JSON.stringify({ shown: tt.shown, hidden: tt.hidden }));
          }
        } finally { await page.close(); }
      }
      // #67: 狭い幅（375 / Android の標準 360 / 最小 320）で、文字付き .seg がカードの外へ出ない。はみ出すなら .scr の内側で横スクロールにする
      if (file === 'tokens-preview.html') for (const width of [375, 360, 320]) {
        const tag = `${file} ${width}/light`;
        const page = await open(browser, file, width, 'light', false);
        try {
          const g = await page.ev(MEASURE_SEG);
          t(`${tag}: カード内の .seg の右端がカードの右端を越えない（.scr の内側で横スクロール）`, g.n > 0 && g.bad.length === 0, g.bad.slice(0, 3).join(' | ') || `${g.n} 個`);
          if (width !== 375) { // 375 はこの上の本線で測っている
            const c = await page.ev(MEASURE_COMMON);
            t(`${tag}: ページ全体に横スクロールがない（scrollWidth == viewport。除外なし）`, c.over.length === 0 && c.scrollW === c.clientW, c.over.slice(0, 3).map(e => e.s).join(' | ') || `scrollWidth ${c.scrollW} / clientWidth ${c.clientW}`);
          }
        } finally { await page.close(); }
      }
      // #79〜#82 ARIA・キーボード到達（ここから 1 つの塊）
      for (const width of [1280, 375, 320]) {
        const tag = `${file} ${width}/light`;
        const page = await open(browser, file, width, 'light', false);
        try {
          const sc = await page.ev(A11Y_SCROLL);
          t(`${tag}: #81 溢れてスクロールする要素は、自身か中のフォーカス可能要素でキーボードに届く`, sc.bad.length === 0, sc.bad.slice(0, 4).join(' | '));
          if (width !== 1280) continue;
          const a = await page.ev(A11Y_STATIC);
          t(`${tag}: #79 aria-hidden=true の祖先の中にフォーカス可能要素（tabindex 0 以上のボタン・リンクなど）がない`, a.hiddenFocus.length === 0, a.hiddenFocus.slice(0, 4).join(' | '));
          t(`${tag}: #82 role のない div / span に aria-label・aria-labelledby がない（role=group / img などを付ける）`, a.noRoleLabel.length === 0, a.noRoleLabel.slice(0, 4).join(' | '));
          t(`${tag}: #82 progressbar・listbox に名前（aria-label / aria-labelledby）がある`, a.unnamed.length === 0, a.unnamed.slice(0, 4).join(' | '));
          t(`${tag}: #82 aria-selected は tab・option などの role だけ、aria-pressed は button だけに付く`, a.badSelected.length === 0 && a.badPressed.length === 0, a.badSelected.concat(a.badPressed).slice(0, 4).join(' | '));
          t(`${tag}: #82 aside に role を上書きしない（dialog は div に付ける）`, a.asideRole.length === 0, a.asideRole.slice(0, 4).join(' | '));
          t(`${tag}: #81 <pre> と overflow-x:auto の要素が tabindex を持つ（または中にフォーカス可能要素がある）`, a.noTabindex.length === 0, a.noTabindex.slice(0, 4).join(' | '));
          if (file === 'tokens-preview.html') {
            const tr = await measureTreeClick(page);
            t(`${tag}: #80 #p2 .tree の閉じた details のシェブロンを実マウスでクリックすると details.open が true になる（button を summary に入れない）`, !!tr && tr.hit && tr.open, JSON.stringify(tr));
          }
        } finally { await page.close(); }
      }
      // ここまで
      // #68: forced-colors でも、一部選択（indeterminate）が未選択・全選択と見分けられる
      if (file === 'tokens-preview.html') {
        const page = await open(browser, file, 1280, 'light', false);
        try {
          await page.s('Emulation.setEmulatedMedia', { features: [{ name: 'forced-colors', value: 'active' }] });
          const f = await page.ev(MEASURE_INDET);
          t(`${file} 1280/forced-colors: 一部選択の「すべて選択」が枠 Highlight・横線 Highlight で、未選択（枠 CanvasText）と違い、全選択と枠が同じ`, !!f && f.part.ind && f.part.bd !== f.none.bd && f.part.bd === f.all.bd && f.part.abg === f.part.bd && f.part.aw === '9px' && f.part.ah === '2px', JSON.stringify(f));
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
