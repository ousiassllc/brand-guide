// Issue #20 の検証。Light / Dark × 1280 / 390 で、実際に描画された値を測る。
// 実行: playwright か playwright-core を入れた場所で `node docs/pr-evidence/20/verify20.cjs`
// Chrome を指定するとき: CHROME=/usr/bin/google-chrome node ...
let pw; try { pw = require('playwright'); } catch { pw = require('playwright-core'); }
const path = require('path');
const root = path.resolve(__dirname, '../../..');
const out = process.env.SHOTS || (root + '/docs/pr-evidence/20');
const lin = c => { c/=255; return c<=.03928 ? c/12.92 : ((c+.055)/1.055)**2.4 };
const L = ([r,g,b]) => .2126*lin(r)+.7152*lin(g)+.0722*lin(b);
const cr = (a,b) => { const x=L(a), y=L(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05) };
const rgb = s => { const n = s.match(/\d*\.?\d+/g).slice(0,3).map(Number); return s.startsWith('color(') ? n.map(v => v*255) : n };
let pass=0, fail=0; const t=(n,c,d='')=>{ c?pass++:fail++; console.log((c?'PASS ':'FAIL ')+n+(d?'  '+d:'')) };
const exp = { light:{bone:'rgb(245, 245, 244)',card:'rgb(255, 255, 255)',sel:'rgb(235, 235, 234)',mute:'rgb(107, 107, 110)'},
              dark:{bone:'rgb(5, 5, 5)',card:'rgb(20, 20, 20)',sel:'rgb(30, 30, 33)',mute:'rgb(139, 139, 142)'} };
(async()=>{
  const b = await pw.chromium.launch(process.env.CHROME ? {executablePath:process.env.CHROME,args:['--no-sandbox']} : {});
  for (const [w,h,wn] of [[1280,900,'desktop'],[390,844,'mobile390']]) {
    for (const theme of ['light','dark']) {
      const p = await (await b.newContext({ viewport:{width:w,height:h} })).newPage();
      await p.goto('file://'+root+'/tokens-preview.html',{waitUntil:'domcontentloaded',timeout:120000}); await p.waitForSelector('#app-ui');
      await Promise.race([p.evaluate(() => document.fonts.ready), new Promise(r => setTimeout(r, 5000))]); // 外部フォントを待ちすぎない
      await p.click(`[data-set-theme=${theme}]`);
      const e = exp[theme]; const tag = `${wn}/${theme}`;
      const m = await p.evaluate(() => {
        const cs = (s, i=0) => getComputedStyle(document.querySelectorAll(s)[i]);
        const bw = (s, i=0) => { const c = cs(s, i); return ['Top','Right','Bottom','Left'].map(k => c['border'+k+'Width']).join(' ') };
        const root = getComputedStyle(document.documentElement);
        const row = cs('#app-ui .au-tbl tbody tr:first-child td'); // 区切り線
        const cards = [...document.querySelectorAll('#app-ui .au-cards .card')].map(c => c.getBoundingClientRect());
        return {
          bone: getComputedStyle(document.body).backgroundColor, card: cs('#app-ui .au-cards .card').backgroundColor, sel: cs('#app-ui .au-nav a[aria-current]').backgroundColor,
          cardBorder: bw('#app-ui .au-cards .card'), cardRadius: cs('#app-ui .au-cards .card').borderRadius, cardPad: cs('#app-ui .au-cards .card').padding,
          tcardBorder: bw('#app-ui .au-tcard'), tcardRadius: cs('#app-ui .au-tcard').borderRadius,
          bannerBorder: bw('#app-ui .au-banner'), bannerRadius: cs('#app-ui .au-banner').borderRadius, bannerPad: cs('#app-ui .au-banner').padding,
          navBorder: bw('#app-ui .au-nav a'), navRadius: cs('#app-ui .au-nav a').borderRadius, navSize: cs('#app-ui .au-nav a').fontSize+'/'+cs('#app-ui .au-nav a').fontWeight,
          btnPri: [cs('#app-ui .au-hd .btn').borderRadius, cs('#app-ui .au-hd .btn').backgroundColor, cs('#app-ui .au-hd .btn').fontSize+'/'+cs('#app-ui .au-hd .btn').fontWeight],
          btnSec: [cs('#app-ui .au-acts .btn.sec').borderRadius, cs('#app-ui .au-acts .btn.sec').backgroundColor, cs('#app-ui .au-acts .btn.sec').fontSize+'/'+cs('#app-ui .au-acts .btn.sec').fontWeight, cs('#app-ui .au-acts .btn.sec').borderTopColor],
          chip: [cs('#app-ui .au-chip').borderRadius, cs('#app-ui .au-chip').fontSize+'/'+cs('#app-ui .au-chip').fontWeight, bw('#app-ui .au-chip'), cs('#app-ui .au-chip').backgroundColor],
          title: cs('#app-ui .au-sample-title, #app-ui .au-main .au-title').fontSize+'/'+cs('#app-ui .au-main .au-title').fontWeight,
          item: cs('#app-ui .au-cards .au-item').fontSize+'/'+cs('#app-ui .au-cards .au-item').fontWeight,
          desc: [cs('#app-ui .au-cards .au-desc').fontSize+'/'+cs('#app-ui .au-cards .au-desc').fontWeight, cs('#app-ui .au-cards .au-desc').color],
          th: [cs('#app-ui .au-tcard th').fontSize+'/'+cs('#app-ui .au-tcard th').fontWeight, cs('#app-ui .au-tcard th').color],
          td: cs('#app-ui .au-tcard td', 1).fontSize+'/'+cs('#app-ui .au-tcard td', 1).fontWeight,
          rowLine: [row.borderBottomWidth, row.borderBottomColor],
          gap: cards.length===2 ? Math.round(cards[1].left - cards[0].right) : -1, stacked: cards.length===2 && cards[1].top > cards[0].bottom - 1 ? Math.round(cards[1].top - cards[0].bottom) : null,
          inputBorder: (() => { const i = document.querySelector('#f1'); return i ? getComputedStyle(i).borderTopWidth : 'none' })(),
          tokens: ['--surface-sel','--line-soft','--r-card','--r-pill'].map(k => root.getPropertyValue(k).trim()),
        };
      });
      t(`${tag}: ページ・カード・選択の色`, m.bone===e.bone && m.card===e.card && m.sel===e.sel, `${m.bone} / ${m.card} / ${m.sel}`);
      t(`${tag}: カード・表・バナー・ナビに枠線なし`, [m.cardBorder,m.tcardBorder,m.bannerBorder,m.navBorder].every(v => v==='0px 0px 0px 0px'), [m.cardBorder,m.tcardBorder,m.bannerBorder,m.navBorder].join(' | '));
      t(`${tag}: カード・表・バナーの角 16px`, [m.cardRadius,m.tcardRadius,m.bannerRadius].every(v => v==='16px'), [m.cardRadius,m.tcardRadius,m.bannerRadius].join(' '));
      t(`${tag}: カードの余白 22px・バナー 22px 24px`, m.cardPad==='22px' && m.bannerPad==='22px 24px', `${m.cardPad} / ${m.bannerPad}`);
      t(`${tag}: カード同士 16px`, wn==='desktop' ? m.gap===16 : m.stacked===16, wn==='desktop' ? `横 ${m.gap}` : `縦 ${m.stacked}`);
      t(`${tag}: ボタン・チップ・ナビはピル（>=999px）`, [m.navRadius,m.btnPri[0],m.btnSec[0],m.chip[0]].every(v => parseFloat(v)>=999), [m.navRadius,m.btnPri[0],m.btnSec[0],m.chip[0]].join(' '));
      t(`${tag}: 主なボタンは --accent 塗り・それ以外は surface-sel（枠は透明）`, m.btnPri[1]===(theme==='light'?'rgb(5, 5, 5)':'rgb(245, 245, 244)') && m.btnSec[1]===e.sel && m.btnSec[3]==='rgba(0, 0, 0, 0)', `${m.btnPri[1]} / ${m.btnSec[1]}（枠の色は透明。主ボタン・danger と外寸をそろえるための 1px）`);
      t(`${tag}: 文字 3 段 28/700・15/600（項目・ボタン・ナビ）・13/400 mute`, m.title==='28px/700' && m.item==='15px/600' && m.navSize==='15px/600' && m.btnPri[2]==='15px/600' && m.btnSec[2]==='15px/600' && m.desc[0]==='13px/400' && m.chip[1]==='13px/400' && m.th[0]==='13px/400' && m.desc[1]===e.mute && m.th[1]===e.mute, `${m.title} ${m.item} ${m.navSize} ${m.desc.join(' ')} ${m.th.join(' ')}`);
      t(`${tag}: 表の本文は 15/400・行の区切りは 1px の --line-soft（枠線ではない薄い線）`, m.td==='15px/400' && m.rowLine[0]==='1px' && /\/ 0\.06\)$/.test(m.rowLine[1]), `${m.td} ${m.rowLine.join(' ')}`);
      t(`${tag}: 入力欄の枠は残る（1px）`, m.inputBorder==='1px', m.inputBorder);
      t(`${tag}: トークン --surface-sel / --line-soft / --r-card / --r-pill`, m.tokens[0]===(theme==='light'?'#ebebea':'#1e1e21') && /color-mix/.test(m.tokens[1]) && m.tokens[2]==='16px' && m.tokens[3]==='999px', m.tokens.join(' | '));
      // 文字コントラスト（mute 13px を各面に置く）
      const bg = { bone:rgb(e.bone), card:rgb(e.card), sel:rgb(e.sel) }; const mute = rgb(e.mute);
      const ctr = ['bone','card','sel'].map(k => cr(mute, bg[k]));
      t(`${tag}: mute のコントラスト（bone / card / sel）`, ctr[0]>=4.5 && ctr[1]>=4.5, ctr.map(v => v.toFixed(2)).join(' / ') + (ctr[2]<4.5 ? '（sel 上は --mute-on-soft を使う規定）' : ''));
      const ms = await p.evaluate(() => { const c = document.querySelector('#app-ui .au-chip'); return getComputedStyle(c).color });
      const cc = cr(rgb(ms), bg.sel); t(`${tag}: sel 上のチップ文字（--mute-on-soft）4.5:1 以上`, cc>=4.5, cc.toFixed(2));
      // いろはの決定（PR #21 の直し）: 浮かぶ面の枠・アラート・線でなく余白・図の点線なし
      const fx = await p.evaluate(() => {
        const cs = (s, i=0) => getComputedStyle(document.querySelectorAll(s)[i]);
        const probe = document.createElement('i'); probe.style.cssText = 'border:1px solid var(--line-soft)'; document.body.appendChild(probe);
        const soft = getComputedStyle(probe).borderTopColor; probe.remove();
        const bw = c => ['Top','Right','Bottom','Left'].map(k => c['border'+k+'Width']).join(' ');
        const floats = ['.modal', '#states .zs .dd1', '#states .zs .mdl', '#states .zs .pop', '#states .dlg', '#states .dpn', '#p0 .dd-panel', '#p0 .pop', '#p1 .sugg', '#p2 .cmdk', '#p2 .coach-tip', '#p2 .snackbar']
          .map(s => { const c = cs(s); return [s, bw(c), c.borderTopColor, c.boxShadow] });
        const al = cs('#al-stage .al[data-al=info]'), dan = cs('#al-stage .al[data-al=danger]'), warn = cs('#al-stage .al[data-al=warning]');
        const ic = document.querySelector('#al-stage .al[data-al=warning] > span:first-child');
        const fs = [...document.querySelectorAll('#states .np-fs')].map(e => e.getBoundingClientRect());
        const fsStyle = cs('#states .np-fs'), cardT = cs('#states .np-card-t'), fig = cs('#app-ui .au-fig');
        return { soft, floats,
          alBorder: bw(al), alLeft: al.borderLeftStyle + ' ' + al.borderLeftColor, alBg: al.backgroundColor, alRadius: al.borderRadius,
          danBorder: bw(dan), danColor: dan.borderTopColor, infoColor: al.borderTopColor, warnColor: warn.borderTopColor, icon: getComputedStyle(ic).color, warnVar: getComputedStyle(ic.parentElement).getPropertyValue('--c').trim(),
          cardTBorder: bw(cardT), fsBorder: bw(fsStyle), fsGap: fs.length === 2 ? Math.round(fs[1].top - fs[0].bottom) : -1, fsItemGap: fsStyle.rowGap,
          figOutline: fig.outlineStyle + ' ' + fig.outlineWidth, figBorder: bw(fig),
          tok: (v => { const q = document.createElement('i'); q.style.color = 'var(' + v + ')'; document.body.appendChild(q); const c = getComputedStyle(q).color; q.remove(); return c })('--warning'),
          tokInfo: (() => { const q = document.createElement('i'); q.style.color = 'var(--info)'; document.body.appendChild(q); const c = getComputedStyle(q).color; q.remove(); return c })(),
          iconInfo: getComputedStyle(document.querySelector('#al-stage .al[data-al=info] > span:first-child')).color,
          bodyWarn: getComputedStyle(document.querySelector('#al-stage .al[data-al=warning] > div')).color, bodyInfo: getComputedStyle(document.querySelector('#al-stage .al[data-al=info] > div')).color };
      });
      t(`${tag}: 浮かぶ面（モーダル・ドロップダウン・ポップオーバー ほか 12 種）は 1px の --line-soft の枠・影あり/なしは従来どおり`, fx.floats.every(f => f[1]==='1px 1px 1px 1px' && f[2]===fx.soft), fx.floats.filter(f => !(f[1]==='1px 1px 1px 1px' && f[2]===fx.soft)).map(f => f.join(' ')).join(' | ') || fx.soft);
      t(`${tag}: モーダルの影は従来どおり（Light 0 1px 2px 6% / Dark 0 1px 2px 40%）`, (() => { const s = fx.floats.find(f => f[0]==='.modal')[3]; return theme==='light' ? /0\.06\)? 0px 1px 2px 0px|rgba\(0, 0, 0, 0\.06\) 0px 1px 2px 0px/.test(s) : /rgba\(0, 0, 0, 0\.4\) 0px 1px 2px 0px/.test(s) })(), fx.floats.find(f => f[0]==='.modal')[3]);
      t(`${tag}: アラートは左の帯なし・地 surface-sel・角 16px・枠は透明 1px（danger 以外）`, /^1px 1px 1px 1px$/.test(fx.alBorder) && fx.alLeft.endsWith('rgba(0, 0, 0, 0)') && fx.alBg===e.sel && fx.alRadius==='16px' && fx.infoColor==='rgba(0, 0, 0, 0)' && fx.warnColor==='rgba(0, 0, 0, 0)', `${fx.alBorder} / ${fx.alLeft} / ${fx.alBg} / ${fx.alRadius}`);
      t(`${tag}: danger のアラートだけ枠 40%（--danger）`, fx.danColor !== 'rgba(0, 0, 0, 0)' && /(\/ 0\.4\)|, 0\.4\))$/.test(fx.danColor), fx.danColor);
      t(`${tag}: アラートの状態色は先頭のアイコンだけ（アイコン色 = --warning / --info の実測値・本文色はそれと別）`, fx.icon===fx.tok && fx.iconInfo===fx.tokInfo && fx.bodyWarn!==fx.tok && fx.bodyInfo!==fx.tokInfo, `icon ${fx.icon} (--warning ${fx.tok}) / info icon ${fx.iconInfo} (--info ${fx.tokInfo}) / 本文 ${fx.bodyWarn}, ${fx.bodyInfo}`);
      t(`${tag}: .np-card の題に下線なし・.np-fs に上線なし・項目 16px・まとまり 24px`, fx.cardTBorder==='0px 0px 0px 0px' && fx.fsBorder==='0px 0px 0px 0px' && fx.fsItemGap==='16px' && fx.fsGap===24, `${fx.cardTBorder} / ${fx.fsBorder} / 項目 ${fx.fsItemGap} / まとまり ${fx.fsGap}`);
      t(`${tag}: 「面は濃さで分ける」の図に点線の枠なし`, fx.figOutline.startsWith('none') && fx.figBorder==='0px 0px 0px 0px', `${fx.figOutline} / ${fx.figBorder}`);
      // フォーカスの輪は残る
      await p.focus('#app-ui .au-hd .btn'); await p.keyboard.press('Tab'); await p.keyboard.press('Shift+Tab');
      const fo = await p.evaluate(() => { const c = getComputedStyle(document.activeElement); return c.outlineStyle+' '+c.outlineWidth });
      t(`${tag}: :focus-visible の輪が出る`, /solid [23]px/.test(fo), fo);
      const ov = await p.evaluate(() => { const cw = document.documentElement.clientWidth; return [...document.querySelectorAll('#app-ui, #app-ui *')].filter(x => x.getBoundingClientRect().right > cw+.5 && !x.closest('[style*="overflow"]') && getComputedStyle(x).position!=='fixed').map(x => x.className||x.tagName).slice(0,5) });
      t(`${tag}: #app-ui の見本がはみ出さない`, ov.length===0, ov.join(','));
      await p.locator('#app-ui').screenshot({ path:`${out}/${process.env.PREFIX||"bg20"}-${wn}-${theme}-app-ui.png` });
      await p.close();
    }
  }
  await b.close(); console.log(`PASS ${pass} FAIL ${fail}`); process.exit(fail?1:0);
})().catch(e=>{console.error(e);process.exit(2)});
