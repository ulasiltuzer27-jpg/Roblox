/* Veri tabanı, fiyatlar, oranlar ve çekiliş mantığı */
(function (CS) {
  'use strict';
  const U = CS.U;
  const D = window.CS2_DATA;
  const E = {};

  /* ---------- Sabitler ---------- */
  E.TIER_COLORS = ['#b0c3d9', '#5e98d9', '#4b69ff', '#8847ff', '#d32ce6', '#eb4b4b', '#ffcc33', '#e4ae39'];
  const TIER_SKIN = ['Tüketici Sınıfı', 'Endüstriyel Sınıf', 'Askeri Sınıf', 'Yasaklı', 'Gizli', 'Örtülü', 'Nadir Özel Eşya', 'Kaçak'];
  const TIER_OTHER = ['Temel Sınıf', 'Endüstriyel', 'Yüksek Sınıf', 'Sıra Dışı', 'Egzotik', 'Olağanüstü', 'Nadir Özel Eşya', 'Kaçak'];
  const TIER_AGENT = ['Temel', 'Endüstriyel', 'Seçkin', 'İstisnai', 'Üstün', 'Usta', 'Nadir', 'Kaçak'];
  E.tierName = (it) => (it.kind === 's' ? TIER_SKIN : it.kind === 'a' ? TIER_AGENT : TIER_OTHER)[it.tier];
  E.TIER_SKIN = TIER_SKIN;

  E.WEARS = [
    { s: 'FN', n: 'Fabrikadan Yeni Çıkmış', a: 0, b: 0.07 },
    { s: 'MW', n: 'Az Aşınmış', a: 0.07, b: 0.15 },
    { s: 'FT', n: 'Görevde Kullanılmış', a: 0.15, b: 0.38 },
    { s: 'WW', n: 'Eskimiş', a: 0.38, b: 0.45 },
    { s: 'BS', n: 'Savaş Görmüş', a: 0.45, b: 1 },
  ];
  // CS2 aşınma dağılımı (0-1 aralığında, sonra skinin min/max aralığına ölçeklenir)
  const WEAR_DIST = [[0.03, 0, 0.07], [0.24, 0.07, 0.15], [0.33, 0.15, 0.38], [0.24, 0.38, 0.45], [0.16, 0.45, 1]];

  E.KIND_NAMES = { s: 'Silah', k: 'Çıkartma', p: 'Arma', m: 'Müzik Kiti', g: 'Grafiti', c: 'Rozet', h: 'Süs', a: 'Ajan', o: 'Eşya' };
  E.CAT_NAMES = { R: 'Tüfek', P: 'Tabanca', S: 'Hafif Makineli', H: 'Ağır Silah', K: 'Bıçak', G: 'Eldiven', E: 'Ekipman' };
  E.CASE_TYPES = [
    { id: 'case', n: 'Silah Kasaları' },
    { id: 'collection', n: 'Koleksiyonlar' },
    { id: 'souvenir', n: 'Hatıra Paketleri' },
    { id: 'sticker', n: 'Çıkartma Kapsülleri' },
    { id: 'autograph', n: 'İmza Kapsülleri' },
    { id: 'other', n: 'Diğer' },
  ];
  E.CASE_TYPE_NAME = { case: 'Silah Kasası', collection: 'Koleksiyon', souvenir: 'Hatıra Paketi', sticker: 'Çıkartma Kapsülü', autograph: 'İmza Kapsülü', other: 'Diğer' };

  E.SPECIAL_CHANCE = 0.0026;
  const PHASE_W = { 'Phase 1': 23, 'Phase 2': 23, 'Phase 3': 23, 'Phase 4': 23, Ruby: 3, Sapphire: 3, 'Black Pearl': 2, Emerald: 6 };
  const BLUE_GEMS = new Set([661, 670, 151, 321, 955, 387, 442, 463, 278, 690, 363, 868, 555, 179, 4]);

  E.wearIndex = (f) => (f < 0.07 ? 0 : f < 0.15 ? 1 : f < 0.38 ? 2 : f < 0.45 ? 3 : 4);

  E.img = (s, size) => {
    if (!s) return E.FALLBACK;
    if (s[0] === '~') return D.econ + s.slice(1) + '/' + (size || 256) + 'fx' + (size || 256) + 'f';
    return s;
  };
  E.FALLBACK = 'data:image/svg+xml;utf8,' + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 70"><rect width="100" height="70" fill="none"/><text x="50" y="44" font-size="30" text-anchor="middle" fill="#3a4354" font-family="Arial">?</text></svg>');

  /* ---------- Eşyalar ---------- */
  E.items = D.items.map((r, idx) => {
    const name = r[1];
    let weapon = '', finish = name;
    const bar = name.indexOf(' | ');
    if (r[2] === 's') {
      if (bar >= 0) { weapon = name.slice(0, bar).replace('★ ', ''); finish = name.slice(bar + 3); }
      else { weapon = name.replace('★ ', ''); finish = 'Vanilla'; }
    } else if (bar >= 0) {
      weapon = name.slice(0, bar); finish = name.slice(bar + 3);
    }
    return {
      idx, id: r[0], name, kind: r[2], tier: r[3], imgS: r[4], min: r[5], max: r[6],
      st: !!(r[7] & 1), sv: !!(r[7] & 2), cat: r[8], phase: r[9],
      weapon, finish, cases: [], cols: [], base: 0, year: 9999,
    };
  });
  E.byId = new Map(E.items.map((it) => [it.id, it]));
  for (const k in D.itemCols) E.items[+k].cols = D.itemCols[k];
  E.cols = D.cols;

  E.fullName = (it, phase) => it.name + (phase !== false && it.phase ? ' (' + it.phase + ')' : '');

  /* ---------- Kasalar ---------- */
  E.cases = D.cases.map((c, idx) => ({
    idx, id: c.i, name: c.n, type: c.t, imgS: c.img, date: c.d || '', items: c.c, rare: c.r, col: c.col,
    year: parseInt((c.d || '9999').slice(0, 4), 10) || 9999, price: 0, ev: 0, pool: null,
  }));
  for (const c of E.cases) {
    for (const i of c.items) E.items[i].cases.push(c.idx);
    for (const i of c.rare) E.items[i].cases.push(c.idx);
  }
  for (const it of E.items) {
    for (const ci of it.cases) it.year = Math.min(it.year, E.cases[ci].year);
  }

  /* ---------- Fiyatlandırma ---------- */
  const FAMOUS = {
    'AWP | Dragon Lore': 9500, 'M4A4 | Howl': 4200, 'AWP | Gungnir': 9000, 'AWP | The Prince': 1800,
    'AWP | Medusa': 2800, 'AK-47 | Wild Lotus': 6500, 'AK-47 | Gold Arabesque': 2400,
    'M4A1-S | Welcome to the Jungle': 1600, 'AK-47 | Fire Serpent': 950, 'M4A1-S | Knight': 1400,
    'AWP | Desert Hydra': 900, 'AWP | Fade': 1100, 'Desert Eagle | Blaze': 450, 'AK-47 | Case Hardened': 230,
    'AWP | Asiimov': 130, 'AK-47 | Redline': 38, 'AK-47 | Vulcan': 190, 'AWP | Lightning Strike': 420,
    'M4A4 | Asiimov': 140, 'AK-47 | Asiimov': 75, 'AK-47 | Hydroponic': 400, 'AWP | Containment Breach': 110,
    'AK-47 | The Empress': 65, 'M4A4 | Poseidon': 420, 'AK-47 | Jaguar': 120, 'AWP | Hyper Beast': 55,
    'Glock-18 | Fade': 1600, 'USP-S | Kill Confirmed': 75, 'M4A1-S | Printstream': 210, 'Desert Eagle | Printstream': 65,
    'AK-47 | Neon Rider': 60, 'AWP | Wildfire': 85, 'AK-47 | Bloodsport': 95, 'M4A4 | The Emperor': 55,
    'AWP | Oni Taiji': 160, 'AK-47 | Head Shot': 55, 'AWP | Chromatic Aberration': 40, 'AK-47 | Inheritance': 105,
    "M4A1-S | Chantico's Fire": 125, 'M4A1-S | Golden Coil': 95, 'AK-47 | Fuel Injector': 160,
    'AK-47 | Neon Revolution': 85, 'AWP | Neo-Noir': 65, "AWP | Man-o'-war": 60, 'M4A1-S | Hot Rod': 520,
    'M4A1-S | Master Piece': 400, 'AWP | Boom': 160, 'AWP | Graphite': 150, 'M4A4 | Temukau': 70,
    'AK-47 | Nightwish': 70, 'Desert Eagle | Code Red': 70, 'USP-S | Printstream': 120, 'AWP | Printstream': 120,
    'M4A1-S | Icarus Fell': 350, 'AK-47 | Aquamarine Revenge': 60, 'AK-47 | Frontside Misty': 45,
    'M4A1-S | Blue Phosphor': 600, 'AWP | Silk Tiger': 700, 'M4A4 | Eye of Horus': 900, 'Desert Eagle | Fennec Fox': 300,
    'AK-47 | X-Ray': 300, 'P250 | X-Ray': 25, 'AWP | Queen\'s Gambit': 70, 'Glock-18 | Fully Tuned': 45,
    'M4A4 | Hellish': 90, 'AK-47 | Leet Museo': 85, 'AWP | Chrome Cannon': 70, 'AK-47 | Searing Rage': 260,
    'M4A1-S | Emphorosaur-S': 25, 'AWP | Duality': 20, 'AK-47 | Slate': 5, 'AK-47 | Ice Coaled': 18,
  };
  const KNIFE_BASE = {
    'Karambit': 650, 'Butterfly Knife': 800, 'M9 Bayonet': 500, 'Bayonet': 330, 'Talon Knife': 450,
    'Skeleton Knife': 450, 'Stiletto Knife': 300, 'Flip Knife': 240, 'Classic Knife': 240, 'Ursus Knife': 180,
    'Nomad Knife': 230, 'Paracord Knife': 160, 'Survival Knife': 150, 'Kukri Knife': 190, 'Huntsman Knife': 170,
    'Bowie Knife': 160, 'Falchion Knife': 130, 'Gut Knife': 110, 'Navaja Knife': 100, 'Shadow Daggers': 110,
  };
  const GLOVE_BASE = {
    'Sport Gloves': 420, 'Specialist Gloves': 220, 'Moto Gloves': 180, 'Driver Gloves': 150, 'Hand Wraps': 140,
    'Hydra Gloves': 120, 'Bloodhound Gloves': 130, 'Broken Fang Gloves': 110,
  };
  const KNIFE_FINISH = [
    ['Marble Fade', 1.9], ['Gamma Doppler', 1.7], ['Doppler', 1.6], ['Fade', 2.0], ['Lore', 1.9], ['Autotronic', 1.5],
    ['Tiger Tooth', 1.5], ['Slaughter', 1.5], ['Crimson Web', 1.6], ['Case Hardened', 1.4], ['Black Laminate', 1.2],
    ['Freehand', 1.0], ['Bright Water', 0.9], ['Damascus Steel', 1.0], ['Ultraviolet', 1.1], ['Rust Coat', 0.7],
    ['Night Stripe', 0.8], ['Night', 1.1], ['Blue Steel', 1.1], ['Stained', 0.85], ['Scorched', 0.7],
    ['Safari Mesh', 0.6], ['Boreal Forest', 0.65], ['Forest DDPAT', 0.65], ['Urban Masked', 0.65], ['Vanilla', 1.3],
  ];
  const PHASE_MULT = { 'Phase 1': 0.95, 'Phase 2': 1.25, 'Phase 3': 0.9, 'Phase 4': 1.1, Ruby: 3.5, Sapphire: 4.2, 'Black Pearl': 2.8, Emerald: 4 };
  const GLOVE_FINISH = {
    "Pandora's Box": 4, 'Vice': 3.5, 'Hedge Maze': 3.5, 'Superconductor': 3, 'Crimson Kimono': 3.5, 'Emerald Web': 3,
    'Fade': 2.2, 'Amphibious': 2.5, 'Spearmint': 2.2, 'Slingshot': 1.6, 'King Snake': 1.8, 'Marble Fade': 2,
    'Foundation': 1.4, 'Omega': 2, 'Nocts': 1.4, 'Crimson Weave': 1.6, 'Lt. Commander': 1.4, 'Overtake': 1.3,
  };
  const WEAPON_POP = {
    'AK-47': 2.2, 'AWP': 2.2, 'M4A4': 1.6, 'M4A1-S': 1.7, 'Desert Eagle': 1.5, 'USP-S': 1.5, 'Glock-18': 1.4,
    'P250': 0.9, 'Five-SeveN': 0.9, 'P90': 1.0, 'MP9': 0.9, 'MAC-10': 0.9, 'FAMAS': 0.9, 'Galil AR': 0.9,
    'Negev': 0.6, 'M249': 0.6, 'G3SG1': 0.65, 'SCAR-20': 0.65, 'Sawed-Off': 0.7, 'MAG-7': 0.7, 'Nova': 0.7,
    'R8 Revolver': 0.75, 'PP-Bizon': 0.7, 'Zeus x27': 1.2,
  };
  const SKIN_RANGE = [[0.03, 0.3], [0.04, 0.8], [0.08, 2.2], [0.4, 7], [2, 28], [8, 110], [100, 1000], [3000, 5000]];
  const OTHER_RANGE = {
    k: [[0.03, 0.3], [0.03, 0.3], [0.03, 0.4], [0.08, 1.5], [0.3, 8], [1, 35], [10, 100], [700, 900]],
    p: [[0.2, 1], [0.2, 1], [0.3, 2], [0.8, 4], [2, 12], [5, 25], [10, 50], [50, 100]],
    m: [[2, 6], [2, 6], [2, 6], [3, 8], [4, 10], [5, 12], [5, 12], [5, 12]],
    g: [[0.03, 0.3], [0.03, 0.3], [0.03, 0.4], [0.1, 0.8], [0.3, 2], [1, 5], [1, 5], [1, 5]],
    c: [[3, 10], [3, 10], [4, 15], [8, 30], [15, 60], [30, 120], [50, 200], [50, 200]],
    h: [[0.2, 1], [0.2, 1], [0.2, 1], [0.6, 4], [2, 15], [8, 60], [8, 60], [8, 60]],
    a: [[0.5, 2], [0.5, 2], [0.6, 3], [1.5, 8], [3, 20], [8, 60], [8, 60], [8, 60]],
    o: [[0.1, 1], [0.1, 1], [0.1, 1], [0.3, 2], [1, 5], [2, 10], [2, 10], [2, 10]],
  };
  const logRange = (lo, hi, r) => lo * Math.pow(hi / lo, r);
  const ageMult = (year) => (year <= 2014 ? 12 : year <= 2015 ? 4 : year <= 2016 ? 2 : year <= 2018 ? 1.5 : 1);

  function basePrice(it) {
    const r = U.hash01(it.id, 'p');
    if (it.kind === 's') {
      if (it.cat === 'K') {
        let m = 1;
        for (const [f, v] of KNIFE_FINISH) if (it.finish.indexOf(f) === 0 || it.finish === f) { m = v; break; }
        if (it.phase) m *= PHASE_MULT[it.phase] || 1;
        return (KNIFE_BASE[it.weapon] || 200) * m * (0.85 + r * 0.35);
      }
      if (it.cat === 'G') {
        const m = GLOVE_FINISH[it.finish] || (0.6 + r * 0.8);
        return (GLOVE_BASE[it.weapon] || 150) * m * (0.9 + U.hash01(it.id, 'g') * 0.25);
      }
      if (FAMOUS[it.name]) return FAMOUS[it.name];
      const rg = SKIN_RANGE[it.tier];
      let p = logRange(rg[0], rg[1], Math.pow(r, 1.6)) * (WEAPON_POP[it.weapon] || 0.85);
      const inCase = it.cases.some((ci) => E.cases[ci].type === 'case');
      if (inCase) p *= it.year <= 2014 ? 1.8 : it.year <= 2016 ? 1.3 : 1;
      else p *= 1.5;
      return p;
    }
    const rg = (OTHER_RANGE[it.kind] || OTHER_RANGE.o)[it.tier];
    let p = logRange(rg[0], rg[1], Math.pow(r, 1.5));
    if (it.kind === 'k' || it.kind === 'p') p *= ageMult(it.year);
    if (it.kind === 'm' && it.st) p *= 2;
    return p;
  }

  function wearMult(it, w) {
    if (it.cat === 'K') return [1.5, 1.15, 1, 0.9, 0.85][w];
    if (it.cat === 'G') return [2.8, 1.6, 1, 0.85, 0.7][w];
    return [2.0, 1.35, 1, 0.88, 0.78][w];
  }
  const stMult = (it) => (it.cat === 'K' ? 1.35 : it.kind === 's' ? 1.9 : 1);
  const SV_MULT = 1.6;

  E.priceOf = (d) => {
    const it = E.items[d.i];
    let p = it.base;
    if (it.min >= 0 && d.f >= 0) p *= wearMult(it, E.wearIndex(d.f));
    if (d.st) p *= stMult(it);
    if (d.sv) p *= SV_MULT;
    if (d.f >= 0 && d.f < 0.01 && it.min < 0.01) p *= 1.25;
    if (E.isBlueGem(d)) p *= 12;
    return Math.max(0.03, U.round2(p));
  };
  E.isBlueGem = (d) => {
    const it = E.items[d.i];
    return it.finish === 'Case Hardened' && BLUE_GEMS.has(d.s);
  };

  // Belirli aşınma için fiyat (katalog, upgrader)
  E.wearRange = (it, w) => {
    const W = E.WEARS[w];
    const a = Math.max(W.a, it.min), b = Math.min(W.b, it.max);
    return a < b ? [a, b] : null;
  };
  E.availableWears = (it) => {
    if (it.min < 0) return [];
    const out = [];
    for (let w = 0; w < 5; w++) if (E.wearRange(it, w)) out.push(w);
    return out;
  };
  E.priceAt = (it, w, st, sv) => {
    let p = it.base;
    if (w != null && w >= 0) p *= wearMult(it, w);
    if (st) p *= stMult(it);
    if (sv) p *= SV_MULT;
    return Math.max(0.03, U.round2(p));
  };
  E.priceRange = (it, opts) => {
    const ws = E.availableWears(it);
    if (!ws.length) {
      const p = E.priceAt(it, -1, false, opts && opts.sv);
      return [p, opts && opts.st ? E.priceAt(it, -1, true, opts.sv) : p];
    }
    let lo = Infinity, hi = 0;
    for (const w of ws) {
      lo = Math.min(lo, E.priceAt(it, w, false, opts && opts.sv));
      hi = Math.max(hi, E.priceAt(it, w, !!(opts && opts.st && it.st), opts && opts.sv));
    }
    return [lo, hi];
  };
  // Katalogda gösterilen tipik fiyat
  E.typicalPrice = (it) => {
    const ws = E.availableWears(it);
    if (!ws.length) return E.priceAt(it, -1, false, false);
    const w = ws.includes(2) ? 2 : ws[Math.floor(ws.length / 2)];
    return E.priceAt(it, w, false, false);
  };

  // Beklenen aşınma çarpanı (kasa EV hesabı)
  function expWearMult(it) {
    if (it.min < 0) return 1;
    let sum = 0;
    for (const [p, a, b] of WEAR_DIST) {
      let s = 0;
      for (let k = 0; k < 10; k++) {
        const x = a + (b - a) * (k + 0.5) / 10;
        s += wearMult(it, E.wearIndex(it.min + x * (it.max - it.min)));
      }
      sum += p * s / 10;
    }
    return sum;
  }

  /* ---------- Çekiliş havuzu ---------- */
  E.dropsST = (c) => c.type === 'case';
  E.dropsSV = (c) => c.type === 'souvenir';

  function buildPool(c) {
    const byTier = new Map();
    for (const i of c.items) {
      const t = Math.min(E.items[i].tier, 5);
      if (!byTier.has(t)) byTier.set(t, []);
      byTier.get(t).push(i);
    }
    const tiers = [...byTier.keys()].sort((a, b) => a - b);
    const t0 = tiers.length ? tiers[0] : 0;
    let wsum = 0;
    for (const t of tiers) wsum += Math.pow(5, -(t - t0));
    const special = c.rare.length ? E.SPECIAL_CHANCE : 0;
    const groups = [];
    for (const t of tiers) {
      groups.push({ tier: t, p: (Math.pow(5, -(t - t0)) / wsum) * (1 - special), items: byTier.get(t) });
    }
    if (special) {
      // Doppler fazları tek eşya gibi gruplanır
      const sub = new Map();
      for (const i of c.rare) {
        const it = E.items[i];
        if (!sub.has(it.name)) sub.set(it.name, []);
        sub.get(it.name).push(i);
      }
      groups.push({ tier: 6, p: special, items: c.rare, sub: [...sub.values()] });
    }
    return groups.reverse();
  }

  // Bir eşyanın kasadan düşme olasılığı
  E.itemChance = (c, idx) => {
    const pool = E.pool(c);
    for (const g of pool) {
      if (g.sub) {
        for (const s of g.sub) {
          if (s.includes(idx)) {
            const it = E.items[idx];
            let w = 1, tot = 1;
            if (s.length > 1) { w = PHASE_W[it.phase] || 10; tot = s.reduce((a, j) => a + (PHASE_W[E.items[j].phase] || 10), 0); }
            return g.p / g.sub.length * (w / tot);
          }
        }
      } else if (g.items.includes(idx)) return g.p / g.items.length;
    }
    return 0;
  };

  E.pool = (c) => c.pool || (c.pool = buildPool(c));

  E.genFloat = (it) => {
    if (it.min < 0) return -1;
    const r = Math.random();
    let acc = 0, seg = WEAR_DIST[4];
    for (const s of WEAR_DIST) { acc += s[0]; if (r < acc) { seg = s; break; } }
    const x = U.rand(seg[1], seg[2]);
    return +(it.min + x * (it.max - it.min)).toFixed(10);
  };

  E.makeDrop = (idx, opts) => {
    const it = E.items[idx];
    const o = opts || {};
    const f = o.f != null ? o.f : E.genFloat(it);
    const d = {
      i: idx, f, s: it.kind === 's' ? U.randInt(0, 1000) : 0,
      st: o.st != null ? (o.st ? 1 : 0) : (o.stChance && it.st && Math.random() < 0.1 ? 1 : 0),
      sv: o.sv && (it.kind === 's' || it.kind === 'k') ? 1 : 0,
      t: Date.now(), src: o.src || '',
    };
    if (it.kind === 'm' && it.st) d.st = 0; // isim zaten StatTrak içeriyor
    if (it.cat === 'G') d.st = 0;
    d.p = E.priceOf(d);
    return d;
  };

  // Kasadan rastgele eşya indeksi seç
  E.rollIndex = (c) => {
    const g = U.weighted(E.pool(c), 'p');
    if (g.sub) {
      const s = U.pick(g.sub);
      if (s.length === 1) return s[0];
      return U.weighted(s.map((j) => ({ j, w: PHASE_W[E.items[j].phase] || 10 }))).j;
    }
    return U.pick(g.items);
  };

  E.roll = (c) => E.makeDrop(E.rollIndex(c), { stChance: E.dropsST(c), sv: E.dropsSV(c), src: c.name });

  /* ---------- Fiyatları hesapla ---------- */
  const RTP = 0.92;
  for (const it of E.items) it.base = basePrice(it);
  for (const it of E.items) it.ewm = expWearMult(it);
  for (const c of E.cases) {
    let ev = 0;
    const st = E.dropsST(c), sv = E.dropsSV(c);
    for (const g of E.pool(c)) {
      let gsum = 0, n = 0;
      if (g.sub) {
        for (const s of g.sub) {
          let w = 0, tot = 0;
          for (const j of s) {
            const it = E.items[j];
            const pw = s.length > 1 ? PHASE_W[it.phase] || 10 : 1;
            let v = it.base * it.ewm;
            if (st && it.st && it.cat !== 'G') v *= 0.9 + 0.1 * stMult(it);
            w += pw * v; tot += pw;
          }
          gsum += w / tot; n++;
        }
      } else {
        for (const j of g.items) {
          const it = E.items[j];
          let v = it.base * it.ewm;
          if (st && it.st) v *= 0.9 + 0.1 * stMult(it);
          if (sv && (it.kind === 's' || it.kind === 'k')) v *= SV_MULT;
          gsum += Math.max(0.03, v); n++;
        }
      }
      ev += g.p * (gsum / n);
    }
    c.ev = ev;
    c.price = Math.max(0.1, U.round2(ev / RTP));
  }

  E.casesByType = (t) => E.cases.filter((c) => t === 'all' || c.type === t);
  E.dataVersion = D.v;

  /* ---------- Bot isimleri ---------- */
  E.BOT_NAMES = [
    'RushB_Mehmet', 'AWPçı Ahmet', 'KarambitAvcısı', 'SilverElite', 'ecoRound', 'flashbangKral', 'dust2enjoyer',
    'NoScopeNuri', 'HeadshotHakan', 'TerörüstSelim', 'clutchMaster', 'deagleDeli', 'GlobalElif', 'botKemal',
    'smokeCriminal', 'ninjaDefuse', 'Ak47Aşkı', 'xX_PRO_Xx', 'BayonetBaba', 'MirageMert', 'InfernoİREM',
    'tapTapBoom', 'kasaKralı', 'şanslıŞükrü', 'StatTrakSevgi', 'fadeFatma', 'dopplerDeniz', 'ruby_rüya',
  ];

  CS.E = E;
})(window.CS);
