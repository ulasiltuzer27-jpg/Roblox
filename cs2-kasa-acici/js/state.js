/* Oyun durumu: bakiye, envanter, istatistikler (localStorage) */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E;
  const KEY = 'cs2kasa_v1';
  const START_BALANCE = 500;

  const freshStats = () => ({
    opened: 0, spent: 0, dropValue: 0, sold: 0, deposited: START_BALANCE,
    tiers: [0, 0, 0, 0, 0, 0, 0, 0], best: null,
    battles: 0, battleWins: 0, battleSpent: 0, battleWon: 0,
    upg: 0, upgWins: 0, tradeups: 0, xp: 0,
  });

  const S = {
    balance: START_BALANCE,
    inv: [],
    uid: 1,
    stats: freshStats(),
    hist: [],
    settings: { sound: true, fast: false, volume: 0.5 },
    listeners: [],
  };

  function serialize() {
    return JSON.stringify({
      v: 1,
      balance: S.balance,
      uid: S.uid,
      inv: S.inv.map((d) => [E.items[d.i].id, d.f, d.s, d.st, d.sv, d.t, d.src, d.u]),
      stats: S.stats,
      hist: S.hist.slice(0, 60),
      settings: S.settings,
    });
  }

  function load() {
    let raw = null;
    try { raw = localStorage.getItem(KEY); } catch (e) { /* gizli sekme */ }
    if (!raw) return;
    try {
      const o = JSON.parse(raw);
      S.balance = typeof o.balance === 'number' ? o.balance : START_BALANCE;
      S.uid = o.uid || 1;
      S.stats = Object.assign(freshStats(), o.stats || {});
      S.hist = o.hist || [];
      S.settings = Object.assign(S.settings, o.settings || {});
      S.inv = [];
      for (const r of o.inv || []) {
        const it = E.byId.get(r[0]);
        if (!it) continue;
        const d = { i: it.idx, f: r[1], s: r[2], st: r[3], sv: r[4], t: r[5], src: r[6], u: r[7] || S.uid++ };
        d.p = E.priceOf(d);
        S.inv.push(d);
      }
    } catch (e) {
      console.warn('Kayıt okunamadı', e);
    }
  }

  const persist = U.debounce(() => {
    try { localStorage.setItem(KEY, serialize()); } catch (e) { /* yer yok / gizli mod */ }
  }, 250);

  S.save = () => { persist(); S.emit(); };
  S.on = (fn) => { S.listeners.push(fn); };
  S.emit = () => { for (const fn of S.listeners) fn(); };

  S.canAfford = (v) => S.balance + 1e-9 >= v;
  S.charge = (v) => {
    if (!S.canAfford(v)) return false;
    S.balance = U.round2(S.balance - v);
    S.save();
    return true;
  };
  S.credit = (v) => { S.balance = U.round2(S.balance + v); S.save(); };
  S.deposit = (v) => { S.stats.deposited += v; S.credit(v); };

  S.addItem = (d) => {
    d.u = S.uid++;
    if (d.p == null) d.p = E.priceOf(d);
    S.inv.unshift(d);
    S.save();
    return d;
  };
  S.removeItems = (uids) => {
    const set = new Set(uids);
    S.inv = S.inv.filter((d) => !set.has(d.u));
    S.save();
  };
  S.getItem = (u) => S.inv.find((d) => d.u === u);
  S.sell = (uids) => {
    const set = new Set(uids);
    let sum = 0;
    for (const d of S.inv) if (set.has(d.u)) sum += d.p;
    S.inv = S.inv.filter((d) => !set.has(d.u));
    sum = U.round2(sum);
    S.stats.sold += sum;
    S.balance = U.round2(S.balance + sum);
    S.save();
    return sum;
  };
  S.invValue = () => U.round2(S.inv.reduce((a, d) => a + d.p, 0));

  // Kasa açılışı istatistiği
  S.recordDrop = (d, cost) => {
    const st = S.stats;
    st.dropValue = U.round2(st.dropValue + d.p);
    st.tiers[E.items[d.i].tier]++;
    if (!st.best || d.p > st.best.p) st.best = { id: E.items[d.i].id, f: d.f, s: d.s, st: d.st, sv: d.sv, p: d.p, src: d.src };
    if (cost) { st.spent = U.round2(st.spent + cost); st.xp += cost; }
  };
  S.addHist = (h) => {
    h.t = Date.now();
    S.hist.unshift(h);
    if (S.hist.length > 60) S.hist.length = 60;
  };

  S.reset = () => {
    try { localStorage.removeItem(KEY); } catch (e) { /* */ }
    S.balance = START_BALANCE; S.inv = []; S.uid = 1; S.stats = freshStats(); S.hist = [];
    S.save();
  };

  S.START_BALANCE = START_BALANCE;
  load();
  window.addEventListener('beforeunload', () => {
    try { localStorage.setItem(KEY, serialize()); } catch (e) { /* */ }
  });

  CS.S = S;
})(window.CS);
