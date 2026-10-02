/* Kasa açma sayfası */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;
  let lastCount = 1;

  CS.Pages.opener = (view, params) => {
    const c = E.cases[+params[0]];
    if (!c) { view.innerHTML = '<div class="empty">Kasa bulunamadı. <a href="#/">Geri dön</a></div>'; return; }
    let count = lastCount, busy = false;
    const pool = E.pool(c);

    // İçerik: ağırlık sırasına göre
    const normal = c.items.slice().sort((a, b) => E.items[b].tier - E.items[a].tier || E.typicalPrice(E.items[b]) - E.typicalPrice(E.items[a]));
    const rareGroups = [];
    const seen = new Map();
    for (const i of c.rare) {
      const it = E.items[i];
      if (!seen.has(it.name)) { seen.set(it.name, rareGroups.length); rareGroups.push([]); }
      rareGroups[seen.get(it.name)].push(i);
    }
    const stOpt = E.dropsST(c), svOpt = E.dropsSV(c);

    const contentCard = (i) => {
      const it = E.items[i];
      const [lo, hi] = E.priceRange(it, { st: stOpt, sv: svOpt });
      return UI.itemCard(it, {
        topLeft: U.pct(E.itemChance(c, i)),
        price: lo === hi ? U.money(lo) : `${U.money(lo)} – ${U.money(hi)}`,
        cls: 'clickable',
      });
    };
    const rareCard = (g) => {
      const it = E.items[g[0]];
      const ch = g.reduce((a, i) => a + E.itemChance(c, i), 0);
      const prices = g.map((i) => E.priceRange(E.items[i], { st: stOpt }));
      const lo = Math.min(...prices.map((p) => p[0])), hi = Math.max(...prices.map((p) => p[1]));
      return UI.itemCard(it, {
        topLeft: U.pct(ch), topRight: g.length > 1 ? `<span class="badge b-ph">${g.length} faz</span>` : '',
        price: `${U.money(lo)} – ${U.money(hi)}`, cls: 'clickable',
      });
    };

    view.innerHTML = `
      <a class="back" href="#/">← Kasalar</a>
      <section class="op-head">
        <div class="op-case"><img src="${E.img(c.imgS, 512)}" alt=""></div>
        <div class="op-meta">
          <span class="cc-type ct-${c.type}">${E.CASE_TYPE_NAME[c.type]}</span>
          <h1>${U.esc(c.name)}</h1>
          <div class="muted">${c.date ? 'Çıkış: ' + U.esc(c.date) + ' · ' : ''}${c.items.length + c.rare.length} eşya${c.rare.length ? ' · ★ Nadir özel eşya içerir' : ''}${stOpt ? ' · StatTrak™ şansı %10' : ''}${svOpt ? ' · Hatıra eşyalar' : ''}</div>
          <div class="op-price">${U.money(c.price)}</div>
          <div class="op-controls">
            <div class="seg" id="countSeg">${[1, 2, 3, 4, 5].map((n) => `<button data-n="${n}" class="${n === count ? 'active' : ''}">x${n}</button>`).join('')}</div>
            <button class="btn primary big" id="openBtn"></button>
            <button class="btn big ghost" id="demoBtn" title="Ücretsiz deneme - eşya verilmez">Deneme</button>
            <label class="switch"><input type="checkbox" id="fastChk" ${S.settings.fast ? 'checked' : ''}><span></span>Hızlı</label>
          </div>
        </div>
      </section>
      <section class="op-stage" id="stage"></section>
      <section class="op-results" id="results"></section>
      <section class="panel">
        <h3>Düşme Oranları</h3>
        <div class="odds">${pool.map((g) => `<div class="odd" style="--rc:${UI.color(g.tier)}"><span class="odd-bar" style="width:${Math.max(2, g.p * 100)}%"></span>
          <span class="odd-n">${g.tier === 6 ? '★ Nadir Özel Eşya' : E.tierName(E.items[g.items[0]])}</span><b>${U.pct(g.p)}</b></div>`).join('')}</div>
      </section>
      <section class="panel">
        <h3>Kasanın İçeriği <small>${c.items.length}</small></h3>
        <div class="grid items-grid" id="contents">${normal.map(contentCard).join('')}</div>
      </section>
      ${rareGroups.length ? `<section class="panel rare-panel">
        <h3>★ Nadir Özel Eşyalar <small>${rareGroups.length}</small></h3>
        <div class="grid items-grid" id="rares">${rareGroups.map(rareCard).join('')}</div>
      </section>` : ''}`;

    const openBtn = U.$('#openBtn', view), demoBtn = U.$('#demoBtn', view);
    const stage = U.$('#stage', view), results = U.$('#results', view);
    const setBtn = () => {
      openBtn.innerHTML = `KASAYI AÇ · ${U.money(c.price * count)}`;
      openBtn.disabled = busy; demoBtn.disabled = busy;
      U.$$('#countSeg button', view).forEach((b) => { b.disabled = busy; });
    };
    setBtn();
    stage.innerHTML = `<div class="stage-idle"><img src="${E.img(c.imgS, 256)}" alt=""><span>Açmak için butona bas</span></div>`;

    async function open(demo) {
      if (busy) return;
      const cost = U.round2(c.price * count);
      if (!demo && !S.canAfford(cost)) {
        UI.toast(`Yetersiz bakiye! <a href="javascript:void 0" onclick="CS.UI.depositModal()">Bakiye ekle</a>`, 'err');
        CS.Snd.beep(false);
        return;
      }
      busy = true; setBtn();
      const fast = U.$('#fastChk', view).checked;
      const drops = [];
      for (let k = 0; k < count; k++) drops.push(E.roll(c));
      if (!demo) {
        S.charge(cost);
        for (const d of drops) { S.addItem(d); S.recordDrop(d, c.price); }
        S.stats.opened += count;
        S.addHist({ k: 'open', c: c.idx, n: count, cost, v: U.round2(drops.reduce((a, d) => a + d.p, 0)) });
        S.save();
      }
      results.innerHTML = '';
      CS.Snd.open();
      stage.innerHTML = drops.map(() => '<div class="op-reel"></div>').join('');
      const r = stage.getBoundingClientRect();
      if (r.top < 120 || r.bottom > window.innerHeight) stage.scrollIntoView({ behavior: 'smooth', block: 'center' });
      const reels = U.$$('.op-reel', stage);
      await Promise.all(drops.map((d, k) => CS.Reel.spin(reels[k], c, d, { axis: 'x', fast, sound: k === 0 })));
      if (!view.isConnected) return;
      const maxTier = Math.max(...drops.map((d) => E.items[d.i].tier));
      CS.Snd.reveal(maxTier);
      if (maxTier >= 5) UI.confetti(maxTier >= 6 ? 200 : 90);
      if (!demo) for (const d of drops) CS.Feed.push(d, 'Sen', true);
      showResults(drops, demo);
      busy = false; setBtn();
    }

    function showResults(drops, demo) {
      const total = U.round2(drops.reduce((a, d) => a + d.p, 0));
      const cost = U.round2(c.price * drops.length);
      const diff = U.round2(total - cost);
      results.innerHTML = `<div class="res-head">
          <div><h3>${demo ? 'Deneme sonucu' : 'Kazandıkların'}</h3>
          <span class="muted">Toplam değer <b>${U.money(total)}</b> ${demo ? '' : `· <b class="${diff >= 0 ? 'pos' : 'neg'}">${diff >= 0 ? '+' : ''}${U.money(diff)}</b>`}</span></div>
          <div class="row gap">
            ${demo ? '' : `<button class="btn" id="sellAll">Hepsini sat · ${U.money(total)}</button>`}
            <button class="btn primary" id="again">Tekrar aç</button>
          </div></div>
        <div class="grid res-grid">${drops.map((d) => UI.dropCard(d, {
          float: true, cls: 'pop clickable' + (demo ? ' demo' : ''),
          extra: demo ? '<span class="badge">DENEME</span>' : `<button class="mini-btn" data-sell="${d.u}">Sat</button>`,
        })).join('')}</div>`;
      results.querySelectorAll('.icard').forEach((el, k) => {
        el.style.animationDelay = k * 80 + 'ms';
        el.addEventListener('click', (e) => {
          if (e.target.closest('[data-sell]')) return;
          UI.dropModal(drops[k], { noActions: demo, onChange: () => refreshSold(drops) });
        });
      });
      const again = U.$('#again', results);
      again.onclick = () => open(demo);
      const sa = U.$('#sellAll', results);
      if (sa) {
        sa.onclick = () => {
          const own = drops.filter((d) => S.getItem(d.u)).map((d) => d.u);
          if (!own.length) return;
          const v = S.sell(own);
          CS.Snd.coin();
          UI.toast(`${own.length} eşya satıldı: +${U.money(v)}`, 'ok');
          refreshSold(drops);
        };
      }
      results.onclick = (e) => {
        const b = e.target.closest('[data-sell]');
        if (!b) return;
        const u = +b.dataset.sell;
        if (!S.getItem(u)) return;
        const v = S.sell([u]);
        CS.Snd.coin();
        UI.toast(`Satıldı +${U.money(v)}`, 'ok');
        refreshSold(drops);
      };
      results.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    function refreshSold(drops) {
      for (const d of drops) {
        const el = results.querySelector(`.icard[data-u="${d.u}"]`);
        if (el && !S.getItem(d.u)) {
          el.classList.add('sold');
          const b = el.querySelector('[data-sell]');
          if (b) b.outerHTML = '<span class="badge b-sold">SATILDI</span>';
        }
      }
      const sa = U.$('#sellAll', results);
      if (sa && !drops.some((d) => S.getItem(d.u))) sa.remove();
    }

    U.$('#countSeg', view).addEventListener('click', (e) => {
      const b = e.target.closest('[data-n]');
      if (!b || busy) return;
      count = lastCount = +b.dataset.n;
      U.$$('#countSeg button', view).forEach((x) => x.classList.toggle('active', x === b));
      setBtn();
      CS.Snd.click();
    });
    U.$('#fastChk', view).addEventListener('change', (e) => { S.settings.fast = e.target.checked; S.save(); });
    openBtn.onclick = () => open(false);
    demoBtn.onclick = () => open(true);

    const onCardClick = (e) => {
      const card = e.target.closest('.icard[data-i]');
      if (card) UI.catalogModal(E.items[+card.dataset.i]);
    };
    U.$('#contents', view).addEventListener('click', onCardClick);
    const rares = U.$('#rares', view);
    if (rares) {
      rares.addEventListener('click', (e) => {
        const card = e.target.closest('.icard[data-i]');
        if (!card) return;
        const it = E.items[+card.dataset.i];
        const g = rareGroups.find((x) => E.items[x[0]].name === it.name);
        if (g && g.length > 1) {
          UI.modal(`<h2>${U.esc(it.name)}</h2><p class="muted">Faz olasılıkları (nadir özel eşya düştüğünde)</p>
            <div class="grid items-grid">${g.map((i) => UI.itemCard(E.items[i], { topLeft: U.pct(E.itemChance(c, i)), cls: 'clickable' })).join('')}</div>`, { cls: 'wide' })
            .body.addEventListener('click', onCardClick);
        } else UI.catalogModal(it);
      });
    }

    const onKey = (e) => {
      if (e.code === 'Space' && document.activeElement === document.body && !document.querySelector('.modal-wrap')) {
        e.preventDefault();
        open(false);
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  };
})(window.CS);
