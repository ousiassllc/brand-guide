# lib.sh — scripts/check-*.sh（grep・awk だけで見る回帰チェック）の共通ヘルパー。単体では実行しない。
# 使い方（各スクリプトの冒頭）:
#   set -u
#   . "$(dirname "$0")/lib.sh"      # root・idx・prev・thm・css が決まる（ルートは第 1 引数。省略時はこのリポジトリ）
#   need "$idx" "$prev"              # 前提のファイルが無ければ「ERROR: <path> がありません」を 1 行出して exit 2
#   …ok / ng / chk / notchk / insec などで検査…
#   finish                           # 末尾に「PASS n / FAIL m」を出し、FAIL があれば exit 1
# check-render.sh・check-theme.sh（headless Chrome を使う）は単体で動く作りで、これを読み込まない。
# 検査の中身（文言・正規表現）はここに置かない。ここは出力・集計・節の取り出しだけを持つ。

root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
idx="$root/index.html"; prev="$root/tokens-preview.html"; thm="$root/theme.js"; css="$root/theme-control.css"
npass=0; nfail=0

ok() { printf 'PASS  %s\n' "$1"; npass=$((npass + 1)); }
ng() { printf 'FAIL  %s\n' "$1"; nfail=$((nfail + 1)); }
# has FILE REGEX: FILE に REGEX（ERE）にマッチする行がある
has() { grep -Eq -- "$2" "$1"; }
# chk LABEL REGEX FILE: 無ければ FAIL / notchk: あれば FAIL
chk() { if has "$3" "$2"; then ok "$1"; else ng "$1"; fi; }
notchk() { if has "$3" "$2"; then ng "$1"; else ok "$1"; fi; }
# intext LABEL TEXT REGEX: 変数に取り出した節（TEXT）に REGEX がある / nottext: あれば FAIL
intext() { if printf '%s' "$2" | grep -Eq -- "$3"; then ok "$1"; else ng "$1"; fi; }
nottext() { if printf '%s' "$2" | grep -Eq -- "$3"; then ng "$1"; else ok "$1"; fi; }

# need FILE…: 前提のファイルが 1 つでも無ければ、1 行のエラーだけ出して exit 2（PASS を出さない）
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { printf 'ERROR: %s がありません\n' "$f" >&2; exit 2; }
  done
}

# sec ID: index.html の <section id="ID" から次の </section> まで / secp ID: tokens-preview.html の <section class="ui" id="ID"> の同じ範囲
sec() { awk -v id="$1" '$0 ~ "<section id=\"" id "\""{f=1} f{print} f&&/<\/section>/{exit}' "$idx"; }
secp() { awk -v id="$1" '$0 ~ "<section class=\"ui\" id=\"" id "\">"{f=1} f{print} f&&/<\/section>/{exit}' "$prev"; }
# insec LABEL ID REGEX: index.html の #ID 節の中に REGEX がある（他の節の同じ語で誤って通らないように） / notinsec: あれば FAIL
insec() { sec "$2" | grep -Eq -- "$3" && ok "$1" || ng "$1"; }
notinsec() { sec "$2" | grep -Eq -- "$3" && ng "$1" || ok "$1"; }

# 末尾の集計。FAIL があれば exit 1
finish() {
  printf 'PASS %d / FAIL %d\n' "$npass" "$nfail"
  [ "$nfail" -eq 0 ]
  exit
}
