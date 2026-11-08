#!/usr/bin/env bash
# check-scrollbar.sh — Issue #3（スクロールバーの共通仕様と見本）の回帰チェック。
# 依存なし（grep と exit code のみ）。使い方: scripts/check-scrollbar.sh [リポジトリルート]
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
idx="$root/index.html"; prev="$root/tokens-preview.html"
fail=0
ok() { printf 'PASS  %s\n' "$1"; }
ng() { printf 'FAIL  %s\n' "$1"; fail=1; }
has() { grep -Eq -- "$2" "$1"; }

sec=$(awk '/<section id="scrollbar"/{f=1} f{print} f&&/<\/section>/{exit}' "$idx")
sechas() { printf '%s' "$sec" | grep -Eq -- "$1"; }
cssblk=$(awk '/<style>/{b=""} {b=b $0 "\n"} /--sb-size/{f=1} f{print} f&&/<\/style>/{exit}' "$prev")
csshas() { printf '%s' "$cssblk" | grep -Eq -- "$1"; }

# (1) index.html: 規定
[ -n "$sec" ] && ok 'index.html に #scrollbar 節がある' || ng 'index.html に #scrollbar 節がない'
sechas 'スライダー.*とは別物' && ok 'スライダーとの区別' || ng 'スライダーとの区別がない'
sechas '矢印.*なし.*透明トラック' && ok '矢印なし・透明トラック' || ng '矢印なし・透明トラックの記述がない'
sechas '8px' && sechas '厳密な 8px は保証しない' && ok '8px 基本・厳密保証しない' || ng '8px / 非保証の記述がない'
sechas '独自 JS のドラッグ機構に置き換えない' && ok 'ネイティブスクロールを維持' || ng 'ネイティブスクロール維持の記述がない'
sechas '常時非表示にしない' && ok '常時非表示にしない' || ng '常時非表示にしない旨がない'
sechas '#6b6b6e' && sechas '#8b8b8e' && ok 'thumb 基準色 (mute Light/Dark)' || ng 'thumb 基準色の記述がない'
sechas 'forced-colors: active' && ok 'forced-colors 例外' || ng 'forced-colors 例外がない'
sechas 'オーバーレイ' && ok 'OS オーバーレイ等の制約' || ng 'OS の制約の記述がない'
sechas '::-webkit-scrollbar' && sechas 'scrollbar-width' && sechas 'scrollbar-color' && ok '擬似要素と標準指定の両方' || ng '擬似要素/標準指定の説明がない'
sechas 'auto</code> 以外だと <code>::-webkit-scrollbar</code> を無視' && sechas '標準指定を <code>auto</code> に戻す' && ok '標準指定が擬似要素を上書きする優先関係' || ng '優先関係の説明がない'
has "$idx" 'href="#scrollbar"' && ok 'ページ内ナビに #scrollbar' || ng 'ページ内ナビに #scrollbar がない'

# (2) tokens-preview.html: 見本（縦・横・両方向。操作可能＝tabindex + role）
for id in sb-vertical sb-horizontal sb-both; do
  has "$prev" "id=\"$id\" tabindex=\"0\" role=\"region\" aria-label=" && ok "見本 #$id（キーボード到達可）" || ng "見本 #$id が無い/キーボード到達不可"
done
has "$prev" 'id="sb-standard"' && ok '標準指定のみの見本' || ng '標準指定のみの見本がない'

# (3) CSS: 実装の要点
csshas '--sb-size:8px' && ok 'サイズ 8px' || ng 'サイズ 8px の変数がない'
csshas '--sb-thumb:var\(--mute\)' && ok 'thumb は --mute 基準' || ng 'thumb が --mute 基準でない'
csshas 'sb-thumb-hover:color-mix\(in srgb,var\(--ink\)' && csshas 'sb-thumb-active:color-mix\(in srgb,var\(--ink\)' && ok 'hover/drag は --ink 側へ強める' || ng 'hover/drag の色定義がない'
csshas '@media \(forced-colors:none\)' && ok 'forced-colors: none のときだけ適用' || ng 'forced-colors の分岐がない'
csshas '::-webkit-scrollbar-button\{display:none' && ok '矢印ボタン非表示' || ng '矢印ボタンを隠していない'
csshas '::-webkit-scrollbar-track,[^{]*::-webkit-scrollbar-corner\{background:transparent' && ok 'トラックと交差部分が透明' || ng 'トラック/交差部分が透明でない'
csshas 'scrollbar-width:thin;scrollbar-color:var\(--sb-thumb\) transparent' && ok '標準指定 (thin・透明トラック)' || ng '標準指定がない'
csshas '@supports selector\(::-webkit-scrollbar\)' && csshas 'scrollbar-width:auto;scrollbar-color:auto' && ok '擬似要素環境では標準指定を auto に戻す' || ng '標準指定の auto 戻しがない'
csshas 'scrollbar-width:none|display:none;?\}.*sb-demo' && ng 'バーを隠している' || ok 'バーを非表示にしていない'
has "$prev" 'addEventListener\([^)]*(mousedown|pointerdown)[^)]*\)[^;]*sb' && ng '見本に独自ドラッグ JS がある' || ok '独自ドラッグ JS なし'

# (4) スコープ: 既存スケール・#2 の規定は不変
grep -Eq 'xs 12 / sm 14 / base 16 / lg 18 / xl 24 / 2xl 32 / 3xl 40' "$idx" && ok '既存サイズスケールを維持' || ng '既存サイズスケールが変わった'

exit "$fail"
