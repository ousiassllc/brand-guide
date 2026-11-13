# Issue #18 検証結果（重ね塗り（写真の上）。head のツリーで実行）

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-overlay.sh（新規。head） | 31 | 0 |
| scripts/check-overlay.sh を origin/main（a66e851）のツリーに当てる | 6 | 25（想定どおり FAIL。#18 の項目） |
| scripts/check-states.sh | 全 PASS | 0 |
| scripts/check-typography.sh | 全 PASS | 0 |
| scripts/check-scrollbar.sh | 全 PASS | 0 |
| Playwright（Chromium。`verify18.cjs`。Light/Dark × 1280 / 390） | 28 | 0 |

- Playwright の内容: トークン値がテーマを切り替えても `#5a0000` / `#ff8c96` のまま・節の位置（状態色の次、Do / Don't の前）・見本 4 つが不透明度 .55 で deep=`rgb(90,0,0)` ×2・pale=`rgb(255,140,150)` ×2・見本のグラデーション両端で「選ぶ」側は 3:1 以上（明るい×deep 3.87 / 3.43、暗い×pale 3.31 / 3.21）、「選ばない」側は 3:1 未満・`#overlay` 内にはみ出す要素なし
- 実行: `npm i playwright` した場所で `node docs/pr-evidence/18/verify18.cjs`
- Firefox / Safari（WebKit）は未検証
- 写真は CSS のグラデーションによる代用（実写ではない）。実写の中間調で 3:1 に届かないのは、Issue のとおり制限として節に書いてある
- ページ全体の横幅が 390px で 396px になる（`#theme` 節の `code`）のは origin/main でも同じで、この PR の変更ではない

スクショ（Chromium。新しい節 `#overlay` だけ）:
- `bg18-chromium-desktop-light-overlay.png`（幅 1280・Light）
- `bg18-chromium-desktop-dark-overlay.png`（幅 1280・Dark）
- `bg18-chromium-mobile390-light-overlay.png`（幅 390・Light）
- `bg18-chromium-mobile390-dark-overlay.png`（幅 390・Dark）
