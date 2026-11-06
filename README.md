# Ousiass UI ガイド

Ousiass 全プロダクト共通の UI ガイドラインです。

- 公開ページ: https://ousiassllc.github.io/brand-guide/
- フォント: Sora (OFL), Noto Sans JP (OFL, Google Fonts), JetBrains Mono (OFL)
- UI アイコン: Iconoir (MIT)

## ページ

| ページ | 中身 | 状態 |
| --- | --- | --- |
| [`index.html`](index.html) | 方針・コアトークン・プリズム・状態色・タイポグラフィ・Do / Don't | 色とフォントは**確定**（2026-11-05） |
| [`tokens-preview.html`](tokens-preview.html) | 全トークンのライト／ダーク実物見本、UI 部品 P0〜P3 | 部品は**下書き** |
| [`product-guide.html`](product-guide.html) | 案件ガイドの作り方、製品 accent の決まり、テーマの例外規定 | 2026-11-06 追加 |
| [`fonts-decide.html`](fonts-decide.html) | フォント選定の比較（決着済み） | 参考 |

## 共通ガイドと案件ガイド

共通ガイドが決めるのは**骨格**です。面・余白・角丸・書体・状態色・モーション・骨格部品は全プロダクトで同じにします。

プロダクトごとに変えてよいのは次の 3 つだけで、いずれも**案件ガイドに宣言してから**使います。

1. `--accent` / `--on-accent` / `--accent-soft`（製品アクセント）
2. ライト／ダークの提供範囲（単一テーマには条件があります）
3. そのプロダクトにしかない拡張トークンと独自ウィジェット

詳しい決まりと、登録済みプロダクトの一覧は [`product-guide.html`](product-guide.html) にあります。

### 登録済みプロダクト

| プロダクト | accent（Light / Dark） | テーマ | 案件ガイド |
| --- | --- | --- | --- |
| VeriCerts Wallet | `#0b57d0` / — | ライトのみ（例外） | `vericerts-wallet` の `spec/content/docs/extension/design/brand.md` |
| VeriCerts DLP | `#1a6974` / `#36bfd3` | ライト・ダーク | `vericerts-dlp` の `docs/design/brand.md` |

新しいプロダクトを足すときは、使い始める前に `product-guide.html` の一覧と、この表に 1 行追加してください。
