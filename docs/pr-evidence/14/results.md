# Issue #14 検証結果（head のツリーで実行）

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-states.sh | 213 | 0 |
| scripts/check-scrollbar.sh | 27 | 0 |
| scripts/check-typography.sh | 20 | 0 |
| main 87c0db5 に新しい check-states.sh を当てる | 97 | 116（想定どおり FAIL） |
| 既存 Playwright（Chromium: verify / verify2 / verify3 / verify5） | 22 + 43 + 28 + 10 = 103 | 0 |
| 既存 Playwright（Firefox: verify-ff） | 15 | 0 |
| 新規 Playwright（Chromium、Light/Dark × desktop/375px、モーダルの閉じ方、見本の動作） | 105 | 0 |
| 新規 Playwright（Firefox、同上） | 105 | 0 |

- Safari / WebKit は未検証（環境に無い）。
- スクショ: `14-<chromium|firefox>-<index|tokens>-<desktop|mobile375>-<light|dark>-<節>.png`

## レビュー反映（fix1: 本文リンクの色・主ボタン hover・ペイン型の行数）

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-states.sh（回帰 10 項目を追加（213→223）） | 223 | 0 |
| scripts/check-scrollbar.sh | 27 | 0 |
| scripts/check-typography.sh | 20 | 0 |
| 06656c4 に新しい check-states.sh を当てる | 216 | 7（想定どおり FAIL: リンク色 1・主ボタン hover 5・.mixh 1） |
| 既存 Playwright（Chromium: verify / verify2 / verify3 / verify5） | 22 + 43 + 28 + 10 = 103 | 0 |
| 既存 Playwright（Firefox: verify-ff） | 15 | 0 |
| #14 の Playwright（Chromium） | 105 | 0 |
| #14 の Playwright（Firefox） | 105 | 0 |
| fix1 の Playwright（Chromium、Light/Dark） | 34 | 0 |
| fix1 の Playwright（Firefox、Light/Dark） | 34 | 0 |
| 06656c4 に fix1 の Playwright を当てる（Chromium） | 17 | 17（想定どおり FAIL） |

| 測定 | 06656c4 | fix1 |
|---|---|---|
| index.html 本文リンク Light（背景 #f5f5f4）: 文字 | `#0000ee` 8.61:1 | `--ink` `#050505` 18.68:1 |
| index.html 本文リンク Dark（背景 #050505）: 文字 | `#0000ee` **2.17:1** | `--ink` `#ffffff` 20.38:1 |
| 下線の色 Light / Dark | 文字色と同じ（青） | `--mute` `#6b6b6e` 4.87:1 / `#8b8b8e` 6.00:1 |
| 主ボタン hover Light | 背景 `#050505` のまま・opacity 0.85 | 背景 `#292929`（accent 85% + bone 15%）・opacity 1・文字 13.34:1 |
| 主ボタン hover Dark | 背景 `#f5f5f4` のまま・opacity 0.85 | 背景 `#d1d1d0`・opacity 1・文字 13.34:1 |

- ペイン型デスクトップアプリの例外の表は本文 12 行（`<thead>` の 1 行を含めた 13 を「13 項目」と数えていた）。ファイル内には「13 項目」の記述は無く、PR 本文だけを直した。
- スクショ（追加）: `14-<chromium|firefox>-index-<desktop|mobile375>-<light|dark>-link.png`（本文リンク）、`14-<chromium|firefox>-tokens-<desktop|mobile375>-<light|dark>-primary-hover.png`（主ボタン hover。「操作できるボタン」の「保存する」にマウスを置いた状態と、固定 hover 見本の並び）。既存スクショのうち 40 枚は検証スクリプトの再実行で撮り直されて差分になっている。
