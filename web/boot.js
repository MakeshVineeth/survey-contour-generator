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

  // sw.js is byte-identical across builds, so the browser would never install a
  // new worker after a deploy. Registering it under a per-build URL (derived from
  // the precache manifest) makes every new build install and precache itself.
  // Offline, the manifest fetch fails and the existing registration stays as is.
  function registerWorker() {
    return fetch('precache_manifest.json', { cache: 'no-store' })
      .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
      .then(function (text) {
        return navigator.serviceWorker.register('sw.js?v=' + hashString(text));
      }, function () {
        return navigator.serviceWorker.getRegistration();
      });
  }

  window.addEventListener('load', function () {
    registerWorker().then(function () {
      // Let the worker cache the engine files (canvaskit/**) this browser loaded.
      onAppReady(function () {
        navigator.serviceWorker.ready.then(function (r) {
          var urls = performance.getEntriesByType('resource')
            .map(function (e) { return e.name; })
            .filter(function (u) { return u.indexOf('/canvaskit/') !== -1; });
          if (r.active && urls.length) r.active.postMessage({ type: 'cache-urls', urls: urls });
        });
      });
    }).catch(function () { /* offline caching is optional */ });
  });
})();
