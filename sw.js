const CACHE="lexaa-pwa-v10";
const SHELL=["/","/index.html","/manifest.webmanifest","/lexaa-icon.svg","/saldo.html","/wallet-register.html","/topup.html"];
self.addEventListener("install",event=>{event.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",event=>{
 const req=event.request;if(req.method!=="GET"||new URL(req.url).origin!==self.location.origin)return;
 event.respondWith(fetch(req).then(res=>{if(res&&res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(req,copy))}return res}).catch(()=>caches.match(req).then(hit=>hit||caches.match("/index.html"))));
});