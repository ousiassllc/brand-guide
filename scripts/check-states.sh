#!/usr/bin/env bash
# check-states.sh — Issue #10（切替・状態・フォーカス・スピナー・z・影）の回帰チェック。
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
chk 'ヘッダー: 切替ラベルは 480px 以下でアイコンのみ' '@media\(max-width:480px\)\{\.seg \.lb\{position:absolute' "$idx"
insec 'accent-soft 上の文字（ink）は推奨案ではなく採用' soft-ripple '地の補助文字 <span class="tag">採用</span>'

# (6) 決定①〜⑤は採用: タグが「採用」で、採用と食い違う代替が残っていない（PR #11 レビュー反映）
notinsec() { sec "$2" | grep -Eq -- "$3" && ng "$1" || ok "$1"; }
insec    '#theme: 採用タグ'                                theme  '<div class="rec"><span class="tag">採用</span><strong>3 モード'
notinsec '#theme: 推奨案タグが残っていない'                theme  '推奨案'
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

exit $fail
