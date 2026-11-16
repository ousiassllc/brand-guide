# Issue #20 検証結果（面の分け方・文字の 3 段・余白と丸み。head のツリーで実行）

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-app-ui.sh（新規） | 53 | 0 |
| scripts/check-states.sh | 375 | 0 |
| scripts/check-typography.sh | 20 | 0 |
| scripts/check-scrollbar.sh | 27 | 0 |
| scripts/check-overlay.sh | 37 | 0 |
| Playwright（Chromium。`verify20.cjs`。Light/Dark × 1280 / 390） | 60 | 0 |

- Playwright の内容（実際に描画された値）: ページ・カード・選択の色（Light #f5f5f4 / #ffffff / #ebebea、Dark #050505 / #141414 / #1e1e21）、カード・表・バナー・ナビの枠線 0、角 16px、カード余白 22px・バナー 22×24px、カード同士 16px、ボタン・チップ・ナビはピル、主なボタンは `--accent` 塗り・それ以外は surface-sel（枠は透明）、文字 28/700・15/600・13/400 mute、表の本文 15/400・行の区切り ink（Dark は bone）6%、入力欄の枠 1px と `:focus-visible` の輪が残る、#app-ui の見本が 390px でもはみ出さない
- コントラスト: `--mute` は bone / surface 上で 4.87〜6.00（AA 4.5 以上）。Light の `--mute` は `--surface-sel` 上で 4.45:1 で届かないため、選択色の面に置く 13px は `--mute-on-soft` を使う規定にした（`--mute-on-soft` の sel 上は Light 5.62・Dark 6.10）
- 実行: `npm i playwright`（または playwright-core。`CHROME=/usr/bin/google-chrome` で Chrome 指定可）した場所で `node docs/pr-evidence/20/verify20.cjs`
- Firefox / Safari（WebKit）、forced-colors の実機（Windows ハイコントラスト）は未検証

## 規定の対象外にしたもの（Issue 本文にないので決めずに据え置き。判断待ち）
- モーダル・シート・ダイアログ・ドロップダウン（浮かぶ面）の 1px 枠
- インラインアラート `.al` の左の状態色の帯と角 `--r-md`（#proposals・#settings-parts で「いろはの決定」として pin 済み。外枠だけ外し、背景を surface-sel にした）
- 設定画面のパーツ（`.np-card` の題の下の 1px 線、`.np-fs` の上線）。カード自体の枠は外した
- 入力欄の角 `--r-md`、ヘッダーのテーマ切替 `.seg` の枠
- 「コンパクトな管理画面の見本」（24 / 18 / 16。タグとサイズが独立であることを示す一般例。規範ではない旨の注記のまま）

## スクショ（Chromium・幅 1280。Light / Dark）
- `bg20-{light,dark}-tp-app-ui.png`: 新しい節 #app-ui（面・文字 3 段・余白と丸み・見本）
- `bg20-{light,dark}-tp-actions.png`: ボタン
- `bg20-{light,dark}-tp-feedback.png`: チップ（ステータス）・インラインアラート・トースト・空状態
- `bg20-{light,dark}-tp-table.png`: 表
- `bg20-{light,dark}-tp-layout.png`: カード・サブナビ（タブ・セグメント）
- `bg20-{light,dark}-tp-radius.png`: 角丸
- `bg20-{light,dark}-idx-app-ui.png`: index.html の規定の節
- `bg20-{desktop,mobile390}-{light,dark}-app-ui.png`: verify20.cjs が出す #app-ui（1280 / 390）
