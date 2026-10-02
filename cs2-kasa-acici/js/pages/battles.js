/* ITEM FIGHT - kasa savaşları (botlara karşı) */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;

  const MODES = [
    { id: '1v1', seats: 2, teams: [0, 1], label: '1 vs 1' },
    { id: '1v1v1', seats: 3, teams: [0, 1, 2], label: '1 vs 1 vs 1' },
    { id: '1v1v1v1', seats: 4, teams: [0, 1, 2, 3], label: '1v1v1v1' },
    { id: '2v2', seats: 4, teams: [0, 0, 1, 1], label: '2 vs 2' },
  ];
  const modeOf = (id) => MODES.find((m) => m.id === id) || MODES[0];
  const MAX_ROUNDS = 50;

  const battles = new Map();
  let lobby = [];
  let nextId = 1;
  const draft = { mode: '1v1', cases: [], crazy: false, tab: 'case', q: '' };

  const ME = () => ({ name: 'Sen', me: true });
  const usedNames = (b) => new Set(b.players.filter(Boolean).map((p) => p.name));
  const botFor = (b) => {
    const used = usedNames(b);
    const free = E.BOT_NAMES.filter((n) => !used.has(n));
    return { name: U.pick(free.length ? free : E.BOT_NAMES), bot: true };
  };

  function newBattle(modeId, caseIdxs, crazy) {
    const mode = modeOf(modeId);
    const b = {
      id: 'b' + (nextId++) + Math.random().toString(36).slice(2, 6),
      mode, cases: caseIdxs.slice(), crazy: !!crazy,
      players: new Array(mode.seats).fill(null), status: 'waiting',
      cost: U.round2(caseIdxs.reduce((a, ci) => a + E.cases[ci].price, 0)),
    };
    battles.set(b.id, b);
    return b;
  }

  let weaponCases = null;
  function genLobbyBattle() {
    if (!weaponCases) weaponCases = E.cases.filter((c) => c.type === 'case');
    const r = Math.random();
    const mode = r < 0.45 ? '1v1' : r < 0.65 ? '2v2' : r < 0.85 ? '1v1v1' : '1v1v1v1';
    const rounds = U.pick([1, 1, 2, 3, 3, 4, 5, 6, 8, 10]);
    const list = [];
    const same = Math.random() < 0.5;
    const base = U.pick(Math.random() < 0.85 ? weaponCases : E.cases.filter((c) => c.type === 'collection' || c.type === 'souvenir'));
    for (let k = 0; k < rounds; k++) list.push((same ? base : U.pick(weaponCases)).idx);
    const b = newBattle(mode, list, Math.random() < 0.15);
    const fill = U.randInt(1, b.mode.seats - 1);
    const seats = U.shuffle([...Array(b.mode.seats).keys()]).slice(0, fill);
    for (const s of seats) b.players[s] = botFor(b);
    b.lobbyAt = Date.now();
    return b;
  }
  function ensureLobby() {
    lobby = lobby.filter((b) => b.status === 'waiting' && b.players.some((p) => !p));
    while (lobby.length < 7) lobby.push(genLobbyBattle());
  }

  const caseThumbs = (b, max) => {
    const m = max || 6;
    const counts = [];
    for (const ci of b.cases) {
      const last = counts[counts.length - 1];
      if (last && last.ci === ci) last.n++; else counts.push({ ci, n: 1 });
    }
    const shown = counts.slice(0, m).map(({ ci, n }) => `<span class="bthumb" title="${U.esc(E.cases[ci].name)}"><img src="${E.img(E.cases[ci].imgS, 128)}" alt="">${n > 1 ? `<b>x${n}</b>` : ''}</span>`).join('');
    return shown + (counts.length > m ? `<span class="bthumb more">+${counts.length - m}</span>` : '');
  };
  const seatsHtml = (b) => b.players.map((p, s) => {
    const sep = s > 0 ? (b.mode.teams[s] !== b.mode.teams[s - 1] ? '<i class="vs">vs</i>' : '') : '';
    return sep + (p ? UI.avatar(p.name, p.bot) : '<span class="avatar av-empty">+</span>');
  }).join('');

  /* ================= LOBİ ================= */
  CS.Pages.battles = (view) => {
    ensureLobby();
    const st = S.stats;
    const hist = S.hist.filter((h) => h.k === 'battle').slice(0, 10);
    view.innerHTML = `
      <section class="bt-hero">
        <div>
          <h1>⚔ ITEM FIGHT</h1>
          <p>Herkes aynı kasaları açar. <b>En yüksek toplam değeri</b> çıkaran savaşın tüm eşyalarını alır! Crazy modda ise en düşük kazanır.</p>
        </div>
        <div class="row gap wrap">
          <div class="statchip"><span>Oynanan</span><b>${st.battles}</b></div>
          <div class="statchip"><span>Kazanılan</span><b>${st.battleWins}</b></div>
          <div class="statchip"><span>Kâr</span><b class="${st.battleWon - st.battleSpent >= 0 ? 'pos' : 'neg'}">${U.money(st.battleWon - st.battleSpent)}</b></div>
          <a class="btn primary big" href="#/battle/new">+ Savaş Oluştur</a>
        </div>
      </section>
      <div class="row between"><h3>Açık Savaşlar</h3><button class="btn ghost" id="refresh">↻ Yenile</button></div>
      <div class="blist" id="blist"></div>
      ${hist.length ? `<h3>Son Savaşların</h3><div class="bhist">${hist.map((h) => `<div class="bh ${h.won ? 'won' : 'lost'}">
        <span class="bh-r">${h.won ? 'KAZANDI' : 'KAYBETTİ'}</span><span>${U.esc(h.mode)}${h.crazy ? ' · Crazy' : ''}</span><span>${h.rounds} tur</span>
        <span>Giriş ${U.money(h.cost)}</span><b class="${h.won ? 'pos' : 'neg'}">${h.won ? '+' + U.money(h.v) : '-' + U.money(h.cost)}</b><span class="muted">${U.timeAgo(h.t)}</span></div>`).join('')}</div>` : ''}`;

    const blist = U.$('#blist', view);
    const render = () => {
      blist.innerHTML = lobby.map((b) => `<div class="brow" data-b="${b.id}">
        <div class="br-mode"><b>${b.mode.label}</b>${b.crazy ? '<span class="badge b-crazy">CRAZY</span>' : ''}</div>
        <div class="br-cases">${caseThumbs(b)}</div>
        <div class="br-rounds"><span>Tur</span><b>${b.cases.length}</b></div>
        <div class="br-seats">${seatsHtml(b)}</div>
        <div class="br-cost"><span>Giriş</span><b>${U.money(b.cost)}</b></div>
        <button class="btn primary" data-join="${b.id}">Katıl</button>
      </div>`).join('');
    };
    render();

    // Lobi canlı: botlar katılır, dolan savaşlar başlar
    const timer = setInterval(() => {
      const open = lobby.filter((b) => b.players.some((p) => !p));
      if (open.length && Math.random() < 0.7) {
        const b = U.pick(open);
        const empty = b.players.map((p, s) => (p ? -1 : s)).filter((s) => s >= 0);
        if (empty.length > 1 || Math.random() < 0.35) {
          b.players[U.pick(empty)] = botFor(b);
          if (!b.players.some((p) => !p)) b.status = 'botonly';
        }
      }
      ensureLobby();
      render();
    }, 2600);

    view.addEventListener('click', (e) => {
      const j = e.target.closest('[data-join]');
      if (j) {
        const b = battles.get(j.dataset.join);
        if (!b || b.status !== 'waiting') { UI.toast('Bu savaş başladı bile!', 'err'); return; }
        if (!S.canAfford(b.cost)) { UI.toast('Yetersiz bakiye!', 'err'); CS.Snd.beep(false); return; }
        S.charge(b.cost);
        const s = b.players.findIndex((p) => !p);
        b.players[s] = ME();
        b.paid = true;
        b.autoFill = true;
        lobby = lobby.filter((x) => x !== b);
        location.hash = '#/battle/' + b.id;
      }
      if (e.target.closest('#refresh')) { lobby = []; ensureLobby(); render(); CS.Snd.click(); }
    });
    return () => clearInterval(timer);
  };

  /* ================= OLUŞTUR ================= */
  CS.Pages.battleNew = (view) => {
    const types = [['case', 'Silah Kasaları'], ['collection', 'Koleksiyonlar'], ['souvenir', 'Hatıra'], ['all', 'Tümü']];
    view.innerHTML = `
      <a class="back" href="#/battles">← Item Fight</a>
      <h1 class="page-title">Savaş Oluştur</h1>
      <div class="bn-layout">
        <div class="panel bn-left">
          <h3>Mod</h3>
          <div class="modes">${MODES.map((m) => `<button class="mode-btn${draft.mode === m.id ? ' active' : ''}" data-mode="${m.id}">
            <span class="mode-ic">${m.teams.map((t, i) => (i > 0 && t !== m.teams[i - 1] ? '<i>vs</i>' : '') + '<b></b>').join('')}</span>${m.label}</button>`).join('')}</div>
          <label class="switch crazy"><input type="checkbox" id="crazy" ${draft.crazy ? 'checked' : ''}><span></span>Crazy Mod <small>(en düşük değer kazanır)</small></label>
          <h3>Seçilen Kasalar <small id="roundCount"></small></h3>
          <div class="sel-cases" id="selCases"></div>
          <div class="bn-sum">
            <div><span>Tur sayısı</span><b id="sumRounds">0</b></div>
            <div><span>Kişi başı giriş</span><b id="sumCost">$0.00</b></div>
          </div>
          <button class="btn primary big full" id="createBtn">Savaşı Oluştur</button>
        </div>
        <div class="panel bn-right">
          <div class="row between wrap gap"><h3>Kasa Ekle</h3>
            <input class="input" type="search" id="bnQ" placeholder="Kasa ara..." value="${U.esc(draft.q)}"></div>
          <div class="tabs small">${types.map(([id, n]) => `<button class="tab${draft.tab === id ? ' active' : ''}" data-t="${id}">${n}</button>`).join('')}</div>
          <div class="grid pick-grid" id="pickGrid"></div>
        </div>
      </div>`;

    const pickGrid = U.$('#pickGrid', view);
    const renderPick = () => {
      let list = draft.tab === 'all' ? E.cases : E.cases.filter((c) => c.type === draft.tab);
      if (draft.q) { const q = U.normTR(draft.q); list = E.cases.filter((c) => U.normTR(c.name).includes(q)); }
      list = list.slice().sort((a, b) => b.date.localeCompare(a.date)).slice(0, 240);
      pickGrid.innerHTML = list.map((c) => {
        const sel = draft.cases.find((x) => x.c === c.idx);
        return `<div class="pcase${sel ? ' sel' : ''}" data-add="${c.idx}"><img src="${E.img(c.imgS, 128)}" loading="lazy" alt="">
          <span>${U.esc(c.name)}</span><b>${U.money(c.price)}</b>${sel ? `<i class="pc-n">x${sel.n}</i>` : ''}<i class="pc-plus">+</i></div>`;
      }).join('');
    };
    const rounds = () => draft.cases.reduce((a, x) => a + x.n, 0);
    const cost = () => U.round2(draft.cases.reduce((a, x) => a + x.n * E.cases[x.c].price, 0));
    const renderSel = () => {
      const sel = U.$('#selCases', view);
      sel.innerHTML = draft.cases.length ? draft.cases.map((x) => {
        const c = E.cases[x.c];
        return `<div class="scase"><img src="${E.img(c.imgS, 128)}" alt=""><div class="sc-t"><span>${U.esc(c.name)}</span><b>${U.money(c.price)}</b></div>
          <div class="qty"><button data-dec="${x.c}">−</button><b>${x.n}</b><button data-inc="${x.c}">+</button></div><button class="x" data-rm="${x.c}">✕</button></div>`;
      }).join('') : '<div class="empty small">Sağdan kasa ekle (en fazla ' + MAX_ROUNDS + ' tur).</div>';
      U.$('#sumRounds', view).textContent = rounds();
      U.$('#roundCount', view).textContent = rounds() ? rounds() + ' tur' : '';
      U.$('#sumCost', view).textContent = U.money(cost());
      const btn = U.$('#createBtn', view);
      btn.disabled = !rounds();
      btn.textContent = rounds() ? `Savaşı Oluştur · ${U.money(cost())}` : 'Savaşı Oluştur';
    };
    renderPick(); renderSel();

    const add = (ci, d) => {
      let x = draft.cases.find((y) => y.c === ci);
      if (d > 0 && rounds() >= MAX_ROUNDS) { UI.toast(`En fazla ${MAX_ROUNDS} tur!`, 'err'); return; }
      if (!x) { if (d < 0) return; x = { c: ci, n: 0 }; draft.cases.push(x); }
      x.n += d;
      if (x.n <= 0) draft.cases = draft.cases.filter((y) => y !== x);
      renderSel(); renderPick();
    };

    view.addEventListener('click', (e) => {
      const t = e.target;
      let el;
      if ((el = t.closest('[data-mode]'))) {
        draft.mode = el.dataset.mode;
        U.$$('[data-mode]', view).forEach((b) => b.classList.toggle('active', b === el));
        CS.Snd.click();
      } else if ((el = t.closest('[data-add]'))) { add(+el.dataset.add, 1); CS.Snd.click(); }
      else if ((el = t.closest('[data-inc]'))) add(+el.dataset.inc, 1);
      else if ((el = t.closest('[data-dec]'))) add(+el.dataset.dec, -1);
      else if ((el = t.closest('[data-rm]'))) add(+el.dataset.rm, -999);
      else if ((el = t.closest('[data-t]'))) {
        draft.tab = el.dataset.t;
        U.$$('[data-t]', view).forEach((b) => b.classList.toggle('active', b === el));
        renderPick();
      }
    });
    U.$('#bnQ', view).addEventListener('input', U.debounce((e) => { draft.q = e.target.value.trim(); renderPick(); }, 150));
    U.$('#crazy', view).addEventListener('change', (e) => { draft.crazy = e.target.checked; });
    U.$('#createBtn', view).onclick = () => {
      const list = [];
      for (const x of draft.cases) for (let k = 0; k < x.n; k++) list.push(x.c);
      if (!list.length) return;
      const b = newBattle(draft.mode, list, draft.crazy);
      if (!S.canAfford(b.cost)) { battles.delete(b.id); UI.toast('Yetersiz bakiye!', 'err'); CS.Snd.beep(false); return; }
      S.charge(b.cost);
      b.paid = true;
      b.players[0] = ME();
      location.hash = '#/battle/' + b.id;
    };
  };

  /* ================= SAVAŞ ODASI ================= */
  function settle(b) {
    const seats = b.mode.seats;
    b.res = b.cases.map((ci) => Array.from({ length: seats }, () => E.roll(E.cases[ci])));
    b.totals = new Array(seats).fill(0);
    for (const round of b.res) round.forEach((d, s) => { b.totals[s] = U.round2(b.totals[s] + d.p); });
    const teamTot = {};
    b.mode.teams.forEach((t, s) => { teamTot[t] = U.round2((teamTot[t] || 0) + b.totals[s]); });
    const vals = Object.values(teamTot);
    const best = b.crazy ? Math.min(...vals) : Math.max(...vals);
    const winTeams = Object.keys(teamTot).filter((t) => Math.abs(teamTot[t] - best) < 0.005).map(Number);
    b.tie = winTeams.length > 1;
    b.winTeam = U.pick(winTeams);
    b.teamTot = teamTot;
    b.winSeats = b.mode.teams.map((t, s) => (t === b.winTeam ? s : -1)).filter((s) => s >= 0);
    b.pot = U.round2(b.totals.reduce((a, v) => a + v, 0));

    // Kazananlar arasında paylaştır
    const all = [];
    b.res.forEach((round) => round.forEach((d) => all.push(d)));
    b.share = {};
    for (const s of b.winSeats) b.share[s] = { items: [], v: 0 };
    all.sort((x, y) => y.p - x.p);
    for (const d of all) {
      let tgt = b.winSeats[0];
      for (const s of b.winSeats) if (b.share[s].v < b.share[tgt].v) tgt = s;
      b.share[tgt].items.push(d);
      b.share[tgt].v = U.round2(b.share[tgt].v + d.p);
    }

    const me = b.players.findIndex((p) => p && p.me);
    b.meSeat = me;
    b.won = b.winSeats.includes(me);
    const st = S.stats;
    if (me >= 0) {
      b.res.forEach((round, r) => S.recordDrop(round[me], E.cases[b.cases[r]].price));
      st.opened += b.cases.length;
      st.battles++;
      st.battleSpent = U.round2(st.battleSpent + b.cost);
      b.myWin = 0;
      if (b.won) {
        st.battleWins++;
        b.myWin = b.share[me].v;
        st.battleWon = U.round2(st.battleWon + b.myWin);
        for (const d of b.share[me].items) S.addItem(Object.assign({}, d, { u: undefined, src: 'Item Fight', t: Date.now() }));
      }
      S.addHist({ k: 'battle', mode: b.mode.label, crazy: b.crazy, rounds: b.cases.length, cost: b.cost, won: b.won, v: b.myWin });
      S.save();
    }
    b.status = 'running';
  }

  CS.Pages.battleRoom = (view, params) => {
    const b = battles.get(params[0]);
    if (!b) {
      view.innerHTML = '<div class="empty">Savaş bulunamadı (sayfa yenilenmiş olabilir). <a href="#/battles">Item Fight lobisine dön</a></div>';
      return;
    }
    const seats = b.mode.seats;
    let alive = true;
    const fastDefault = S.settings.fast;

    view.innerHTML = `
      <a class="back" href="#/battles">← Lobi</a>
      <section class="room-head">
        <div class="rh-l"><h1>⚔ ITEM FIGHT</h1><span class="badge b-mode">${b.mode.label}</span>${b.crazy ? '<span class="badge b-crazy">CRAZY</span>' : ''}</div>
        <div class="rh-r">
          <div class="statchip"><span>Giriş</span><b>${U.money(b.cost)}</b></div>
          <div class="statchip"><span>Toplam ödül</span><b id="pot">$0.00</b></div>
          <label class="switch"><input type="checkbox" id="fastChk" ${fastDefault ? 'checked' : ''}><span></span>Hızlı</label>
        </div>
      </section>
      <div class="rounds" id="rounds">${b.cases.map((ci, r) => `<div class="rnd" data-r="${r}"><img src="${E.img(E.cases[ci].imgS, 128)}" alt="" title="${U.esc(E.cases[ci].name)}"><span>${r + 1}</span></div>`).join('')}</div>
      <div class="room-status" id="rstatus"></div>
      <div class="players cols-${seats}${b.mode.id === '2v2' ? ' teams' : ''}" id="players">
        ${b.players.map((p, s) => `${s > 0 && b.mode.teams[s] !== b.mode.teams[s - 1] ? '<div class="vs-sep"><span>VS</span></div>' : ''}
          <div class="pcol team-${b.mode.teams[s]}" data-seat="${s}">
            <div class="pc-head"></div>
            <div class="pc-reel"><div class="pc-wait"></div></div>
            <div class="pc-total"><span>Toplam</span><b data-total="${s}">$0.00</b></div>
            <div class="pc-drops"></div>
          </div>`).join('')}
      </div>
      <div class="room-result" id="rresult"></div>`;

    const statusEl = U.$('#rstatus', view);
    const cols = U.$$('.pcol', view);
    const headOf = (s) => cols[s].querySelector('.pc-head');
    const reelOf = (s) => cols[s].querySelector('.pc-reel');

    const renderHeads = () => {
      b.players.forEach((p, s) => {
        headOf(s).innerHTML = p
          ? `${UI.avatar(p.name, p.bot)}<div class="ph-n"><b>${U.esc(p.name)}</b><small>${p.me ? 'Sen' : 'Bot'}${b.mode.id === '2v2' ? ' · Takım ' + (b.mode.teams[s] ? 'B' : 'A') : ''}</small></div>`
          : `<span class="avatar av-empty">?</span><div class="ph-n"><b>Boş koltuk</b><small>Bekleniyor...</small></div>
             ${b.status === 'waiting' ? `<button class="btn small" data-bot="${s}">🤖 Bot çağır</button>` : ''}`;
        if (!b.res) {
          const w = reelOf(s).querySelector('.pc-wait');
          if (w) w.innerHTML = p ? '<span class="ready">HAZIR</span>' : '<span class="dots"><i></i><i></i><i></i></span>';
        }
      });
    };

    const setStatus = (h) => { statusEl.innerHTML = h; };
    const waitingStatus = () => {
      const empty = b.players.filter((p) => !p).length;
      setStatus(empty
        ? `<span>${empty} oyuncu bekleniyor</span> <button class="btn primary" id="fillBots">🤖 Botlarla doldur ve başlat</button>`
        : '<span>Hazırlanıyor...</span>');
    };

    async function run() {
      if (!b.res) settle(b);
      renderHeads();
      U.$('#pot', view).textContent = U.money(0);
      // geri sayım
      for (const n of [3, 2, 1]) {
        if (!alive) return;
        setStatus(`<span class="count">${n}</span>`);
        CS.Snd.beep(false);
        await U.sleep(650);
      }
      CS.Snd.beep(true);
      const running = new Array(seats).fill(0);
      let pot = 0;
      for (let r = 0; r < b.cases.length; r++) {
        if (!alive) return;
        const fast = U.$('#fastChk', view).checked;
        U.$$('.rnd', view).forEach((el) => el.classList.toggle('active', +el.dataset.r === r));
        U.$$('.rnd', view).forEach((el) => el.classList.toggle('done', +el.dataset.r < r));
        const act = U.$(`.rnd[data-r="${r}"]`, view);
        if (act) act.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
        const c = E.cases[b.cases[r]];
        setStatus(`<span>Tur <b>${r + 1}</b> / ${b.cases.length}</span> <span class="muted">${U.esc(c.name)}</span>`);
        CS.Snd.whoosh();
        await Promise.all(b.res[r].map((d, s) => CS.Reel.spin(reelOf(s), c, d, { axis: 'y', fast, sound: s === 0 })));
        if (!alive) return;
        CS.Snd.reveal(Math.max(...b.res[r].map((d) => E.items[d.i].tier)));
        b.res[r].forEach((d, s) => {
          const prev = running[s];
          running[s] = U.round2(running[s] + d.p);
          pot = U.round2(pot + d.p);
          U.countTo(U.$(`[data-total="${s}"]`, view), prev, running[s], 500);
          const dl = cols[s].querySelector('.pc-drops');
          dl.insertAdjacentHTML('afterbegin', UI.dropCard(d, { cls: 'pop small' }));
        });
        U.$('#pot', view).textContent = U.money(pot);
        // lider
        const teamRun = {};
        b.mode.teams.forEach((t, s) => { teamRun[t] = (teamRun[t] || 0) + running[s]; });
        const vals = Object.values(teamRun);
        const best = b.crazy ? Math.min(...vals) : Math.max(...vals);
        cols.forEach((col, s) => col.classList.toggle('leading', Math.abs(teamRun[b.mode.teams[s]] - best) < 0.005));
        await U.sleep(fast ? 350 : 800);
      }
      if (!alive) return;
      U.$$('.rnd', view).forEach((el) => { el.classList.remove('active'); el.classList.add('done'); });
      if (b.tie) {
        setStatus('<span>Beraberlik! Yazı-tura atılıyor...</span> <span class="coin">🪙</span>');
        CS.Snd.coin();
        await U.sleep(1600);
        if (!alive) return;
      }
      finish();
    }

    function finish() {
      b.status = 'done';
      cols.forEach((col, s) => {
        col.classList.remove('leading');
        col.classList.add(b.winSeats.includes(s) ? 'winner' : 'loser');
        if (b.winSeats.includes(s)) col.querySelector('.pc-reel').insertAdjacentHTML('beforeend', `<div class="win-flag">🏆 KAZANDI<br><b>${U.money(b.share[s].v)}</b></div>`);
      });
      const me = b.meSeat;
      const res = U.$('#rresult', view);
      if (me >= 0) {
        if (b.won) {
          CS.Snd.win();
          UI.confetti(160);
          setStatus(`<span class="win-txt">KAZANDIN! +${U.money(b.myWin)}</span>`);
        } else {
          CS.Snd.lose();
          setStatus(`<span class="lose-txt">Kaybettin... -${U.money(b.cost)}</span>`);
        }
      }
      res.innerHTML = `<div class="row gap center wrap">
        <button class="btn primary big" id="again">↻ Aynı savaşı tekrar oyna · ${U.money(b.cost)}</button>
        <a class="btn big" href="#/battles">Lobiye dön</a>
        ${b.won ? '<a class="btn big ghost" href="#/inventory">Envantere git</a>' : ''}</div>`;
      U.$('#again', res).onclick = () => {
        const nb = newBattle(b.mode.id, b.cases, b.crazy);
        if (!S.canAfford(nb.cost)) { battles.delete(nb.id); UI.toast('Yetersiz bakiye!', 'err'); return; }
        S.charge(nb.cost);
        nb.paid = true;
        nb.players[Math.max(0, b.meSeat)] = ME();
        nb.autoFill = true;
        location.hash = '#/battle/' + nb.id;
      };
      res.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    function maybeStart() {
      if (b.status !== 'waiting') return;
      renderHeads();
      if (b.players.every(Boolean)) { b.status = 'starting'; run(); } else waitingStatus();
    }

    async function autoFill() {
      while (alive && b.players.some((p) => !p)) {
        await U.sleep(U.randInt(500, 1100));
        if (!alive || b.status !== 'waiting') return;
        const s = b.players.findIndex((p) => !p);
        b.players[s] = botFor(b);
        CS.Snd.click();
        maybeStart();
      }
    }

    view.addEventListener('click', (e) => {
      const bb = e.target.closest('[data-bot]');
      if (bb && b.status === 'waiting') {
        const s = +bb.dataset.bot;
        if (!b.players[s]) { b.players[s] = botFor(b); CS.Snd.click(); maybeStart(); }
      }
      if (e.target.closest('#fillBots') && b.status === 'waiting') {
        b.players.forEach((p, s) => { if (!p) b.players[s] = botFor(b); });
        CS.Snd.click();
        maybeStart();
      }
    });

    if (b.status === 'done' || b.status === 'running' || b.status === 'starting') {
      // Sayfaya geri dönüldü: sonucu doğrudan göster
      renderHeads();
      b.res.forEach((round) => round.forEach((d, s) => cols[s].querySelector('.pc-drops').insertAdjacentHTML('afterbegin', UI.dropCard(d, { cls: 'small' }))));
      b.totals.forEach((v, s) => { U.$(`[data-total="${s}"]`, view).textContent = U.money(v); });
      U.$('#pot', view).textContent = U.money(b.pot);
      U.$$('.pc-wait', view).forEach((w) => { w.innerHTML = ''; });
      finish();
    } else {
      maybeStart();
      if (b.autoFill) autoFill();
    }
    return () => {
      alive = false;
      // Başlamadan çıkılırsa giriş ücreti iade edilir
      if (b.status === 'waiting' && b.paid) {
        b.paid = false;
        S.credit(b.cost);
        battles.delete(b.id);
        UI.toast(`Savaştan ayrıldın, ${U.money(b.cost)} iade edildi`, 'ok');
      }
    };
  };
})(window.CS);
