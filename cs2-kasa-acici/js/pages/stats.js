/* Profil ve istatistikler */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, S = CS.S, UI = CS.UI;

  const RANKS = [
    ['Silver I', 0], ['Silver II', 10], ['Silver III', 25], ['Silver IV', 50], ['Silver Elite', 100],
    ['Silver Elite Master', 175], ['Gold Nova I', 275], ['Gold Nova II', 400], ['Gold Nova III', 600],
    ['Gold Nova Master', 850], ['Master Guardian I', 1200], ['Master Guardian II', 1700], ['Master Guardian Elite', 2400],
    ['Distinguished Master Guardian', 3300], ['Legendary Eagle', 4500], ['Legendary Eagle Master', 6000],
    ['Supreme Master First Class', 8000], ['The Global Elite', 11000],
  ];
  const rankGroup = (i) => (i < 6 ? 'silver' : i < 10 ? 'gold' : i < 14 ? 'mg' : i < 16 ? 'eagle' : i < 17 ? 'smfc' : 'ge');

  CS.Pages.stats = (view) => {
    const st = S.stats;
    const xp = st.xp;
    let r = 0;
    for (let i = 0; i < RANKS.length; i++) if (xp >= RANKS[i][1]) r = i;
    const next = RANKS[r + 1];
    const prog = next ? (xp - RANKS[r][1]) / (next[1] - RANKS[r][1]) : 1;
    const net = U.round2(S.balance + S.invValue() - st.deposited);
    const tierTotal = st.tiers.reduce((a, v) => a + v, 0) || 1;
    const best = st.best && E.byId.get(st.best.id) ? Object.assign({}, st.best, { i: E.byId.get(st.best.id).idx, t: Date.now() }) : null;
    const histTxt = (h) => {
      if (h.k === 'open') return `<b>${U.esc(E.cases[h.c] ? E.cases[h.c].name : 'Kasa')}</b> x${h.n} açıldı`;
      if (h.k === 'battle') return `Item Fight (${U.esc(h.mode)}${h.crazy ? ', Crazy' : ''}) ${h.won ? 'kazanıldı' : 'kaybedildi'}`;
      if (h.k === 'upgrade') return `Upgrader ${h.won ? 'başarılı' : 'başarısız'}`;
      if (h.k === 'tradeup') return 'Takas sözleşmesi imzalandı';
      return h.k;
    };

    view.innerHTML = `
      <h1 class="page-title">👤 Profil</h1>
      <section class="profile">
        <div class="rank-card rk-${rankGroup(r)}">
          <div class="rank-emb"><span>${'★'.repeat(Math.min(4, (r % 6) + 1))}</span></div>
          <div class="rank-info">
            <small>Rütbe</small><h2>${RANKS[r][0]}</h2>
            <div class="xpbar"><span style="width:${Math.round(prog * 100)}%"></span></div>
            <small>${next ? `Sonraki rütbe: <b>${next[0]}</b> · ${U.money(next[1] - xp)} daha harca` : 'Zirvedesin!'}</small>
          </div>
        </div>
        <div class="tiles">
          <div class="tile"><span>Bakiye</span><b>${U.money(S.balance)}</b></div>
          <div class="tile"><span>Envanter değeri</span><b>${U.money(S.invValue())}</b></div>
          <div class="tile"><span>Net kâr / zarar</span><b class="${net >= 0 ? 'pos' : 'neg'}">${net >= 0 ? '+' : ''}${U.money(net)}</b></div>
          <div class="tile"><span>Açılan kasa</span><b>${U.num(st.opened)}</b></div>
          <div class="tile"><span>Toplam harcama</span><b>${U.money(st.spent)}</b></div>
          <div class="tile"><span>Satışlardan</span><b>${U.money(st.sold)}</b></div>
          <div class="tile"><span>Item Fight</span><b>${st.battleWins} / ${st.battles}</b></div>
          <div class="tile"><span>Upgrader</span><b>${st.upgWins} / ${st.upg}</b></div>
          <div class="tile"><span>Takas sözleşmesi</span><b>${st.tradeups}</b></div>
          <div class="tile"><span>Yüklenen bakiye</span><b>${U.money(st.deposited)}</b></div>
        </div>
      </section>
      <div class="two-col">
        <section class="panel">
          <h3>Kalite Dağılımı</h3>
          <div class="odds">${[7, 6, 5, 4, 3, 2, 1, 0].map((t) => `<div class="odd" style="--rc:${UI.color(t)}"><span class="odd-bar" style="width:${Math.max(1, st.tiers[t] / tierTotal * 100)}%"></span>
            <span class="odd-n">${E.TIER_SKIN[t]}</span><b>${U.num(st.tiers[t])}</b></div>`).join('')}</div>
        </section>
        <section class="panel">
          <h3>En İyi Düşüş</h3>
          ${best ? `<div class="best">${UI.dropCard(best, { float: true })}<div><p>${U.esc(UI.dropName(best))}</p><p class="muted">${U.esc(best.src || '')}</p></div></div>` : '<div class="empty small">Henüz bir şey açmadın.</div>'}
        </section>
      </div>
      <section class="panel">
        <h3>Son Hareketler</h3>
        ${S.hist.length ? `<div class="hist">${S.hist.slice(0, 30).map((h) => `<div class="hrow"><span>${histTxt(h)}</span>
          <span class="muted">${h.cost != null ? U.money(h.cost) : ''}</span>
          <b class="${h.v >= (h.cost || 0) ? 'pos' : 'neg'}">${U.money(h.v || 0)}</b><span class="muted">${U.timeAgo(h.t)}</span></div>`).join('')}</div>` : '<div class="empty small">Henüz hareket yok.</div>'}
      </section>
      <section class="panel danger-zone">
        <h3>Ayarlar</h3>
        <div class="row gap wrap center-v">
          <label>Ses seviyesi <input type="range" min="0" max="1" step="0.05" id="vol" value="${S.settings.volume}"></label>
          <label class="switch"><input type="checkbox" id="fastAll" ${S.settings.fast ? 'checked' : ''}><span></span>Hızlı animasyonlar</label>
          <button class="btn danger" id="reset">İlerlemeyi sıfırla</button>
        </div>
      </section>`;

    U.$('#vol', view).addEventListener('input', (e) => { S.settings.volume = +e.target.value; S.save(); });
    U.$('#vol', view).addEventListener('change', () => CS.Snd.reveal(3));
    U.$('#fastAll', view).addEventListener('change', (e) => { S.settings.fast = e.target.checked; S.save(); });
    U.$('#reset', view).onclick = async () => {
      if (await UI.confirm('Tüm envanter, bakiye ve istatistikler silinecek. Emin misin?', 'Sıfırla')) {
        S.reset();
        UI.toast('İlerleme sıfırlandı', 'ok');
        CS.Pages.stats(view);
      }
    };
    const bc = U.$('.best .icard', view);
    if (bc && best) bc.addEventListener('click', () => UI.dropModal(best, { noActions: true }));
  };
})(window.CS);
