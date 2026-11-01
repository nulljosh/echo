// Footer band: Echo's own things in a row (the microphone, a waveform, words landing, the keyboard, two voices, the timer), cut like a line engraving in plain 2D canvas. Faint rules
// run across the band; inside the glyphs they thicken, and thicken again on the edge facing away from the light, so the
// glyphs look cut into the page. Drawn once per size and theme. Same engine as the Hermes landing; only the glyphs differ.
(function () {
  var band = document.querySelector('.word-band'), canvas = band && band.querySelector('canvas');
  if (!canvas) return;

  // Each glyph is drawn white on a 100 unit square.
  var GLYPHS = [
    function (c) { // the microphone
      c.beginPath(); c.roundRect(37, 12, 26, 46, 13); c.fill();
      c.lineWidth = 6; c.lineCap = 'round'; c.beginPath(); c.arc(50, 44, 24, 0.15 * Math.PI, 0.85 * Math.PI); c.stroke();
      c.beginPath(); c.moveTo(50, 70); c.lineTo(50, 86); c.moveTo(36, 88); c.lineTo(64, 88); c.stroke();
    },
    function (c) { // a voice, as a waveform
      c.lineCap = 'round'; c.lineWidth = 7;
      [8, 22, 38, 54, 30, 46, 18, 10].forEach(function (h, i) { var x = 16 + i * 10; c.beginPath(); c.moveTo(x, 50 - h / 2); c.lineTo(x, 50 + h / 2); c.stroke(); });
    },
    function (c) { // words landing, line by line
      c.fillRect(14, 22, 72, 9); c.fillRect(14, 40, 58, 9); c.fillRect(14, 58, 66, 9); c.fillRect(14, 76, 30, 9); c.fillRect(48, 72, 4, 17);
    },
    function (c) { // the keyboard it lives in
      c.beginPath(); c.roundRect(10, 28, 80, 46, 7); c.fill(); c.globalCompositeOperation = 'destination-out';
      for (var r = 0; r < 2; r++) for (var k = 0; k < 6; k++) c.fillRect(16 + k * 12.3, 34 + r * 13, 9, 9);
      c.fillRect(28, 61, 44, 8);
    },
    function (c) { // you and them: two voices in turn
      c.beginPath(); c.arc(34, 38, 12, 0, 7); c.fill(); c.beginPath(); c.arc(34, 82, 22, Math.PI, 0); c.fill();
      c.lineWidth = 6; c.beginPath(); c.arc(68, 38, 11, 0, 7); c.stroke(); c.beginPath(); c.arc(68, 82, 19, Math.PI, 0); c.stroke();
    },
    function (c) { // the timer that runs while it listens
      c.lineWidth = 7; c.beginPath(); c.arc(50, 54, 32, 0, 7); c.stroke(); c.fillRect(42, 10, 16, 8);
      c.lineCap = 'round'; c.beginPath(); c.moveTo(50, 54); c.lineTo(50, 34); c.moveTo(50, 54); c.lineTo(64, 62); c.stroke();
    }
  ];
  // Lays the glyphs out evenly across a w by h 2D context, in the given colour: one row, or two on a narrow band.
  function grid(w, h) {
    var n = GLYPHS.length, rows = w < h * 3 ? 2 : 1, per = Math.ceil(n / rows);
    return { rows: rows, per: per, cell: Math.min(h / rows * 0.86, w / per) };
  }
  function paint(c, w, h, colour) {
    var g = grid(w, h), gap = (w - g.cell * g.per) / g.per, rowH = h / g.rows;
    GLYPHS.forEach(function (draw, i) {
      var col = i % g.per, row = Math.floor(i / g.per);
      c.save(); c.translate(gap / 2 + col * (g.cell + gap), row * rowH + (rowH - g.cell) / 2 + rowH * 0.04); c.scale(g.cell / 100, g.cell / 100);
      c.fillStyle = c.strokeStyle = colour; draw(c); c.restore();
    });
  }

  var ctx = canvas.getContext('2d');
  if (!ctx) return;
  function layer(w, h) { var c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  // Horizontal rules `t` px thick, one every `pitch` px, kept only where `mask` is drawn (everywhere when null).
  function rules(w, h, pitch, t, colour, mask) {
    var c = layer(w, h), x = c.getContext('2d');
    x.fillStyle = colour;
    for (var y = 0; y < h; y += pitch) x.fillRect(0, Math.round(y + (pitch - t) / 2), w, Math.max(1, Math.round(t)));
    if (mask) { x.globalCompositeOperation = 'destination-in'; x.drawImage(mask, 0, 0); }
    return c;
  }
  var drawnW = 0;
  function draw() {
    var dpr = Math.min(window.devicePixelRatio || 1, 2), w = Math.round(canvas.clientWidth * dpr), h = Math.round(canvas.clientHeight * dpr);
    if (!w || !h) return;
    drawnW = w; canvas.width = w; canvas.height = h;
    var colour = getComputedStyle(band).color, pitch = Math.min(5 * dpr, Math.max(3 * dpr, grid(w, h).cell / 22)), s = Math.max(2, h * 0.014);
    var glyphs = layer(w, h); paint(glyphs.getContext('2d'), w, h, '#fff');
    // the shadow side: glyph pixels whose neighbour down and right is outside the glyph (light from the top left)
    var shade = layer(w, h), sc = shade.getContext('2d');
    sc.drawImage(glyphs, 0, 0); sc.globalCompositeOperation = 'destination-out'; sc.drawImage(glyphs, -s, -s);
    ctx.globalAlpha = 0.28; ctx.drawImage(rules(w, h, pitch, dpr * 0.75, colour, null), 0, 0);
    ctx.globalAlpha = 1; ctx.drawImage(rules(w, h, pitch, pitch * 0.32, colour, glyphs), 0, 0);
    ctx.drawImage(rules(w, h, pitch, pitch * 0.6, colour, shade), 0, 0);
    // fade out toward the legal line
    var g = ctx.createLinearGradient(0, h * 0.88, 0, h);
    g.addColorStop(0, '#000'); g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.globalCompositeOperation = 'destination-in'; ctx.fillStyle = g; ctx.fillRect(0, 0, w, h);
    ctx.globalCompositeOperation = 'source-over';
  }
  band.classList.add('live');
  draw();
  // iOS fires resize as the toolbar slides; only a width change needs a redraw
  window.addEventListener('resize', function () { if (Math.round(canvas.clientWidth * Math.min(window.devicePixelRatio || 1, 2)) !== drawnW) draw(); });
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', draw);
})();
