/* Ousiass ライト/ダーク切替（ガイド見本の共通実装・推奨案）
 *
 * モード: light / dark / system（未選択の初期値は system = prefers-color-scheme に従う）
 * 保存:   light / dark を選んだときだけ localStorage に保存する（system は保存を消す）。
 *         保存済みの間は OS の変更で上書きしない。system のときだけ OS の変化に追従する。
 * 適用:   <html data-theme="light|dark">（解決後の値）と data-theme-mode="light|dark|system"（選択値）
 * 描画前: <head> で同期読み込みして、最初の描画前に data-theme を決める（FOUC 回避）。
 * 切替時: リロードなし・スクロール位置は維持。色のアニメーションは付けない（transition を一瞬止めて即時に切り替える）。
 * UI:     [data-theme-control] 内の [data-set-theme="light|dark|system"] ボタン（aria-pressed）。
 *         Tab で移動、Space / Enter で選択、←→↑↓ / Home / End でボタン間のフォーカス移動。
 *
 * KEY はこのガイド用。プロダクトは自分の名前空間のキーを使ってよい（theme / oth など旧デモ用キーに合わせる必要はない）。
 */
(function () {
  var KEY = 'ousiass-theme';
  var root = document.documentElement;
  var mq = matchMedia('(prefers-color-scheme: dark)');

  var quietStyle = document.createElement('style');
  quietStyle.textContent =
    '[data-theme-switching] *,[data-theme-switching] *::before,[data-theme-switching] *::after{transition:none!important}';
  document.head.appendChild(quietStyle);

  /* 保存できない環境（プライベートモード等）では、このページの間だけ選択を保持する */
  var session = null;

  function stored() {
    try {
      var v = localStorage.getItem(KEY);
      if (v === 'light' || v === 'dark') return v;
    } catch (e) {
      /* 読めない環境は session を使う */
    }
    return session;
  }

  function mode() {
    return stored() || 'system';
  }

  function resolve(m) {
    return m === 'system' ? (mq.matches ? 'dark' : 'light') : m;
  }

  function sync(m) {
    document.querySelectorAll('[data-set-theme]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.setTheme === m));
    });
  }

  function apply() {
    var m = mode();
    var t = resolve(m);
    root.setAttribute('data-theme-switching', '');
    root.dataset.theme = t;
    root.dataset.themeMode = m;
    sync(m);
    document.dispatchEvent(new CustomEvent('themechange', { detail: { mode: m, theme: t } }));
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        root.removeAttribute('data-theme-switching');
      });
    });
  }

  function set(m) {
    session = m === 'light' || m === 'dark' ? m : null;
    try {
      if (session) localStorage.setItem(KEY, session);
      else localStorage.removeItem(KEY);
    } catch (e) {
      /* session のまま動かす */
    }
    apply();
  }

  var first = mode();
  root.dataset.theme = resolve(first);
  root.dataset.themeMode = first;

  mq.addEventListener('change', function () {
    if (mode() === 'system') apply();
  });

  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('[data-set-theme]');
    if (b) set(b.dataset.setTheme);
  });

  document.addEventListener('keydown', function (e) {
    var b = e.target.closest && e.target.closest('[data-theme-control] [data-set-theme]');
    if (!b) return;
    var list = Array.prototype.slice.call(b.closest('[data-theme-control]').querySelectorAll('[data-set-theme]'));
    var i = list.indexOf(b);
    var next = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: list.length - 1 }[e.key];
    if (next === undefined) return;
    e.preventDefault();
    list[(next + list.length) % list.length].focus();
  });

  document.addEventListener('DOMContentLoaded', function () {
    sync(mode());
  });

  window.OusiassTheme = {
    key: KEY,
    mode: mode,
    resolved: function () {
      return resolve(mode());
    },
    set: set,
    reset: function () {
      set('system');
    },
  };
})();
