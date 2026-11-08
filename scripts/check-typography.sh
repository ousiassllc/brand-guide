#!/usr/bin/env bash
# check-typography.sh — Issue #2（見出しタグと表示サイズの分離）の回帰チェック。
# 依存なし（grep と exit code のみ）。使い方: scripts/check-typography.sh [リポジトリルート]
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
idx="$root/index.html"; prev="$root/tokens-preview.html"
fail=0
ok()  { printf 'PASS  %s\n' "$1"; }
ng()  { printf 'FAIL  %s\n' "$1"; fail=1; }
has() { grep -Eq -- "$2" "$1"; }

# #typography 節だけを取り出す（次の <section> まで）
ty=$(awk '/<section id="typography"/{f=1} f{print} f&&/<\/section>/{exit}' "$idx")
tyhas() { printf '%s' "$ty" | grep -Eq -- "$1"; }

# (1) サイズ表の用途は「例示」であり、h1・ヒーロー等がタグとの必須対応に読めない
tyhas '<th>用途（例）</th>' && ok 'サイズ表の列名が「用途（例）」' || ng 'サイズ表の列名が「用途（例）」でない'
tyhas '独立して指定' && ok 'タグと表示サイズの独立を明記' || ng 'タグと表示サイズの独立の記述がない'
tyhas 'H1 は必須ではない' && ok 'H1 必須でないことを明記' || ng 'H1 必須でないことの記述がない'
tyhas 'CSS でサイズを調整' && ok 'CSS 調整の推奨を明記' || ng 'CSS 調整の推奨の記述がない'
tyhas 'レベルを飛ばす' && ok '階層を飛ばす場合の確認を明記' || ng '階層を飛ばす場合の記述がない'

# (2) 既存スケールの維持
for row in 'xs</code></td><td>0.75</td><td>12<' 'sm</code></td><td>0.875</td><td>14<' 'base</code></td><td>1</td><td>16<' \
           'lg</code></td><td>1.125</td><td>18<' 'xl</code></td><td>1.5</td><td>24<' '2xl</code></td><td>2</td><td>32<' '3xl</code></td><td>2.5</td><td>40<'; do
  tyhas "$row" || { ng "スケール行が無い: ${row%%<*}"; }
done
tyhas 'xs 12 / sm 14 / base 16 / lg 18 / xl 24 / 2xl 32 / 3xl 40' && ok '既存スケール xs12〜3xl40 を維持' || ng '既存スケールの表記が変わった'

# (3) 管理画面見本: id・「規範ではない」注記・タグとサイズの併記
has "$prev" 'id="heading-compact"' && ok '管理画面見本の id がある' || ng '管理画面見本の id がない'
has "$prev" '見本であり規範ではない' && ok '見本は規範でない旨の注記' || ng '見本は規範でない旨の注記がない'
has "$prev" '必須値ではない' && ok '数値は必須値でない旨の注記' || ng '数値は必須値でない旨の注記がない'
has "$prev" 'h3 · xl 24' && has "$prev" 'h4 · lg 18' && has "$prev" 'h5 · base 16' && ok 'タグとサイズの併記' || ng 'タグとサイズの併記がない'

# (3b) 見本ラベルと実 CSS の突合（本文16・小ボタン14の維持）
for css in '\.adm \.pg-t\{font-size:24px' '\.adm \.sec-t\{font-size:18px' '\.adm \.cd-t\{font-size:16px' '\.adm \.abtn\{font:600 14px'; do
  has "$prev" "$css" && ok "CSS 実体: ${css//\\/}" || ng "CSS 実体が無い/変わった: ${css//\\/}"
done

# (4) 説明文は本文 16（14 を「本文」の新ルールにしない）
has "$prev" '\.adm \.cd p:not\(\.cap\)\{font-size:16px' && ok '見本の説明文 CSS が 16px' || ng '見本の説明文 CSS が 16px でない'
has "$prev" '<tr><td>説明文</td>.*base 16px' && ok '対応表の説明文が base 16px' || ng '対応表の説明文が base 16px でない'
grep -Eq '^\.adm [^{]*\bp\b[^{]*\{[^}]*font-size:14px' "$prev" && ng '見本の p に 14px が指定されている' || ok '見本の p に 14px 指定なし'
has "$prev" '一覧・カード説明を sm 14' && ng '見本に「説明文 14」の記述が残っている' || ok '見本に「説明文 14」の記述なし'

# (5) タグを替えても同じ見た目: リセットは役割クラスに置き、h3/h4/h5 要素セレクタに置かない
reset=$(grep -E '^\.adm \.pg-t,\.adm \.sec-t,\.adm \.cd-t\{' "$prev")
rs_ok=1; for d in 'font-weight:600' 'letter-spacing:normal' 'margin:0'; do printf '%s' "$reset" | grep -Fq "$d" || rs_ok=0; done
[ "$rs_ok" = 1 ] && ok 'ウェイト・字間・margin リセットが役割クラス側' || ng 'リセットが役割クラス側にない'
has "$prev" '\.adm h[1-6]' && ng '.adm にタグ要素セレクタが残っている' || ok '.adm にタグ要素セレクタなし'

exit "$fail"
