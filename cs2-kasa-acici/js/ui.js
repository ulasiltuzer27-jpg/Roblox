/* Ortak arayüz bileşenleri: kartlar, modallar, bildirimler */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S;
  const UI = {};

  UI.color = (tier) => E.TIER_COLORS[tier] || E.TIER_COLORS[0];

  UI.nameParts = (it, d) => {
    let top, bottom;
    if (it.kind === 's') {
      top = (it.tier === 6 ? '★ ' : '') + (d && d.st ? 'StatTrak™ ' : '') + (d && d.sv ? 'Hatıra ' : '') + it.weapon;
      bottom = it.finish + (it.phase ? ' · ' + it.phase : '');
    } else {
      top = (d && d.sv ? 'Hatıra ' : '') + E.KIND_NAMES[it.kind];
      bottom = it.name;
    }
    return [top, bottom];
  };

  UI.dropName = (d) => {
    const it = E.items[d.i];
    let n = '';
    if (it.kind === 's') {
      n = (it.tier === 6 ? '★ ' : '') + (d.st ? 'StatTrak™ ' : '') + (d.sv ? 'Hatıra ' : '') + it.name.replace('★ ', '');
      if (it.phase) n += ' (' + it.phase + ')';
      if (d.f >= 0) n += ' (' + E.WEARS[E.wearIndex(d.f)].s + ')';
    } else {
      n = (d.sv ? 'Hatıra ' : '') + E.KIND_NAMES[it.kind] + ' | ' + it.name;
    }
    return n;
  };

  // Envanter/çekiliş kartı
  UI.dropCard = (d, opts) => {
    const o = opts || {};
    const it = E.items[d.i];
    const [top, bottom] = UI.nameParts(it, d);
    const wear = d.f >= 0 ? E.WEARS[E.wearIndex(d.f)].s : '';
    const badges = [];
    if (d.st) badges.push('<span class="badge b-st">ST</span>');
    if (d.sv) badges.push('<span class="badge b-sv">HATIRA</span>');
    if (E.isBlueGem(d)) badges.push('<span class="badge b-gem">💎</span>');
    return `<div class="icard t${it.tier}${o.cls ? ' ' + o.cls : ''}" style="--rc:${UI.color(it.tier)}" data-u="${d.u || ''}">
      <div class="ic-top"><span class="ic-wear">${wear}${d.f >= 0 && o.float ? ' <i>' + d.f.toFixed(4) + '</i>' : ''}</span><span>${badges.join('')}</span></div>
      <div class="ic-img"><img src="${E.img(it.imgS, 256)}" loading="lazy" alt=""></div>
      <div class="ic-name"><span class="ic-w">${U.esc(top)}</span><span class="ic-f">${U.esc(bottom)}</span></div>
      <div class="ic-bot"><span class="ic-price">${U.money(d.p)}</span>${o.extra || ''}</div>
      ${o.check ? '<span class="ic-check">✓</span>' : ''}
    </div>`;
  };

  // Katalog / kasa içeriği kartı (çekiliş değil, eşya türü)
  UI.itemCard = (it, opts) => {
    const o = opts || {};
    const [top, bottom] = UI.nameParts(it, null);
    const pr = o.price != null ? o.price : U.money(E.typicalPrice(it));
    return `<div class="icard t${it.tier}${o.cls ? ' ' + o.cls : ''}" style="--rc:${UI.color(it.tier)}" data-i="${it.idx}"${o.attrs || ''}>
      <div class="ic-top"><span class="ic-wear">${o.topLeft || ''}</span><span>${o.topRight || ''}</span></div>
      <div class="ic-img"><img src="${E.img(it.imgS, 256)}" loading="lazy" alt=""></div>
      <div class="ic-name"><span class="ic-w">${U.esc(top)}</span><span class="ic-f">${U.esc(bottom)}</span></div>
      <div class="ic-bot"><span class="ic-price">${pr}</span>${o.extra || ''}</div>
    </div>`;
  };

  UI.goldCard = (extra) => `<div class="icard gold-card t6" style="--rc:${UI.color(6)}">
      <div class="gold-star">★</div>
      <div class="ic-name"><span class="ic-w">Nadir Özel Eşya</span><span class="ic-f">${extra || 'Bıçak / Eldiven'}</span></div>
    </div>`;

  UI.caseCard = (c) => `<a class="ccard" href="#/case/${c.idx}" data-c="${c.idx}">
      <span class="cc-type ct-${c.type}">${E.CASE_TYPE_NAME[c.type]}</span>
      <div class="cc-img"><img src="${E.img(c.imgS, 256)}" loading="lazy" alt=""></div>
      <div class="cc-name">${U.esc(c.name)}</div>
      <div class="cc-price">${U.money(c.price)}</div>
    </a>`;

  /* ---------- Modal ---------- */
  UI.modal = (content, opts) => {
    const o = opts || {};
    const wrap = U.html(`<div class="modal-wrap"><div class="modal ${o.cls || ''}"><button class="modal-x" aria-label="Kapat">✕</button><div class="modal-body"></div></div></div>`);
    const body = wrap.querySelector('.modal-body');
    if (typeof content === 'string') body.innerHTML = content; else body.appendChild(content);
    document.body.appendChild(wrap);
    requestAnimationFrame(() => wrap.classList.add('show'));
    const close = () => {
      if (!wrap.parentNode) return;
      wrap.classList.remove('show');
      document.removeEventListener('keydown', onKey);
      setTimeout(() => wrap.remove(), 200);
      if (o.onClose) o.onClose();
    };
    const onKey = (e) => { if (e.key === 'Escape') close(); };
    document.addEventListener('keydown', onKey);
    wrap.addEventListener('mousedown', (e) => { if (e.target === wrap) close(); });
    wrap.querySelector('.modal-x').onclick = close;
    return { el: wrap, body, close };
  };

  UI.confirm = (msg, okText) => new Promise((res) => {
    let done = false;
    const m = UI.modal(`<div class="confirm"><p>${msg}</p><div class="row gap end">
      <button class="btn ghost" data-a="no">Vazgeç</button><button class="btn primary" data-a="yes">${okText || 'Onayla'}</button></div></div>`,
    { cls: 'small', onClose: () => { if (!done) res(false); } });
    m.body.addEventListener('click', (e) => {
      const a = e.target.closest('[data-a]');
      if (!a) return;
      done = true;
      res(a.dataset.a === 'yes');
      m.close();
    });
  });

  /* ---------- Bildirim ---------- */
  UI.toast = (msg, type) => {
    let box = U.$('#toasts');
    const t = U.html(`<div class="toast ${type || ''}">${msg}</div>`);
    box.appendChild(t);
    requestAnimationFrame(() => t.classList.add('show'));
    setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 300); }, 3200);
  };

  /* ---------- Float çubuğu ---------- */
  UI.floatBar = (f, it) => {
    const segs = [[0, 0.07], [0.07, 0.15], [0.15, 0.38], [0.38, 0.45], [0.45, 1]]
      .map(([a, b], i) => `<span class="fb-seg fb-${i}" style="width:${(b - a) * 100}%"></span>`).join('');
    const range = it && it.min >= 0 ? `<span class="fb-range" style="left:${it.min * 100}%;width:${(it.max - it.min) * 100}%"></span>` : '';
    const mark = f >= 0 ? `<span class="fb-mark" style="left:${f * 100}%"></span>` : '';
    return `<div class="floatbar">${segs}${range}${mark}</div>`;
  };

  /* ---------- Eşya detay modalı (envanter) ---------- */
  UI.dropModal = (d, opts) => {
    const o = opts || {};
    const it = E.items[d.i];
    const [top, bottom] = UI.nameParts(it, d);
    const wear = d.f >= 0 ? E.WEARS[E.wearIndex(d.f)] : null;
    const owned = !!S.getItem(d.u);
    const html = `<div class="dmodal" style="--rc:${UI.color(it.tier)}">
      <div class="dm-img t${it.tier}"><img src="${E.img(it.imgS, 512)}" alt=""></div>
      <div class="dm-info">
        <div class="dm-rarity">${E.tierName(it)} ${it.kind === 's' ? E.CAT_NAMES[it.cat] || '' : E.KIND_NAMES[it.kind]}</div>
        <h2>${U.esc(top)}<br><span>${U.esc(bottom)}</span></h2>
        ${wear ? `<div class="dm-wear">${wear.n} <b>(${wear.s})</b></div>` : ''}
        ${d.f >= 0 ? `<div class="dm-float"><div class="row between"><span>Float</span><b class="mono">${d.f.toFixed(10)}</b></div>${UI.floatBar(d.f, it)}</div>` : ''}
        <div class="dm-grid">
          ${it.kind === 's' ? `<div><span>Desen tohumu</span><b>${d.s}</b></div>` : ''}
          <div><span>Kaynak</span><b>${U.esc(d.src || '-')}</b></div>
          ${d.st ? '<div><span>StatTrak™</span><b class="st-col">Onaylı Öldürme: 0</b></div>' : ''}
          ${E.isBlueGem(d) ? '<div><span>Desen</span><b style="color:#5cb8ff">💎 Blue Gem!</b></div>' : ''}
          <div><span>Elde edildi</span><b>${U.timeAgo(d.t)}</b></div>
        </div>
        <div class="dm-price">${U.money(d.p)}</div>
        <div class="row gap wrap">
          ${owned && !o.noActions ? `<button class="btn primary" data-a="sell">Sat · ${U.money(d.p)}</button>
            <button class="btn" data-a="upg">Upgrader'a gönder</button>` : ''}
          <button class="btn ghost" data-a="cat">Katalogda gör</button>
        </div>
      </div></div>`;
    const m = UI.modal(html, { cls: 'wide' });
    m.body.addEventListener('click', (e) => {
      const a = e.target.closest('[data-a]');
      if (!a) return;
      if (a.dataset.a === 'sell') {
        const v = S.sell([d.u]);
        CS.Snd.coin();
        UI.toast(`Satıldı: <b>${U.esc(UI.dropName(d))}</b> +${U.money(v)}`, 'ok');
        m.close();
        if (o.onChange) o.onChange();
      } else if (a.dataset.a === 'upg') {
        m.close();
        CS.pendingUpgrade = [d.u];
        location.hash = '#/upgrader';
      } else if (a.dataset.a === 'cat') {
        m.close();
        UI.catalogModal(it);
      }
    });
    return m;
  };

  /* ---------- Katalog eşya modalı ---------- */
  UI.catalogModal = (it) => {
    const ws = E.availableWears(it);
    let rows = '';
    if (ws.length) {
      rows = ws.map((w) => `<tr><td>${E.WEARS[w].n} <small>(${E.WEARS[w].s})</small></td><td>${U.money(E.priceAt(it, w, false, false))}</td>
        <td>${it.st ? U.money(E.priceAt(it, w, true, false)) : '—'}</td><td>${it.sv ? U.money(E.priceAt(it, w, false, true)) : '—'}</td></tr>`).join('');
    } else {
      rows = `<tr><td>Standart</td><td>${U.money(E.priceAt(it, -1, false, false))}</td><td>${it.st && it.kind === 's' ? U.money(E.priceAt(it, -1, true, false)) : '—'}</td><td>—</td></tr>`;
    }
    const cases = it.cases.map((ci) => E.cases[ci]);
    const cols = it.cols.map((i) => E.cols[i]);
    const [top, bottom] = UI.nameParts(it, null);
    const html = `<div class="dmodal" style="--rc:${UI.color(it.tier)}">
      <div class="dm-img t${it.tier}"><img src="${E.img(it.imgS, 512)}" alt=""></div>
      <div class="dm-info">
        <div class="dm-rarity">${E.tierName(it)} ${it.kind === 's' ? E.CAT_NAMES[it.cat] || '' : E.KIND_NAMES[it.kind]}</div>
        <h2>${U.esc(top)}<br><span>${U.esc(bottom)}</span></h2>
        ${it.min >= 0 ? `<div class="dm-float"><div class="row between"><span>Float aralığı</span><b class="mono">${it.min.toFixed(2)} – ${it.max.toFixed(2)}</b></div>${UI.floatBar(-1, it)}</div>` : ''}
        <table class="ptable"><thead><tr><th>Durum</th><th>Normal</th><th>StatTrak™</th><th>Hatıra</th></tr></thead><tbody>${rows}</tbody></table>
        ${cols.length ? `<div class="dm-sub">Koleksiyon: ${cols.map((c) => `<b>${U.esc(c.n)}</b>`).join(', ')}</div>` : ''}
        <div class="dm-sub">${cases.length ? 'Bulunduğu kasalar:' : 'Hiçbir kasada bulunmuyor (Upgrader / Takas ile elde edilebilir).'}</div>
        <div class="chips">${cases.slice(0, 40).map((c) => `<a class="chip" href="#/case/${c.idx}"><img src="${E.img(c.imgS, 64)}" alt="">${U.esc(c.name)}</a>`).join('')}${cases.length > 40 ? `<span class="chip">+${cases.length - 40} daha</span>` : ''}</div>
      </div></div>`;
    const m = UI.modal(html, { cls: 'wide' });
    m.body.addEventListener('click', (e) => { if (e.target.closest('a.chip')) m.close(); });
    return m;
  };

  /* ---------- Bakiye ---------- */
  UI.updateBalance = () => {
    const b = U.$('#balance');
    if (!b) return;
    const prev = parseFloat(b.dataset.v || '0');
    if (Math.abs(prev - S.balance) > 0.001) {
      U.countTo(b, prev, S.balance, 500);
      b.dataset.v = S.balance;
      const chip = b.closest('.balance');
      chip.classList.remove('up', 'down');
      void chip.offsetWidth;
      chip.classList.add(S.balance > prev ? 'up' : 'down');
    }
    const ic = U.$('#invCount');
    if (ic) ic.textContent = S.inv.length;
  };

  UI.depositModal = () => {
    const m = UI.modal(`<div class="deposit">
      <h2>Bakiye Ekle</h2>
      <p class="muted">Bu tamamen eğlence amaçlı sanal bakiyedir. Gerçek para yoktur, hiçbir şey satın alınmaz.</p>
      <div class="dep-grid">
        ${[50, 100, 500, 1000, 5000, 25000].map((v) => `<button class="dep-btn" data-v="${v}"><b>${U.money(v)}</b><span>Ücretsiz</span></button>`).join('')}
      </div></div>`, { cls: 'small' });
    m.body.addEventListener('click', (e) => {
      const b = e.target.closest('[data-v]');
      if (!b) return;
      S.deposit(+b.dataset.v);
      CS.Snd.coin();
      UI.toast(`+${U.money(+b.dataset.v)} bakiye eklendi`, 'ok');
      m.close();
    });
  };

  /* ---------- Konfeti ---------- */
  UI.confetti = (n, colors) => {
    const box = U.html('<div class="confetti"></div>');
    document.body.appendChild(box);
    const cols = colors || ['#ffcc33', '#eb4b4b', '#4b69ff', '#8847ff', '#d32ce6', '#3ddc84'];
    for (let i = 0; i < (n || 120); i++) {
      const p = document.createElement('i');
      p.style.left = Math.random() * 100 + 'vw';
      p.style.background = U.pick(cols);
      p.style.animationDelay = Math.random() * 0.6 + 's';
      p.style.animationDuration = 2 + Math.random() * 2 + 's';
      p.style.transform = `rotate(${Math.random() * 360}deg)`;
      box.appendChild(p);
    }
    setTimeout(() => box.remove(), 5000);
  };

  UI.avatar = (name, bot) => {
    const h = Math.floor(U.hash01(name, 'av') * 360);
    const ch = name.replace(/[^A-Za-zÇĞİÖŞÜçğıöşü0-9]/g, '').slice(0, 2).toUpperCase() || '?';
    return `<span class="avatar${bot ? ' bot' : ''}" style="--h:${h}">${U.esc(ch)}</span>`;
  };

  CS.UI = UI;
})(window.CS);
