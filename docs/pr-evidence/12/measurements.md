# Issue #12 検証メモ（Chromium 156 / Firefox 159）

ヘッダー（`.top`）の幅別実測（直し 1 回目の後）。Chromium と Firefox は同値。ボタン w×h は「見える部分」。≤480px は 38×38（外枠 padding 3px。直し前は 44×44）。

| page | theme | 幅 | header 高 | 1 行 | ラベル | ボタン w×h | scrollWidth/vw |
|---|---|---|---|---|---|---|---|
| index.html | light | 320 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 336/320 |
| index.html | light | 375 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 375/375 |
| index.html | light | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 720/720 |
| index.html | dark | 320 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 336/320 |
| index.html | dark | 375 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 375/375 |
| index.html | dark | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 720/720 |
| tokens-preview.html | light | 320 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 377/320 |
| tokens-preview.html | light | 375 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 432/375 |
| tokens-preview.html | light | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 777/720 |
| tokens-preview.html | dark | 320 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 377/320 |
| tokens-preview.html | dark | 375 | 95 | Y | 視覚的に隠す | 38×38 38×38 38×38 | 432/375 |
| tokens-preview.html | dark | 720 | 85.8 | Y | 表示 | 92×29 92×29 106×29 | 777/720 |

- 320 / 375px の scrollWidth 超過（index 336・tokens-preview 377 / 432）は main（87c0db5）と同値で、この Issue 由来ではない（#6〜#9 の範囲）。ヘッダーの切替自体は右端が viewport 内。
- ヘッダー高は ≤480px で 95px（44px 相当のボタンのため。直し前の aa4129d と同値）、481px 以上は 85.8px。幅ごとの高さ（`.top` / `.seg`）を aa4129d と並べて比較: 320・375・414・480px は 95 / 46、481・600・720・1280px は 85.8 / 36.8 で、すべて同じ。
- main（87c0db5）の同じ測定: ≤480px のボタンは 40×28、1 行・scrollWidth は上と同じ。

## アイコンだけのタップ範囲（直し 1 回目 P2-1）

`elementFromPoint` で、ボタンの中心から上下／左右に同じボタンに当たる範囲を測定（index.html・ヘッダー 320 / 375px、Light・Dark 共通）。

| 方向 | 1 つ目 | 2 つ目 | 3 つ目 | 備考 |
|---|---|---|---|---|
| 縦 | 44 | 44 | 44 | `::before { inset: -3px }` で 38 + 3 + 3 |
| 横 | 38 | 38 | 44 | 隣のボタンと接していて、あとの `::before`（inset:-3px）が前のボタンの右端 3px を覆う。1 つ目・2 つ目は当たる範囲が 38px（見える部分より 3px 左にずれる。1 つ目は左の外枠側へ 3px はみ出し、右 3px は 2 つ目に取られる）、3 つ目だけ 44px |

- 見える部分（選択中の塗り）は 38×38、外枠との間は上下左右とも 3px、外枠の高さは 46px（aa4129d と同値）。
- 横が 44px に届かないのは、ボタンを隙間なく並べる以上、隣と重なるため。縦 44px を保つ形にした。0.5px 刻みの `elementFromPoint`（ヘッダー 375px）の直接測定: 1 つ目 x=225.5〜263（見える部分 229〜267）、2 つ目 263.5〜301（267〜305）、3 つ目 301.5〜345.5（305〜343）。

## forced-colors の吹き出し（直し 1 回目 P3-3）

| 版 | 吹き出しの border | 背景 |
|---|---|---|
| aa4129d | 1px solid CanvasText | Canvas |
| 直し後 CSS から forced-colors の規則だけ抜いた版（反実仮想） | 0px none | Canvas（ページと同色で枠もなく見えなくなる） |
| 直し後 | 1px solid CanvasText | Canvas |

- aa4129d は吹き出しに `border:1px solid var(--ink)` があったので forced-colors でも枠が残っていた。P2-2 で枠をなくす（Tooltip の規定にそろえる）と枠も背景も消えるため、forced-colors だけ `1px solid CanvasText` ＋ `Canvas` 背景を足した。

ログ: `verification-chromium.log`（210 PASS / 0 FAIL）、`verification-firefox.log`（197 PASS / 0 FAIL。forced-colors は Chromium のみ）。`verification-chromium-on-aa4129d.log` は同じスクリプトを aa4129d に当てた結果（164 PASS / 46 FAIL。完走）。`check-states.txt`（直し後 184 PASS / 0 FAIL）、`check-states-new-script-on-aa4129d.txt`（新しい check-states.sh を aa4129d のツリーに当てると 147 PASS / 37 FAIL）。
