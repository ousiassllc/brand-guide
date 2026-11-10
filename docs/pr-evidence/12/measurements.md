# Issue #12 検証メモ（Chromium 156 / Firefox 159）

ヘッダー（`.top`）の幅別実測。Chromium と Firefox は同値。

| page | theme | 幅 | header 高 | 1 行 | ラベル | ボタン w×h | scrollWidth/vw |
|---|---|---|---|---|---|---|---|
| index.html | light | 320 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 336/320 |
| index.html | light | 375 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 375/375 |
| index.html | light | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 720/720 |
| index.html | dark | 320 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 336/320 |
| index.html | dark | 375 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 375/375 |
| index.html | dark | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 720/720 |
| tokens-preview.html | light | 320 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 377/320 |
| tokens-preview.html | light | 375 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 432/375 |
| tokens-preview.html | light | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 777/720 |
| tokens-preview.html | dark | 320 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 377/320 |
| tokens-preview.html | dark | 375 | 95 | Y | 視覚的に隠す | 44×44 44×44 44×44 | 432/375 |
| tokens-preview.html | dark | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 777/720 |

- 320 / 375px の scrollWidth 超過（index 336・tokens-preview 377 / 432）は main（87c0db5）と同値で、この Issue 由来ではない（#6〜#9 の範囲）。ヘッダーの切替自体は右端が viewport 内。
- ヘッダー高は ≤480px で 85 → 95px（ボタンが 44px になるため）。481px 以上は 85.8px のまま。
- main（87c0db5）の同じ測定: ≤480px のボタンは 40×28、1 行・scrollWidth は上と同じ。

ログ: `verification-chromium.log`（131 PASS / 0 FAIL）、`verification-firefox.log`（122 PASS / 0 FAIL。forced-colors は Chromium のみ）。
