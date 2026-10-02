/* Dönen şerit (rulet) animasyonu - yatay (kasa açma) ve dikey (Item Fight) */
(function (CS) {
  'use strict';
  const U = CS.U, E = CS.E, UI = CS.UI;

  const ease = (t) => 1 - Math.pow(1 - t, 4.2);

  function cell(idx, real) {
    const it = E.items[idx];
    if (it.tier === 6 && !real) {
      return `<div class="rcell gold" style="--rc:${UI.color(6)}"><div class="gold-star">★</div><span class="rc-n">Nadir Özel Eşya</span></div>`;
    }
    const [top, bottom] = UI.nameParts(it, null);
    return `<div class="rcell t${it.tier}" style="--rc:${UI.color(it.tier)}"><img src="${E.img(it.imgS, 160)}" alt="">
      <span class="rc-n"><small>${U.esc(top)}</small>${U.esc(bottom)}</span></div>`;
  }

  function teaserIndex(c) {
    const pool = E.pool(c);
    const hi = pool.filter((g) => g.tier >= 4);
    if (!hi.length) return E.rollIndex(c);
    return U.pick(U.pick(hi).items);
  }

  /**
   * host: kapsayıcı eleman; c: kasa; d: kazanılan çekiliş
   * opts: { axis: 'x'|'y', fast, sound, duration }
   */
  function spin(host, c, d, opts) {
    const o = opts || {};
    const axis = o.axis || 'x';
    const N = axis === 'x' ? 64 : 40;
    const WIN = N - 9;
    const strip = [];
    for (let k = 0; k < N; k++) strip.push(k === WIN ? d.i : E.rollIndex(c));
    if (Math.random() < 0.4) strip[WIN + (Math.random() < 0.5 ? -1 : 1)] = teaserIndex(c);

    host.innerHTML = `<div class="reel reel-${axis}"><div class="reel-track">${strip.map((i) => cell(i)).join('')}</div><div class="reel-line"></div></div>`;
    const reel = host.firstElementChild;
    const track = reel.firstElementChild;
    const cells = track.children;

    return new Promise((resolve) => {
      requestAnimationFrame(() => {
        const r0 = cells[0].getBoundingClientRect();
        const r1 = cells[1].getBoundingClientRect();
        const cs = axis === 'x' ? r1.left - r0.left : r1.top - r0.top;
        const view = axis === 'x' ? reel.clientWidth : reel.clientHeight;
        const center = WIN * cs + (axis === 'x' ? r0.width : r0.height) / 2 - view / 2;
        const jitter = (Math.random() - 0.5) * cs * 0.8;
        const final = center + jitter;
        const dur = o.duration || (o.fast ? 1800 : (axis === 'x' ? 6200 : 4200)) + Math.random() * 300;
        const start = performance.now();
        let lastIdx = -1;
        const set = (v) => {
          track.style.transform = axis === 'x' ? `translate3d(${-v}px,0,0)` : `translate3d(0,${-v}px,0)`;
        };
        const frame = (now) => {
          if (!reel.isConnected) { resolve(); return; }
          const t = Math.min(1, (now - start) / dur);
          const v = final * ease(t);
          set(v);
          const idx = Math.floor((v + view / 2) / cs);
          if (idx !== lastIdx) { lastIdx = idx; if (o.sound) CS.Snd.tick(); }
          if (t < 1) { requestAnimationFrame(frame); return; }
          // ortaya hizala
          track.style.transition = 'transform .35s cubic-bezier(.3,.7,.3,1)';
          set(center);
          setTimeout(() => {
            track.style.transition = '';
            const win = cells[WIN];
            if (E.items[d.i].tier === 6) {
              const real = U.html(cell(d.i, true));
              win.replaceWith(real);
              real.classList.add('win', 'reveal');
            } else {
              win.classList.add('win');
            }
            reel.classList.add('done');
            resolve();
          }, 360);
        };
        requestAnimationFrame(frame);
      });
    });
  }

  CS.Reel = { spin };
})(window.CS);
