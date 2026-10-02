/* Ana sayfa: tüm kasalar */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, UI = CS.UI;
  const st = { tab: 'case', q: '', sort: 'new' };

  CS.Pages.cases = (view) => {
    const counts = {};
    for (const c of E.cases) counts[c.type] = (counts[c.type] || 0) + 1;
    const featured = E.cases.filter((c) => c.type === 'case' && c.rare.length).sort((a, b) => b.date.localeCompare(a.date)).slice(0, 4);
    const skinCount = E.items.filter((i) => i.kind === 's').length;

    view.innerHTML = `
      <section class="hero">
        <div class="hero-txt">
          <h1>CS2 <span>KASA AÇICI</span></h1>
          <p>Oyundaki tüm silah kasaları, hatıra paketleri, kapsüller ve koleksiyonlar. ${U.num(skinCount)} skin, ${U.num(E.items.length)} eşya.
          Kasa aç, <b>Item Fight</b>'ta botlarla kapış, Upgrader'da şansını dene!</p>
          <div class="row gap wrap">
            <a class="btn primary big" href="#/battles">⚔ Item Fight</a>
            <a class="btn big" href="#/upgrader">⬆ Upgrader</a>
            <a class="btn big ghost" href="#/tradeup">🔁 Takas Sözleşmesi</a>
          </div>
        </div>
        <div class="hero-cases">${featured.map((c, k) => `<a href="#/case/${c.idx}" class="hc hc-${k}" title="${U.esc(c.name)}"><img src="${E.img(c.imgS, 256)}" alt=""><span>${U.esc(c.name)}</span><b>${U.money(c.price)}</b></a>`).join('')}</div>
      </section>
      <div class="toolbar sticky">
        <div class="tabs">
          ${E.CASE_TYPES.map((t) => `<button class="tab${st.tab === t.id ? ' active' : ''}" data-tab="${t.id}">${t.n} <small>${counts[t.id] || 0}</small></button>`).join('')}
          <button class="tab${st.tab === 'all' ? ' active' : ''}" data-tab="all">Tümü <small>${E.cases.length}</small></button>
        </div>
        <div class="row gap">
          <input class="input" type="search" placeholder="Kasa ara..." value="${U.esc(st.q)}" id="caseQ">
          <select class="input" id="caseSort">
            <option value="new">En yeni</option><option value="old">En eski</option>
            <option value="pa">Fiyat (artan)</option><option value="pd">Fiyat (azalan)</option><option value="name">İsim</option>
          </select>
        </div>
      </div>
      <div class="grid cases-grid" id="caseGrid"></div>`;

    const grid = U.$('#caseGrid', view);
    U.$('#caseSort', view).value = st.sort;

    const render = () => {
      let list = E.casesByType(st.tab);
      if (st.q) {
        // Arama tüm kategorilerde yapılır
        const q = U.normTR(st.q);
        list = E.cases.filter((c) => U.normTR(c.name).includes(q));
      }
      const s = st.sort;
      list = list.slice().sort((a, b) =>
        s === 'new' ? b.date.localeCompare(a.date) : s === 'old' ? a.date.localeCompare(b.date)
          : s === 'pa' ? a.price - b.price : s === 'pd' ? b.price - a.price : a.name.localeCompare(b.name));
      grid.innerHTML = list.length ? list.map(UI.caseCard).join('') : '<div class="empty">Sonuç bulunamadı.</div>';
    };

    view.addEventListener('click', (e) => {
      const t = e.target.closest('[data-tab]');
      if (!t) return;
      st.tab = t.dataset.tab;
      U.$$('[data-tab]', view).forEach((b) => b.classList.toggle('active', b === t));
      render();
    });
    U.$('#caseQ', view).addEventListener('input', U.debounce((e) => { st.q = e.target.value.trim(); render(); }, 120));
    U.$('#caseSort', view).addEventListener('change', (e) => { st.sort = e.target.value; render(); });
    render();
  };
})(window.CS);
