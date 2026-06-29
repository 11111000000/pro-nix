// pro-nix site — minimal vanilla JS
(function(){
  'use strict';

  // Theme toggle (light/dark)
  var root = document.documentElement;
  var KEY  = 'pro-nix-theme';
  var pref = (function(){ try { return localStorage.getItem(KEY); } catch(e){ return null; } })();
  if (pref === 'light' || pref === 'dark') {
    root.dataset.theme = pref;
  } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
    root.dataset.theme = 'light';
  } else {
    root.dataset.theme = 'dark';
  }
  document.addEventListener('click', function(e){
    var t = e.target.closest('.theme-toggle');
    if (!t) return;
    var next = root.dataset.theme === 'light' ? 'dark' : 'light';
    root.dataset.theme = next;
    try { localStorage.setItem(KEY, next); } catch(_){}
  });

  // Language switch — remember
  document.addEventListener('click', function(e){
    var s = e.target.closest('.lang-switch');
    if (!s) return;
    try {
      var m = s.getAttribute('href').match(/^\/(en|ru)\//);
      if (m) localStorage.setItem('pro-nix-lang', m[1]);
    } catch(_){}
  });

  // Copy button for <pre> blocks
  document.addEventListener('click', function(e){
    var b = e.target.closest('pre');
    if (!b) return;
    if (b.querySelector('.copy-btn')) return;
    var btn = document.createElement('button');
    btn.className = 'copy-btn';
    btn.textContent = 'copy';
    btn.title = 'Copy to clipboard';
    btn.addEventListener('click', function(ev){
      ev.stopPropagation();
      var txt = b.innerText.replace(/^copy\s*/, '');
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(txt).then(function(){
          btn.textContent = 'copied'; setTimeout(function(){ btn.textContent = 'copy'; }, 1200);
        });
      }
    });
    b.style.position = 'relative';
    b.appendChild(btn);
  });

  // Search — Enter on input
  var input = document.querySelector('.search input');
  if (input) {
    input.addEventListener('keydown', function(e){
      if (e.key === 'Enter') {
        var q = input.value.trim();
        if (!q) return;
        var path = window.location.pathname;
        var lang = /^\/en\//.test(path) ? 'en' : 'ru';
        // Map to /reference/glossary (no fuzzy search engine needed)
        var target = '/' + lang + '/reference/glossary/?q=' + encodeURIComponent(q);
        window.location.href = target;
      }
    });
  }

  // Active-link highlight (in case CSS attribute selectors don't catch all)
  var path = window.location.pathname;
  document.querySelectorAll('.sidebar a, .main-nav a').forEach(function(a){
    var href = a.getAttribute('href') || '';
    if (href && path.indexOf(href.replace(/^https?:\/\/[^/]+/, '')) === 0) {
      a.classList.add('active');
    }
  });
})();
