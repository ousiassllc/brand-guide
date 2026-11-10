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
