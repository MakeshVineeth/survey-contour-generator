// Loading indicator + offline service worker. Kept in a file (no inline
// scripts) so the strict Content-Security-Policy in index.html applies.

(function () {
  var ready = false;
  var callbacks = [];

  // Runs [cb] once the Flutter app has painted (or immediately if it has).
  function onAppReady(cb) {
    if (ready) cb(); else callbacks.push(cb);
  }

  function markReady() {
    if (ready) return;
    ready = true;
    var boot = document.getElementById('boot');
    if (boot) {
      boot.classList.add('done');
      setTimeout(function () { boot.remove(); }, 250);
    }
    callbacks.splice(0).forEach(function (cb) { cb(); });
  }

  // Older engines dispatch this event; newer ones do not.
  window.addEventListener('flutter-first-frame', markReady, { once: true });

  // Otherwise: the <flutter-view> host appears, then wait two frames to paint.
  function afterPaint() {
    requestAnimationFrame(function () { requestAnimationFrame(markReady); });
    // Animation frames are paused in background tabs; never leave the splash up.
    setTimeout(markReady, 700);
  }
  if (document.querySelector('flutter-view')) {
    afterPaint();
  } else {
    var observer = new MutationObserver(function () {
      if (document.querySelector('flutter-view')) {
        observer.disconnect();
        afterPaint();
      }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  }

  // Offline support: custom service worker (see sw.js).
  if (!('serviceWorker' in navigator)) return;

  function hashString(s) {
    var h = 2166136261;
    for (var i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  // Which app bundle did this browser load? The service worker then precaches only that one
  // (the Wasm and the JS fallback bundles are never both needed by the same browser).
  function loadedBuild() {
    var names = performance.getEntriesByType('resource').map(function (e) { return e.name; });
    var has = function (re) { return names.some(function (n) { return re.test(n); }); };
    if (has(/\/main\.dart\.[0-9a-f]+\.wasm(\?|$)/)) return 'wasm';
    if (has(/\/main\.dart\.[0-9a-f]+\.js(\?|$)/)) return 'js';
    return '';
  }

  // sw.js is byte-identical across builds, so the browser would never install a
  // new worker after a deploy. Registering it under a per-build URL (derived from
  // the precache manifest) makes every new build install and precache itself.
  // Offline, the manifest fetch fails and the existing registration stays as is.
  function registerWorker() {
    var build = loadedBuild();
    return fetch('precache_manifest.json', { cache: 'no-store' })
      .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
      .then(function (text) {
        var url = 'sw.js?v=' + hashString(text) + (build ? '&b=' + build : '');
        return navigator.serviceWorker.register(url);
      }, function () {
        return navigator.serviceWorker.getRegistration();
      });
  }

  // Installing the worker downloads the whole precache. Start it only once the app is on
  // screen (and the browser is idle) so it never competes with the engine for bandwidth.
  onAppReady(function () {
    var start = function () {
      registerWorker().then(function () {
        // Let the worker cache the engine files (canvaskit/**) this browser loaded.
        navigator.serviceWorker.ready.then(function (r) {
          var urls = performance.getEntriesByType('resource')
            .map(function (e) { return e.name; })
            .filter(function (u) { return u.indexOf('/canvaskit/') !== -1; });
          if (r.active && urls.length) r.active.postMessage({ type: 'cache-urls', urls: urls });
        });
      }).catch(function () { /* offline caching is optional */ });
    };
    if (window.requestIdleCallback) window.requestIdleCallback(start, { timeout: 2000 });
    else setTimeout(start, 500);
  });
})();
