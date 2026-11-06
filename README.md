# Ousiass UI ガイド

Ousiass 全プロダクト共通の UI ガイドラインです。**プロダクトをまたいで同じ見た目の形式にする**ことを目的にしています。

- 公開ページ: https://ousiassllc.github.io/brand-guide/
- フォント: Sora (OFL), Noto Sans JP (OFL, Google Fonts), JetBrains Mono (OFL)
- UI アイコン: Iconoir (MIT)

## トークンの実体

値の正は **`tokens.json`** です。CSS はそこから `build-tokens.mjs` が生成します。**CSS を手で直さないでください。**

```sh
node build-tokens.mjs          # tokens.css と theme.css を生成する
node build-tokens.mjs --check  # tokens.json と一致するか調べる（CI 用）
```

| ファイル | 形 | 使うところ |
| --- | --- | --- |
| [`tokens.json`](tokens.json) | JSON | 値の正。Figma の変数・スクリプト・CSS 以外のスタック |
| [`tokens.css`](tokens.css) | 素の `:root` ＋ `[data-theme=dark]` ＋ `prefers-color-scheme` | Tailwind を使わないビルド |
| [`theme.css`](theme.css) | Tailwind v4 の `@theme` | wallet と DLP の本体 |

各プロダクトはこれを**写して持ち**、写しが原本と一致することを nightly で検査します。写しは編集せず、製品の上書き（accent 3 変数）は隣の別ファイルに書きます。詳しくは [`product-guide.html`](product-guide.html) の「2. トークンの配り方」。

## ページ

| ページ | 中身 | 状態 |
| --- | --- | --- |
| [`index.html`](index.html) | 方針・コアトークン・プリズム・状態色・タイポグラフィ・狭い面・Do / Don't | 色とフォントは**確定**（2026-11-05） |
| [`tokens-preview.html`](tokens-preview.html) | 全トークンのライト／ダーク実物見本、UI 部品 P0〜P3 | 部品は**下書き** |
| [`product-guide.html`](product-guide.html) | 案件ガイドの作り方、トークンの配り方、今のトークンからの移行表 | 2026-11-06 追加 |
| [`fonts-decide.html`](fonts-decide.html) | フォント選定の比較（決着済み） | 参考 |

## 共通ガイドと案件ガイド

共通ガイドが決めるのは**骨格**です。面・余白・角丸・書体・状態色・モーション・骨格部品・部品の寸法は全プロダクトで同じにします。狭い面（420px 以下）でも**部品の寸法は変えません**。変わるのは外側の余白とナビの形だけです。

プロダクトごとに変えてよいのは次の 3 つだけで、いずれも**案件ガイドに宣言してから**使います。

1. `--accent` / `--on-accent` / `--accent-soft`（製品アクセント）
2. ライト／ダークの提供範囲（単一テーマには条件があります）
3. そのプロダクトにしかない拡張トークンと独自ウィジェット

### 登録済みプロダクト

| プロダクト | accent（Light / Dark） | テーマ | 案件ガイド |
| --- | --- | --- | --- |
| VeriCerts Wallet | `#0b57d0` / — | ライトのみ（例外） | `vericerts-wallet` の `spec/content/docs/extension/design/brand.md` |
| VeriCerts DLP | `#1a6974` / `#36bfd3` | ライト・ダーク | `vericerts-dlp` の `docs/design/brand.md` |

新しいプロダクトを足すときは、使い始める前に `product-guide.html` の一覧と、この表に 1 行追加してください。
