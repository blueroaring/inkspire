/* Private gameplay snapshots; never send a nickname, save or public score. */
(() => {
  const key = 'inkspire.private-telemetry.v1';
  const endpoint = '/api/telemetry';
  let enabled = false, queue = {}, pending = new Set();
  try { const value = JSON.parse(localStorage.getItem(key) || '{}'); if (value && typeof value === 'object' && !Array.isArray(value)) queue = value; } catch {}
  for (const [i,id] of Object.keys(queue).entries()) if (i >= 8 || typeof queue[id] !== 'string' || new Blob([queue[id]]).size > 48000) delete queue[id];
  function persist() { try { localStorage.setItem(key, JSON.stringify(queue)); } catch {} }
  function flush(unloading = false) {
    if (!enabled || pending.size) return;
    // One bounded body fits the browser's shared 64 KiB keepalive budget.
    const id = Object.keys(queue).find(id => !pending.has(id));
    if (!id) return;
    const body = queue[id];
    if (unloading && navigator.sendBeacon) {
      navigator.sendBeacon(endpoint, new Blob([body], {type: 'application/json'}));
      return; // Beacon only acknowledges queuing; keep it until a later HTTP ACK.
    }
    pending.add(id);
    let acknowledged = false;
    fetch(endpoint, {method:'POST', headers:{'Content-Type':'application/json'}, body, keepalive:true, credentials:'omit', redirect:'error'})
      .then(response => { acknowledged = response.ok; if (response.ok && queue[id] === body) { delete queue[id]; persist(); } })
      .catch(() => {})
      .finally(() => { pending.delete(id); if (acknowledged) flush(); });
  }
  window.inkspireTelemetry = {
    configure(value) { enabled = value === true; if (!enabled) { queue = {}; persist(); } },
    stage(id, body) { if (!enabled || typeof body !== 'string' || new Blob([body]).size > 48000) return; if (!(id in queue) && Object.keys(queue).length >= 8) delete queue[Object.keys(queue)[0]]; queue[id] = body; persist(); },
    flush() { flush(); }
  };
  window.addEventListener('pagehide', () => flush(true));
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') flush(true); });
})();
