#!/usr/bin/env bash
# check-product-names.sh — Issue #55（製品の名前 Product names。Issue #22・2026-11-18 決定）の回帰チェック。
# 依存なし（grep・awk と exit code のみ）。共通ヘルパー scripts/lib.sh を読み込む。使い方: scripts/check-product-names.sh [リポジトリルート]
set -u
. "$(dirname "$0")/lib.sh"
need "$idx"

# #product-names 節だけを取り出す（他の節の同じ語で誤って通らないように）
nm=$(sec product-names)
# 節の中の 1 枚のカード（<div class="nm-card" id="ID">…次の nm-card／節の終わりまで）
card() { printf '%s\n' "$nm" | awk -v id="$1" '/<div class="nm-card"/{f=($0 ~ "id=\"" id "\"")} f{print}'; }
# カード内の表の行を「1 列目|2 列目」にする（タグを外す）
rows() { card "$1" | awk '/<tr><td>/{
  s=$0; gsub(/<\/td><td>/,"|",s); gsub(/<[^>]*>/,"",s); print s }'; }

# (1) 節の有無と位置: 重ね塗りの次、文字の前。ジャンプ導線・題・id
[ -n "$nm" ] && ok 'index.html に #product-names 節がある' || ng 'index.html に #product-names 節がない'
order=$(grep -n -o '<section id="overlay"\|<section id="product-names"\|<section id="typography"' "$idx" | cut -d: -f2- | tr '\n' ' ')
[ "$order" = '<section id="overlay" <section id="product-names" <section id="typography" ' ] && ok '節の順は 重ね塗り → 製品の名前 → 文字' || ng "節の順が違う: $order"
chk 'ページ先頭のジャンプ導線に #product-names がある' '<nav class="jump"[^>]*>.*<a href="#product-names">製品の名前</a>' "$idx"
jump=$(grep -o '<a href="#[a-z-]*">' "$idx" | head -40 | tr '\n' ' ')
case "$jump" in *'#overlay"> <a href="#product-names"> <a href="#typography">'*) ok 'ジャンプ導線の順は 重ね塗り → 製品の名前 → 文字' ;; *) ng 'ジャンプ導線の順が 重ね塗り → 製品の名前 → 文字 でない' ;; esac
insec '節の題は「製品の名前 Product names」' product-names '<h2>製品の名前 Product names</h2>'
insec '頭の名前は Nefos（2026-11-18 決定）' product-names '有料の仕事ツールの頭の名前は <strong>Nefos</strong>（2026-11-18 決定）'
for id in names-rule names-nefos names-bare names-oss names-writing; do
  [ -n "$(card $id)" ] && ok "カード #$id がある" || ng "カード #$id がない"
done
[ "$(printf '%s' "$nm" | grep -o 'class="nm-card"' | wc -l)" -eq 5 ] && ok 'カードは 5 枚（仕組み・Nefos の製品・何もつけない製品・オープンソース・書き方）' || ng 'カードが 5 枚でない'
cardorder=$(printf '%s' "$nm" | grep -o 'id="names-[a-z]*"' | tr '\n' ' ')
[ "$cardorder" = 'id="names-rule" id="names-nefos" id="names-bare" id="names-oss" id="names-writing" ' ] && ok 'カードの順は 仕組み → Nefos の製品 → 何もつけない製品 → オープンソース → 書き方' || ng "カードの順が違う: $cardorder"

# (2) 名前の仕組み
r=$(card names-rule)
printf '%s' "$r" | grep -Eq '「<strong>Nefos</strong>」＋ふつうの英単語 1 つ（例: Nefos Video）' && ok '仕組み: 「Nefos」＋ふつうの英単語 1 つ' || ng '仕組み: 「Nefos」＋ふつうの英単語 1 つ の文言が違う'
printf '%s' "$r" | grep -Eq 'ギリシャ語で「雲」' && ok '仕組み: 由来はギリシャ語の「雲」' || ng '仕組み: 由来の文言が違う'
printf '%s' "$r" | grep -Eq '会社名 <strong>Ousiass は製品名の頭につけない</strong>' && ok '仕組み: 会社名 Ousiass は製品名の頭につけない' || ng '仕組み: Ousiass を頭につけない規定がない'

# (3) 「Nefos の製品」の表: 11 行・製品名と旧名・リポジトリの組（決定どおり。順も）
expect_nefos='Nefos Video|mam
Nefos Inbox|Hitomado（日本語のニックネーム「ひと窓」）
Nefos Browser|kozue-browser
Nefos Hub|swarm-console
Nefos Monitor|swarm-viewer
Nefos Remote|puppet-remo
Nefos Trader|pitha-trador
Nefos Messages|Reloop
Nefos Calendar|Calenshare
Nefos Projects|SWORD
Nefos Phone|dw'
got=$(rows names-nefos)
[ "$(printf '%s\n' "$got" | grep -c .)" -eq 11 ] && ok 'Nefos の製品の表は 11 行' || ng "Nefos の製品の表が 11 行でない（$(printf '%s\n' "$got" | grep -c .) 行）"
if [ "$got" = "$expect_nefos" ]; then ok 'Nefos の製品の表: 製品名と旧名・リポジトリの組・順が決定どおり'; else
  ng 'Nefos の製品の表: 製品名と旧名・リポジトリの組・順が決定と違う'
  diff <(printf '%s\n' "$expect_nefos") <(printf '%s\n' "$got") | sed 's/^/        /'
fi
printf '%s\n' "$expect_nefos" | while IFS='|' read -r name old; do
  printf '%s\n' "$got" | grep -Fxq -- "$name|$old" || echo "MISSING $name|$old"
done | grep -q . && ng 'Nefos の製品の表に、決定した組（製品名|旧名）が欠けている' || ok 'Nefos の製品の表に、決定した 11 組がすべてある'
[ "$(card names-nefos | grep -c '<th>製品名</th><th>旧名・リポジトリ</th>')" -eq 1 ] && ok 'Nefos の製品の表の列は「製品名」「旧名・リポジトリ」' || ng 'Nefos の製品の表の列見出しが違う'
# 製品名の書き方: 「Nefos」の直後は半角スペース 1 つ＋頭だけ大文字の英単語。Ousiass は頭につかない
bad=$(printf '%s\n' "$got" | cut -d'|' -f1 | grep -Ev '^Nefos [A-Z][a-z]+$' || true)
[ -z "$bad" ] && ok 'Nefos の製品名は「Nefos」＋半角スペース 1 つ＋頭だけ大文字の英単語' || ng "Nefos の製品名の書き方が違う: $(printf '%s' "$bad" | tr '\n' ',')"

# (4) 「頭に何もつけない」表: 3 行
expect_bare='AI Liver|ai-liver
Fun ID|funid
Buddy AI|buddy-ai'
gotb=$(rows names-bare)
[ "$(printf '%s\n' "$gotb" | grep -c .)" -eq 3 ] && ok '頭に何もつけない製品の表は 3 行' || ng "頭に何もつけない製品の表が 3 行でない（$(printf '%s\n' "$gotb" | grep -c .) 行）"
[ "$gotb" = "$expect_bare" ] && ok '頭に何もつけない製品: AI Liver・Fun ID・Buddy AI と各リポジトリ名が決定どおり' || ng '頭に何もつけない製品の製品名・リポジトリ名・順が決定と違う'
[ "$(card names-bare | grep -c '<th>製品名</th><th>リポジトリ</th>')" -eq 1 ] && ok '頭に何もつけない製品の表の列は「製品名」「リポジトリ」' || ng '頭に何もつけない製品の表の列見出しが違う'
# Nefos の表と何もつけない表で製品が混ざっていない（Nefos Trader の表の移動を含む）
printf '%s\n' "$gotb" | cut -d'|' -f1 | grep -q '^Nefos ' && ng '頭に何もつけない表に Nefos の製品が入っている' || ok '頭に何もつけない表に Nefos の製品は入っていない'
printf '%s\n' "$got" | cut -d'|' -f1 | grep -Eq '^(AI Liver|Fun ID|Buddy AI|MolePort|Linterly)$' && ng 'Nefos の表に、頭に何もつけない製品・オープンソースが入っている' || ok 'Nefos の表に、頭に何もつけない製品・オープンソースは入っていない'

# (5) オープンソース: MolePort・Linterly の 2 つだけ
goto=$(card names-oss | grep -o '<li>[^<]*</li>' | sed 's/<[^>]*>//g')
[ "$goto" = 'MolePort
Linterly' ] && ok 'オープンソースは MolePort・Linterly の 2 つ（今の名前のまま）' || ng "オープンソースの製品が MolePort・Linterly の 2 つでない: $(printf '%s' "$goto" | tr '\n' ',')"
card names-oss | grep -q '<h3>4\. オープンソースは今の名前のまま</h3>' && ok 'オープンソースの見出しは「今の名前のまま」' || ng 'オープンソースの見出しが違う'

# (6) 製品名の表（節全体）に「Ousiass Xxx」の形がない。節の中で Ousiass は「頭につけない」の文と説明だけ
printf '%s\n' "$got" "$gotb" | cut -d'|' -f1 | grep -q 'Ousiass' && ng '製品名の表に Ousiass がついた名前がある' || ok '製品名の表に「Ousiass Xxx」の形がない'
n=$(printf '%s' "$nm" | grep -o 'Ousiass [A-Z][a-z]*' | grep -vc 'Ousiass は')
[ "$n" -eq 0 ] && ok '節の中に「Ousiass Xxx」の形の製品名がない' || ng '節の中に「Ousiass Xxx」の形がある'
# 節の中の「Nefos ＋ 英単語」は半角スペース 1 つ（全角・スペースなし・小文字始まり・大文字だけを除く）
badn=$(printf '%s' "$nm" | grep -o 'Nefos[^ <（」、。,)]*' | grep -Ev '^Nefos$' || true)
[ -z "$badn" ] && ok '節の中で「Nefos」の直後は、半角スペースか区切りだけ' || ng "「Nefos」の直後が半角スペースでない書き方がある: $(printf '%s' "$badn" | tr '\n' ',')"
badc=$(printf '%s' "$nm" | grep -Eo 'Nefos [A-Za-z]+' | grep -Ev '^Nefos [A-Z][a-z]+$' || true)
[ -z "$badc" ] && ok '節の中の「Nefos ＋ 英単語」は頭だけ大文字' || ng "「Nefos ＋ 英単語」が頭だけ大文字でない: $(printf '%s' "$badc" | tr '\n' ',')"

# (7) 書き方のルール
w=$(card names-writing)
printf '%s' "$w" | grep -Eq '欧文は「Nefos Video」のように<strong>頭だけ大文字</strong>で、間に<strong>半角スペース</strong>' && ok '書き方: 欧文は頭だけ大文字・間に半角スペース' || ng '書き方: 欧文の規定の文言が違う'
printf '%s' "$w" | grep -Eq 'カタカナで書くときは「<strong>ネフォス</strong>」' && ok '書き方: カタカナは「ネフォス」' || ng '書き方: カタカナの規定が「ネフォス」でない'
printf '%s' "$w" | grep -Eq 'リポジトリ名・ファイル名・パスは今のまま。<strong>製品名とは別</strong>（例: Nefos Video のリポジトリは <code>mam</code> のまま）' && ok '書き方: リポジトリ名・ファイル名・パスは今のまま（製品名とは別）' || ng '書き方: リポジトリ名等は今のまま の規定の文言が違う'
badk=$(printf '%s' "$nm" | grep -Eo 'ネ[フホ]ォ*.' | grep -vx 'ネフォス' || true)
[ "$(printf '%s' "$nm" | grep -o 'ネフォス' | wc -l)" -ge 1 ] && [ -z "$badk" ] && ok 'カタカナの表記は「ネフォス」だけ' || ng "カタカナの表記が「ネフォス」でない書き方がある: $badk"

# (8) forced-colors では地が消えるので枠を足す（<style> の「製品の名前の節（Issue #22）」の下）
chk 'style: 製品の名前の節（Issue #22）のコメントがある' '/\* 製品の名前の節（Issue #22）' "$idx"
chk 'style: forced-colors で .nm-card に枠 1px solid CanvasText' '@media\(forced-colors:active\)\{[^}]*\.nm-card\{border:1px solid CanvasText\}' "$idx"
chk 'style: 通常は .nm-card に線を引かない（border:0・surface の地）' '\.nm-card\{background:var\(--surface\);border:0;' "$idx"
chk 'style: forced-colors で表の奇数行の地を消し、行の上に線' '\.nm-card \.ut tbody tr:nth-child\(odd\)\{background:none\}\.nm-card \.ut tbody tr\{border-top:1px solid CanvasText\}' "$idx"

finish
