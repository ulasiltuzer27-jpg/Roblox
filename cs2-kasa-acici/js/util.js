/* Yardımcı fonksiyonlar */
window.CS = window.CS || {};
window.CS.Pages = window.CS.Pages || {};
(function (CS) {
  'use strict';

  const U = {};

  U.$ = (sel, root) => (root || document).querySelector(sel);
  U.$$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));

  U.esc = (s) => String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

  U.html = (str) => {
    const t = document.createElement('template');
    t.innerHTML = str.trim();
    return t.content.firstElementChild;
  };

  const moneyFmt = new Intl.NumberFormat('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  U.money = (v) => {
    const r = Math.round((v || 0) * 100) / 100;
    return (r < 0 ? '-$' : '$') + moneyFmt.format(Math.abs(r));
  };
  U.num = (v) => new Intl.NumberFormat('tr-TR').format(v || 0);
  U.pct = (v) => {
    const p = v * 100;
    if (p >= 10) return p.toFixed(2) + '%';
    if (p >= 1) return p.toFixed(2) + '%';
    if (p >= 0.01) return p.toFixed(3) + '%';
    return p.toFixed(4) + '%';
  };
  U.round2 = (v) => Math.round(v * 100) / 100;
  U.clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  U.sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  U.rand = (a, b) => a + Math.random() * (b - a);
  U.randInt = (a, b) => Math.floor(U.rand(a, b + 1));
  U.pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
  U.shuffle = (arr) => {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  };

  // FNV-1a -> [0,1)
  U.hash01 = (str, salt) => {
    let h = 0x811c9dc5;
    const s = (salt || '') + str;
    for (let i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 0x01000193);
    }
    h ^= h >>> 13; h = Math.imul(h, 0x5bd1e995); h ^= h >>> 15;
    return (h >>> 0) / 4294967296;
  };

  U.debounce = (fn, ms) => {
    let t;
    return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
  };

  U.timeAgo = (ts) => {
    const s = Math.floor((Date.now() - ts) / 1000);
    if (s < 60) return 'az önce';
    if (s < 3600) return Math.floor(s / 60) + ' dk önce';
    if (s < 86400) return Math.floor(s / 3600) + ' sa önce';
    return Math.floor(s / 86400) + ' gün önce';
  };

  // Ağırlıklı seçim: [{w, ...}]
  U.weighted = (list, key) => {
    const k = key || 'w';
    let total = 0;
    for (const x of list) total += x[k];
    let r = Math.random() * total;
    for (const x of list) {
      r -= x[k];
      if (r < 0) return x;
    }
    return list[list.length - 1];
  };

  // Sayı sayma animasyonu
  U.countTo = (el, from, to, ms, fmt) => {
    const f = fmt || U.money;
    const start = performance.now();
    const step = (now) => {
      const t = Math.min(1, (now - start) / ms);
      const e = 1 - Math.pow(1 - t, 3);
      el.textContent = f(from + (to - from) * e);
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };

  U.normTR = (s) => String(s).toLocaleLowerCase('tr-TR')
    .replace(/ı/g, 'i').replace(/ğ/g, 'g').replace(/ü/g, 'u').replace(/ş/g, 's')
    .replace(/ö/g, 'o').replace(/ç/g, 'c').replace(/™/g, '').replace(/★/g, '');

  CS.U = U;
})(window.CS);
