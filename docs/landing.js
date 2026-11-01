// Fade sections up as they scroll in. Nothing here is needed to read the page.
(function () {
  document.documentElement.classList.add('js');
  var els = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) { els.forEach(function (e) { e.classList.add('in'); }); return; }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
  }, { rootMargin: '0px 0px -8% 0px' });
  els.forEach(function (e) { io.observe(e); });
})();

// Hero wall: Echo's own live view, run on a script. Each card "hears" a line and writes it word by word, holds, then starts the next.
(function () {
  var wall = document.getElementById('wall'); if (!wall) return;
  var LINES = [
    ['Meeting', [['You', 'Can we move the launch to Thursday?'], ['Them', 'Thursday works. I will tell the team tonight.']]],
    ['Memo', [['', 'Pick up milk, call the dentist, and send Sam the photos from Saturday.']]],
    ['Live', [['', 'Bonjour, je voudrais un café et un croissant, s’il vous plaît.']]],
    ['Lecture', [['', 'Photosynthesis turns light, water and carbon dioxide into sugar and oxygen.']]],
    ['Meeting', [['Them', 'What did the numbers look like last week?'], ['You', 'Up nine percent, mostly from the new signups.']]],
    ['Idea', [['', 'App idea: a tide clock for the kayak club. One screen, no login.']]],
    ['File', [['', 'Interview, part two. She started the bakery in 1998 with one oven.']]],
    ['Memo', [['', 'Remember the parking is on level three, row F, near the elevator.']]],
    ['Live', [['', 'Hola, ¿a qué hora sale el próximo tren a Madrid?']]]
  ];
  var n = matchMedia('(max-width: 560px)').matches ? 3 : matchMedia('(max-width: 900px)').matches ? 6 : 9;
  var still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  function card(i) {
    var el = document.createElement('div'); el.className = 'tr';
    el.innerHTML = '<div class="tr-head"><i></i><span></span><time>0:00</time></div><div class="tr-wave">' + new Array(29).join('<b></b>') + '</div><p class="tr-text"></p>';
    wall.appendChild(el);
    var head = el.querySelector('.tr-head span'), clock = el.querySelector('time'), text = el.querySelector('.tr-text'), bars = el.querySelectorAll('.tr-wave b');
    var k = i;
    function play() {
      var item = LINES[k % LINES.length], turns = item[1], secs = 0; k += n;
      head.textContent = item[0]; text.textContent = ''; el.classList.add('live');
      var words = [];
      turns.forEach(function (t, ti) { words.push({ who: t[0], br: ti > 0 }); t[1].split(' ').forEach(function (w) { words.push({ w: w }); }); });
      if (still) { words.forEach(add); el.classList.remove('live'); return; }
      var tick = setInterval(function () { secs++; clock.textContent = '0:' + String(secs).padStart(2, '0'); }, 1000);
      var j = 0;
      (function next() {
        if (j >= words.length) {
          clearInterval(tick); el.classList.remove('live'); bars.forEach(function (b) { b.style.height = ''; });
          return setTimeout(play, 2600 + Math.random() * 1800);
        }
        add(words[j++]);
        bars.forEach(function (b) { b.style.height = (15 + Math.random() * 85) + '%'; });
        setTimeout(next, 150 + Math.random() * 190);
      })();
    }
    function add(x) {
      if (x.who !== undefined) { if (x.br) text.appendChild(document.createElement('br')); if (x.who) { var e = document.createElement('em'); e.textContent = x.who; text.appendChild(e); } return; }
      var s = document.createElement('span'); s.textContent = x.w + ' '; text.appendChild(s);
    }
    setTimeout(play, i * 700);
  }
  for (var i = 0; i < n; i++) card(i);
})();

// Hero parallax: the wall drifts at 0.45, the copy lifts at 0.2 and fades. Off under reduced motion.
(function () {
  var bg = document.querySelector('.hero-bg'), copy = document.querySelector('.hero-copy');
  if (!bg || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  var t = 0;
  addEventListener('scroll', function () {
    if (t) return;
    t = requestAnimationFrame(function () {
      t = 0; var y = scrollY, h = innerHeight; if (y > h * 1.2) return;
      bg.style.setProperty('--py', (y * .45) + 'px');
      copy.style.transform = 'translate3d(0,' + (y * .2) + 'px,0)'; copy.style.opacity = Math.max(0, 1 - y / (h * .7));
    });
  }, { passive: true });
})();
