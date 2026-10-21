/*
 * أذان ليبيا — web prayer-call engine.
 *
 * Loaded from index.html BEFORE Flutter boots, so as soon as the page/PWA is
 * opened the saved schedule is active again (no need to wait for Flutter).
 *
 *  - Ticks every second from a Web Worker (not throttled like main-thread
 *    timers in background tabs).
 *  - At prayer time: plays audio/azan.mp3, shows a system notification with a
 *    "إيقاف الأذان" button (via service worker), an in-page stop banner, and
 *    Media Session controls (lock screen / notification shade pause button).
 *  - Browsers cannot wake a closed page, so this works while the site is open
 *    in a tab or installed as an app (foreground or background).
 *
 * Public API (window.AzanWeb): permission, requestPermission, schedule,
 * cancel, stop, test.
 */
(function () {
  'use strict';

  var STORE_ITEMS = 'azan-libya:web-items:v1';
  var STORE_FIRED = 'azan-libya:web-fired:v1';
  var MAX_LATE_MS = 10 * 60 * 1000;
  var TAG = 'azan-prayer';

  var items = [];
  var audio = null;
  var primed = false;
  var worker = null;
  var fallbackTimer = null;
  var swReg = null;
  var banner = null;
  var channel = null;

  function base(path) {
    return new URL(path, document.baseURI).href;
  }

  // ---------------------------------------------------------------- storage
  function readJson(key, fallback) {
    try {
      var raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : fallback;
    } catch (e) {
      return fallback;
    }
  }
  function writeJson(key, value) {
    try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* ignore */ }
  }
  function itemKey(it) { return it.id + ':' + it.time; }

  // ------------------------------------------------------------------ audio
  function ensureAudio() {
    if (audio) return audio;
    audio = new Audio(base('audio/azan.mp3'));
    audio.preload = 'auto';
    audio.addEventListener('ended', function () { stop(true); });
    return audio;
  }

  // Browsers only allow scripted playback after a user gesture; "prime" the
  // element on the first tap/click/key so prayer-time playback is allowed.
  function prime() {
    if (primed) return;
    primed = true;
    try {
      var a = ensureAudio();
      a.muted = true;
      var p = a.play();
      var done = function () { a.pause(); a.currentTime = 0; a.muted = false; };
      if (p && p.then) { p.then(done, function () { a.muted = false; primed = false; }); }
      else { done(); }
    } catch (e) { primed = false; }
  }
  ['pointerdown', 'touchstart', 'click', 'keydown'].forEach(function (ev) {
    window.addEventListener(ev, prime, { once: true, passive: true, capture: true });
  });

  function playAudio() {
    try {
      var a = ensureAudio();
      a.muted = false;
      a.currentTime = 0;
      var p = a.play();
      if (p && p.then) return p.then(function () { return true; }, function () { return false; });
      return Promise.resolve(true);
    } catch (e) {
      return Promise.resolve(false);
    }
  }

  // ---------------------------------------------------------- service worker
  function registerSw() {
    if (!('serviceWorker' in navigator)) return Promise.resolve(null);
    if (swReg) return Promise.resolve(swReg);
    // Own scope so it never collides with Flutter's service worker.
    return navigator.serviceWorker
      .register(base('azan_sw.js'), { scope: base('azan-notifications/') })
      .then(function () { return navigator.serviceWorker.ready.catch(function () { return null; }); })
      .then(function () { return navigator.serviceWorker.getRegistration(base('azan-notifications/')); })
      .then(function (reg) { swReg = reg || null; return swReg; })
      .catch(function () { return null; });
  }

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (e) {
      if (e.data && e.data.type === 'azan-stop') stop(false);
    });
  }
  try {
    channel = new BroadcastChannel('azan-libya');
    channel.onmessage = function (e) { if (e.data === 'stop') stop(false); };
  } catch (e) { channel = null; }

  // ----------------------------------------------------------- notifications
  function permission() {
    if (typeof Notification === 'undefined') return 'unsupported';
    return Notification.permission;
  }

  function requestPermission() {
    prime();
    registerSw();
    if (typeof Notification === 'undefined') return Promise.resolve('unsupported');
    if (Notification.permission !== 'default') return Promise.resolve(Notification.permission);
    try {
      var r = Notification.requestPermission(function () {});
      if (r && r.then) return r;
    } catch (e) { /* old callback-only API */ }
    return new Promise(function (resolve) { Notification.requestPermission(resolve); });
  }

  function showNotification(item, audioPlaying) {
    if (permission() !== 'granted') return Promise.resolve();
    var options = {
      body: item.body,
      icon: base('icons/icon-192.png'),
      badge: base('icons/icon-192.png'),
      tag: TAG,
      renotify: true,
      requireInteraction: true,
      dir: 'rtl',
      lang: 'ar',
      // We play our own audio; only let the OS make a sound if ours is blocked
      // and the user did not ask for silent mode.
      silent: !(item.sound && !audioPlaying),
      vibrate: item.sound ? [250, 180, 250] : undefined,
      actions: audioPlaying ? [{ action: 'stop', title: 'إيقاف الأذان' }] : [],
      data: { time: item.time }
    };
    return registerSw().then(function (reg) {
      if (reg && reg.showNotification) return reg.showNotification(item.title, options);
      delete options.actions;
      var n = new Notification(item.title, options);
      n.onclick = function () { window.focus(); n.close(); };
    }).catch(function () {
      try { delete options.actions; new Notification(item.title, options); } catch (e) { /* ignore */ }
    });
  }

  function closeNotifications() {
    if (!swReg || !swReg.getNotifications) return;
    swReg.getNotifications({ tag: TAG }).then(function (list) {
      list.forEach(function (n) { n.close(); });
    }).catch(function () {});
  }

  // ------------------------------------------------------------------ banner
  function showBanner(item) {
    hideBanner();
    var el = document.createElement('div');
    el.setAttribute('dir', 'rtl');
    el.setAttribute('role', 'alert');
    el.style.cssText = 'position:fixed;left:12px;right:12px;bottom:12px;z-index:2147483647;' +
      'display:flex;align-items:center;gap:12px;padding:14px 16px;border-radius:16px;' +
      'background:#16382f;color:#fff;box-shadow:0 8px 30px rgba(0,0,0,.35);' +
      'font:600 15px/1.5 "NotoSansArabic",system-ui,sans-serif';
    var text = document.createElement('div');
    text.style.flex = '1';
    text.textContent = item.title;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = 'إيقاف الأذان';
    btn.style.cssText = 'border:0;border-radius:12px;padding:10px 16px;background:#fff;color:#16382f;' +
      'font:700 14px "NotoSansArabic",system-ui,sans-serif;cursor:pointer';
    btn.addEventListener('click', function () { stop(true); });
    el.appendChild(text);
    el.appendChild(btn);
    document.body.appendChild(el);
    banner = el;
  }
  function hideBanner() {
    if (banner && banner.parentNode) banner.parentNode.removeChild(banner);
    banner = null;
  }

  // ------------------------------------------------------------ media session
  function setMediaSession(item) {
    if (!('mediaSession' in navigator)) return;
    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: item.title,
        artist: 'أذان ليبيا',
        artwork: [{ src: base('icons/icon-512.png'), sizes: '512x512', type: 'image/png' }]
      });
      navigator.mediaSession.playbackState = 'playing';
      ['pause', 'stop'].forEach(function (a) {
        navigator.mediaSession.setActionHandler(a, function () { stop(true); });
      });
    } catch (e) { /* ignore */ }
  }
  function clearMediaSession() {
    if (!('mediaSession' in navigator)) return;
    try {
      navigator.mediaSession.playbackState = 'none';
      navigator.mediaSession.metadata = null;
    } catch (e) { /* ignore */ }
  }

  // -------------------------------------------------------------------- fire
  function fire(item) {
    var playing = item.sound ? playAudio() : Promise.resolve(false);
    return playing.then(function (ok) {
      if (ok) { setMediaSession(item); }
      showBanner(item);
      return showNotification(item, ok).then(function () {
        if (!ok) { /* silent mode or blocked: keep the banner a while only */
          setTimeout(hideBanner, 60 * 1000);
        }
      });
    });
  }

  function stop(broadcast) {
    try {
      if (audio) { audio.pause(); audio.currentTime = 0; }
    } catch (e) { /* ignore */ }
    hideBanner();
    clearMediaSession();
    closeNotifications();
    if (broadcast && channel) { try { channel.postMessage('stop'); } catch (e) { /* ignore */ } }
  }

  // -------------------------------------------------------------------- tick
  function tick() {
    if (!items.length) return;
    var now = Date.now();
    var fired = readJson(STORE_FIRED, {});
    var dirty = false;
    items.forEach(function (it) {
      var key = itemKey(it);
      if (it.time <= now && !fired[key]) {
        fired[key] = now;
        dirty = true;
        if (now - it.time <= MAX_LATE_MS) fire(it);
      }
    });
    if (dirty) {
      Object.keys(fired).forEach(function (k) {
        if (now - fired[k] > 2 * 24 * 3600 * 1000) delete fired[k];
      });
      writeJson(STORE_FIRED, fired);
    }
  }

  function startTicking() {
    if (worker || fallbackTimer) return;
    try {
      var blob = new Blob(['setInterval(function(){postMessage(1)},1000)'], { type: 'text/javascript' });
      worker = new Worker(URL.createObjectURL(blob));
      worker.onmessage = tick;
      worker.onerror = function () { worker = null; startFallback(); };
    } catch (e) {
      startFallback();
    }
  }
  function startFallback() {
    if (!fallbackTimer) fallbackTimer = setInterval(tick, 1000);
  }
  function stopTicking() {
    if (worker) { try { worker.terminate(); } catch (e) { /* ignore */ } worker = null; }
    if (fallbackTimer) { clearInterval(fallbackTimer); fallbackTimer = null; }
  }
  document.addEventListener('visibilitychange', function () { if (!document.hidden) tick(); });
  window.addEventListener('focus', tick);
  window.addEventListener('pageshow', tick);

  // --------------------------------------------------------------- public API
  function schedule(json) {
    var list = typeof json === 'string' ? JSON.parse(json) : json;
    var now = Date.now();
    items = list.filter(function (it) { return it.time > now - MAX_LATE_MS; });
    writeJson(STORE_ITEMS, items);
    if (items.length) startTicking(); else stopTicking();
    registerSw();
    return items.length;
  }

  function cancel() {
    items = [];
    writeJson(STORE_ITEMS, []);
    stopTicking();
    stop(true);
  }

  function test(json) {
    var it = typeof json === 'string' ? JSON.parse(json) : json;
    it.time = Date.now();
    prime();
    return fire(it);
  }

  // Restore the saved schedule immediately on page load.
  items = readJson(STORE_ITEMS, []);
  if (items.length) { startTicking(); registerSw(); }

  window.AzanWeb = {
    permission: permission,
    requestPermission: requestPermission,
    schedule: schedule,
    cancel: cancel,
    stop: function () { stop(true); },
    test: test
  };
})();
