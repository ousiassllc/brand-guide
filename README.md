# Ousiass UI カラーガイド（下書き / DRAFT）

Ousiass 全プロダクト共通の UI カラー設計ガイドラインの**下書き**です。悠太さんの OK 前のため、値はすべて提案段階です。

- 公開ページ: https://ousiassllc.github.io/brand-guide/
- フォント: Sora / Noto Sans JP / JetBrains Mono (OFL, Google Fonts)
- ライト／ダーク切替の参照実装: `theme.js`（切替の動作）と `theme-control.css`（切替コントロール 3 形の見た目の差分）。`theme-control.css` は基底の `.seg`（枠・padding・選択中の塗り・フォーカスリング・svg の大きさ）に足す差分で、**基底の `.seg` は各ページ側（`index.html` と `tokens-preview.html` のインライン `<style>`）にある**ため、`theme-control.css` だけでは動かない。`index.html` と `tokens-preview.html` が head で同期読み込みする（FOUC を避けるため。相対パス）。規定は index の「ライト／ダーク切替」
- 回帰チェック（`scripts/check-*.sh` 全 8 本。どれも `scripts/check-xxx.sh [ルート]` で動き、ルート省略時はこのリポジトリ。末尾に `PASS n / FAIL m` を出し、FAIL があれば exit 1）:
  - grep・awk だけで見る（依存なし）: `check-states.sh`（Issue #10・#12・#14・#16 ほか。状態・切替・フォーカス・スピナー・z・影・テーマ切替の 3 形・設定画面のパーツ）、`check-scrollbar.sh`（#3）、`check-typography.sh`（#2）、`check-overlay.sh`（#18 の重ね塗り）、`check-app-ui.sh`（#20 の面・文字 3 段・余白と丸み）、`check-product-names.sh`（#55 の製品の名前）。このうち `check-states.sh`・`check-scrollbar.sh`・`check-typography.sh`・`check-overlay.sh`・`check-app-ui.sh` は共通ヘルパー `scripts/lib.sh` を読み込む（前提のファイルが無いときは「ERROR: <path> がありません」を 1 行出して exit 2。PASS は出さない）
  - 実行して測る（Node 22 以上と Chrome / Chromium が前提。Chrome の場所は環境変数 `CHROME`。省略時は `google-chrome` / `chromium` を探す。Node か Chrome が無いときは SKIP を表示して exit 0。npm パッケージは不要）: `check-render.sh`（Issue #54。見本の寸法・文字サイズ・コントラスト・reduced-motion・横スクロール・リンク先・id 重複を Light / Dark × 1280px / 375px で実測する）、`check-theme.sh`（Issue #53。`theme.js` を実際に動かして初期値 system・保存（`ousiass-theme`）・OS 追従・`aria-pressed`・矢印キー・描画前の `data-theme` を確かめる。`check-states.sh` には `theme.js` の文字列を見る grep を置かない）
