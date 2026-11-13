const { chromium } = require('playwright');
const root = require('path').resolve(__dirname, '../../..');
const out = root + '/docs/pr-evidence/18';
const lin = c => { c/=255; return c<=.03928 ? c/12.92 : ((c+.055)/1.055)**2.4 };
const L = ([r,g,b]) => .2126*lin(r)+.7152*lin(g)+.0722*lin(b);
const cr = (a,b) => { const x=L(a), y=L(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05) };
const rgb = s => s.match(/\d+(\.\d+)?/g).slice(0,3).map(Number);
let pass=0, fail=0; const t=(n,c,d='')=>{ c?pass++:fail++; console.log((c?'PASS ':'FAIL ')+n+(d?'  '+d:'')) };
(async()=>{
  const b = await chromium.launch();
  for (const [w,h,wn] of [[1280,900,'desktop'],[390,844,'mobile390']]) {
    for (const theme of ['light','dark']) {
      const ctx = await b.newContext({ viewport:{width:w,height:h}, deviceScaleFactor:1 });
      const p = await ctx.newPage();
      await p.goto('file://'+root+'/index.html'); await p.waitForTimeout(400);
      await p.click(`[data-set-theme=${theme}]`);
      t(`${wn}/${theme}: data-theme=${theme}`, await p.evaluate(()=>document.documentElement.dataset.theme)===theme);
      const v = await p.evaluate(()=>{ const cs=getComputedStyle(document.documentElement); return [cs.getPropertyValue('--overlay-deep').trim(), cs.getPropertyValue('--overlay-pale').trim()] });
      t(`${wn}/${theme}: トークン値（テーマで変わらない）`, v[0]==='#5a0000'&&v[1]==='#ff8c96', v.join(' '));
      const sec = p.locator('#overlay');
      t(`${wn}/${theme}: #overlay が #states 相当の直前節（状態色）の次`, await p.evaluate(()=>document.getElementById('overlay').previousElementSibling.querySelector('h2').textContent==='状態色' && document.getElementById('overlay').nextElementSibling.querySelector('h2').textContent==="Do / Don't"));
      const tiles = await p.evaluate(()=>[...document.querySelectorAll('#overlay .ov-ph')].map(d=>{ const path=d.querySelector('path'); const pc=getComputedStyle(path); const bg=getComputedStyle(d).backgroundImage; return {cls:d.className, stroke:pc.stroke, op:pc.opacity, bg} }));
      t(`${wn}/${theme}: 見本 4 つ・不透明度 .55`, tiles.length===4 && tiles.every(x=>x.op==='0.55'));
      t(`${wn}/${theme}: 塗りの色は deep=rgb(90,0,0)・pale=rgb(255,140,150)`, tiles.filter(x=>x.stroke==='rgb(90, 0, 0)').length===2 && tiles.filter(x=>x.stroke==='rgb(255, 140, 150)').length===2);
      // 選ぶ側の見え方（グラデーション両端で 3:1 以上）
      if (theme==='light' && wn==='desktop') {
        const blend=(pt,bg)=>pt.map((c,i)=>.55*c+.45*bg[i]);
        const ends={bright:[[247,244,238],[211,205,192]], dark:[[5,5,5],[28,28,32]]};
        for (const [ph,tok,col] of [['bright','deep',[90,0,0]],['dark','pale',[255,140,150]],['bright','pale',[255,140,150]],['dark','deep',[90,0,0]]]) {
          const rs=ends[ph].map(bg=>cr(blend(col,bg),bg));
          const sel=(ph==='bright'&&tok==='deep')||(ph==='dark'&&tok==='pale');
          t(`見本の見え方: ${ph}×${tok}（${sel?'選ぶ':'選ばない'}）`, sel? rs.every(r=>r>=3) : rs.every(r=>r<3), rs.map(r=>r.toFixed(2)).join('/'));
        }
        const lum=await p.evaluate(()=>{ const out={}; for (const k of ['bright','dark']){ const c=document.createElement('canvas');c.width=c.height=16;const x=c.getContext('2d'); const el=document.querySelector('#overlay .ov-'+k); const g=getComputedStyle(el).backgroundImage; out[k]=g } return out });
        console.log('  gradient', JSON.stringify(lum));
      }
      const ov = await p.evaluate(()=>{const cw=document.documentElement.clientWidth; return {cw, n:[...document.querySelectorAll('#overlay, #overlay *')].filter(e=>e.getBoundingClientRect().right>cw+.5||e.getBoundingClientRect().left<-.5).length}});
      t(`${wn}/${theme}: #overlay 内にはみ出す要素なし（ページ全体の 396px は main 既存の #theme の code で、この節とは無関係）`, ov.n===0, `n=${ov.n} cw=${ov.cw}`);
      await p.waitForTimeout(150);
      const f = `${out}/bg18-chromium-${wn}-${theme}-overlay.png`;
      await sec.screenshot({ path:f }); console.log('shot', f);
      await ctx.close();
    }
  }
  await b.close(); console.log(`PASS ${pass} FAIL ${fail}`); process.exit(fail?1:0);
})().catch(e=>{console.error(e);process.exit(2)});
