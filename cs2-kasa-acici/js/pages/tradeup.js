/* Takas Sözleşmesi (Trade-Up): 10 eşya -> 1 üst kalite, 5 Örtülü -> ★ */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;
  const PHASE_W = { 'Phase 1': 23, 'Phase 2': 23, 'Phase 3': 23, 'Phase 4': 23, Ruby: 3, Sapphire: 3, 'Black Pearl': 2, Emerald: 6 };
  const poolCache = new Map();
  const st = { sel: [], tier: -1 };

  // Bir girdi eşyasının olası sonuç anahtarları (Örtülü için ★ grup isimleri)
  function pool(it) {
    if (poolCache.has(it.idx)) return poolCache.get(it.idx);
    let out = [];
    if (it.kind === 's' && it.tier < 5) {
      const set = new Set();
      for (const ci of it.cols) for (const j of E.cols[ci].it) {
        const o = E.items[j];
        if (o.kind === 's' && o.tier === it.tier + 1) set.add(j);
      }
      out = [...set].map((j) => ({ key: 'i' + j, idxs: [j] }));
    } else if (it.kind === 's' && it.tier === 5) {
      const groups = new Map();
      for (const ci of it.cols) for (const k of E.cols[ci].cs) {
        const c = E.cases[k];
        if (c.type !== 'case') continue;
        for (const j of c.rare) {
          const n = E.items[j].name;
          if (!groups.has(n)) groups.set(n, new Set());
          groups.get(n).add(j);
        }
      }
      out = [...groups].map(([n, s]) => ({ key: 'g' + n, idxs: [...s] }));
    }
    poolCache.set(it.idx, out);
    return out;
  }

  const eligible = (d) => {
    const it = E.items[d.i];
    return it.kind === 's' && it.tier <= 5 && !d.sv && pool(it).length > 0;
  };
  const need = (tier) => (tier === 5 ? 5 : 10);

  function outcomes(drops) {
    const tickets = new Map();
    let total = 0;
    for (const d of drops) {
      const p = pool(E.items[d.i]);
      total += p.length;
      for (const g of p) {
        if (!tickets.has(g.key)) tickets.set(g.key, { g, n: 0 });
        tickets.get(g.key).n++;
      }
    }
    return [...tickets.values()].map(({ g, n }) => ({ g, p: n / total })).sort((a, b) => b.p - a.p);
  }

  function avgNorm(drops) {
    const vals = drops.map((d) => {
      const it = E.items[d.i];
      return it.min >= 0 && d.f >= 0 ? (d.f - it.min) / Math.max(1e-6, it.max - it.min) : 0.5;
    });
    return vals.reduce((a, v) => a + v, 0) / vals.length;
  }
  const outFloat = (it, avg) => (it.min < 0 ? -1 : +(it.min + avg * (it.max - it.min)).toFixed(10));

  CS.Pages.tradeup = (view) => {
    st.sel = st.sel.filter((u) => S.getItem(u));
    if (!st.sel.length) st.tier = -1;
    let busy = false;

    view.innerHTML = `
      <h1 class="page-title">🔁 Takas Sözleşmesi</h1>
      <p class="muted">Aynı kalitede <b>10 eşya</b> ver, aynı koleksiyonlardan <b>bir üst kalitede 1 eşya</b> al. CS2'deki gibi <b>5 Örtülü (kırmızı)</b> eşya ile ★ bıçak/eldiven çıkarabilirsin! Çıkan eşyanın float değeri girdilerin ortalamasına göre hesaplanır.</p>
      <section class="tu-top">
        <div class="panel tu-slots-wrap"><div class="tu-slots" id="slots"></div></div>
        <div class="panel tu-info" id="info"></div>
      </section>
      <section class="panel"><h3>Olası Sonuçlar</h3><div class="grid items-grid sm" id="outs"></div></section>
      <section class="panel">
        <div class="row between wrap gap"><h3>Uygun Eşyaların</h3><div class="tabs small" id="tierTabs"></div></div>
        <div class="grid items-grid sm" id="elig"></div>
      </section>`;

    const selDrops = () => st.sel.map((u) => S.getItem(u)).filter(Boolean);

    function render() {
      const drops = selDrops();
      const n = st.tier >= 0 ? need(st.tier) : 10;
      const slots = [];
      for (let k = 0; k < n; k++) slots.push(drops[k] ? UI.dropCard(drops[k], { cls: 'small clickable' }) : '<div class="slot-empty">+</div>');
      U.$('#slots', view).innerHTML = slots.join('');

      const value = U.round2(drops.reduce((a, d) => a + d.p, 0));
      const outs = drops.length ? outcomes(drops) : [];
      const avg = drops.length ? avgNorm(drops) : 0;
      const isST = drops.length && drops[0].st;
      let ev = 0;
      const outCards = outs.map(({ g, p }) => {
        const tot = g.idxs.reduce((a, j) => a + (g.idxs.length > 1 ? PHASE_W[E.items[j].phase] || 10 : 1), 0);
        let gev = 0;
        for (const j of g.idxs) {
          const it = E.items[j];
          const w = g.idxs.length > 1 ? (PHASE_W[it.phase] || 10) / tot : 1;
          const f = outFloat(it, avg);
          gev += w * E.priceOf({ i: j, f, st: isST && it.st && it.cat !== 'G' ? 1 : 0, sv: 0, s: -1 });
        }
        ev += p * gev;
        const it = E.items[g.idxs[0]];
        const f = outFloat(it, avg);
        return UI.itemCard(it, {
          topLeft: U.pct(p), topRight: f >= 0 ? `<span class="badge">${E.WEARS[E.wearIndex(f)].s}</span>` : '',
          price: U.money(gev), cls: 'clickable',
        });
      });
      U.$('#outs', view).innerHTML = drops.length ? outCards.join('') : '<div class="empty small">Eşya seçtikçe olası sonuçlar burada görünür.</div>';
      const ready = drops.length === n && st.tier >= 0;
      U.$('#info', view).innerHTML = `
        <div class="tu-row"><span>Kalite</span><b style="color:${st.tier >= 0 ? UI.color(st.tier) : 'inherit'}">${st.tier >= 0 ? E.TIER_SKIN[st.tier] + ' → ' + (st.tier === 5 ? '★ Nadir Özel' : E.TIER_SKIN[st.tier + 1]) : '-'}</b></div>
        <div class="tu-row"><span>StatTrak™</span><b>${drops.length ? (isST ? 'Evet' : 'Hayır') : '-'}</b></div>
        <div class="tu-row"><span>Eşya</span><b>${drops.length} / ${n}</b></div>
        <div class="tu-row"><span>Ortalama float (normalize)</span><b class="mono">${drops.length ? avg.toFixed(4) : '-'}</b></div>
        <div class="tu-row"><span>Verilen değer</span><b>${U.money(value)}</b></div>
        <div class="tu-row"><span>Beklenen değer</span><b class="${ev >= value ? 'pos' : 'neg'}">${drops.length ? U.money(ev) : '-'}</b></div>
        <div class="row gap wrap">
          <button class="btn primary big" id="sign" ${ready && !busy ? '' : 'disabled'}>✍ Sözleşmeyi İmzala</button>
          <button class="btn" id="autoFill" ${busy ? 'disabled' : ''}>Otomatik doldur</button>
          <button class="btn ghost" id="clear" ${busy ? 'disabled' : ''}>Temizle</button>
        </div>`;

      // uygun eşyalar
      const elig = S.inv.filter(eligible);
      const counts = [0, 0, 0, 0, 0, 0];
      for (const d of elig) counts[E.items[d.i].tier]++;
      const tabs = [0, 1, 2, 3, 4, 5].filter((t) => counts[t]);
      if (st.tier < 0 && !st.viewTier) st.viewTier = tabs.length ? tabs[tabs.length - 1] : 2;
      const vt = st.tier >= 0 ? st.tier : st.viewTier;
      U.$('#tierTabs', view).innerHTML = tabs.map((t) => `<button class="tab${t === vt ? ' active' : ''}" data-tier="${t}" style="--rc:${UI.color(t)}" ${st.tier >= 0 && t !== st.tier ? 'disabled' : ''}>${E.TIER_SKIN[t]} <small>${counts[t]}</small></button>`).join('');
      const selSet = new Set(st.sel);
      let list = elig.filter((d) => E.items[d.i].tier === vt && !selSet.has(d.u));
      if (drops.length) list = list.filter((d) => !!d.st === !!isST);
      list.sort((a, b) => a.p - b.p);
      U.$('#elig', view).innerHTML = list.length ? list.slice(0, 200).map((d) => UI.dropCard(d, { cls: 'clickable', float: true })).join('')
        : '<div class="empty small">Bu kalitede uygun eşyan yok. Kasa açarak eşya topla! (Hatıra eşyalar ve ★ eşyalar takasa girmez.)</div>';
    }

    async function sign() {
      const drops = selDrops();
      if (busy || st.tier < 0 || drops.length !== need(st.tier)) return;
      busy = true;
      const outs = outcomes(drops);
      const avg = avgNorm(drops);
      const isST = !!drops[0].st;
      const g = U.weighted(outs.map((o) => ({ g: o.g, w: o.p }))).g;
      const idx = g.idxs.length > 1 ? U.weighted(g.idxs.map((j) => ({ j, w: PHASE_W[E.items[j].phase] || 10 }))).j : g.idxs[0];
      const it = E.items[idx];
      const inVal = U.round2(drops.reduce((a, d) => a + d.p, 0));
      S.removeItems(drops.map((d) => d.u));
      const d = S.addItem(E.makeDrop(idx, { f: outFloat(it, avg), st: isST && it.st && it.cat !== 'G', src: 'Takas Sözleşmesi' }));
      S.stats.tradeups++;
      S.stats.tiers[it.tier]++;
      S.addHist({ k: 'tradeup', v: d.p, cost: inVal });
      S.save();
      // animasyon
      U.$('#slots', view).classList.add('merge');
      CS.Snd.whoosh();
      await U.sleep(S.settings.fast ? 500 : 1300);
      if (!view.isConnected) return;
      U.$('#slots', view).classList.remove('merge');
      CS.Snd.reveal(it.tier);
      if (it.tier >= 5 || d.p > inVal) UI.confetti(it.tier >= 6 ? 200 : 100);
      CS.Feed.push(d, 'Sen', true);
      UI.modal(`<div class="upg-res${d.p >= inVal ? ' win' : ''}"><h2>Sözleşme tamamlandı!</h2>${UI.dropCard(d, { float: true, cls: 'pop' })}
        <p>Verilen: <b>${U.money(inVal)}</b> → Alınan: <b class="${d.p >= inVal ? 'pos' : 'neg'}">${U.money(d.p)}</b></p></div>`, { cls: 'small center' });
      st.sel = []; st.tier = -1;
      busy = false;
      render();
    }

    function autoFill() {
      const tier = st.tier >= 0 ? st.tier : st.viewTier;
      if (tier == null || tier < 0) return;
      const drops = selDrops();
      const isST = drops.length ? !!drops[0].st : null;
      const selSet = new Set(st.sel);
      let list = S.inv.filter((d) => eligible(d) && E.items[d.i].tier === tier && !selSet.has(d.u));
      const stFilter = isST != null ? isST : (list.filter((d) => !d.st).length >= need(tier) - drops.length ? false : true);
      list = list.filter((d) => !!d.st === stFilter).sort((a, b) => a.p - b.p);
      for (const d of list) {
        if (st.sel.length >= need(tier)) break;
        st.sel.push(d.u);
      }
      if (st.sel.length) st.tier = tier;
      if (st.sel.length < need(tier)) UI.toast(`Yeterli eşya yok (${st.sel.length}/${need(tier)})`, 'err');
      render();
    }

    view.addEventListener('click', (e) => {
      if (busy) return;
      let el;
      if ((el = e.target.closest('#elig .icard[data-u]'))) {
        const d = S.getItem(+el.dataset.u);
        if (!d) return;
        const t = E.items[d.i].tier;
        if (st.tier < 0) st.tier = t;
        if (st.sel.length >= need(st.tier)) { UI.toast('Sözleşme dolu', 'err'); return; }
        st.sel.push(d.u);
        CS.Snd.click();
        render();
      } else if ((el = e.target.closest('#slots .icard[data-u]'))) {
        st.sel = st.sel.filter((u) => u !== +el.dataset.u);
        if (!st.sel.length) st.tier = -1;
        render();
      } else if ((el = e.target.closest('#outs .icard[data-i]'))) {
        UI.catalogModal(E.items[+el.dataset.i]);
      } else if ((el = e.target.closest('[data-tier]'))) {
        if (st.tier >= 0) return;
        st.viewTier = +el.dataset.tier;
        render();
      } else if (e.target.closest('#sign')) sign();
      else if (e.target.closest('#clear')) { st.sel = []; st.tier = -1; render(); }
      else if (e.target.closest('#autoFill')) autoFill();
    });
    render();
  };
})(window.CS);
