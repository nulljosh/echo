// Hero scene, after Keyrate and Plank. Echo's live view under the title hears a take and writes it word by word, the
// word being heard in blue as the app does it, the wave moving and the clock running; when the take ends, the export
// formats light in turn. The readout under the buttons says the same in one line. Loose chips drift at three depths.
// Every layer eases toward the scroll position at its own speed and leans away from the pointer on desktop.
// Reduced motion gets a still scene.
(function () {
  var still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var el = function (t, c, x) { var e = document.createElement(t); if (c) e.className = c; if (x != null) e.textContent = x; return e; };
  var wait = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };

  // [kind, [speaker, line]...]; the hot key take copies to the clipboard instead of only saving
  var TAKES = [
    ['Meeting', [['You', 'Can we move the launch to Thursday?'], ['Them', 'Thursday works. I will tell the team tonight.']]],
    ['Memo', [['', 'Pick up milk, call the dentist, and send Sam the photos from Saturday.']]],
    ['French', [['', 'Bonjour, je voudrais un café et un croissant, s’il vous plaît.']]],
    ['Hot key', [['', 'Thanks, that works for me. Send it over when you are ready.']]],
    ['Lecture', [['', 'Photosynthesis turns light, water and carbon dioxide into sugar and oxygen.']]],
    ['Meeting', [['Them', 'What did the numbers look like last week?'], ['You', 'Up nine percent, mostly from the new signups.']]],
    ['File', [['', 'Interview, part two. She started the bakery in 1998 with one oven.']]],
    ['Spanish', [['', 'Hola, ¿a qué hora sale el próximo tren a Madrid?']]]
  ];
  var FMTS = ['.txt', '.md', '.srt', '.docx'];

  var board = document.getElementById('board'), ground = document.querySelector('.ground');
  var take, kind, clock, words, bars = [], fmts = [];
  if (board) {
    take = board.appendChild(el('div', 'take'));
    var bar = take.appendChild(el('div', 'take-bar'));
    bar.appendChild(el('i')); kind = bar.appendChild(el('span')); clock = bar.appendChild(el('time', '', '0:00'));
    var f = bar.appendChild(el('span', 'fmts'));
    FMTS.forEach(function (x) { fmts.push(f.appendChild(el('span', '', x))); });
    var wave = take.appendChild(el('div', 'wave'));
    for (var b = 0; b < 40; b++) bars.push(wave.appendChild(el('b')));
    words = take.appendChild(el('p', 'words'));
  }
  var mode = document.getElementById('rMode'), said = document.getElementById('rSaid');

  var onscreen = true, hero = document.querySelector('.hero');
  if ('IntersectionObserver' in window && hero) new IntersectionObserver(function (es) { onscreen = es[0].isIntersecting; }).observe(hero);
  var awake = function () { return (document.hidden || !onscreen) ? wait(400).then(awake) : Promise.resolve(); };
  function lit(n) { fmts.forEach(function (s, i) { s.className = i < n ? 'done' : i === n ? 'on' : ''; }); }
  function level(on) { bars.forEach(function (x) { x.style.height = on ? (12 + Math.random() * 88) + '%' : ''; }); }

  function play(t) {
    var turns = t[1], seq = [], last = null;
    turns.forEach(function (turn, ti) { seq.push({ who: turn[0], br: ti > 0 }); turn[1].split(' ').forEach(function (w) { seq.push({ w: w }); }); });
    kind.textContent = t[0]; clock.textContent = '0:00'; words.textContent = ''; lit(-1);
    if (mode) mode.textContent = t[0];
    if (said) said.textContent = '';
    var line = '';
    function add(x) {
      if (x.who !== undefined) {
        if (x.br) words.appendChild(el('br'));
        if (x.who) words.appendChild(el('em', '', x.who));
        line = ''; return;
      }
      if (last) last.className = '';
      last = words.appendChild(el('span', 'now', x.w)); words.appendChild(document.createTextNode(' '));
      line += (line ? ' ' : '') + x.w; if (said) said.textContent = line;
    }
    if (still) { seq.forEach(add); if (last) last.className = ''; lit(FMTS.length); return Promise.resolve(); }
    take.classList.add('rec');
    var t0 = Date.now(), q = wait(500);
    seq.forEach(function (x) {
      q = q.then(awake).then(function () {
        add(x); level(true);
        var s = Math.floor((Date.now() - t0) / 1000); clock.textContent = Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
        return wait(x.w ? 150 + Math.random() * 190 : 260);
      });
    });
    return q.then(function () {
      take.classList.remove('rec'); level(false); if (last) last.className = '';
      if (said) said.textContent = t[0] === 'Hot key' ? 'Copied to the clipboard' : 'Saved to history';
      return FMTS.reduce(function (p, x, i) { return p.then(function () { lit(i); return wait(260); }); }, Promise.resolve());
    }).then(function () { lit(FMTS.length); return wait(2600); });
  }
  if (board) {
    if (still) play(TAKES[0]);
    else (function loop(i) { play(TAKES[i % TAKES.length]).then(function () { loop(i + 1); }); })(0);
  }

  // loose chips at three depths; the middle stays clear for the title
  var sky = document.getElementById('sky'), layers = [];
  if (sky) {
    var seed = 13, rnd = function () { return (seed = (seed * 16807) % 2147483647) / 2147483647; };
    var few = innerWidth < 600;
    var chips = ['You', 'Them', 'hello', 'bonjour', '.docx', '0:42', 'hola', '⌃⇧Space', '.srt', 'ciao', 'EN', 'こんにちは', '.md', 'hallo', 'FR', 'olá', '1:07', '.txt', 'JA', '你好', 'ES', 'DE'];
    var depths = [
      { cls: 'far', n: 12, size: 22, lag: .7, o: .45, tilt: 10, spin: .02 },
      { cls: 'mid', n: 9, size: 36, lag: .35, o: .75, tilt: 20, spin: .04 },
      { cls: 'near', n: 6, size: 60, lag: -.35, o: .95, tilt: 34, spin: .08 }
    ];
    depths.forEach(function (d, di) {
      var layer = sky.appendChild(el('div', 'layer ' + d.cls));
      var n = few ? (d.cls === 'near' ? 0 : Math.ceil(d.n / 2)) : d.n;
      for (var i = 0; i < n; i++) {
        // stratified: alternate sides, each chip its own slice of height, jittered so none pile up
        var side = i % 2, slot = Math.floor(i / 2), slots = Math.ceil(n / 2);
        var band = d.cls === 'far' ? 24 : 13;
        var x = side ? 96 - band + rnd() * band - 4 : 2 + rnd() * band;
        var y = 4 + (slot + .15 + rnd() * .7) * (64 / slots);
        var hot = d.cls !== 'far' && rnd() < .25;
        var c = layer.appendChild(el('span', 'chip' + (hot ? ' hot' : ''), chips[(i * 7 + di * 5 + 2) % chips.length]));
        c.style.cssText = 'left:' + x.toFixed(1) + '%;top:' + y.toFixed(1) + '%;--s:' + d.size + 'px;opacity:' + d.o + ';' +
          'animation-duration:' + (5 + rnd() * 5).toFixed(1) + 's;animation-delay:' + (-rnd() * 10).toFixed(1) + 's;--r:' + Math.round(rnd() * 30 - 15) + 'deg';
        c.dataset.spin = ((rnd() < .5 ? -1 : 1) * d.spin * (.6 + rnd() * .8)).toFixed(3);
      }
      layers.push({ layer: layer, lag: d.lag, tilt: d.tilt, chips: Array.prototype.slice.call(layer.children) });
    });
  }

  // parallax, eased toward the target each frame so a flick of the wheel glides; the copy lifts and fades
  var copy = document.querySelector('.hero-copy');
  if (still) return;
  var now = { y: scrollY, px: 0, py: 0 }, goal = { y: scrollY, px: 0, py: 0 }, running = false;
  function frame() {
    var moving = false;
    for (var k in now) { var dd = goal[k] - now[k]; now[k] = Math.abs(dd) < .05 ? goal[k] : now[k] + dd * .12; if (now[k] !== goal[k]) moving = true; }
    var y = now.y;
    if (y < innerHeight * 1.4) {
      if (ground) ground.style.transform = 'translate3d(' + (now.px * 8).toFixed(2) + 'px,' + (y * .55 + now.py * 5).toFixed(2) + 'px,0)';
      layers.forEach(function (L) {
        L.layer.style.transform = 'translate3d(' + (now.px * L.tilt).toFixed(2) + 'px,' + (y * L.lag + now.py * L.tilt * .6).toFixed(2) + 'px,0)';
        L.chips.forEach(function (c) { c.style.rotate = (y * c.dataset.spin).toFixed(2) + 'deg'; });
      });
      if (copy) { copy.style.transform = 'translate3d(0,' + (y * .2).toFixed(2) + 'px,0)'; copy.style.opacity = Math.max(0, 1 - y / (innerHeight * .7)); }
    }
    running = moving;
    if (moving) requestAnimationFrame(frame);
  }
  function kick() { if (!running) { running = true; requestAnimationFrame(frame); } }
  addEventListener('scroll', function () { goal.y = scrollY; kick(); }, { passive: true });
  if (matchMedia('(pointer: fine)').matches) addEventListener('pointermove', function (e) {
    goal.px = -(e.clientX / innerWidth - .5) * 2; goal.py = -(e.clientY / innerHeight - .5) * 2; kick();
  }, { passive: true });
})();
