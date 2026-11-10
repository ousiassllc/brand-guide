# Issue #10 測定メモ（WCAG 相対輝度で計算。ページ内の「非テキストコントラスト」表はライブ計算で同じ値）

## フォーカスインジケータ（`--focus`）対 隣接背景 — 基準 3:1（SC 1.4.11）

| テーマ | bone | surface | accent-soft |
|---|---|---|---|
| Light（#4a72d0）実線 | 4.18 | 4.56 | 3.68 |
| Dark（#60a5fa）実線 | 8.02 | 7.25 | 5.65 |
| Light `--ring`（focus 40%、旧） | 1.65 | 1.69 | 1.61 |
| Dark `--ring`（focus 40%、旧） | 2.08 | 2.16 | 2.06 |

- 旧見本の `--ring` は 3:1 に届かない → 実線の `--focus`（色は不変）で描く。離散コントロールは offset 2px の outline、入力は枠＋ outline 2px。
- Dark の primary（塗り #f5f5f4）に focus #60a5fa を接して置くと 2.33:1。offset 2px で背景側（bone/surface）に逃がして上表の値にしている。

## accent-soft 上の補助文字

| テーマ | `--ink` | `--mute` |
|---|---|---|
| Light（#e7e7e5） | 16.46 | 4.29（AA 4.5 未満） |
| Dark（#2a2a2a） | 14.35 | 4.22（AA 4.5 未満） |

## 実ピクセルでの確認（ボタンを Tab でフォーカス、スクショの 1 ライン走査）

| テーマ | リング画素 | 隣接背景（surface） | 比 |
|---|---|---|---|
| Light | rgb(74,114,208) 3px 幅 | rgb(255,255,255) | 4.56 |
| Dark | rgb(96,165,250) 3px 幅 | rgb(20,20,20) | 7.25 |

リングとボタン本体の間に 2px の背景色の余白があり、計算値（上表）と一致。

## スイッチ ON の見た目（Space で切替、400ms 待った後の computed style）

| テーマ | OFF の背景 | ON の背景 / 枠 | ON のつまみ |
|---|---|---|---|
| Light | rgb(231,231,229)（accent-soft） | rgb(5,5,5)（accent） | rgb(245,245,244)（bone） |
| Dark | rgb(42,42,42)（accent-soft） | rgb(245,245,244)（accent） | rgb(5,5,5)（bone） |

（遷移中の 180ms 以内に読むと OFF の値になるため、安定後に評価する。）

## 375px の scrollWidth（同一条件: viewport 375×800、フォント読込後）

| | main 5d816f8 | feat/#10 |
|---|---|---|
| index.html | 375 | 375 |
| tokens-preview.html | 432 | 432 |

どちらも超過要素は既存節の隠しスイッチ `input`（`input{width:100%}` の absolute 配置、right=432）。`.tbl2`/`code` は overflow コンテナ内で、ページ幅は押し広げていない。新節は `#states .sw2` で抑えているため 432 のまま増えない（#6 を直した扱いにはしない）。
