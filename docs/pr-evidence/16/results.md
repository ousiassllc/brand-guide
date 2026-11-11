# Issue #16 検証結果（puppet-remo 由来の部品 5 種。head のツリーで実行）

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-states.sh（#16 の項目 44 を追加。320→364） | 364 | 0 |
| scripts/check-typography.sh | 20 | 0 |
| scripts/check-scrollbar.sh | 27 | 0 |
| origin/main（ccede33）のツリーに新しい check-states.sh を当てる | 321 | 43（想定どおり FAIL。#16 の項目） |
| 新規 Playwright（#16。Chromium、Light/Dark × 1280/375） | 122 | 0 |
| 新規 Playwright（#16。Firefox、同上） | 122 | 0 |
| 既存 Playwright Chromium（verify / verify2 / verify3 / verify5） | 22 + 43 + 28 + 10 = 103 | 0 |
| 既存 Playwright Firefox（verify-ff） | 15 | 0 |
| #14 の Playwright（verify14。Chromium / Firefox） | 105 / 105 | 0 / 0 |
| #14 決定 4 件の Playwright（Chromium / Firefox） | 42 / 42 | 0 / 0 |
| #12（テーマ切替）の Playwright（Chromium / Firefox。比較元 aa4129d は別サーバで起動） | 210 / 197 | 0 / 0 |

- 新規 Playwright の内容: 1) カードの題（実際の h3 と h2 を 1 枚ずつ。どちらも 18px/600・マージン 0・下線 1px）・本文 padding 24px・影なし 2) 秘密の入力欄: 初期は value 属性なし・登録済みバッジ（xs12・`--mute-on-soft`・コントラスト 4.5:1 以上）と「変更」だけ、「変更」で空の入力欄（base 16・フォーカス・伏せ字）、Eye/EyeClosed の切り替え（aria-label・type・入力値の保持・Space キー）、最初に戻すと空に 3) 題なしアラート: `--r-md` 8px・padding 12×16・本文 14px・アイコン 16px・題なし 4) fieldset: legend 14px/600・上に 1px の線・グループ間 16px 5) ページ送り: 1 ページ目は「前へ」disabled（opacity .4）・3 ページ目は「次へ」disabled・「N ページ目」14px `--mute`・端で disabled になったらフォーカスを反対側へ。画面外へのはみ出しなし。index の `#puppet-parts`（5 項目すべて採用・ジャンクリンク）
- 旧ツリー（ccede33）には `#st-parts` が無いため、#16 の Playwright は旧ツリーでは最初の待機でタイムアウトする（想定どおり）
- Safari / WebKit は未検証（環境に無い）
- スクショ（Light / Dark、Chromium / Firefox）: `bg16-<chromium|firefox>-<desktop|mobile375>-<light|dark>-<card|secret|secret-editing|secret-visible|notice|fieldset|pager>.png`（56 枚）、`bg16-<chromium|firefox>-index-desktop-<light|dark>-spec.png`（4 枚）。計 60 枚

## レビュー反映（規定は Issue #16 にある内容だけにした）
- index の `#puppet-parts` から、Issue にない補足（aria-label の文言・「左に前へ・右に次へ」・P1 のページネーションとの使い分け・Eye/EyeClosed のどちらをどの状態に使うか・見出しの階層の補足）を外した。見本の実装上必要な値（aria-label など）は tokens-preview に残した。`check-states.sh` に、これらを規定として書かない項目を追加
- カードの見本を、実際の `<h3>` と `<h2>` のカード 1 枚ずつにした（見た目は同じ lg 18）

## fix1: いろはの決定 6 点（head e1a3943 の次のコミット）
1. 秘密の入力欄は「バッジ＋変更」の形。バッジと入力欄は並べない（保存済みの値を匂わせる欄を出さないため）
2. 題なしアラートの色は左の線だけ。`--warning`: データの扱い・取り消せないことなど、ずっと出す注意書き。`--info`: 同意のチェックの枠とただの補足。地は既存のまま
3. ページ送り: 押したボタンが端で使えなくなったら、フォーカスを反対側のボタンへ移す（規定に明記）
4. カードの見本は本物の h3 / h2（見た目はクラスで lg 18 SemiBold。タグと見た目は別）。規定にも「クラスでそろえる」と明記
5. 節の名前を `#puppet-parts` → `#settings-parts`（題「設定画面のパーツ」）、見本を `#st-parts` → `#st-settings-parts`。`#proposals` のすぐ後ろのまま、相互リンクあり
6. 見本の「見本を最初に戻す」を、小さいリンク風（sm 14・--mute・400・下線）にし、部品から 24px 離した

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-states.sh（320→375） | 375 | 0 |
| scripts/check-typography.sh | 20 | 0 |
| scripts/check-scrollbar.sh | 27 | 0 |
| e1a3943 のツリーに新しい check-states.sh を当てる | 328 | 47（想定どおり FAIL） |
| #16 の Playwright（Chromium / Firefox。戻すリンク・アラートの色・節の位置を追加） | 136 / 136 | 0 / 0 |
| 既存 Playwright Chromium（verify / verify2 / verify3 / verify5） | 103 | 0 |
| 既存 Playwright Firefox（verify-ff） | 15 | 0 |
| #14（verify14 Chromium / Firefox） | 105 / 105 | 0 / 0 |
| #14 決定 4 件（Chromium / Firefox） | 42 / 42 | 0 / 0 |
| #12（Chromium / Firefox） | 210 / 197 | 0 / 0 |

- スクショは全部撮り直した（60 枚。/tmp/swarm-console/shots-bg-16-fix1/ と同じもの）
