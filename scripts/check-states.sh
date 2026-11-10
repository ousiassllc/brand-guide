#!/usr/bin/env bash
# check-states.sh — Issue #10（切替・状態・フォーカス・スピナー・z・影）と Issue #12（テーマ切替の 3 形）の回帰チェック。
# 依存なし（grep と exit code のみ）。使い方: scripts/check-states.sh [リポジトリルート]
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
idx="$root/index.html"; prev="$root/tokens-preview.html"; thm="$root/theme.js"
fail=0
ok() { printf 'PASS  %s\n' "$1"; }
ng() { printf 'FAIL  %s\n' "$1"; fail=1; }
has() { grep -Eq -- "$2" "$1"; }
chk() { if has "$3" "$2"; then ok "$1"; else ng "$1"; fi; }
sec() { awk -v id="$1" '$0 ~ "<section id=\"" id "\""{f=1} f{print} f&&/<\/section>/{exit}' "$idx"; }
# 節の中だけを grep する（他の節の同じ語で誤って通らないように）
insec() { sec "$2" | grep -Eq -- "$3" && ok "$1" || ng "$1"; }
# tokens-preview の新節 #states の中だけ（main に既にある行で通らないように）
instates() { awk '/<section class="ui" id="states">/{f=1} f{print} f&&/<\/section>/{exit}' "$prev" | grep -Eq -- "$2" && ok "$1" || ng "$1"; }

# (1) index.html: 節と推奨案／代替の区別
for id in theme states focus spinner layers soft-ripple a11y-modes; do
  [ -n "$(sec "$id")" ] && ok "index.html に #$id 節がある" || ng "index.html に #$id 節がない"
done
for id in states spinner soft-ripple; do
  s=$(sec "$id")
  printf '%s' "$s" | grep -q '推奨案' && printf '%s' "$s" | grep -q '代替' && ok "#$id: 推奨案と代替を区別" || ng "#$id: 推奨案／代替の区別がない"
done
insec '切替: 3 モードと system 初期値'            theme  'system.*prefers-color-scheme'
insec '切替: aria-pressed'                        theme  'aria-pressed="true"'
insec '切替: Space / Enter のキーボード操作'      theme  'Space / Enter'
insec 'フォーカス: 入力系 2px'                    focus  '入力系 2px'
insec 'フォーカス: 離散コントロール 3px'          focus  '離散コントロール 3px'
insec 'フォーカス: 非テキスト 3:1'                focus  '3:1'
insec 'スピナー: 20px・線 2px・0.9s linear'       spinner '20px・線 2px.*0\.9s linear'
insec 'z: --z-popup 401'                          layers '--z-popup 401'
insec 'z: 既存の段を並べ替えない'                 layers '並べ替えない'
insec '影: Light 6% / Dark 40%'                   layers '6%.*40%'
insec 'ラジオ: 18px・6px の点'                    states '18px.*6px'

# (2) 共通テーマ実装
[ -f "$thm" ] && ok 'theme.js がある' || ng 'theme.js がない'
chk 'theme.js: system 追従 (matchMedia change)'  "addEventListener\('change'"            "$thm"
chk 'theme.js: light/dark だけ保存'              "light.*dark"                          "$thm"
for f in "$idx" "$prev"; do
  chk "$(basename "$f"): head で theme.js を同期読み込み" '<script src="theme.js"></script>' "$f"
  chk "$(basename "$f"): 切替コントロール 3 ボタン"       'data-set-theme="system"'        "$f"
done
! has "$idx" "localStorage\.theme[^-]" && ! has "$prev" "getItem\('oth'\)" && ok '旧キー theme / oth を使っていない' || ng '旧キーが残っている'

# (3) tokens-preview: 見本
for id in st-theme st-buttons st-switch st-focus st-spinner st-z st-shadow st-soft st-ripple; do
  chk "tokens-preview: #$id" "id=\"$id\"" "$prev"
done
chk 'tokens-preview: --z-popup:401'              '--z-popup:401'                        "$prev"
instates 'tokens-preview #states: loading（aria-busy）'    'is-loading.*aria-busy="true"'
chk 'tokens-preview: Light 側の影トークン（並置見本用）'   '\[data-theme=light\]\{--shadow-modal:0 1px 2px rgba\(0,0,0,\.06\)\}' "$prev"
chk 'tokens-preview: Dark の影 40%'              'dark\]\{--shadow-modal:0 1px 2px rgba\(0,0,0,\.4\)\}' "$prev"
chk 'tokens-preview: 入力は outline 2px'           '\.ui \.fld:focus,\.ui \.fld\.is-focus\{outline:2px solid var\(--focus\)' "$prev"
chk 'tokens-preview: ボタンは outline 3px'         '\.ui \.btn:focus-visible,\.ui \.btn\.is-focus\{outline:3px solid var\(--focus\)' "$prev"
! has "$prev" 'box-shadow:0 0 0 3px var\(--ring\)' && ok 'tokens-preview: 旧 --ring の box-shadow を使わない' || ng 'tokens-preview: 旧 --ring の box-shadow が残っている'
instates 'tokens-preview #states: forced-colors 対応'       'forced-colors:active'
instates 'tokens-preview #states: reduced-motion の遷移停止' 'prefers-reduced-motion:reduce\)\{\.ui \.btn'
instates 'tokens-preview #states: スピナー周期は .spin 既存（0.9s）を使う' 'class="spin"'

# (4) 既存の正本を壊していない
for f in "$idx" "$prev"; do
  n=$(basename "$f")
  chk "$n: Dark 背景 --bone #050505"   '\-\-bone:#050505'            "$f"
  chk "$n: --mute Light #6b6b6e"        '\-\-mute:#6b6b6e'            "$f"
  chk "$n: --mute Dark #8b8b8e"         '\-\-mute:#8b8b8e'            "$f"
  chk "$n: --focus Light #4a72d0"       '\-\-focus:#4a72d0'           "$f"
  chk "$n: --focus Dark #60a5fa"        '\-\-focus:#60a5fa'           "$f"
done
for t in '--z-base:0' '--z-dropdown:100' '--z-sticky:200' '--z-drawer:300' '--z-modal:400' '--z-toast:500' '--motion-fade-in:320ms' '--motion-fade-out:240ms' '--motion-slow:280ms'; do
  chk "tokens-preview: $t" "$t" "$prev"
done
! has "$idx" '--bone:#000000|--bone:#000;' && ! has "$prev" '--bone:#000000|--bone:#000;' && ok '真っ黒 #000 を背景に使っていない' || ng '真っ黒背景がある'

# (5) index.html: ヘッダーと確定／推奨案の表記（PR #11 レビュー反映）
chk 'ヘッダー: 480px 以下は .top のアイコンだけ形（44×44）で、ラベルは視覚的に隠す' '@media\(max-width:480px\)\{\.top \.seg\{padding:0\}\.top \.seg button\{[^}]*width:44px;height:44px' "$idx"
chk 'ヘッダー: 480px 以下でラベルを視覚的に隠す（読み上げ用に残す）' '\.top \.seg \.lb\{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect\(0 0 0 0\)' "$idx"
insec 'accent-soft 上の文字（ink）は推奨案ではなく採用' soft-ripple '地の補助文字 <span class="tag">採用</span>'

# (6) 決定①〜⑤は採用: タグが「採用」で、採用と食い違う代替が残っていない（PR #11 レビュー反映）
notinsec() { sec "$2" | grep -Eq -- "$3" && ng "$1" || ok "$1"; }
insec    '#theme: 採用タグ'                                theme  '<div class="rec"><span class="tag">採用</span><strong>3 モード'
# 新節 #theme-forms（Issue #12・推奨案）を除いた部分に 推奨案 が残っていない
sec theme | awk '/id="theme-forms"/{f=1} /<h3>最小の実装/{f=0} !f' | grep -Eq -- '推奨案' && ng '#theme: 採用済みの部分に推奨案タグが残っていない' || ok '#theme: 採用済みの部分に推奨案タグが残っていない'
notinsec '#theme: 代替 A（2 モードのみ）を消した'          theme  '2 モードのみ'
insec    '#theme: 代替 B（クッキー保存）は参考として残す'  theme  '<span class="tag">参考</span>.*クッキー'
insec    '#focus: 幅の使い分け（入力 2px / 離散 3px）が採用' focus  '幅の使い分け <span class="tag">採用</span>'
notinsec '#focus: 推奨案タグが残っていない'                focus  '推奨案'
notinsec '#focus: 「すべて 2px / すべて 3px」案を消した'   focus  'すべて 2px|すべて 3px'
insec    '#layers: z-index が採用'                         layers 'z-index <span class="tag">採用</span>'
insec    '#layers: モーダルの影が採用'                     layers 'モーダルの影 <span class="tag">採用</span>'
notinsec '#layers: 推奨案タグが残っていない'               layers '推奨案'
notinsec '#layers: 「401 を足さず文章だけ」案を消した'     layers '401 を足さず'
notinsec '#layers: 影の 24% / 32% 案を消した'              layers '24%|32%'
notinsec '#layers: 「確定値としては断定しない」を消した'   layers '断定しない'
chk '冒頭（index）: 採用済み 5 項目を明記' '推奨案（未確定）。テーマ切替（3 モード）・フォーカスの実線リング・<code>--z-popup</code> 401・Dark のモーダル影 40%・accent-soft 上の文字（<code>--ink</code>）は採用済み' "$idx"
! has "$idx" '新しい節は推奨案（未確定）' && ok '冒頭（index）: 旧「新しい節は推奨案（未確定）」を消した' || ng '冒頭（index）: 旧文言が残っている'
for id in st-theme st-focus st-z st-shadow st-soft; do
  grep -Eq "<h3 id=\"$id\">[^<]*<span class=\"tag\">採用</span></h3>" "$prev" && ok "tokens-preview: #$id が採用" || ng "tokens-preview: #$id が採用になっていない"
done
for id in st-buttons st-switch st-spinner st-ripple; do
  grep -Eq "<h3 id=\"$id\">[^<]*<span class=\"tag\">推奨案</span></h3>" "$prev" && ok "tokens-preview: #$id は推奨案のまま" || ng "tokens-preview: #$id が推奨案でない"
done
grep -A1 'id="states-draft"' "$prev" | grep -Eq '推奨案.*テーマ切替.*3 モード.*実線リング.*--z-popup.*401.*40%.*--ink.*採用' && ok '冒頭（tokens-preview）: 採用済み 5 項目を明記' || ng '冒頭（tokens-preview）: 採用済みの明記がない'
awk '/<section class="ui" id="states">|id="states-draft"/{f=1} f{print}' "$prev" | grep -q '確定と断定しない\|確定値としては断定しない' && ng 'tokens-preview: 「断定しない」が残っている' || ok 'tokens-preview: 「断定しない」を消した'

# (7) ヘッダー: 切替ラベルを折らない／バッジは ≤720px で隠す（PR #11 再チェック）
chk 'ヘッダー（index）: 720px 以下でバッジを非表示（481〜720px で切替が縦に折れない）' '@media\(max-width:720px\)\{\.badge\{display:none\}\}' "$idx"
! has "$idx" '@media\(max-width:480px\)\{\.badge' && ok 'ヘッダー（index）: 旧 480px のバッジ規則を残さない' || ng 'ヘッダー（index）: 旧 480px のバッジ規則が残っている'
chk 'ヘッダー（index）: .seg button は white-space:nowrap' '\.seg button\{[^}]*white-space:nowrap' "$idx"
chk 'ヘッダー（tokens-preview）: .seg button は white-space:nowrap' '\.seg button\{[^}]*white-space:nowrap' "$prev"

# (8) Issue #12: テーマ切替の 3 形（アイコンだけ／縦積み／文字付き横並び）
# 見本は 3 形 × 3 ボタン。形ごとの role=group の行（aria-label で特定。ヘッダーの .seg と取り違えない）を調べる
form_of() { grep -F -- "aria-label=\"テーマ（$2）\"" "$1" | head -1; }
thm_prev() { awk '/<h3 id="st-theme">/{f=1} /<h3 id="st-env">/{f=0} f' "$prev"; }
for f in "$idx" "$prev"; do
  n=$(basename "$f")
  for form in '文字付き横並び' 'アイコンだけ' '縦積み'; do
    row=$(form_of "$f" "$form")
    [ -n "$row" ] && printf '%s' "$row" | grep -q 'role="group"' && printf '%s' "$row" | grep -q 'data-theme-control' && [ "$(printf '%s' "$row" | grep -o 'data-set-theme="\(light\|dark\|system\)" aria-pressed="false"' | wc -l)" -eq 3 ] \
      && ok "$n: 見本「$form」（role=group・3 ボタン・aria-pressed・data-theme-control）" || ng "$n: 見本「$form」がない／3 ボタンでない"
    [ -n "$row" ] && [ "$(printf '%s' "$row" | grep -o 'class="lb">\(ライト\|ダーク\|システム\)</span>' | wc -l)" -eq 3 ] \
      && ok "$n: 見本「$form」は 3 ボタンとも文字ラベル（.lb）を持つ（アクセシブルな名前）" || ng "$n: 見本「$form」のラベル（.lb）が 3 つない"
  done
  form_of "$f" 'アイコンだけ' | grep -q 'class="seg seg-icon"' && form_of "$f" '縦積み' | grep -q 'class="seg seg-stack"' && ok "$n: 見本のクラス（.seg-icon / .seg-stack）" || ng "$n: 見本のクラスがない"
  ! has "$f" '<[a-z]+ [^>]*role="radiogroup"' && ok "$n: 要素に role=radiogroup を付けない（role=group + aria-pressed）" || ng "$n: role=radiogroup の要素がある"
  # CSS（44px・ツールチップ・ラジオ印・forced-colors・タップ領域）
  chk "$n: アイコンだけは 44×44 のボタン" '\.seg-icon button\{[^}]*width:44px;height:44px' "$f"
  chk "$n: アイコンだけのラベルは視覚的に隠し、hover / focus-visible で吹き出しに出す" '\.seg-icon \.lb\{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect\(0 0 0 0\)' "$f"
  chk "$n: アイコンだけのツールチップは hover と focus-visible の両方" '\.seg-icon button:is\(:hover,:focus-visible\) \.lb\{' "$f"
  chk "$n: 縦積みは 1 行 44px 以上" '\.seg-stack button\{[^}]*min-height:44px' "$f"
  chk "$n: 縦積みはラジオ印（18px の円・6px の点）" '\.seg-stack button::after\{[^}]*width:18px;height:18px.*radial-gradient\(circle,var\(--bone\) 0 3px' "$f"
  chk "$n: 文字付きは見た目を変えずタップ領域だけ 44px 以上（::before で縦に広げる）" '\.seg button::before\{content:"";position:absolute;inset:-8px 0\}' "$f"
  chk "$n: forced-colors で縦積みのラジオ印も HighlightText" 'forced-colors:active\)\{.*\.seg-stack button\[aria-pressed=true\]::after\{background:radial-gradient\(circle,HighlightText' "$f"
  chk "$n: 選択中は Highlight / HighlightText（全形共通）" '\.seg button\[aria-pressed=true\]\{background:Highlight;color:HighlightText;forced-color-adjust:none\}' "$f"
  chk "$n: ヘッダーのアイコンだけ形のツールチップ（≤480px）" '\.top \.seg button:is\(:hover,:focus-visible\) \.lb\{' "$f"
  chk "$n: フォーカスの実線リング（3px・offset 2px）を維持" '\.seg button:focus-visible\{outline:3px solid var\(--focus\);outline-offset:2px\}' "$f"
done
# 文言: 新節は推奨案、ただし「両方を定義して場所で使い分ける」は決定済み
insec '#theme-forms: 推奨案タグ' theme '<div class="rec" id="theme-forms"><span class="tag">推奨案</span>'
insec '#theme-forms: 両方を定義して場所で使い分けるのは決定済み' theme '決定済み:</strong> 「アイコンだけ」と「縦積み」の<strong>両方を定義し、置く場所で使い分ける</strong>'
insec '#theme-forms: 使い分け表（ヘッダー等の横一列で狭い→アイコンだけ）' theme '<tr><td>ヘッダー・ツールバーなど、横一列で狭い</td><td>アイコンだけ</td>'
insec '#theme-forms: 使い分け表（縦に余裕がある→縦積み）' theme '<tr><td>サイドバー・ドロワー・設定ページ・モバイルメニューなど、縦に余裕がある</td><td>縦積み</td>'
insec '#theme-forms: 使い分け表（幅が十分→文字付き横並び）' theme '<tr><td>幅が十分（横にラベルが 1 行で収まる）</td><td>文字付き横並び'
insec '#theme-forms: 切り替えの基準はコンテナ幅（または置く場所）で、閾値は未確定' theme 'コンテナ幅（または置く場所そのもの）.*数値は確定ではなく'
insec '#theme-forms: 3 形の見本（id=theme-forms-demo）' theme 'id="theme-forms-demo"'
insec '#theme-forms: 3 形とも theme.js の契約と role=group を保つ' theme 'role="radiogroup"</code> にはせず、<code>role="group"</code> \+ <code>aria-pressed</code>'
insec '#theme-forms: タップ領域 44' theme '44×44px'
# 採用済みの文言は変えない（3 モードの箇条書き・ヘッダー見本の ≤480px 記述）
insec '#theme: 採用済み「狭い幅（≤480px）ではアイコンのみ（ラベルは読み上げ用に残す）」を変えていない' theme '狭い幅（≤480px）ではアイコンのみ（ラベルは読み上げ用に残す）'
thm_prev | grep -q 'id="st-theme-forms"' && thm_prev | grep -q '推奨案' && ok 'tokens-preview #st-theme: 3 形の見本ブロック（推奨案）' || ng 'tokens-preview #st-theme: 3 形の見本ブロックがない'
thm_prev | grep -Eq '決定済み:</strong> 「アイコンだけ」と「縦積み」の<strong>両方を定義し、置く場所で使い分ける</strong>' && ok 'tokens-preview #st-theme: 両方を定義して場所で使い分けるのは決定済み' || ng 'tokens-preview #st-theme: 決定済みの明記がない'
thm_prev | grep -Eq '<th>置く場所</th><th>形</th>' && ok 'tokens-preview #st-theme: 使い分け表' || ng 'tokens-preview #st-theme: 使い分け表がない'
thm_prev | grep -q 'id="theme-forms-demo"' && ok 'tokens-preview #st-theme: 3 形の見本が #st-theme の中にある' || ng 'tokens-preview #st-theme: 見本が #st-theme の外にある'
chk '#st-theme は採用のまま（新ブロックだけ推奨案）' '<h3 id="st-theme">[^<]*<span class="tag">採用</span></h3>' "$prev"
chk 'theme.js: 保存キーは ousiass-theme のまま' "KEY = 'ousiass-theme'" "$thm"

exit $fail
