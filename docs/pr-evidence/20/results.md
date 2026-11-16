# Issue #20 検証結果（面の分け方・文字の 3 段・余白と丸み。head のツリーで実行）

| 項目 | PASS | FAIL |
|---|---|---|
| scripts/check-app-ui.sh（新規） | 58 | 0 |
| scripts/check-states.sh | 375 | 0 |
| scripts/check-typography.sh | 20 | 0 |
| scripts/check-scrollbar.sh | 27 | 0 |
| scripts/check-overlay.sh | 37 | 0 |
| Playwright（Chromium。`verify20.cjs`。Light/Dark × 1280 / 390） | 60 | 0 |

- Playwright の内容（実際に描画された値）: ページ・カード・選択の色（Light #f5f5f4 / #ffffff / #ebebea、Dark #050505 / #141414 / #1e1e21）、カード・表・バナー・ナビの枠線 0、角 16px、カード余白 22px・バナー 22×24px、カード同士 16px、ボタン・チップ・ナビはピル、主なボタンは `--accent` 塗り・それ以外は surface-sel（枠は透明）、文字 28/700・15/600・13/400 mute、表の本文 15/400・行の区切り ink（Dark は bone）6%、入力欄の枠 1px と `:focus-visible` の輪が残る、#app-ui の見本が 390px でもはみ出さない
- コントラスト: `--mute` は bone / surface 上で 4.87〜6.00（AA 4.5 以上）。Light の `--mute` は `--surface-sel` 上で 4.45:1 で届かないため、選択色の面に置く 13px は `--mute-on-soft` を使う規定にした（`--mute-on-soft` の sel 上は Light 5.62・Dark 6.10）
- 実行: `npm i playwright`（または playwright-core。`CHROME=/usr/bin/google-chrome` で Chrome 指定可）した場所で `node docs/pr-evidence/20/verify20.cjs`
- Firefox / Safari（WebKit）、forced-colors の実機（Windows ハイコントラスト）は未検証

## レビュー反映（review エージェントの指摘）
- 押下・ホバー・選択が `--surface-sel` と同色で見えなくなる箇所を直した: `.sec` / `.ib` / `.mbtn` のホバーは surface-sel に ink 8%、トグル `#tgl` は未押下を透明に（押下は従来どおり accent-soft）、`.fchip` の押下は accent 塗り、選択中のナビ・行（`.acct.on` `.rw.on`）は surface-sel、リップル見本の `.rpitem` は面なし
- 枠線が残っていたペイン `.pn>*`・`.ld`・行型選択 `.rowsel` を、枠なし・surface-sel・角 16 に
- forced-colors: `.tabs` / `.tb40` / `.acct.on` の選択を Highlight に
- 「Dark の影が見えない」の文を、浮かぶ面は 1px `--border`・カードは濃さ、に直した。`--line-soft` の説明を `--accent` の 6% に統一
- `.adm .cd .cap` の色を `--mute-on-soft` に（Light の `--mute` は surface-sel 上で 4.45:1）
- check-app-ui.sh に上記の状態の検査を追加（53 → 58）

## 規定の対象外にしたもの（Issue 本文にないので決めずに据え置き。判断待ち）
- モーダル・シート・ダイアログ・ドロップダウン（浮かぶ面）の 1px 枠
- インラインアラート `.al` の左の状態色の帯と角 `--r-md`（#proposals・#settings-parts で「いろはの決定」として pin 済み。外枠だけ外し、背景を surface-sel にした）
- `.seg-stack`（テーマ切替の縦積み）の選択行は accent-soft のまま（#12 の決定で check-states が pin。カード面の上なので見分けは付く）
- `.alt`（index の破線の代替案ボックス）の破線
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
- `bg20-{light,dark}-tp-ripple.png` / `-tp-states-buttons.png` / `-tp-theme.png`: リップルの対象・ボタンの状態・テーマ切替
- `bg20-{light,dark}-idx-app-ui.png`: index.html の規定の節
- `bg20-{desktop,mobile390}-{light,dark}-app-ui.png`: verify20.cjs が出す #app-ui（1280 / 390）

## いろはの決定による直し（PR #21 への追加コミット）
- 浮かぶ面（モーダル・ダイアログ・ドロップダウン・ポップオーバー・メニュー・コマンドパレット・コーチ・スナックバー・ドロワー）: 1px の枠は残し、色を `--line-soft` に。影（`--shadow-modal`）は変えない
- インラインアラート `.al`: 左の状態色の帯をなくし、地 `--surface-sel`・角 16px（`--r-card`）。状態色は先頭のアイコンだけ。danger だけ枠 40%（`.al-dan`）
- `.np-card` の題の下線・`.np-fs` の上線をなくし、余白で区切る（項目のあいだ 16px・まとまりのあいだ 24px）
- 「面は濃さで分ける」の図 `.au-fig` の点線の枠をなくした
- 28px のアプリ画面専用 3 段・Light の surface-sel 上の 13px は `--mute-on-soft`・管理画面の見本（24/18/16）は触らない（`#app-ui` へ誘導）: 変更なし
- 上の「規定の対象外にしたもの」のうち、浮かぶ面の枠・アラートの帯と角・`.np-card` / `.np-fs` の線は、この直しで規定に入った
- 検査: check-app-ui 105 / check-states 376 / check-typography 20 / check-scrollbar 27 / check-overlay 37 / Playwright（Chromium。Light/Dark × 1280/390）88、すべて FAIL 0

