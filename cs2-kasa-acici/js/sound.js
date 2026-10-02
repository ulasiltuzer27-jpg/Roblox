/* WebAudio ile sentezlenen sesler (dosya gerektirmez) */
(function (CS) {
  'use strict';
  let ctx = null, master = null;
  let lastTick = 0;

  function ac() {
    if (!CS.S.settings.sound) return null;
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
      master = ctx.createGain();
      master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    master.gain.value = 0.35 * (CS.S.settings.volume == null ? 0.5 : CS.S.settings.volume) * 2;
    return ctx;
  }

  function tone(freq, dur, type, vol, when, slide) {
    const c = ac();
    if (!c) return;
    const t = c.currentTime + (when || 0);
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = type || 'sine';
    o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(slide, t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol || 0.3, t + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(master);
    o.start(t); o.stop(t + dur + 0.02);
  }

  function noise(dur, vol, when, freq) {
    const c = ac();
    if (!c) return;
    const t = c.currentTime + (when || 0);
    const len = Math.floor(c.sampleRate * dur);
    const buf = c.createBuffer(1, len, c.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
    const src = c.createBufferSource();
    src.buffer = buf;
    const f = c.createBiquadFilter();
    f.type = 'bandpass'; f.frequency.value = freq || 3000; f.Q.value = 1.2;
    const g = c.createGain();
    g.gain.value = vol || 0.2;
    src.connect(f); f.connect(g); g.connect(master);
    src.start(t);
  }

  const Snd = {
    tick() {
      const now = performance.now();
      if (now - lastTick < 28) return;
      lastTick = now;
      tone(1900 + Math.random() * 200, 0.035, 'square', 0.07);
      noise(0.02, 0.08, 0, 5000);
    },
    click() { tone(900, 0.05, 'triangle', 0.12); },
    open() {
      noise(0.25, 0.15, 0, 1200);
      tone(220, 0.3, 'sawtooth', 0.06, 0, 440);
    },
    reveal(tier) {
      const sets = [
        [523], [523, 659], [523, 659, 784], [587, 740, 880], [659, 831, 988, 1319],
        [698, 880, 1047, 1397, 1760], [784, 988, 1175, 1568, 1976, 2349], [784, 988, 1175, 1568, 1976, 2349],
      ];
      const notes = sets[tier] || sets[2];
      notes.forEach((f, i) => tone(f, 0.35 + i * 0.05, tier >= 5 ? 'triangle' : 'sine', 0.18, i * 0.07));
      if (tier >= 6) {
        for (let i = 0; i < 10; i++) tone(2000 + Math.random() * 2500, 0.15, 'sine', 0.05, 0.4 + i * 0.06);
        tone(98, 1.2, 'sawtooth', 0.08, 0, 49);
      }
    },
    coin() { tone(1319, 0.08, 'square', 0.08); tone(1760, 0.18, 'square', 0.08, 0.07); },
    win() { [523, 659, 784, 1047, 1319].forEach((f, i) => tone(f, 0.4, 'triangle', 0.16, i * 0.09)); },
    lose() { [392, 330, 262, 196].forEach((f, i) => tone(f, 0.35, 'sawtooth', 0.07, i * 0.13)); },
    beep(hi) { tone(hi ? 1320 : 880, 0.12, 'square', 0.1); },
    whoosh() { noise(0.4, 0.12, 0, 800); },
  };

  CS.Snd = Snd;
})(window.CS);
