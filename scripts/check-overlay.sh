#!/usr/bin/env bash
# check-overlay.sh — Issue #18（重ね塗り（写真の上）の専用色）の回帰チェック。
# 依存なし（grep・awk と exit code のみ）。使い方: scripts/check-overlay.sh [リポジトリルート]
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
idx="$root/index.html"
fail=0
ok() { printf 'PASS  %s\n' "$1"; }
ng() { printf 'FAIL  %s\n' "$1"; fail=1; }
has() { grep -Eq -- "$2" "$1"; }
chk() { if has "$3" "$2"; then ok "$1"; else ng "$1"; fi; }

# #overlay 節だけを取り出す（他の節の同じ語で誤って通らないように）
ov=$(awk '/<section id="overlay"/{f=1} f{print} f&&/<\/section>/{exit}' "$idx")
inov() { if printf '%s' "$ov" | grep -Eq -- "$2"; then ok "$1"; else ng "$1"; fi; }
notov() { if printf '%s' "$ov" | grep -Eq -- "$2"; then ng "$1"; else ok "$1"; fi; }

# (1) 節の有無と位置: 状態色の次、Do / Don't の前
[ -n "$ov" ] && ok 'index.html に #overlay 節がある' || ng 'index.html に #overlay 節がない'
inov '節の題は「重ね塗り（写真の上）」' '<h2>重ね塗り（写真の上）'
order=$(grep -n -o '<section><h2>状態色</h2>\|<section id="overlay"\|<section><h2>Do / Don' "$idx" | cut -d: -f2- | tr '\n' ' ')
[ "$order" = '<section><h2>状態色</h2> <section id="overlay" <section><h2>Do / Don ' ] && ok '節の順は 状態色 → 重ね塗り → Do / Don'"'"'t' || ng "節の順が違う: $order"
chk '先頭のジャンプ導線に #overlay がある' '<a href="#overlay">重ね塗り</a>' "$idx"

# (2) トークン: 値・定数（テーマで変えない）
chk '--overlay-deep は #5a0000'  '^:root,\[data-theme\]\{[^}]*--overlay-deep:#5a0000[;}]' "$idx"
chk '--overlay-pale は #ff8c96'  '^:root,\[data-theme\]\{[^}]*--overlay-pale:#ff8c96[;}]' "$idx"
[ "$(grep -o -- '--overlay-deep:' "$idx" | wc -l)" -eq 1 ] && [ "$(grep -o -- '--overlay-pale:' "$idx" | wc -l)" -eq 1 ] && ok 'トークンの定義は 1 か所ずつ（テーマ別に値を持たない）' || ng 'トークンが複数か所で定義されている'
grep -E '^(:root\{|\[data-theme=dark\]\{)' "$idx" | grep -q -- '--overlay' && ng 'ライト／ダーク別の規則に --overlay がある' || ok 'ライト／ダーク別の規則に --overlay がない'

# (3) 既存の状態色・--danger の値は変えない
chk '--danger（Light #7a4545）を維持' '^:root\{[^}]*--danger:#7a4545' "$idx"
chk '--danger（Dark #c49a9a）を維持'  '^\[data-theme=dark\]\{[^}]*--danger:#c49a9a' "$idx"
chk '状態色（Light）を維持' '^:root\{[^}]*--success:#3d5c4a;--warning:#7a6a3a;--danger:#7a4545;--info:#4a5a6a' "$idx"
chk '状態色（Dark）を維持'  '^\[data-theme=dark\]\{[^}]*--success:#8fafa0;--warning:#c4b87a;--danger:#c49a9a;--info:#9aabbc' "$idx"

# (4) 規定の中身（Issue #18 の決めごと）
inov '状態色には混ぜず独立した節'                 '状態色には混ぜず、独立した節'
inov '状態色より彩度がある・エラー色と取り違えやすい' '状態色より彩度がある。エラー色と並べると取り違えやすい'
inov '--danger は使わない（面用で写真の上では見えなくなる）' '<code>--danger</code> は使わない。.*面（カード・文字）用.*下地によって見えなくなる'
inov '選び方: 16×16 の平均の相対輝度・境 0.11'     '16×16 に写して平均の相対輝度.*境は <strong>0\.11</strong>'
inov '0.11 以上は deep・より暗いときは pale'       '0\.11 以上は <code>--overlay-deep</code>、より暗いときは <code>--overlay-pale</code>'
inov '輝度が読めない写真も deep'                   '輝度が読めない写真も deep'
inov '不透明度は .55'                              '不透明度は <strong>\.55</strong>'
inov 'ライト／ダークで変えない定数'                'ライト／ダークで値を変えない定数'
inov '他プロダクトも同じトークン・独自色は作らない' '他プロダクトが写真の上に塗るときも同じトークンを使う。独自色は作らない'
inov '制限: 中間調（0.02〜0.4）で 3:1 に届かない'  '中間調の写真（相対輝度およそ 0\.02〜0\.4）では、半透明の 1 色だけではコントラスト 3:1 に届かない'
inov '制限: 不透明度を上げる・縁取りを足す案は採らない' '不透明度を上げる・縁取りを足す案は採らない'
notov '節の中で状態色トークンを使っていない'      'var\(--(success|warning|danger|info)\)'

# (5) 見本: 明るい写真・暗い写真 × deep・pale（.55）
[ "$(printf '%s' "$ov" | grep -o 'class="ov-ph ov-bright"' | wc -l)" -eq 2 ] && ok '明るい写真の見本が 2 つ（deep・pale）' || ng '明るい写真の見本が 2 つでない'
[ "$(printf '%s' "$ov" | grep -o 'class="ov-ph ov-dark"' | wc -l)" -eq 2 ] && ok '暗い写真の見本が 2 つ（deep・pale）' || ng '暗い写真の見本が 2 つでない'
[ "$(printf '%s' "$ov" | grep -o 'stroke:var(--overlay-deep)' | wc -l)" -eq 2 ] && [ "$(printf '%s' "$ov" | grep -o 'stroke:var(--overlay-pale)' | wc -l)" -eq 2 ] && ok '見本の塗りはトークンを読む（deep 2・pale 2。直書きしない）' || ng '見本の塗りがトークンを読んでいない'
chk '見本の塗りは不透明度 .55' '\.ov-ph path\{[^}]*opacity:\.55' "$idx"

# (6) トークン表: 名前・HEX・用途・テーマで変えないこと
inov 'トークン表の列（名前・HEX・用途・テーマで変えるか）' '<th>名前</th><th>HEX</th><th>用途</th><th>テーマで変えるか</th>'
inov '表: --overlay-deep #5a0000 の行'  '<code>--overlay-deep</code>.*data-hex="#5a0000".*変えない'
inov '表: --overlay-pale #ff8c96 の行'  '<code>--overlay-pale</code>.*data-hex="#ff8c96".*変えない'

exit $fail
