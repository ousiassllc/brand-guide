# Ousiass UI カラーガイド（下書き / DRAFT）

Ousiass 全プロダクト共通の UI カラー設計ガイドラインの**下書き**です。悠太さんの OK 前のため、値はすべて提案段階です。

- 公開ページ: https://ousiassllc.github.io/brand-guide/
- フォント: Sora / Noto Sans JP / JetBrains Mono (OFL, Google Fonts)
- ライト／ダーク切替の参照実装: `theme.js`（`index.html` と `tokens-preview.html` が head で読み込む。規定は index の「ライト／ダーク切替」）
- 回帰チェック: `scripts/check-states.sh`（Issue #10・#12 のテーマ切替の 3 形）、`scripts/check-scrollbar.sh`、`scripts/check-typography.sh`、`scripts/check-overlay.sh`（Issue #18 の重ね塗り）、`scripts/check-app-ui.sh`（Issue #20 の面・文字 3 段・余白と丸み）
- 回帰チェック（テーマ切替の実行検査）: `scripts/check-theme.sh [ルート]`（Issue #53）。headless Chrome を CDP で操作し、`theme.js` を実際に動かして初期値 system・保存・OS 追従・`aria-pressed`・矢印キー・描画前の `data-theme` を確かめる。前提は Chrome と Node 22 以降（Chrome のパスは環境変数 `CHROME` で指定。無いときは SKIP して exit 0）
- 回帰チェック: `scripts/check-product-names.sh [ルート]`（Issue #55 の製品の名前の節。grep・awk のみ）
