# Ousiass UI カラーガイド（下書き / DRAFT）

Ousiass 全プロダクト共通の UI カラー設計ガイドラインの**下書き**です。悠太さんの OK 前のため、値はすべて提案段階です。

- 公開ページ: https://ousiassllc.github.io/brand-guide/
- フォント: Sora / Noto Sans JP / JetBrains Mono (OFL, Google Fonts)
- ライト／ダーク切替の参照実装: `theme.js`（`index.html` と `tokens-preview.html` が head で読み込む。規定は index の「ライト／ダーク切替」）
- 回帰チェック: `scripts/check-states.sh`（Issue #10・#12 のテーマ切替の 3 形）、`scripts/check-scrollbar.sh`、`scripts/check-typography.sh`、`scripts/check-overlay.sh`（Issue #18 の重ね塗り）、`scripts/check-app-ui.sh`（Issue #20 の面・文字 3 段・余白と丸み）
- 描画の回帰チェック: `scripts/check-render.sh`（Issue #54。Node 22 以上と Chrome / Chromium で、見本の寸法・文字サイズ・コントラスト・reduced-motion・横スクロール・リンク先・id 重複を Light / Dark × 1280px / 375px で実測する。npm パッケージは不要。Chrome の場所は `CHROME=/path/to/chrome scripts/check-render.sh`、省略時は `google-chrome` / `chromium` を探す。Node か Chrome が無いときは SKIP を表示して exit 0。ほかの `check-*.sh` と違い、見本の描画結果を測る）
