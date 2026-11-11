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
# #states はボタン（採用）とスイッチ・ラジオ（推奨案・代替つき）が同居する。#spinner / #soft-ripple は全面「採用」（下の (8) で確認）
s=$(sec states)
printf '%s' "$s" | grep -q '推奨案' && printf '%s' "$s" | grep -q '代替' && ok '#states: スイッチ・ラジオは推奨案と代替を区別' || ng '#states: スイッチ・ラジオの推奨案／代替の区別がない'
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
chk 'ヘッダー: 480px 以下は .top のアイコンだけ形（見える 38×38・padding 3px）で、ラベルは視覚的に隠す' '@media\(max-width:480px\)\{\.top \.seg\{padding:3px\}\.top \.seg button\{[^}]*width:38px;height:38px' "$idx"
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
chk '冒頭（index）: 採用済み（決定 4 件を含む）を明記' 'スイッチ・ラジオの状態は推奨案（未確定）。ボタンの loading・スピナー・リップルの対象・テーマ切替（3 モード）・フォーカスの実線リング・<code>--z-popup</code> 401・Dark のモーダル影 40%・accent-soft 上の文字（<code>--ink</code> / <code>--mute-on-soft</code>）・ダイアログ本文 base 16・モーダルの閉じ方・ペイン型デスクトップアプリの例外・スイッチのラベル base 16・入力の文字サイズ（base 16 が基本、狭い設定ペインだけ sm 14 可、モバイルは必ず 16）・使えないメニュー項目の opacity <code>\.4</code>・全幅バナーの即時の出入りは採用済み' "$idx"
! has "$idx" '新しい節は推奨案（未確定）' && ok '冒頭（index）: 旧「新しい節は推奨案（未確定）」を消した' || ng '冒頭（index）: 旧文言が残っている'
for id in st-theme st-focus st-z st-shadow st-soft st-buttons st-spinner st-ripple st-dialog st-pane proposals-draft; do
  grep -Eq "<h3 id=\"$id\">[^<]*<span class=\"tag\">採用</span></h3>" "$prev" && ok "tokens-preview: #$id が採用" || ng "tokens-preview: #$id が採用になっていない"
done
grep -Eq '<h3 id="st-switch">[^<]*<span class="tag">推奨案</span></h3>' "$prev" && ok 'tokens-preview: #st-switch は推奨案のまま' || ng 'tokens-preview: #st-switch が推奨案でない'
grep -Eq '<h3 id="st-decided">[^<]*<span class="tag">採用</span></h3>' "$prev" && ok 'tokens-preview: #st-decided は採用' || ng 'tokens-preview: #st-decided が採用になっていない'
grep -A1 'id="states-draft"' "$prev" | grep -Eq '推奨案.*ボタンの loading・スピナー・リップルの対象・テーマ切替.*実線リング.*--z-popup.*401.*40%.*--mute-on-soft.*ダイアログ本文 base 16.*ペイン型デスクトップアプリの例外・スイッチのラベル base 16・入力の文字サイズ.*狭い設定ペインだけ 14 可、モバイルは 16.*使えないメニュー項目の opacity <code>\.4</code>.*全幅バナーの即時の出入りは <span class="tag">採用</span>' && ok '冒頭（tokens-preview）: 採用済みの明記（決定 4 件を含む）' || ng '冒頭（tokens-preview）: 採用済みの明記がない'
awk '/<section class="ui" id="states">|id="states-draft"/{f=1} f{print}' "$prev" | grep -q '確定と断定しない\|確定値としては断定しない' && ng 'tokens-preview: 「断定しない」が残っている' || ok 'tokens-preview: 「断定しない」を消した'

# (6b) Issue #14: 採用（loading・リップルの対象・スピナー）、--mute-on-soft、ダイアログ、ペイン型の例外、Hitomado #283〜#287 の反映。
#      #theme 節とテーマ切替コントロール（PR #13 の範囲）の項目はここに入れない。
h3sec() { awk -v id="$1" '$0 ~ "^<h3 id=\"" id "\""{f=1;print;next} f&&(/^<h3 id=/||/^<\/section>/){exit} f{print}' "$prev"; }
inh3()  { h3sec "$2" | grep -Eq -- "$3" && ok "$1" || ng "$1"; }
inh3no(){ h3sec "$2" | grep -Eq -- "$3" && ng "$1" || ok "$1"; }
# (8-1) 採用: 推奨案・代替の残骸がない
insec    '#states: ボタンは採用タグ'                        states '<h3>ボタン <span class="tag">採用</span>'
insec    '#states: loading は薄くしない（opacity を掛けない）' states 'loading</strong>: 寸法を維持し、薄くしない（opacity を掛けない）'
insec    '#states: loading は aria-busy・クリック無効'      states 'aria-busy="true"</code>、クリックは無効'
notinsec '#states: loading の代替（文言のみ「保存中…」）を消した' states '保存中…'
insec    '#spinner: 採用タグ'                               spinner '寸法・色・周期 <span class="tag">採用</span>'
insec    '#spinner: 20px・線 2px・トラック accent-soft・先端 accent・0.9s linear' spinner '20px・線 2px・トラック <code>--accent-soft</code>・先端 <code>--accent</code>・<strong>0\.9s linear</strong>'
notinsec '#spinner: 推奨案タグ・代替が残っていない'        spinner '推奨案|代替'
notinsec '#spinner: 周期 0.8s・sm / md 2 段の案を消した'    spinner '0\.8s|sm / md'
insec    '#spinner: reduced-motion は回転を止め aria-busy・ラベルを残す' spinner '回転を止める</strong>.*aria-busy'
insec    '#soft-ripple: リップルの対象が採用'                soft-ripple 'リップルの対象 <span class="tag">採用</span>'
notinsec '#soft-ripple: 推奨案タグ・代替が残っていない'    soft-ripple '推奨案|代替'
notinsec '#soft-ripple: タブ・セレクトにも付ける案を消した' soft-ripple 'タブやセレクトのトリガにも付ける'
insec    '#soft-ripple: 対象は通常ボタンとアイコンボタンだけ' soft-ripple '通常ボタン（pri / sec / ghost / dan）とクローズ等のアイコンボタンだけ'
insec    '#soft-ripple: 非対象（行型・カード型・テキストリンク・タブ・セレクトのトリガ・スイッチ／ラジオ／スライダー）' soft-ripple '行型・カード型・テキストリンク・タブ・セレクトのトリガ・スイッチ／ラジオ／スライダー'
insec    '#soft-ripple: 押下は背景色・文字色の変化で示す'   soft-ripple '押下は背景色・文字色の変化'
insec    '#soft-ripple: loading 中と reduced-motion では出さない' soft-ripple 'loading 中と reduced-motion では出さない'
# (8-2) --mute-on-soft
insec    '#soft-ripple: --mute-on-soft の定義（新しい HEX を作らない）' soft-ripple 'color-mix\(in srgb, var\(--mute\) 85%, var\(--ink\)\)'
insec    '#soft-ripple: Light ≈ #5c5c5e・約 5.4:1'          soft-ripple 'Light ≈ <code>#5c5c5e</code>.*5\.4:1'
insec    '#soft-ripple: Dark ≈ #9c9c9f・約 5.2:1（--mute のままは 4.29 / 4.22）' soft-ripple 'Dark ≈ <code>#9c9c9f</code>.*5\.2:1.*4\.29 / 4\.22:1'
insec    '#soft-ripple: accent-soft 地の補助文字は --ink か --mute-on-soft、--mute のまま置かない' soft-ripple '<code>--accent-soft</code> を地にする面の補助テキストは <strong><code>--ink</code></strong> か <strong><code>--mute-on-soft</code></strong>。<code>--mute</code> のまま置かない'
insec    '#soft-ripple: 主テキストとの階層は --mute-on-soft' soft-ripple '残したいときは <code>--mute-on-soft</code>'
chk 'index: --mute-on-soft を :root と [data-theme] に定義' ':root,\[data-theme\]\{--mute-on-soft:color-mix\(in srgb,var\(--mute\) 85%,var\(--ink\)\)' "$idx"
chk 'tokens-preview: --mute-on-soft を :root と [data-theme] に定義' ':root,\[data-theme\]\{--mute-on-soft:color-mix\(in srgb,var\(--mute\) 85%,var\(--ink\)\)' "$prev"
! has "$idx" '--mute-on-soft:#' && ! has "$prev" '--mute-on-soft:#' && ok '--mute-on-soft に HEX を直書きしていない' || ng '--mute-on-soft に HEX を直書きしている'
inh3 'tokens-preview #st-soft: --mute-on-soft の見本とライブ計算'   st-soft 'class="s-mos".*data-cr="mos"|data-cr="mos"'
inh3 'tokens-preview #st-soft: Light / Dark を並べた見本'          st-soft 'id="mos-pair"'
inh3 'tokens-preview #st-soft: Light ペインと Dark ペイン'          st-soft 'data-theme="light"'
inh3 'tokens-preview #st-soft: Dark ペイン'                         st-soft 'data-theme="dark"'
# (8-3) ダイアログの本文
insec    '#dialog: 節がある'                                dialog '<h2>ダイアログの本文と閉じ方'
insec    '#dialog: 本文は base 16・行間 1.8'                 dialog '本文は base 16.*base</code>（16px・行間 1\.8）'
insec    '#dialog: 補足・説明文は sm 14、14px 未満を本文にしない' dialog 'sm 14 のままでよい。14px 未満を本文にしない'
grep -Eq '#states \.dlg \.dlg-body\{margin:0;font-size:16px;line-height:1\.8\}' "$prev" && ok 'tokens-preview: ダイアログ本文の CSS が 16px / 1.8' || ng 'tokens-preview: ダイアログ本文の CSS が 16px / 1.8 でない'
grep -Eq '#states \.dlg \.dlg-note\{[^}]*font-size:14px' "$prev" && ok 'tokens-preview: ダイアログの補足は 14px' || ng 'tokens-preview: ダイアログの補足が 14px でない'
# (8-4) モーダルの閉じ方
insec    '#dialog: Esc と外側クリックで閉じる・× も出す'     dialog 'Esc と外側クリック（スクラム）で閉じられる</strong>。× も出す'
insec    '#dialog: 閉じることは確認（acknowledge）扱いにしない' dialog '「確認した（acknowledge）」扱いにしない'
insec    '#dialog: 確認済みにするのは明示のボタンだけ'       dialog '確認済みにするのは明示のボタンだけ'
insec    '#dialog: 止めてよいのは処理中だけ・× を隠すか無効に・戻す' dialog '処理中（送信中・保存中など）だけ</strong>.*処理中は × を隠すか無効に.*終わったら戻す'
insec    '#dialog: 「確認必須だから常に閉じられない」は不可' dialog '「確認必須だから常に閉じられない」は不可'
grep -Eq 'dlg\.addEventListener\(.cancel.,e=>\{if\(busy\)\{e\.preventDefault\(\)' "$prev" && ok 'tokens-preview: 処理中は Esc（cancel）を受けない' || ng 'tokens-preview: 処理中の Esc 無効化がない'
grep -Eq "if\(e\.target===dlg&&!busy\)finish\('外側クリック'\)" "$prev" && ok 'tokens-preview: 外側クリックで閉じる（処理中は除く）' || ng 'tokens-preview: 外側クリックの処理がない'
grep -Eq "xB\.disabled=true" "$prev" && grep -Eq "xB\.disabled=false" "$prev" && ok 'tokens-preview: 処理中は × を無効にし、終わったら戻す' || ng 'tokens-preview: × の無効化と復帰がない'
grep -Eq "okB\.addEventListener\('click',\(\)=>\{if\(busy\)return;\\$\('dlg-ack'\)\.textContent='確認済み'" "$prev" && ok 'tokens-preview: 確認済みになるのは「確認しました」ボタンだけ' || ng 'tokens-preview: 確認ボタンの処理がない'
# (8-5) ペイン型デスクトップアプリの例外
insec    '#pane-app: 節がある（ページ型には当てはめない）'  pane-app 'ペイン型デスクトップアプリの例外.*ページ型の画面には当てはめない'
insec    '#pane-app: ツールバー gap 4（--s-1）・文字ボタン混在は --gap-inline 8' pane-app 'アイコンボタンだけのツールバーは gap 4（<code>--s-1</code>）。文字ボタン混在は <code>--gap-inline</code> 8'
insec    '#pane-app: 複合行の選択リスト 8・素のラジオ行 --gap-option 4' pane-app '項目間 8。素のラジオ行は <code>--gap-option</code> 4'
insec    '#pane-app: ダイアログ内サブセクション --gap-field 16' pane-app 'h4 付きサブセクションの間は <code>--gap-field</code> 16'
insec    '#pane-app: ペイン内 padding --s-4、ガター --s-6 は 12 カラム向け' pane-app '<code>--s-4</code>（モバイル・デスクトップ共通）。ガター <code>--s-6</code> は 12 カラムのページグリッド向け'
insec    '#pane-app: サイドナビの 2 行項目 ~62px・1 行は 40'  pane-app '2 行（名前 sm ＋メール xs の注記）、高さ ~62px まで可。1 行項目は従来の 40'
insec    '#pane-app: ドロップダウン等は項目間 gap 0・パネル padding 4' pane-app '項目間 gap 0、パネル padding 4（<code>--s-1</code>）'
insec    '#pane-app: アカウント識別色の帯 4 / 6 / 8px'       pane-app 'ヘッダー上 4px／行・サイドナビ 6px／差出人バッジ 8px'
insec    '#pane-app: スウォッチ選択は 2px の --ink・フォーカスは --focus' pane-app '2px の <code>--ink</code>.*<code>--focus</code> リング'
insec    '#pane-app: 見出しの段 lg 18 / h3 base 16 / h4 sm 14（SemiBold）' pane-app 'モーダルの題 lg 18／h3 base 16／h4 sm 14（いずれも SemiBold）'
insec    '#pane-app: インラインアラートの題は SemiBold・sm'  pane-app '見出し扱いで SemiBold・sm'
insec    '#pane-app: トーストのタイマーは入場アニメ後に数える' pane-app '入場アニメーションが終わってから数える'
insec    '#pane-app: お知らせのロックは処理中だけ'          pane-app '閉じる操作を止めるのは処理中だけ'
inh3 'tokens-preview #st-pane: ページ型には当てはめない（3 ペイン）' st-pane 'ページ型の画面には当てはめない'
grep -Eq '#states \.tbr\{display:flex;align-items:center;gap:var\(--s-1\)\}#states \.tbr\.tx\{gap:var\(--gap-inline\)\}' "$prev" && ok 'tokens-preview: ツールバー gap --s-1 / 文字混在 --gap-inline' || ng 'tokens-preview: ツールバー gap の CSS がない'
grep -Eq '#states \.nv a\.acct\{[^}]*min-height:62px[^}]*border-left:6px' "$prev" && ok 'tokens-preview: 2 行項目 62px・帯 6px' || ng 'tokens-preview: 2 行項目 62px・帯 6px の CSS がない'
grep -Eq '#states \.dpn\{[^}]*gap:0;padding:var\(--s-1\)' "$prev" && ok 'tokens-preview: ドロップダウン gap 0・padding --s-1' || ng 'tokens-preview: ドロップダウン gap 0・padding の CSS がない'
grep -Eq '#states \.sws button\[aria-pressed=true\]\{border-color:var\(--ink\)\}' "$prev" && ok 'tokens-preview: スウォッチ選択は --ink の 2px' || ng 'tokens-preview: スウォッチ選択の CSS がない'
# (8-6) Hitomado #283〜#287 の残り。未確定だった 4 件は決定済み（採用）。「未確定」「判断待ち」「案」を残さない
decided=$(sec proposals | awk '/id="decided"/{f=1} f{print} f&&/<\/table>/{exit}')
n=$(printf '%s\n' "$decided" | grep -o '<td><span class="tag">採用</span></td>' | wc -l)
[ "$n" -eq 4 ] && ok "#proposals: 決定の行が採用 4 件（$n）" || ng "#proposals: 決定の行が採用 4 件でない（$n）"
insec    '#proposals: 決定 4 件の枠は 採用' proposals 'id="decided"><span class="tag">採用</span>'
notinsec '#proposals: 「未確定」「判断待ち」「案:」が残っていない' proposals 'id="pending"|判断待ち|<span class="tag">未確定</span>|案: base|案 a'
indec() { printf '%s\n' "$decided" | grep -Eq -- "$2" && ok "$1" || ng "$1"; }
indec    '#proposals: スイッチのラベルは base 16（15 は使わない）' 'スイッチのラベルのサイズ</td><td>base 16（Regular）。15 はスケールに無いので使わない'
indec    '#proposals: 入力は基本 16・狭い設定ペインだけ sm 14 可・モバイル 640px 以下は必ず 16（iOS の自動拡大）' 'フォーム入力の文字サイズ</td><td>基本は base 16。設定ペインのような狭い場所だけ sm 14 も可。モバイル（<code>--bp-sm</code> 640px 以下）では必ず 16（iOS の自動拡大を防ぐため）'
indec    '#proposals: 使えないメニュー項目は .4（ボタンの disabled と同じ）・.5 は使わない' '使えないメニュー項目の opacity</td><td><code>\.4</code>（ボタンの disabled と同じ値）。<code>\.5</code> は使わない'
indec    '#proposals: 全幅バナーはアニメーションなしで即時' '全幅バナーの出入り</td><td>アニメーションなしで、すぐ出す・すぐ消す'
insec    '#controls: スイッチのラベルは base 16（採用）' controls 'サイズは base 16 <span class="tag">採用</span>'
notinsec '#controls: 「Regular 15」を規範として残していない' controls 'ラベルは Regular 15'
! has "$idx" '#pending|id="pending"' && ! has "$prev" 'st-pending|悠太さんの判断待ち' && ok 'index / tokens-preview: 旧 #pending / #st-pending と「判断待ち」を残していない' || ng 'index / tokens-preview: 旧 #pending / #st-pending か「判断待ち」が残っている'
insec    '#proposals: --font-mono の日本語フォールバック'    proposals '"JetBrains Mono", "Noto Sans JP", ui-monospace, monospace'
insec    '#proposals: Variable 版の family 名を許容'         proposals '"Sora Variable"'
insec    '#proposals: 入力下の補足 1 文は xs・複数文は sm'   proposals '1 文の注記は xs、複数文の補足は sm'
insec    '#proposals: 単独ラベルの数字は桁が変わる値だけ Mono' proposals '桁が変わり並べて比べる値だけ Mono'
insec    '#proposals: リッチテキストの太字は 600'            proposals '太字は 600'
insec    '#proposals: --label-col 72〜96px'                  proposals '--label-col</code>（72〜96px'
insec    '#proposals: モバイルのトップバー左右 padding --s-4'  proposals 'トップバーの左右 padding は <code>--s-4</code> 16'
insec    '#proposals: タブ（40・--s-3・下線 2px --accent・非選択 mute・hover ink）' proposals 'タブ</strong>: 高さ 40、左右 padding <code>--s-3</code> 12.*下線 2px <code>--accent</code>、非選択 <code>--mute</code>・ホバー <code>--ink</code>'
insec    '#proposals: --bp-* と JS 定数 BP_SM の対応表'      proposals '<code>BP_SM</code>.*<code>BP_XL</code>'
insec    '#proposals: トグル pressed は accent-soft 地＋ink'  proposals 'aria-pressed="true"</code> で <code>--accent-soft</code> 地＋<code>--ink</code> 文字'
insec    '#proposals: 主ボタンのホバーは accent を bone へ 15%' proposals 'color-mix\(in srgb, var\(--accent\) 85%, var\(--bone\)\)'
insec    '#proposals: スイッチ OFF のつまみ・枠 mute 案は見本で確認' proposals 'スイッチ OFF のつまみ.*surface.*枠を <code>--mute</code> にする案'
insec    '#proposals: ドロップダウンのリングは :focus-visible のときだけ 2px・offset 2' proposals ':focus-visible</code> のときだけ 2px <code>--focus</code>・offset 2'
insec    '#proposals: メニュー・ナビ項目の角丸 --r-sm'       proposals 'メニュー・ナビ項目の角丸は <code>--r-sm</code>'
insec    '#proposals: ショートカット表記は Mono・xs・mute（強調行は mute-on-soft）' proposals 'Mono・xs・<code>--mute</code>（強調行では <code>--mute-on-soft</code>）'
insec    '#proposals: アコーディオンのシェブロン 180°・reduced-motion' proposals '180° 回転・<code>--motion-base</code>'
insec    '#proposals: title 属性は使わずツールチップに統一'  proposals '標準の <code>title</code> 属性は使わず'
insec    '#proposals: ツールチップ遅延 400ms・--tip-pad-y/x'  proposals '表示遅延 400ms（フォーカス時は即時）.*--tip-pad-y: 6px.*--tip-pad-x: 10px'
insec    '#proposals: --toast-duration 3s / --toast-duration-action 5s' proposals '--toast-duration</code> 3s / <code>--toast-duration-action</code> 5s'
insec    '#proposals: トーストの先頭アイコンは成功・お知らせのみ 16px' proposals '成功・お知らせのみ可、16px（<code>--icon-sm</code>）'
insec    '#proposals: インラインアラート --r-md・12×16'      proposals '角丸 <code>--r-md</code>、padding 12×16'
insec    '#proposals: 読み込みはスピナー単体・2 秒以上は「読み込み中…」' proposals '領域の中央にスピナー単体。2 秒以上かかる場合は下に「読み込み中…」を xs'
insec    '#proposals: 文字数カウンタ xs・mute・Mono・danger・role=status' proposals '入力下の文字数カウンタ: xs・<code>--mute</code>・数字は Mono、超過は <code>--danger</code>、<code>role="status"</code>'
insec    '#proposals: ドロワー dialog・aria-modal・フォーカス・Esc' proposals 'role="dialog"</code>・<code>aria-modal="true"</code>.*フォーカストラップ、Esc'
insec    '#proposals: ドロワー幅 78vw・上限 320px・fade＋8px'  proposals '78vw・上限 320px。出入りは fade＋8px の移動'
insec    '#proposals: ドロップ先はドラッグ中だけ accent-soft＋破線' proposals 'ドラッグ中だけ <code>--accent-soft</code> 地＋1px <code>--accent</code> の破線（内側 offset 4）'
insec    '#proposals: リサイズハンドルは --z-sticky を流用'   proposals 'リサイズハンドルは <code>--z-sticky</code> を流用'
chk 'tokens-preview: --tip-pad-y / --toast-duration を定義' ':root\{--tip-pad-y:6px;--tip-pad-x:10px;--toast-duration:3s;--toast-duration-action:5s\}' "$prev"
inh3 'tokens-preview #st-decided: 4 件の見本（スイッチ・入力・メニュー・バナー）' st-decided 'class="sw2"'
for k in 'class="fld f14"' 'role="menuitem" disabled' 'id="bn-t"' 'id="bn-i"'; do
  inh3 "tokens-preview #st-decided: 見本 $k" st-decided "$k"
done
inh3no 'tokens-preview #st-decided: 比較用の案（l14 / o4 / o5 / 案 a・b）を置かない' st-decided 'sw2 l1[46]|dpn o[45]|bn-ia|bn-ib|fadeh|案 [ab]'
for k in 'class="mono14"' 'class="tb40"' 'id="tgl"' 'class="tipw"' 'id="cnt-in"' 'class="ld"' 'id="dz"' 'class="lblrow"'; do
  inh3 "tokens-preview #proposals-draft: 見本 $k" proposals-draft "$k"
done

# (7) ヘッダー: 切替ラベルを折らない／バッジは ≤720px で隠す（PR #11 再チェック）
chk 'ヘッダー（index）: 720px 以下でバッジを非表示（481〜720px で切替が縦に折れない）' '@media\(max-width:720px\)\{\.badge\{display:none\}\}' "$idx"
! has "$idx" '@media\(max-width:480px\)\{\.badge' && ok 'ヘッダー（index）: 旧 480px のバッジ規則を残さない' || ng 'ヘッダー（index）: 旧 480px のバッジ規則が残っている'
chk 'ヘッダー（index）: .seg button は white-space:nowrap' '\.seg button\{[^}]*white-space:nowrap' "$idx"
chk 'ヘッダー（tokens-preview）: .seg button は white-space:nowrap' '\.seg button\{[^}]*white-space:nowrap' "$prev"

# (9) PR #15 レビュー反映（#14）: 本文リンクの色・主ボタン hover・ペイン型の例外の行数
# P2-1: index の本文リンクはブラウザ既定の青にしない（Dark で 2.17:1）。tokens-preview の a に合わせて ink、下線は mute
chk 'index: a は color:var(--ink)・下線の色は var(--mute)（既定の青にしない）' '^a\{color:var\(--ink\);text-decoration-color:var\(--mute\);text-underline-offset:3px\}' "$idx"
chk 'tokens-preview: a は color:var(--ink)（index がそろえる元）' '^a\{color:var\(--ink\);text-underline-offset:3px\}' "$prev"
# P2-2: 主ボタンの hover は色だけ（採用済みの color-mix）。opacity を使わない（実 hover と固定見本の両方）
chk 'tokens-preview: 主ボタンの実 hover は accent 85% / bone の color-mix' '\.pri:not\(:disabled\):hover\{background:color-mix\(in srgb,var\(--accent\) 85%,var\(--bone\)\)\}' "$prev"
chk 'tokens-preview: 主ボタンの固定 hover 見本（.is-hover.pri）も同じ color-mix' '\.ui \.btn\.is-hover\.pri\{background:color-mix\(in srgb,var\(--accent\) 85%,var\(--bone\)\)\}' "$prev"
! has "$prev" '\.is-hover\.pri\{[^}]*opacity' && ok 'tokens-preview: .is-hover.pri に opacity を使わない' || ng 'tokens-preview: .is-hover.pri に opacity が残っている'
! has "$prev" '\.btn:hover\{opacity|\.pri:hover\{[^}]*opacity|\.btn\.pri[^{]*:hover\{[^}]*opacity:\.85' && ok 'tokens-preview: 主ボタンの hover に opacity .85 を掛けない' || ng 'tokens-preview: 主ボタンの hover に opacity が掛かっている'
chk 'tokens-preview: loading 中の主ボタンは hover で色を変えない' '\.ui \.btn\.pri\.is-loading:hover\{background:var\(--accent\)\}' "$prev"
! has "$prev" 'mixh' && ok 'tokens-preview: 主ボタン hover の別枠 .mixh を残さない（現行見本と同じ値）' || ng 'tokens-preview: .mixh が残っている'
# P3: ペイン型の例外の表は 12 行。本文の「13 項目」（thead を含めた数え間違い）を残さない
n=$(sec pane-app | grep -c '<tr><td>')
[ "$n" -eq 12 ] && ok "#pane-app: 表の行が 12（$n）" || ng "#pane-app: 表の行が 12 でない（$n）"
! has "$idx" '13 ?項目' && ! has "$prev" '13 ?項目' && ok 'index / tokens-preview: 「13 項目」と書いていない' || ng 'index / tokens-preview: 「13 項目」が残っている'

# (10) PR #15 fix2: 未確定だった 4 件の決定を CSS で担保する（回帰）
# 1. スイッチのラベルは 16（15 はスケールに無い）
chk 'tokens-preview: .sw2 のラベルは 16px' '\.sw2\{[^}]*font-size:16px\}' "$prev"
! has "$prev" '\.sw2\{[^}]*font-size:15px' && ok 'tokens-preview: .sw2 に 15px を使わない' || ng 'tokens-preview: .sw2 に 15px が残っている'
# 2. 入力: 基本 16（.fld）。狭い場所だけ 14（.f14）。モバイル（640px 以下）は必ず 16
chk 'tokens-preview: .fld の基本は 16px' '\.ui \.fld\{[^}]*font:400 16px' "$prev"
chk 'tokens-preview: 狭い場所だけ使う .fld.f14 は 14px' '#states \.fld\.f14\{font-size:14px\}' "$prev"
chk 'tokens-preview: 640px 以下は .fld.f14 も 16px（iOS の自動拡大を防ぐ）' '@media \(max-width:640px\)\{#states \.fld\.f14\{font-size:16px\}\}' "$prev"
# 3. 使えないメニュー項目は opacity .4（ボタンの disabled と同じ）。.5 は使わない。ホバーに反応しない
chk 'tokens-preview: 使えないメニュー項目は opacity .4' '#states \.dpn button:disabled\{opacity:\.4;cursor:not-allowed\}' "$prev"
chk 'tokens-preview: 使えないメニュー項目はホバーで背景が付かない' '#states \.dpn button:disabled:hover\{background:transparent\}' "$prev"
! has "$prev" 'dpn\.o[45]' && ok 'tokens-preview: 比較用の .dpn.o4 / .o5 を残さない' || ng 'tokens-preview: .dpn.o4 / .o5 が残っている'
# 4. 全幅バナーはアニメーションなし（即時）
chk 'tokens-preview: バナーは .off で display:none（即時）' '#states \.bn\.off\{display:none\}' "$prev"
! has "$prev" '#states \.bn[^{]*\{[^}]*transition' && ! has "$prev" 'fadeh' && ok 'tokens-preview: バナーに transition・フェード（fadeh）を使わない' || ng 'tokens-preview: バナーに transition かフェードが残っている'

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
  chk "$n: アイコンだけは見える部分 38×38 のボタン（外枠 padding 3px）" '\.seg-icon\{padding:3px\}\.seg-icon button\{[^}]*width:38px;height:38px' "$f"
  chk "$n: アイコンだけのラベルは視覚的に隠し、hover / focus-visible で吹き出しに出す" '\.seg-icon \.lb\{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect\(0 0 0 0\)' "$f"
  chk "$n: アイコンだけのツールチップは hover と focus-visible の両方" '\.seg-icon button:is\(:hover,:focus-visible\) \.lb\{' "$f"
  chk "$n: 縦積みは 1 行 44px 以上" '\.seg-stack button\{[^}]*min-height:44px' "$f"
  chk "$n: 縦積みはラジオ印（18px の円・6px の点）" '\.seg-stack button::after\{[^}]*width:18px;height:18px.*radial-gradient\(circle,var\(--bone\) 0 3px' "$f"
  chk "$n: 文字付きは見た目を変えずタップ領域だけ 44px 以上（::before で縦に広げる）" '\.seg button::before\{content:"";position:absolute;inset:-8px 0\}' "$f"
  chk "$n: forced-colors で縦積みのラジオ印も HighlightText" 'forced-colors:active\)\{.*\.seg-stack button\[aria-pressed=true\]::after\{border-color:HighlightText;background:radial-gradient\(circle,HighlightText' "$f"
  chk "$n: 選択中は Highlight / HighlightText（全形共通）" '\.seg button\[aria-pressed=true\]\{background:Highlight;color:HighlightText;forced-color-adjust:none\}' "$f"
  chk "$n: ヘッダーのアイコンだけ形のツールチップ（≤480px）" '\.top \.seg button:is\(:hover,:focus-visible\) \.lb\{' "$f"
  chk "$n: フォーカスの実線リング（3px・offset 2px）を維持" '\.seg button:focus-visible\{outline:3px solid var\(--focus\);outline-offset:2px\}' "$f"
  # --- 直し 1 回目（PR #13 レビュー P2-1〜P3-3）。aa4129d では FAIL する ---
  chk "$n: P2-1 アイコンだけのタップ範囲は ::before の inset:-3px で 44px を保つ" '\.seg-icon button::before\{inset:-3px\}' "$f"
  chk "$n: P2-1 ヘッダー（≤480px）も ::before の inset:-3px でタップ範囲 44px" '\.top \.seg button::before\{inset:-3px\}' "$f"
  chk "$n: P2-2 アイコンだけの吹き出しは padding 6×10・角丸 4px・Regular 400・320ms フェードイン" '\.seg-icon button:is\(:hover,:focus-visible\) \.lb\{[^}]*padding:6px 10px;border-radius:4px;[^}]*font:400 12px[^}]*animation:seg-tip 320ms' "$f"
  chk "$n: P2-2 ヘッダー（≤480px）の吹き出しも同じ（6×10・4px・400・320ms）" '\.top \.seg button:is\(:hover,:focus-visible\) \.lb\{[^}]*padding:6px 10px;border-radius:4px;[^}]*font:400 12px[^}]*animation:seg-tip 320ms' "$f"
  chk "$n: P2-2 フェードイン（@keyframes seg-tip）と reduced-motion でアニメなし" '@keyframes seg-tip\{from\{opacity:0\}\}' "$f"
  chk "$n: P2-2 reduced-motion では吹き出しのアニメを止める" '@media\(prefers-reduced-motion:reduce\)\{\.seg \.lb\{animation:none!important\}\}' "$f"
  ! has "$f" 'border:1px solid var\(--ink\);border-radius:6px' && ok "$n: P2-2 旧い吹き出し（枠 1px・角丸 6px・600）を残さない" || ng "$n: P2-2 旧い吹き出しの指定が残っている"
  chk "$n: P2-3 縦積みの選択中の行は --accent-soft の地＋--ink の文字" '\.seg-stack button\[aria-pressed=true\]\{background:var\(--accent-soft\);color:var\(--ink\)\}' "$f"
  chk "$n: P2-3 縦積みはラジオ印の円だけ --accent で塗る（点は --bone）" '\.seg-stack button\[aria-pressed=true\]::after\{border-color:var\(--accent\);background:radial-gradient\(circle,var\(--bone\) 0 3px,var\(--accent\) 3\.5px\)' "$f"
  chk "$n: P3-1 文字付き見本の注記（右端が切れる）の置き場" '\.sgrid \.scr-note\{width:0;min-width:100%\}' "$f"
  grep -E 'class="(sub|help) scr-note"[^>]*>[^<]*右端（「システム」）が切れて' "$f" | grep -q . && ok "$n: P3-1 320px の見本に「システムが切れる」注記がある" || ng "$n: P3-1 見本に注記がない"
  chk "$n: P3-3 forced-colors でアイコンだけの吹き出しに 1px solid CanvasText の枠" 'forced-colors:active\)\{.*\.seg-icon button:is\(:hover,:focus-visible\) \.lb\{border:1px solid CanvasText;background:Canvas;color:CanvasText\}' "$f"
  chk "$n: P3-3 forced-colors でヘッダー（≤480px）の吹き出しにも枠" '@media\(forced-colors:active\) and \(max-width:480px\)\{\.top \.seg button:is\(:hover,:focus-visible\) \.lb\{border:1px solid CanvasText' "$f"
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
insec '#theme-forms: タップ範囲は縦 44px（アイコンだけ）' theme '縦 44px</strong> を保つ'
insec '#theme-forms: P2-1 見える部分 38×38 とタップ範囲（::before inset -3px）' theme '<strong>38×38px</strong>.*inset: -3px.*<strong>縦 44px</strong>'
insec '#theme-forms: P2-2 吹き出しは Tooltip の規定（6×10・角丸 4px・Regular・320ms・reduced-motion・forced-colors）' theme 'padding 6×10・角丸 4px・<code>--ink</code> 地に <code>--bone</code> 文字・320ms のフェードイン。<code>prefers-reduced-motion: reduce</code> ではアニメなし。<code>forced-colors: active</code> では <code>1px solid CanvasText</code>'
insec '#theme-forms: P2-3 縦積みの選択中は --accent-soft の行＋--ink、ラジオの円だけ塗る' theme '縦積みは行を <code>--accent-soft</code> の地＋<code>--ink</code> の文字にし、<strong>ラジオ印の円だけ</strong>'
insec '#theme-forms: 使い分け表の幅は見える 38px × 3（約 122px）' theme '約 122px（見える 38px × 3'
thm_prev | grep -q '約 122px（見える 38px × 3' && ok 'tokens-preview #st-theme: 使い分け表の幅は約 122px' || ng 'tokens-preview #st-theme: 使い分け表の幅が 3×44px のまま'
# 採用済みの文言は変えない（3 モードの箇条書き・ヘッダー見本の ≤480px 記述）
insec '#theme: 採用済み「狭い幅（≤480px）ではアイコンのみ（ラベルは読み上げ用に残す）」を変えていない' theme '狭い幅（≤480px）ではアイコンのみ（ラベルは読み上げ用に残す）'
thm_prev | grep -q 'id="st-theme-forms"' && thm_prev | grep -q '推奨案' && ok 'tokens-preview #st-theme: 3 形の見本ブロック（推奨案）' || ng 'tokens-preview #st-theme: 3 形の見本ブロックがない'
thm_prev | grep -Eq '決定済み:</strong> 「アイコンだけ」と「縦積み」の<strong>両方を定義し、置く場所で使い分ける</strong>' && ok 'tokens-preview #st-theme: 両方を定義して場所で使い分けるのは決定済み' || ng 'tokens-preview #st-theme: 決定済みの明記がない'
thm_prev | grep -Eq '<th>置く場所</th><th>形</th>' && ok 'tokens-preview #st-theme: 使い分け表' || ng 'tokens-preview #st-theme: 使い分け表がない'
thm_prev | grep -q 'id="theme-forms-demo"' && ok 'tokens-preview #st-theme: 3 形の見本が #st-theme の中にある' || ng 'tokens-preview #st-theme: 見本が #st-theme の外にある'
chk '#st-theme は採用のまま（新ブロックだけ推奨案）' '<h3 id="st-theme">[^<]*<span class="tag">採用</span></h3>' "$prev"
chk 'theme.js: 保存キーは ousiass-theme のまま' "KEY = 'ousiass-theme'" "$thm"

# (11) Issue #16: puppet-remo 由来の部品 5 種（見出し付きカード・秘密の入力欄・題なしアラート・fieldset 見出し・前へ/次へのページ送り）
insec    '#puppet-parts: 節がある（puppet-remo#148〜#152 を参照）'  puppet-parts 'puppet-remo#148〜#152'
for id in parts-card parts-secret parts-notice parts-fieldset parts-pager; do
  sec puppet-parts | grep -Eq "<h3 id=\"$id\">[^<]*<span class=\"tag\">採用</span></h3>" && ok "#puppet-parts: #$id が採用" || ng "#puppet-parts: #$id が採用になっていない"
done
# 1. 見出し付きカード
insec    '#puppet-parts: カードの題は lg 18 SemiBold・タグは h2 / h3 のどちらでもよい（タグとサイズは独立）' puppet-parts '題は lg 18 SemiBold。タグは h2 / h3 のどちらでもよい（<strong>タグと表示サイズは独立</strong>'
insec    '#puppet-parts: カードの題の下に --border の 1px の線'   puppet-parts '題の下に <code>--border</code> の 1px の線'
insec    '#puppet-parts: カードの本文 padding --s-6（24）・影なし' puppet-parts '本文の padding は <code>--s-6</code>（24）。<strong>影は付けない</strong>'
# 2. 秘密の入力欄
insec    '#puppet-parts: 保存済みの値・伏せ字を描画しない'          puppet-parts '保存済みの値は描画しない</strong>。伏せ字（●●●）も描画しない'
insec    '#puppet-parts: 登録済みバッジは accent-soft 地＋mute-on-soft 文字・xs 12' puppet-parts '<code>--accent-soft</code> 地＋<code>--mute-on-soft</code> 文字、xs 12'
insec    '#puppet-parts: 「変更」で空の入力欄・入力文字は base 16'  puppet-parts '「変更」ボタンを押すと<strong>空の入力欄</strong>になる。入力文字は base 16'
insec    '#puppet-parts: 表示切り替えは Iconoir の Eye / EyeClosed のアイコンボタン' puppet-parts 'Iconoir の <strong>Eye</strong>.*<strong>EyeClosed</strong>.*アイコンボタン'
# 3. 題なしのインラインアラート
insec    '#puppet-parts: 題なしアラートは既存と同じ形（--r-md・padding 12×16）・アイコン 16＋本文 sm 14・題なし' puppet-parts '角丸 <code>--r-md</code>、padding 12×16）。アイコン 16 ＋ 本文 sm 14。<strong>題は付けない</strong>'
insec    '#puppet-parts: 題なしアラートは常設の注意書き・同意の枠に使う' puppet-parts '常設の注意書き・同意の枠に使う'
# 4. fieldset / legend
insec    '#puppet-parts: legend は h4 の段（sm 14 SemiBold）'        puppet-parts 'legend は <strong>h4 の段（sm 14 SemiBold）</strong>'
insec    '#puppet-parts: グループの上に --border の線・グループ間 --gap-field' puppet-parts 'グループの上に <code>--border</code> の 1px の線。グループ間の間隔は <code>--gap-field</code>'
# 5. 前へ／次へのページ送り
insec    '#puppet-parts: 件数が分からない一覧向けの簡易形'          puppet-parts '全体の件数が分からない一覧（ログなど）向けの簡易形として許可する'
insec    '#puppet-parts: 中央に「N ページ目」を sm 14・--mute'      puppet-parts '中央に「N ページ目」を sm 14・<code>--mute</code>'
insec    '#puppet-parts: 端ではその側のボタンを disabled（opacity .4）' puppet-parts '端ではその側のボタンを disabled にする（opacity <code>\.4</code>'
chk      'index: ジャンプ行に #puppet-parts のリンク'               '<a href="#puppet-parts">puppet-remo 部品</a>' "$idx"
# tokens-preview の見本（Light / Dark は共通トークンで切り替わる。値は CSS で担保）
grep -Eq '<h3 id="st-parts">[^<]*<span class="tag">採用</span></h3>' "$prev" && ok 'tokens-preview: #st-parts が採用' || ng 'tokens-preview: #st-parts が採用になっていない'
for k in 'class="np-card"' 'id="np-sec-change"' 'id="np-eye"' 'class="e-open"' 'class="e-closed"' 'class="al np-note"' '<fieldset class="np-fs">' '<legend>' 'id="np-pg-prev"' 'id="np-pg-next"' 'id="np-pg-n"'; do
  inh3 "tokens-preview #st-parts: 見本 $k" st-parts "$k"
done
inh3     'tokens-preview #st-parts: 秘密の入力欄は value を描画しない（伏せ字・自動入力停止）' st-parts 'id="np-sec-in" name="api_key" type="password" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder'
inh3no   'tokens-preview #st-parts: 秘密の入力欄に value 属性を書かない' st-parts 'id="np-sec-in"[^>]* value='
chk      'tokens-preview: カードの題 lg 18 SemiBold・下に 1px の線'  '#states \.np-card-t\{[^}]*padding:var\(--s-4\) var\(--s-6\)[^}]*border-bottom:1px solid var\(--border\)[^}]*font-size:18px;font-weight:600' "$prev"
chk      'tokens-preview: カードの本文 padding --s-6'                '#states \.np-card-b\{padding:var\(--s-6\)' "$prev"
! has "$prev" '#states \.np-card\{[^}]*shadow' && ok 'tokens-preview: カードに影を付けない' || ng 'tokens-preview: カードに影が付いている'
chk      'tokens-preview: 登録済みバッジは accent-soft 地＋mute-on-soft・xs 12' '#states \.np-badge\{[^}]*background:var\(--accent-soft\);color:var\(--mute-on-soft\);font-size:12px' "$prev"
chk      'tokens-preview: 題なしアラートのアイコンは 16px'           '#states \.np-note svg\{width:16px;height:16px' "$prev"
chk      'tokens-preview: legend は sm 14 SemiBold'                  '#states \.np-fs legend\{[^}]*font-size:14px;font-weight:600' "$prev"
chk      'tokens-preview: fieldset は上に --border の 1px・間隔は --gap-field' '#states \.np-fs\{[^}]*border-top:1px solid var\(--border\)[^}]*gap:var\(--gap-field\)' "$prev"
chk      'tokens-preview: ページ送りの「N ページ目」は sm 14・--mute'  '#states \.np-pg-n\{font-size:14px;color:var\(--mute\)\}' "$prev"

exit $fail
