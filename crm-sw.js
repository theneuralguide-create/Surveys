/* Personal CRM — service worker.
   Caches ONLY the app shell so the app opens instantly and still loads
   with no signal. Strategy is network-first with cache fallback, so a
   change you deploy shows up on the next open instead of a week later.
   Supabase API calls are never touched. Bump CACHE_VERSION on changes. */
var CACHE_VERSION = 'crm-shell-v1';
var SHELL = [
  './crm.html', './crm.css', './hub.css',
  './manifest.webmanifest',
  './icons/crm-180.png', './icons/crm-192.png', './icons/crm-512.png'
];

self.addEventListener('install', function(e){
  e.waitUntil(
    caches.open(CACHE_VERSION)
      .then(function(c){ return c.addAll(SHELL); })
      .then(function(){ return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function(e){
  e.waitUntil(
    caches.keys().then(function(keys){
      return Promise.all(keys.filter(function(k){ return k !== CACHE_VERSION; })
        .map(function(k){ return caches.delete(k); }));
    }).then(function(){ return self.clients.claim(); })
  );
});

function isShell(url){
  var u = new URL(url);
  if (u.origin !== self.location.origin) return false;
  var here = new URL('./', self.location.href).pathname;
  var path = u.pathname.replace(here, './');
  if (path === './' || path === '.') path = './crm.html';
  return SHELL.indexOf(path) !== -1;
}

self.addEventListener('fetch', function(e){
  if (e.request.method !== 'GET' || !isShell(e.request.url)) return;  /* pass through */
  e.respondWith(
    fetch(e.request).then(function(res){
      if (res && res.ok){
        var copy = res.clone();
        caches.open(CACHE_VERSION).then(function(c){ c.put(e.request, copy); });
      }
      return res;
    }).catch(function(){
      return caches.match(e.request, { ignoreSearch: true });
    })
  );
});
