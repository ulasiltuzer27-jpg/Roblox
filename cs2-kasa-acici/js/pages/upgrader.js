/* Upgrader: eşyalarını daha değerli bir skine yükseltmeyi dene */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;
  const EDGE = 0.92, MAX_CHANCE = 0.8, MAX_INPUT = 8;
  let variants = null;
  const st = { sel: [], bal: 0, target: null, q: '', invQ: '' };

  function buildVariants() {
    if (variants) return variants;
    variants = [];
    for (const it of E.items) {
      if (it.kind !== 's') continue;
      const ws = E.availableWears(it);
      const stOpts = it.st && it.cat !== 'G' ? [false, true] : [false];
      for (const s of stOpts) {
        if (!ws.length) variants.push({ i: it.idx, w: -1, st: s, p: E.priceAt(it, -1, s, false) });
        for (const w of ws) variants.push({ i: it.idx, w, st: s, p: E.priceAt(it, w, s, false) });
      }
    }
    variants.sort((a, b) => a.p - b.p);
    return variants;
  }

  const variantName = (v) => {
    const it = E.items[v.i];
    return (v.st ? 'StatTrak™ ' : '') + it.name + (it.phase ? ' (' + it.phase + ')' : '') + (v.w >= 0 ? ' (' + E.WEARS[v.w].s + ')' : '');
  };

  const variantCard = (v, cls) => {
    const it = E.items[v.i];
    return UI.itemCard(it, {
      topLeft: v.w >= 0 ? E.WEARS[v.w].s : '', topRight: v.st ? '<span class="badge b-st">ST</span>' : '',
      price: U.money(v.p), cls: 'clickable ' + (cls || ''),
      attrs: ` data-v="${v.i}:${v.w}:${v.st ? 1 : 0}"`,
    });
  };

  CS.Pages.upgrader = (view) => {
    buildVariants();
    if (CS.pendingUpgrade) { st.sel = CS.pendingUpgrade.slice(); CS.pendingUpgrade = null; st.target = null; }
    st.sel = st.sel.filter((u) => S.getItem(u));
    let spinning = false;

    view.innerHTML = `
      <h1 class="page-title">⬆ Upgrader</h1>
      <p class="muted">Eşyalarını (ve istersen bakiyeni) koy, daha pahalı bir hedef seç. Şans tutarsa hedef skin senin, tutmazsa koyduğun her şey gider!</p>
      <section class="upg-stage">
        <div class="upg-side" id="upgIn"></div>
        <div class="upg-center">
          <div class="gauge">
            <svg viewBox="0 0 240 240">
              <circle cx="120" cy="120" r="100" class="g-track"/>
              <circle cx="120" cy="120" r="100" class="g-arc" id="gArc" transform="rotate(-90 120 120)"/>
            </svg>
            <div class="g-pointer" id="gPtr"><i></i></div>
            <div class="g-mid"><b id="gPct">0%</b><span>Şans</span></div>
          </div>
          <div class="mult" id="multBtns">${[1.5, 2, 3, 5, 10, 20].map((m) => `<button data-m="${m}">x${m}</button>`).join('')}</div>
          <button class="btn primary big" id="upgBtn">UPGRADE</button>
        </div>
        <div class="upg-side" id="upgOut"></div>
      </section>
      <div class="upg-lists">
        <section class="panel">
          <div class="row between wrap gap"><h3>Envanterin <small>en fazla ${MAX_INPUT} eşya</small></h3>
            <input class="input" type="search" id="invQ" placeholder="Ara..." value="${U.esc(st.invQ)}"></div>
          <div class="row gap bal-in"><span>+ Bakiye ekle:</span><input class="input" type="number" min="0" step="0.01" id="balIn" value="${st.bal || ''}" placeholder="0.00"></div>
          <div class="grid items-grid sm" id="invList"></div>
        </section>
        <section class="panel">
          <div class="row between wrap gap"><h3>Hedef Skin</h3>
            <input class="input" type="search" id="tgtQ" placeholder="Skin ara..." value="${U.esc(st.q)}"></div>
          <div class="grid items-grid sm" id="tgtList"></div>
        </section>
      </div>`;

    const inputValue = () => U.round2(st.sel.reduce((a, u) => a + (S.getItem(u) ? S.getItem(u).p : 0), 0) + (st.bal || 0));
    const chance = () => (st.target && inputValue() > 0 ? Math.min(MAX_CHANCE, (inputValue() / st.target.p) * EDGE) : 0);

    const arc = U.$('#gArc', view);
    const CIRC = 2 * Math.PI * 100;
    arc.style.strokeDasharray = CIRC;

    function renderStage() {
      const inEl = U.$('#upgIn', view), outEl = U.$('#upgOut', view);
      const items = st.sel.map((u) => S.getItem(u)).filter(Boolean);
      inEl.innerHTML = `<div class="us-label">Koyduğun <b>${U.money(inputValue())}</b></div>
        <div class="us-box">${items.length || st.bal ? items.map((d) => UI.dropCard(d, { cls: 'small' })).join('') + (st.bal ? `<div class="bal-card">+${U.money(st.bal)}<small>bakiye</small></div>` : '')
        : '<div class="empty small">Aşağıdan eşya seç</div>'}</div>`;
      outEl.innerHTML = `<div class="us-label">Hedef <b>${st.target ? U.money(st.target.p) : '-'}</b></div>
        <div class="us-box">${st.target ? variantCard(st.target, 'big') : '<div class="empty small">Hedef seç</div>'}</div>`;
      const ch = chance();
      U.$('#gPct', view).textContent = (ch * 100).toFixed(2) + '%';
      arc.style.strokeDashoffset = CIRC * (1 - ch);
      const btn = U.$('#upgBtn', view);
      btn.disabled = spinning || !ch;
      btn.textContent = st.target ? `UPGRADE · x${(st.target.p / Math.max(0.01, inputValue())).toFixed(2)}` : 'UPGRADE';
    }

    function renderInv() {
      const q = U.normTR(st.invQ);
      let list = S.inv.slice().sort((a, b) => b.p - a.p);
      if (q) list = list.filter((d) => U.normTR(UI.dropName(d)).includes(q));
      const sel = new Set(st.sel);
      U.$('#invList', view).innerHTML = list.length
        ? list.slice(0, 200).map((d) => UI.dropCard(d, { cls: 'clickable' + (sel.has(d.u) ? ' selected' : ''), check: true })).join('')
        : '<div class="empty small">Envanterin boş. Önce kasa aç veya sadece bakiye kullan!</div>';
    }

    function renderTargets() {
      const min = inputValue() * 1.05;
      const q = U.normTR(st.q);
      let list = variants;
      if (q) list = list.filter((v) => U.normTR(variantName(v)).includes(q));
      list = list.filter((v) => v.p >= min);
      const out = list.slice(0, 90);
      U.$('#tgtList', view).innerHTML = out.length
        ? out.map((v) => variantCard(v, st.target && st.target.i === v.i && st.target.w === v.w && st.target.st === v.st ? 'selected' : '')).join('')
        : '<div class="empty small">Uygun hedef yok.</div>';
    }

    const renderAll = () => { renderStage(); renderInv(); renderTargets(); };
    renderAll();

    function pickMult(m) {
      const v = inputValue();
      if (!v) { UI.toast('Önce eşya seç veya bakiye ekle', 'err'); return; }
      const goal = v * m;
      let lo = 0, hi = variants.length - 1;
      while (lo < hi) { const mid = (lo + hi) >> 1; if (variants[mid].p < goal) lo = mid + 1; else hi = mid; }
      const cands = variants.slice(Math.max(0, lo - 4), lo + 5).filter((x) => x.p > v * 1.05);
      if (!cands.length) { UI.toast('Bu çarpan için hedef yok', 'err'); return; }
      st.target = U.pick(cands);
      CS.Snd.click();
      renderStage(); renderTargets();
    }

    async function spin() {
      const ch = chance();
      if (spinning || !ch || !st.target) return;
      if (st.bal && !S.canAfford(st.bal)) { UI.toast('Yetersiz bakiye!', 'err'); return; }
      const items = st.sel.map((u) => S.getItem(u)).filter(Boolean);
      if (!items.length && !st.bal) return;
      spinning = true;
      renderStage();
      const inVal = inputValue();
      // Ödeme
      if (st.bal) { S.charge(st.bal); S.stats.spent = U.round2(S.stats.spent + st.bal); S.stats.xp += st.bal; }
      S.removeItems(items.map((d) => d.u));
      const win = Math.random() < ch;
      const arcDeg = ch * 360;
      const finalDeg = win ? U.rand(arcDeg * 0.05, arcDeg * 0.95) : U.rand(arcDeg + (360 - arcDeg) * 0.03, 360 - (360 - arcDeg) * 0.03);
      const total = 360 * 5 + finalDeg;
      const ptr = U.$('#gPtr', view);
      const dur = S.settings.fast ? 1800 : 4200;
      const start = performance.now();
      let lastTick = 0;
      await new Promise((res) => {
        const f = (now) => {
          if (!view.isConnected) { res(); return; }
          const t = Math.min(1, (now - start) / dur);
          const deg = total * (1 - Math.pow(1 - t, 4));
          ptr.style.transform = `rotate(${deg}deg)`;
          if (Math.floor(deg / 12) !== lastTick) { lastTick = Math.floor(deg / 12); CS.Snd.tick(); }
          if (t < 1) requestAnimationFrame(f); else res();
        };
        requestAnimationFrame(f);
      });
      const tgt = st.target;
      const it = E.items[tgt.i];
      S.stats.upg++;
      let resultHtml;
      if (win) {
        let f = -1;
        if (tgt.w >= 0) { const r = E.wearRange(it, tgt.w); f = +U.rand(r[0], r[1]).toFixed(10); }
        const d = S.addItem(E.makeDrop(tgt.i, { f, st: tgt.st, src: 'Upgrader' }));
        S.stats.upgWins++;
        S.stats.tiers[it.tier]++;
        CS.Snd.reveal(it.tier); CS.Snd.win();
        UI.confetti(140);
        CS.Feed.push(d, 'Sen', true);
        U.$('.gauge', view).classList.add('g-win');
        resultHtml = `<div class="upg-res win"><h2>UPGRADE BAŞARILI!</h2>${UI.dropCard(d, { float: true, cls: 'pop' })}</div>`;
        S.addHist({ k: 'upgrade', won: true, v: d.p, cost: inVal });
      } else {
        CS.Snd.lose();
        U.$('.gauge', view).classList.add('g-lose');
        resultHtml = `<div class="upg-res lose"><h2>Olmadı...</h2><p>${U.money(inVal)} değerindeki eşyalar gitti. Bir dahakine!</p></div>`;
        S.addHist({ k: 'upgrade', won: false, v: 0, cost: inVal });
      }
      S.save();
      if (!view.isConnected) return;
      const m = UI.modal(resultHtml, { cls: 'small center' });
      setTimeout(() => {
        U.$('.gauge', view) && U.$('.gauge', view).classList.remove('g-win', 'g-lose');
      }, 1500);
      st.sel = []; st.bal = 0;
      U.$('#balIn', view).value = '';
      st.target = null;
      spinning = false;
      renderAll();
      return m;
    }

    view.addEventListener('click', (e) => {
      if (spinning) return;
      const inv = e.target.closest('#invList .icard[data-u]');
      if (inv) {
        const u = +inv.dataset.u;
        if (st.sel.includes(u)) st.sel = st.sel.filter((x) => x !== u);
        else if (st.sel.length >= MAX_INPUT) { UI.toast(`En fazla ${MAX_INPUT} eşya`, 'err'); return; }
        else st.sel.push(u);
        if (st.target && st.target.p <= inputValue() * 1.05) st.target = null;
        CS.Snd.click();
        renderAll();
        return;
      }
      const tg = e.target.closest('#tgtList .icard[data-v], #upgOut .icard[data-v]');
      if (tg && tg.closest('#tgtList')) {
        const [i, w, s] = tg.dataset.v.split(':').map(Number);
        st.target = variants.find((v) => v.i === i && v.w === w && (v.st ? 1 : 0) === s);
        CS.Snd.click();
        renderStage(); renderTargets();
        return;
      }
      const mb = e.target.closest('[data-m]');
      if (mb) { pickMult(+mb.dataset.m); return; }
      if (e.target.closest('#upgBtn')) spin();
    });
    U.$('#invQ', view).addEventListener('input', U.debounce((e) => { st.invQ = e.target.value.trim(); renderInv(); }, 150));
    U.$('#tgtQ', view).addEventListener('input', U.debounce((e) => { st.q = e.target.value.trim(); renderTargets(); }, 150));
    U.$('#balIn', view).addEventListener('input', U.debounce((e) => {
      let v = U.round2(Math.max(0, parseFloat(e.target.value) || 0));
      if (v > S.balance) { v = U.round2(S.balance); e.target.value = v; }
      st.bal = v;
      if (st.target && st.target.p <= inputValue() * 1.05) st.target = null;
      renderStage(); renderTargets();
    }, 250));
  };
})(window.CS);
