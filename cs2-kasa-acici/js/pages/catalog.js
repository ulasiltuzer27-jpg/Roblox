/* Katalog: oyundaki tüm skin ve eşyalar */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, UI = CS.UI;
  const st = { q: '', kind: 'w', tier: -1, sort: 'tier', limit: 180 };
  const KINDS = [
    ['w', 'Silahlar'], ['K', 'Bıçaklar'], ['G', 'Eldivenler'], ['k', 'Çıkartmalar'], ['a', 'Ajanlar'],
    ['h', 'Süsler'], ['p', 'Armalar'], ['m', 'Müzik Kitleri'], ['c', 'Rozetler'], ['g', 'Grafitiler'], ['all', 'Tümü'],
  ];
  let priceCache = null;

  const match = (it, k) => {
    if (k === 'all') return true;
    if (k === 'w') return it.kind === 's' && it.cat !== 'K' && it.cat !== 'G';
    if (k === 'K' || k === 'G') return it.kind === 's' && it.cat === k;
    return it.kind === k;
  };

  CS.Pages.catalog = (view) => {
    if (!priceCache) priceCache = E.items.map((it) => E.typicalPrice(it));
    const counts = {};
    for (const [k] of KINDS) counts[k] = E.items.filter((it) => match(it, k)).length;
    view.innerHTML = `
      <h1 class="page-title">📖 Katalog <small>${U.num(E.items.length)} eşya</small></h1>
      <div class="toolbar sticky">
        <div class="tabs">${KINDS.map(([k, n]) => `<button class="tab${st.kind === k ? ' active' : ''}" data-k="${k}">${n} <small>${U.num(counts[k])}</small></button>`).join('')}</div>
        <div class="row gap wrap">
          <input class="input" type="search" id="catQ" placeholder="Skin / eşya ara..." value="${U.esc(st.q)}">
          <select class="input" id="catTier"><option value="-1">Tüm kaliteler</option>${E.TIER_SKIN.map((n, i) => `<option value="${i}">${n}</option>`).join('')}</select>
          <select class="input" id="catSort"><option value="tier">Kalite</option><option value="pd">Fiyat (azalan)</option><option value="pa">Fiyat (artan)</option><option value="name">İsim</option></select>
        </div>
      </div>
      <div class="muted small" id="catInfo"></div>
      <div class="grid items-grid" id="catGrid"></div>
      <div class="row center"><button class="btn ghost" id="catMore" hidden>Daha fazla göster</button></div>`;
    U.$('#catTier', view).value = st.tier;
    U.$('#catSort', view).value = st.sort;
    const grid = U.$('#catGrid', view);

    function render() {
      let list = E.items.filter((it) => match(it, st.kind));
      if (st.tier >= 0) list = list.filter((it) => it.tier === st.tier);
      if (st.q) { const q = U.normTR(st.q); list = list.filter((it) => U.normTR(it.name + ' ' + it.phase).includes(q)); }
      const s = st.sort;
      list.sort((a, b) => s === 'tier' ? b.tier - a.tier || priceCache[b.idx] - priceCache[a.idx]
        : s === 'pd' ? priceCache[b.idx] - priceCache[a.idx] : s === 'pa' ? priceCache[a.idx] - priceCache[b.idx] : a.name.localeCompare(b.name));
      U.$('#catInfo', view).textContent = `${U.num(list.length)} sonuç`;
      grid.innerHTML = list.length ? list.slice(0, st.limit).map((it) => UI.itemCard(it, {
        price: U.money(priceCache[it.idx]), cls: 'clickable',
        topLeft: it.cases.length ? `${it.cases.length} kasa` : '',
        topRight: it.st && it.kind === 's' ? '<span class="badge b-st">ST</span>' : '',
      })).join('') : '<div class="empty">Sonuç yok.</div>';
      U.$('#catMore', view).hidden = list.length <= st.limit;
    }

    view.addEventListener('click', (e) => {
      const card = e.target.closest('#catGrid .icard[data-i]');
      if (card) { UI.catalogModal(E.items[+card.dataset.i]); return; }
      const k = e.target.closest('[data-k]');
      if (k) {
        st.kind = k.dataset.k; st.limit = 180;
        U.$$('[data-k]', view).forEach((b) => b.classList.toggle('active', b === k));
        render();
      }
      if (e.target.closest('#catMore')) { st.limit += 180; render(); }
    });
    U.$('#catQ', view).addEventListener('input', U.debounce((e) => { st.q = e.target.value.trim(); st.limit = 180; render(); }, 180));
    U.$('#catTier', view).addEventListener('change', (e) => { st.tier = +e.target.value; render(); });
    U.$('#catSort', view).addEventListener('change', (e) => { st.sort = e.target.value; render(); });
    render();
  };
})(window.CS);
