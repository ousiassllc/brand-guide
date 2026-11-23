#!/usr/bin/env bash
# check-app-ui.sh — Issue #20（線ではなく濃さで面を分ける・文字 3 段・余白と丸み）の回帰チェック。
# 依存なし（grep・awk と exit code のみ）。使い方: scripts/check-app-ui.sh [リポジトリルート]
set -u
. "$(dirname "$0")/lib.sh"
need "$idx" "$prev"

# 節だけを取り出す（他の節の同じ語で誤って通らないように）
au=$(sec app-ui)
inau() { intext "$1" "$au" "$2"; }
pv=$(secp app-ui)
inpv() { intext "$1" "$pv" "$2"; }

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
inau '12px などの中間サイズは使わない・14px は補足だけ'          '12px などの中間サイズは使わない。14px（sm）は画面の主な段ではなく、補足'
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
chk '.ui .btn.sm は 14px / 600 にそろえる（通常ボタンは 15）' '\.ui \.btn\.sm\{height:32px;padding:0 14px;font-size:14px\}' "$prev"
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
chk 'forced-colors: サブナビ・ナビの選択は Highlight、タブは下線が Highlight' 'forced-colors:active\)\{\.tabs button\[aria-selected=true\],#states \.nv a\.acct\.on\{background:Highlight[^}]*\}#states \.tb40 button\[aria-selected=true\]\{border-bottom-color:Highlight' "$prev"
chk 'ペイン .pn・.ld・.rowsel は枠なしの surface-sel'         '#states \.pn>\*\{min-width:0;border-radius:var\(--r-card\);background:var\(--surface-sel\)' "$prev"
# #app-ui の見本: 文字は 28 / 15 / 13 だけ・枠線なし
inpv '#app-ui の見本: ページタイトル 28 / 700'            '\.au-t1\{font-size:28px;font-weight:700'
inpv '#app-ui の見本: 項目名 15 / 600・説明 13 / 400'     '\.au-item\{margin:0;font-size:15px;font-weight:600.*\.au-desc\{[^}]*font-size:13px;font-weight:400'
if printf '%s' "$pv" | awk '/<style>/{f=1} f{print}' | grep -Eq 'border:1px solid|border-bottom:1px solid var\(--border\)'; then ng '#app-ui の見本の CSS に 1px solid の枠線がある（区切りの --line-soft は可）'; else ok '#app-ui の見本の CSS に 1px solid の枠線がない'; fi
sizes=$(printf '%s' "$pv" | awk '/<style>/{f=1} f&&/<\/style>/{exit} f{print}' | grep -o 'font-size:[0-9.]*px' | sort -u | tr '\n' ' ')
case "$sizes" in *"font-size:12px"*|*"font-size:14px"*) ng "#app-ui の見本に中間サイズがある: $sizes";; *) ok "#app-ui の見本の font-size は 28 / 15 / 13 のみ: $sizes";; esac

# (5) いろはの決定（#21 の直し）: 浮かぶ面は --line-soft の枠・アラートは帯なし・線でなく余白・図の点線なし
inau '浮かぶ面は 1px の枠を残す・色は --line-soft・影は今のまま'  '浮かぶ面は、<strong>1px の枠を残す</strong>。色は <code>--line-soft</code>（ink 6%、Dark は bone 6%）、影は今のまま'
inau 'アラート: 地 surface-sel・角 16px・左の帯なし・状態色はアイコンか丸だけ・danger だけ枠 40%' 'インラインアラートの地は <code>--surface-sel</code>、角は 16px.*左の状態色の帯は使わない</strong>。状態色は先頭のアイコンか丸だけ.*danger のアラートだけは枠 40%'
inau '題の下・グループの上に線を引かない・項目 16px・まとまり 24px'  'カードの題の下やフォームのグループの上に線を引かない。区切りは余白で出す: 項目のあいだは 16px、まとまりのあいだは 24px。線にするより、面の濃さの差を優先する'
notchk 'アラートの状態色の帯を「規定の対象外」にしていない'          '状態色の帯は、この規定の対象外|アラートの角は、この規定の対象外' "$idx"
# 浮かぶ面（モーダル・ダイアログ・ドロップダウン・ポップオーバー）の枠は 1px の --line-soft。--border の枠は残さない
for sel in '\.modal' '\.sheet' '#states \.zs \.dd1' '#states \.zs \.mdl' '#states \.zs \.pop' '#states \.dlg' '#states \.dpn' '#p0 \.dd-panel' '#p0 \.pop' '#p1 \.sugg' '#p2 \.cmdk' '#p2 \.coach-tip' '#p2 \.snackbar'; do
  chk "浮かぶ面 $sel: 1px の --line-soft の枠" "^$sel\{[^}]*border:1px solid var\(--line-soft\)" "$prev"
  notchk "浮かぶ面 $sel: --border の枠を残していない" "^$sel\{[^}]*border:1px solid var\(--border\)" "$prev"
done
chk 'モーダルの影は今のまま（--shadow-modal）'                '^\.modal\{[^}]*box-shadow:var\(--shadow-modal\)' "$prev"
chk '--shadow-modal の値は変えない（Light）'                  '\[data-theme=light\]\{--shadow-modal:0 1px 2px rgba\(0,0,0,\.06\)\}' "$prev"
chk '--shadow-modal の値は変えない（Dark）'                   '\[data-theme=dark\]\{--shadow-modal:0 1px 2px rgba\(0,0,0,\.4\)\}' "$prev"
# アラート .al: 左の帯なし・surface-sel・角 16px・danger だけ枠 40%・状態色はアイコンだけ
chk 'アラート .al: surface-sel・角 --r-card・左の帯なし'      '^\.al\{[^}]*border:1px solid transparent;border-radius:var\(--r-card\);background:var\(--surface-sel\)' "$prev"
notchk 'アラート .al に border-left がない'                   '^\.al\{[^}]*border-left' "$prev"
chk 'アラートの状態色は先頭のアイコンだけ'                    '\.al>span:first-child\{color:var\(--c,var\(--info\)\)\}' "$prev"
chk 'danger のアラートだけ枠 40%'                             '\.al\.al-dan\{border-color:color-mix\(in srgb,var\(--danger\) 40%,transparent\)\}' "$prev"
n=$(grep -c 'class="al al-dan ' "$prev"); [ "$n" -eq 1 ] && ok 'al-dan は danger のアラート 1 つだけ' || ng "al-dan の数が違う: $n"
# 線でなく余白: .np-card の題の下線・.np-fs の上線をなくし、項目 16 / まとまり 24
chk '.np-card-t: 下線なし・上と左右 24'                       '#states \.np-card-t\{margin:0;padding:var\(--s-6\) var\(--s-6\) 0;' "$prev"
notchk '.np-card-t に border がない'                          '#states \.np-card-t\{[^}]*border' "$prev"
chk '.np-fs: 上線なし・項目のあいだ 16（--gap-field）'        '#states \.np-fs\{margin:0;min-width:0;padding:0;border:0;display:flex;flex-direction:column;gap:var\(--gap-field\)\}' "$prev"
notchk '.np-fs に border-top がない'                          '#states \.np-fs\{[^}]*border-top' "$prev"
chk '.np-form: まとまりのあいだ 24（--s-6）'                  '#states \.np-form\{[^}]*gap:var\(--s-6\)\}' "$prev"
# 「面は濃さで分ける」の図: 点線の枠をなくし、濃さの差だけで見せる
notchk '#app-ui の図 .au-fig に点線・破線の枠がない'           '\.au-fig\{[^}]*(outline|border)[^}]*(dashed|dotted)' "$prev"
notchk '#app-ui の節に点線・破線がない'                       'dashed|dotted' <(printf '%s' "$pv")
# フォローアップ（PR #78）: タブ・disabled の opacity・ドロワー・バッジ・ウェイトの決まり
chk 'タブ .tb40: 下線 2px・角なし・非選択 --mute・左右 --s-3'   '#states \.tb40 button\{height:40px;padding:0 var\(--s-3\);background:none;border:0;border-bottom:2px solid transparent;border-radius:0;color:var\(--mute\)' "$prev"
chk 'タブ .tb40: 選択は --accent の下線（地は塗らない）'         '#states \.tb40 button\[aria-selected=true\]\{color:var\(--ink\);border-bottom-color:var\(--accent\)\}' "$prev"
chk '入力欄 .fld:disabled も opacity .4'                       '^\.ui \.fld:disabled\{opacity:\.4;' "$prev"
notchk 'disabled に opacity .5 を使わない'                      'disabled[^{]*\{[^}]*opacity:\.5[^0-9]' "$prev"
chk 'モバイルドロワーの項目はピル（--r-pill）'                  '#p0 \.mnav-panel a\{[^}]*border-radius:var\(--r-pill\)' "$prev"
chk '#toast の font に sans-serif の予備がある'                 '^#toast\{[^}]*font:400 14px Sora,"Noto Sans JP",sans-serif' "$prev"
chk '#toast の font に sans-serif の予備がある（index）'        '^#toast\{[^}]*font:400 14px Sora,"Noto Sans JP",sans-serif' "$idx"
chk '#states の決まりに「入力欄も .4」'                         '入力欄も <code>\.4</code>' "$idx"
chk '決まりに「バッジの数字は 11px Mono・最小 18」'              'バッジの数字は 11px Mono・最小 18' "$idx"
chk '見出しのウェイトは最大 600'                                '見出しのウェイトは最大 600' "$idx"
nottext '「提案」が色の節に残っていない'                        "$(cat "$idx")" '（提案）|提案値'
chk '--r-lg のラベルはポップオーバー・ドロップ領域'             '--r-lg</code><br><span class="tk">12px · ポップオーバー・ドロップ領域など' "$prev"
finish
