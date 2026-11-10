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
