#!/usr/bin/env bash
# check-app-ui.sh — Issue #20（線ではなく濃さで面を分ける・文字 3 段・余白と丸み）の回帰チェック。
# 依存なし（grep・awk と exit code のみ）。使い方: scripts/check-app-ui.sh [リポジトリルート]
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
idx="$root/index.html"; prev="$root/tokens-preview.html"
fail=0
ok() { printf 'PASS  %s\n' "$1"; }
ng() { printf 'FAIL  %s\n' "$1"; fail=1; }
has() { grep -Eq -- "$2" "$1"; }
chk() { if has "$3" "$2"; then ok "$1"; else ng "$1"; fi; }
notchk() { if has "$3" "$2"; then ng "$1"; else ok "$1"; fi; }

# 節だけを取り出す（他の節の同じ語で誤って通らないように）
au=$(awk '/<section id="app-ui"/{f=1} f{print} f&&/<\/section>/{exit}' "$idx")
inau() { if printf '%s' "$au" | grep -Eq -- "$2"; then ok "$1"; else ng "$1"; fi; }
pv=$(awk '/<section class="ui" id="app-ui">/{f=1} f{print} f&&/<\/section>/{exit}' "$prev")
inpv() { if printf '%s' "$pv" | grep -Eq -- "$2"; then ok "$1"; else ng "$1"; fi; }

# (1) 節の有無・導線
[ -n "$au" ] && ok 'index.html に #app-ui 節がある' || ng 'index.html に #app-ui 節がない'
[ -n "$pv" ] && ok 'tokens-preview.html に #app-ui 節がある' || ng 'tokens-preview.html に #app-ui 節がない'
chk '先頭のジャンプ導線に #app-ui がある' '<a href="#app-ui">アプリ UI</a>' "$idx"
order=$(grep -n -o '<section id="typography"\|<section id="app-ui"\|<section id="ui-draft"' "$idx" | cut -d: -f2- | tr '\n' ' ')
[ "$order" = '<section id="typography" <section id="app-ui" <section id="ui-draft" ' ] && ok '節の順は 文字 → アプリ UI → UI部品' || ng "節の順が違う: $order"

# (2) トークン: 値（ライト／ダーク）
chk '--surface-sel Light #ebebea' '^:root\{[^}]*--surface-sel:#ebebea' "$idx"
chk '--surface-sel Dark #1e1e21'  '^\[data-theme=dark\]\{[^}]*--surface-sel:#1e1e21' "$idx"
chk '--surface-sel Light #ebebea（tokens-preview）' '^:root,\[data-theme=light\]\{[^}]*--surface-sel:#ebebea' "$prev"
chk '--surface-sel Dark #1e1e21（tokens-preview）'  '^\[data-theme=dark\]\{[^}]*--surface-sel:#1e1e21' "$prev"
for f in "$idx" "$prev"; do
  n=$(basename "$f")
  chk "$n: --line-soft は accent 6%" '--line-soft:color-mix\(in srgb,var\(--accent\) 6%,transparent\)' "$f"
  chk "$n: ページ Light #f5f5f4 / カード Light #ffffff を維持" '--bone:#f5f5f4;--mute:#6b6b6e;--surface:#ffffff;' "$f"
  chk "$n: ページ Dark #050505 / カード Dark #141414 を維持"   '--bone:#050505;--mute:#8b8b8e;--surface:#141414;' "$f"
done
chk 'tokens-preview: --r-card 16px / --r-pill 999px' '--r-card:16px;--r-pill:999px' "$prev"

# (3) 規定の中身（Issue #20 の決めごと）
inau '1px の枠線を使わない（カード・表・サブナビ・バナー）' 'カード・表・サブナビ・バナーに <strong>1px の枠線を使わない'
inau 'Light の面: #f5f5f4 → #ffffff → #ebebea'               '#f5f5f4.*#ffffff.*#ebebea'
inau 'Dark の面: #050505・#141414 のまま・選択は #1e1e21'    '#050505.*#141414.*#1e1e21'
inau '表の行の区切りは ink / bone 6%（--accent の 6%）'          '<code>--line-soft</code>（<code>--accent</code> の 6%。Light は ink、Dark は bone'
inau '例外: 入力欄・:focus-visible・danger 40%'               '入力欄.*focus-visible.*危険（danger）の枠 40%'
inau '文字 3 段: 28 / 700'                                    '<td>28px / 700</td>'
inau '文字 3 段: 15 / 600（節・項目名・ボタン・ナビ）'        '節・項目名・ボタン・ナビ</td><td>15px / 600</td>'
inau '文字 3 段: 13 / 400 mute（説明・チップ・表の見出し）'   '説明・チップ・表の見出し</td><td>13px / 400</td>'
inau '12px・14px などの中間サイズは使わない'                  '12px や 14px などの中間サイズは使わない'
inau '見出しタグと表示サイズの節と矛盾しない旨'               '「見出しタグと表示サイズ」とは矛盾しない'
inau 'カード・バナーの余白 20〜24px（標準 22px）'             '20〜24px（標準 22px）'
inau 'カード同士 16px'                                        'カード同士の間</td><td>16px'
inau 'カード・表・バナーの角 16px'                            'カード・表・バナーの角</td><td>16px'
inau 'ボタン・チップ・選んでいるナビはピル 999px'             'ボタン・チップ・選んでいるナビ</td><td>ピル <code>border-radius: 999px'
inau '主なボタンは塗りピル・それ以外は静かなピル'            '主なボタンは <code>--accent</code> の塗りピル.*<code>--surface-sel</code> の静かなピル'
# 既存の「文字」節の記述は消していない
chk '文字節: 見出しタグと表示サイズの独立を維持' '<h3 class="h">見出しタグと表示サイズ</h3>' "$idx"
chk '文字節: スケール xs12〜3xl40 を維持'        'xs 12 / sm 14 / base 16 / lg 18 / xl 24 / 2xl 32 / 3xl 40' "$idx"

# (4) 見本の CSS（枠線を使わない・ピル・16px・文字 3 段）
chk 'カード: 枠線なし・角 --r-card・余白 22px'       '^\.card\{background:var\(--surface\);border-radius:var\(--r-card\);padding:var\(--pad-card,22px\)\}' "$prev"
chk 'カード余白トークン --pad-card は 22px'          '--pad-card:22px' "$prev"
chk '.ui .btn はピル（--r-pill）・15px / 600'          '^\.ui \.btn\{[^}]*border-radius:var\(--r-pill\);font:600 15px' "$prev"
chk '.ui .btn.sm も 15px（中間の 14px を使わない）'     '\.ui \.btn\.sm\{height:32px;padding:0 14px;font-size:15px\}' "$prev"
chk 'それ以外のボタン .sec は surface-sel のピル'      '\.sec\{background:var\(--surface-sel\);color:var\(--ink\);border-color:transparent\}' "$prev"
chk 'danger の枠 45% を維持'                           '\.ui \.dan\{[^}]*border-color:color-mix\(in srgb,var\(--danger\) 45%' "$prev"
chk 'チップ .pill: 13px / 400・ピル・枠線なし'          '^\.pill\{[^}]*font-size:13px;font-weight:400;[^}]*border-radius:var\(--r-pill\)' "$prev"
notchk 'チップ .pill に border がない'                  '^\.pill\{[^}]*border:' "$prev"
chk '表の区切りは --line-soft'                          '--table-divider:var\(--stroke\) solid var\(--line-soft\)' "$prev"
chk '表の見出しは 13px・本文は 15px'                    '--table-head-size:13px;--table-body-size:15px' "$prev"
chk '表の行ホバーは surface-sel'                        '--table-row-hover:var\(--surface-sel\)' "$prev"
chk 'サブナビ .tabs は選択が surface-sel のピル'        '\.tabs button:hover,\.tabs button\[aria-selected=true\]\{background:var\(--surface-sel\)\}' "$prev"
chk 'サブナビ .tabs はピル・15px / 600'                 '\.tabs button\{[^}]*font:600 15px[^}]*border-radius:var\(--r-pill\)' "$prev"
chk '縦のナビ .nv a はピル・15px / 600'                 '#states \.nv a\{[^}]*border-radius:var\(--r-pill\)[^}]*font-size:15px;font-weight:600' "$prev"
chk 'バナー .bn .in は surface-sel・角 16・枠線なし'     '#states \.bn \.in\{[^}]*border-radius:var\(--r-card\);background:var\(--surface-sel\)' "$prev"
chk '入力欄の枠は残す（.ui .fld）'                      '^\.ui \.fld\{[^}]*border:1px solid var\(--border\)' "$prev"
chk ':focus-visible の --focus の輪は残す'              '^:focus-visible\{outline:2px solid var\(--focus\)' "$prev"
# 状態の見分け（背景色だけで示す部品が --surface-sel と同色にならない）
chk '.sec のホバーは surface-sel に ink 8% を重ねる'        '\.sec:hover\{background:color-mix\(in srgb,var\(--ink\) 8%,var\(--surface-sel\)\)\}' "$prev"
chk '押下トグル .tgl: 未押下は透明・押下は accent-soft'     '#states \.btn\.sec\.tgl\{background:transparent\}.*#states \.btn\.sec\.tgl\[aria-pressed=true\]\{background:var\(--accent-soft\)' "$prev"
chk 'フィルタチップ .fchip の押下は --accent の塗り'          '#p2 \.fchip\[aria-pressed=true\]\{background:var\(--accent\);color:var\(--bone\)\}' "$prev"
chk '選択中の縦ナビ .acct.on は surface-sel'  '#states \.nv a\.acct\.on\{background:var\(--surface-sel\)\}' "$prev"
chk '選択中の行 .rw.on は surface-sel'  '#states \.rw\.on\{background:var\(--surface-sel\)\}' "$prev"
chk 'forced-colors: タブ・ナビの選択は Highlight'            'forced-colors:active\)\{\.tabs button\[aria-selected=true\],#states \.tb40 button\[aria-selected=true\],#states \.nv a\.acct\.on\{background:Highlight' "$prev"
chk 'ペイン .pn・.ld・.rowsel は枠なしの surface-sel'         '#states \.pn>\*\{min-width:0;border-radius:var\(--r-card\);background:var\(--surface-sel\)' "$prev"
# #app-ui の見本: 文字は 28 / 15 / 13 だけ・枠線なし
inpv '#app-ui の見本: ページタイトル 28 / 700'            '\.au-t1\{font-size:28px;font-weight:700'
inpv '#app-ui の見本: 項目名 15 / 600・説明 13 / 400'     '\.au-item\{margin:0;font-size:15px;font-weight:600.*\.au-desc\{[^}]*font-size:13px;font-weight:400'
if printf '%s' "$pv" | awk '/<style>/{f=1} f{print}' | grep -Eq 'border:1px solid|border-bottom:1px solid var\(--border\)'; then ng '#app-ui の見本の CSS に 1px solid の枠線がある（区切りの --line-soft は可）'; else ok '#app-ui の見本の CSS に 1px solid の枠線がない'; fi
sizes=$(printf '%s' "$pv" | awk '/<style>/{f=1} f&&/<\/style>/{exit} f{print}' | grep -o 'font-size:[0-9.]*px' | sort -u | tr '\n' ' ')
case "$sizes" in *"font-size:12px"*|*"font-size:14px"*) ng "#app-ui の見本に中間サイズがある: $sizes";; *) ok "#app-ui の見本の font-size は 28 / 15 / 13 のみ: $sizes";; esac

exit "$fail"
