/* Uygulama başlatma: yönlendirici, üst menü, canlı düşüş akışı */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;
  CS.Pages = CS.Pages || {};

  /* ---------- Canlı düşüş akışı ---------- */
  const Feed = {
    push(d, who, me) {
      const track = U.$('#feedTrack');
      if (!track) return;
      const it = E.items[d.i];
      const [top, bottom] = UI.nameParts(it, d);
      const el = U.html(`<div class="fitem t${it.tier}${me ? ' me' : ''}" style="--rc:${UI.color(it.tier)}" title="${U.esc(UI.dropName(d))} · ${U.esc(d.src || '')}">
        <img src="${E.img(it.imgS, 128)}" alt="">
        <div class="fi-txt"><small>${U.esc(who)}</small><b>${U.esc(bottom)}</b><span>${U.money(d.p)}</span></div></div>`);
      track.prepend(el);
      requestAnimationFrame(() => el.classList.add('in'));
      while (track.children.length > 28) track.lastElementChild.remove();
    },
  };
  CS.Feed = Feed;

  let botCases = null;
  function botLoop() {
    if (!botCases) {
      botCases = {
        weapon: E.cases.filter((c) => c.type === 'case'),
        any: E.cases.filter((c) => c.type !== 'case'),
      };
    }
    // Bir kasadan birkaç açılış yap, en iyisini akışta göster
    if (!document.hidden) {
      const c = U.pick(Math.random() < 0.75 ? botCases.weapon : botCases.any);
      let best = null;
      const tries = U.randInt(4, 30);
      for (let k = 0; k < tries; k++) {
        const d = E.roll(c);
        if (!best || E.items[d.i].tier > E.items[best.i].tier) best = d;
      }
      Feed.push(best, U.pick(E.BOT_NAMES), false);
    }
    setTimeout(botLoop, U.randInt(1600, 4200));
  }

  /* ---------- Yönlendirici ---------- */
  const routes = [
    [/^\/?$/, 'cases'],
    [/^\/case\/(\d+)$/, 'opener'],
    [/^\/battles$/, 'battles'],
    [/^\/battle\/new$/, 'battleNew'],
    [/^\/battle\/([\w-]+)$/, 'battleRoom'],
    [/^\/upgrader$/, 'upgrader'],
    [/^\/tradeup$/, 'tradeup'],
    [/^\/inventory$/, 'inventory'],
    [/^\/catalog$/, 'catalog'],
    [/^\/stats$/, 'stats'],
  ];
  let cleanup = null;

  function route() {
    const path = (location.hash || '#/').slice(1) || '/';
    let page = 'cases', params = [];
    for (const [re, name] of routes) {
      const m = path.match(re);
      if (m) { page = name; params = m.slice(1); break; }
    }
    if (typeof cleanup === 'function') { try { cleanup(); } catch (e) { console.error(e); } }
    cleanup = null;
    const view = U.$('#view');
    view.innerHTML = '';
    view.className = 'view page-' + page;
    const nav = { cases: 'cases', opener: 'cases', battles: 'battles', battleNew: 'battles', battleRoom: 'battles' }[page] || page;
    U.$$('.nav a').forEach((a) => a.classList.toggle('active', a.dataset.nav === nav));
    U.$('body').classList.remove('menu-open');
    window.scrollTo(0, 0);
    const fn = CS.Pages[page];
    if (fn) {
      try { cleanup = fn(view, params); } catch (e) {
        console.error(e);
        view.innerHTML = `<div class="empty">Bir hata oluştu: ${U.esc(e.message)}</div>`;
      }
    }
  }

  /* ---------- Başlat ---------- */
  function init() {
    U.$('#balance').dataset.v = S.balance;
    U.$('#balance').textContent = U.money(S.balance);
    U.$('#invCount').textContent = S.inv.length;
    S.on(UI.updateBalance);

    U.$('#addBalance').onclick = () => UI.depositModal();
    U.$('#balanceChip').onclick = (e) => { if (e.target.id !== 'addBalance') UI.depositModal(); };
    const snd = U.$('#soundBtn');
    const setSnd = () => { snd.textContent = S.settings.sound ? '🔊' : '🔇'; snd.title = S.settings.sound ? 'Sesi kapat' : 'Sesi aç'; };
    setSnd();
    snd.onclick = () => { S.settings.sound = !S.settings.sound; S.save(); setSnd(); if (S.settings.sound) CS.Snd.click(); };
    U.$('#menuBtn').onclick = () => U.$('body').classList.toggle('menu-open');

    // Görsel yüklenemezse yedek
    document.addEventListener('error', (e) => {
      const t = e.target;
      if (t && t.tagName === 'IMG' && !t.dataset.fb) { t.dataset.fb = '1'; t.src = E.FALLBACK; }
    }, true);

    window.addEventListener('hashchange', route);
    route();
    const sp = U.$('#splash');
    if (sp) { sp.classList.add('hide'); setTimeout(() => sp.remove(), 500); }
    setTimeout(botLoop, 800);
    U.$('#footInfo').textContent = `${E.cases.length} kasa/paket · ${U.num(E.items.length)} eşya · veri: ${E.dataVersion}`;
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})(window.CS);
