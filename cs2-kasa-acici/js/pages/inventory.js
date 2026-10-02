/* Envanter */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;
  const st = { q: '', sort: 'new', tier: -1, kind: 'all', selMode: false, sel: new Set(), limit: 240 };

  CS.Pages.inventory = (view) => {
    st.sel = new Set();
    st.selMode = false;
    view.innerHTML = `
      <div class="row between wrap gap">
        <h1 class="page-title">🎒 Envanter</h1>
        <div class="row gap wrap">
          <div class="statchip"><span>Eşya</span><b id="invN"></b></div>
          <div class="statchip"><span>Toplam değer</span><b id="invV"></b></div>
        </div>
      </div>
      <div class="toolbar">
        <div class="row gap wrap">
          <input class="input" type="search" id="invQ" placeholder="Eşya ara..." value="${U.esc(st.q)}">
          <select class="input" id="invKind">
            <option value="all">Tüm türler</option><option value="w">Silahlar</option><option value="K">Bıçaklar</option><option value="G">Eldivenler</option>
            <option value="k">Çıkartmalar</option><option value="x">Diğer</option>
          </select>
          <select class="input" id="invTier"><option value="-1">Tüm kaliteler</option>${E.TIER_SKIN.map((n, i) => `<option value="${i}">${n}</option>`).join('')}</select>
          <select class="input" id="invSort">
            <option value="new">En yeni</option><option value="old">En eski</option><option value="pd">Fiyat (azalan)</option>
            <option value="pa">Fiyat (artan)</option><option value="tier">Kalite</option><option value="float">Float (düşük)</option>
          </select>
        </div>
        <div class="row gap wrap">
          <button class="btn" id="selMode">☑ Seç</button>
          <button class="btn" id="sellCheap">$1 altını sat</button>
          <button class="btn danger" id="sellVis">Görünenleri sat</button>
        </div>
      </div>
      <div class="selbar" id="selbar"></div>
      <div class="grid items-grid" id="invGrid"></div>
      <div class="row center"><button class="btn ghost" id="more" hidden>Daha fazla göster</button></div>`;

    U.$('#invSort', view).value = st.sort;
    U.$('#invTier', view).value = st.tier;
    U.$('#invKind', view).value = st.kind;
    const grid = U.$('#invGrid', view);

    const filtered = () => {
      let list = S.inv;
      if (st.q) { const q = U.normTR(st.q); list = list.filter((d) => U.normTR(UI.dropName(d)).includes(q)); }
      if (st.tier >= 0) list = list.filter((d) => E.items[d.i].tier === st.tier);
      if (st.kind !== 'all') {
        list = list.filter((d) => {
          const it = E.items[d.i];
          if (st.kind === 'w') return it.kind === 's' && it.cat !== 'K' && it.cat !== 'G';
          if (st.kind === 'K' || st.kind === 'G') return it.kind === 's' && it.cat === st.kind;
          if (st.kind === 'k') return it.kind === 'k';
          return it.kind !== 's' && it.kind !== 'k';
        });
      }
      const s = st.sort;
      return list.slice().sort((a, b) => s === 'new' ? b.t - a.t || b.u - a.u : s === 'old' ? a.t - b.t || a.u - b.u
        : s === 'pd' ? b.p - a.p : s === 'pa' ? a.p - b.p : s === 'tier' ? E.items[b.i].tier - E.items[a.i].tier || b.p - a.p
          : (a.f < 0 ? 2 : a.f) - (b.f < 0 ? 2 : b.f));
    };

    function render() {
      const list = filtered();
      U.$('#invN', view).textContent = U.num(S.inv.length);
      U.$('#invV', view).textContent = U.money(S.invValue());
      grid.innerHTML = list.length
        ? list.slice(0, st.limit).map((d) => UI.dropCard(d, { float: true, check: st.selMode, cls: 'clickable' + (st.sel.has(d.u) ? ' selected' : '') })).join('')
        : `<div class="empty">${S.inv.length ? 'Filtreye uyan eşya yok.' : 'Envanterin boş. <a href="#/">Hemen kasa aç!</a>'}</div>`;
      U.$('#more', view).hidden = list.length <= st.limit;
      renderSel();
    }
    function renderSel() {
      const bar = U.$('#selbar', view);
      U.$('#selMode', view).classList.toggle('active', st.selMode);
      if (!st.selMode) { bar.innerHTML = ''; return; }
      let v = 0;
      for (const u of st.sel) { const d = S.getItem(u); if (d) v += d.p; }
      bar.innerHTML = `<span><b>${st.sel.size}</b> eşya seçildi · ${U.money(v)}</span>
        <button class="btn ghost small" id="selAll">Görünenleri seç</button>
        <button class="btn ghost small" id="selNone">Temizle</button>
        <button class="btn primary small" id="sellSel" ${st.sel.size ? '' : 'disabled'}>Seçilenleri sat · ${U.money(v)}</button>
        <button class="btn small" id="upgSel" ${st.sel.size && st.sel.size <= 8 ? '' : 'disabled'}>Upgrader'a gönder</button>`;
    }

    const sellMany = async (uids, label) => {
      if (!uids.length) { UI.toast('Satılacak eşya yok', 'err'); return; }
      const v = U.round2(uids.reduce((a, u) => a + (S.getItem(u) ? S.getItem(u).p : 0), 0));
      if (!(await UI.confirm(`${label}: <b>${uids.length}</b> eşya <b>${U.money(v)}</b> karşılığında satılsın mı?`, 'Sat'))) return;
      const got = S.sell(uids);
      CS.Snd.coin();
      UI.toast(`${uids.length} eşya satıldı: +${U.money(got)}`, 'ok');
      st.sel = new Set();
      render();
    };

    view.addEventListener('click', (e) => {
      const card = e.target.closest('#invGrid .icard[data-u]');
      if (card) {
        const u = +card.dataset.u;
        if (st.selMode) {
          if (st.sel.has(u)) st.sel.delete(u); else st.sel.add(u);
          card.classList.toggle('selected', st.sel.has(u));
          renderSel();
        } else {
          const d = S.getItem(u);
          if (d) UI.dropModal(d, { onChange: render });
        }
        return;
      }
      const id = (e.target.closest('button') || {}).id;
      if (id === 'selMode') { st.selMode = !st.selMode; st.sel = new Set(); render(); }
      else if (id === 'more') { st.limit += 240; render(); }
      else if (id === 'selAll') { filtered().slice(0, st.limit).forEach((d) => st.sel.add(d.u)); render(); }
      else if (id === 'selNone') { st.sel = new Set(); render(); }
      else if (id === 'sellSel') sellMany([...st.sel].filter((u) => S.getItem(u)), 'Seçilenler');
      else if (id === 'sellVis') sellMany(filtered().map((d) => d.u), 'Görünen tüm eşyalar');
      else if (id === 'sellCheap') sellMany(S.inv.filter((d) => d.p < 1).map((d) => d.u), '$1 altı eşyalar');
      else if (id === 'upgSel') { CS.pendingUpgrade = [...st.sel]; location.hash = '#/upgrader'; }
    });
    U.$('#invQ', view).addEventListener('input', U.debounce((e) => { st.q = e.target.value.trim(); render(); }, 150));
    U.$('#invSort', view).addEventListener('change', (e) => { st.sort = e.target.value; render(); });
    U.$('#invTier', view).addEventListener('change', (e) => { st.tier = +e.target.value; render(); });
    U.$('#invKind', view).addEventListener('change', (e) => { st.kind = e.target.value; render(); });
    render();
  };
})(window.CS);
