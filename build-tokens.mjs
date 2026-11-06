#!/usr/bin/env node
// tokens.json から tokens.css と theme.css を生成する。
//
//   node build-tokens.mjs          生成して書き出す
//   node build-tokens.mjs --check  生成結果が現在のファイルと一致するか調べる（CI 用）
//
// 値の正は tokens.json。css を手で直さないこと。

import { readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const src = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));

const header = (what) =>
  `/* ${what}\n` +
  ` * Ousiass 共通 UI トークン v${src.version}（${src.updated}）\n` +
  ` * https://ousiassllc.github.io/brand-guide/\n` +
  ` *\n` +
  ` * このファイルは build-tokens.mjs が tokens.json から生成する。手で直さないこと。\n` +
  ` * 製品が上書きしてよいのは --accent / --on-accent / --accent-soft の 3 つだけ。\n` +
  ` * 上書きは案件ガイドに宣言してから行う。\n` +
  ` */\n`;

const decl = (name, value) => `\t--${name}: ${value};`;

/** 色以外（テーマで変わらない）の群を 1 枚に並べる */
function staticGroups(indent = '\t') {
  const out = [];
  for (const g of src.groups) {
    if (g.themed) continue;
    out.push(`${indent}/* ${g.label} */`);
    for (const t of g.tokens) {
      out.push(indent + `--${t.name}: ${t.value};`);
      if (t.lineHeight) out.push(indent + `--${t.name}--line-height: ${t.lineHeight};`);
    }
    out.push('');
  }
  out.pop();
  return out.join('\n');
}

/** 色の群を light / dark のどちらかで並べる */
function colorGroups(theme, indent = '\t') {
  const out = [];
  for (const g of src.groups) {
    if (!g.themed) continue;
    out.push(`${indent}/* ${g.label} */`);
    for (const t of g.tokens) out.push(indent + `--${t.name}: ${t[theme]};`);
    out.push('');
  }
  out.pop();
  return out.join('\n');
}

// ---- tokens.css: 素の :root。Tailwind を使わないスタックとアドオン向け ----
const tokensCss =
  header('tokens.css — 素のカスタムプロパティ') +
  `\n:root {\n\tcolor-scheme: light;\n\n` +
  colorGroups('light') +
  `\n\n` +
  staticGroups() +
  `\n}\n\n` +
  `/* 手動の切り替え。OS 設定だけに従うなら下の @media だけでよい */\n` +
  `[data-theme="dark"] {\n\tcolor-scheme: dark;\n\n` +
  colorGroups('dark') +
  `\n}\n\n` +
  `@media (prefers-color-scheme: dark) {\n` +
  `\t:root:not([data-theme="light"]) {\n\t\tcolor-scheme: dark;\n\n` +
  colorGroups('dark', '\t\t') +
  `\n\t}\n}\n`;

// ---- theme.css: Tailwind v4 の @theme。wallet と DLP の本体向け ----
// Tailwind は --color-* / --radius-* / --text-* / --font-* を見てユーティリティを作る。
const TW_PREFIX = { color: 'color', accent: 'color', state: 'color', prism: 'color' };
const twName = (group, name) => {
  const p = TW_PREFIX[group];
  if (p) return `${p}-${name}`;
  if (name.startsWith('r-')) return `radius-${name.slice(2)}`;
  return name; // text-* / font-* / s-* などはそのまま
};

// Tailwind 側では色が --color-* に改名されるので、値の中の var(--x) も同じ表に通す。
// これをしないと --ring の var(--focus) が解決できなくなる。
const renames = new Map();
for (const g of src.groups) {
  for (const t of g.tokens) {
    const n = twName(g.name, t.name);
    if (n !== t.name) renames.set(t.name, n);
  }
}
const twValue = (v) => String(v).replace(/var\(--([a-z0-9-]+)\)/gi, (m, n) => `var(--${renames.get(n) ?? n})`);

function twGroups(filter) {
  const out = [];
  for (const g of src.groups) {
    if (!filter(g)) continue;
    out.push(`\t/* ${g.label} */`);
    for (const t of g.tokens) {
      const n = twName(g.name, t.name);
      out.push(decl(n, twValue(g.themed ? t.light : t.value)));
      if (t.lineHeight) out.push(decl(`${n}--line-height`, t.lineHeight));
    }
    out.push('');
  }
  out.pop();
  return out.join('\n');
}

const themeCss =
  header('theme.css — Tailwind v4 の @theme') +
  `\n/* Tailwind 既定のパレットを落として、共通トークンだけを色の語彙にする。\n` +
  ` * 残すと bg-gray-100 のようなユーティリティが書けてしまい、独自色が混ざる。 */\n` +
  `@theme {\n\t--color-*: initial;\n\n` +
  twGroups((g) => g.themed) +
  `\n\n` +
  twGroups((g) => !g.themed) +
  `\n}\n\n` +
  `/* ダーク。@theme は 1 つしか持てないので素の CSS で再定義する。 */\n` +
  `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));\n\n` +
  `[data-theme="dark"] {\n\tcolor-scheme: dark;\n\n` +
  src.groups
    .filter((g) => g.themed)
    .map(
      (g) =>
        `\t/* ${g.label} */\n` +
        g.tokens.map((t) => decl(`color-${t.name}`, t.dark)).join('\n'),
    )
    .join('\n\n') +
  `\n}\n`;

const outputs = [
  ['tokens.css', tokensCss],
  ['theme.css', themeCss],
];

if (process.argv.includes('--check')) {
  let bad = 0;
  for (const [file, want] of outputs) {
    const got = readFileSync(join(here, file), 'utf8');
    if (got !== want) {
      console.error(`NG ${file} が tokens.json と一致しません。node build-tokens.mjs を実行してください。`);
      bad++;
    } else {
      console.log(`OK ${file}`);
    }
  }
  process.exit(bad ? 1 : 0);
}

for (const [file, body] of outputs) {
  writeFileSync(join(here, file), body);
  console.log(`wrote ${file} (${body.split('\n').length} 行)`);
}
