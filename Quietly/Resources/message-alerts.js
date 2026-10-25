(() => {
  "use strict";
  if (location.protocol !== "https:" || !["www.instagram.com", "instagram.com"].includes(location.hostname)
      || location.port || window.top !== window) return;
  let previous, timer, stopped = false;
  const normalize = value => (value || "").normalize("NFKC").replace(/\s+/g, " ").trim();
  const countFrom = value => {
    const text = normalize(value);
    // Accept exact badges or explicit unread labels, never arbitrary page numbers.
    const match = text.match(/^(\d{1,3})\+?$/)
      || text.match(/^(\d{1,3})\+? (?:unread messages?|mensajes? sin leer|mensajes? no le[ií]dos?)$/i)
      || text.match(/^(?:messages?|mensajes?)\s*[,:(]?\s*(\d{1,3})\+?\)?$/i);
    return match ? Math.min(999, Number(match[1])) : null;
  };
  function count() {
    if (document.hidden || /^\/(accounts|challenge)\//.test(location.pathname)) return null;
    const values = [];
    for (const link of document.querySelectorAll('a[href]')) {
      let url;
      try { url = new URL(link.getAttribute("href"), location.href); } catch { continue; }
      if (url.origin !== location.origin || !/^\/direct\/inbox\/?$/.test(url.pathname)
          || link.closest('article, main article, [role="dialog"]')) continue;
      if (!link.getClientRects().length || getComputedStyle(link).visibility === "hidden") continue;
      const counts = [];
      for (const node of [link, ...link.querySelectorAll('[aria-label], span, div')]) {
        if (!node.getClientRects().length || getComputedStyle(node).visibility === "hidden") continue;
        for (const value of [node.getAttribute("aria-label"), node.textContent]) {
          const n = countFrom(value);
          if (n !== null) counts.push(n);
        }
      }
      if (counts.length) values.push(Math.max(...counts));
      else {
        const labels = [link.textContent, link.getAttribute("aria-label"),
          ...Array.from(link.querySelectorAll('svg title, svg[aria-label]'), n => n.textContent || n.getAttribute("aria-label"))];
        // A missing or unfamiliar indicator is unknown, not an invented zero.
        if (labels.some(value => /^(messages?|mensajes?|messenger|direct)$/i.test(normalize(value)))) values.push(0);
      }
    }
    // Duplicate mobile/desktop navs are not separate unread messages.
    return values.length ? Math.max(...values) : null;
  }
  function report() {
    clearTimeout(timer);
    timer = null;
    if (stopped) return;
    const value = count();
    if (value === previous) return;
    previous = value;
    window.webkit?.messageHandlers?.quietly?.postMessage({ type: "inboxCount", count: value === null ? "unknown" : String(value) });
  }
  function schedule() {
    // Throttle, don't debounce forever on animation-heavy pages.
    if (!timer && !stopped) timer = setTimeout(() => { timer = null; report(); }, 600);
  }
  const observer = new MutationObserver(schedule);
  function start() {
    observer.observe(document.documentElement, { subtree: true, childList: true, characterData: true,
      attributes: true, attributeFilter: ["aria-label", "href", "hidden", "class", "style"] });
    schedule();
  }
  document.addEventListener("visibilitychange", () => {
    previous = undefined;
    report();
  });
  window.__quietlyStopMessageAlerts = () => { stopped = true; clearTimeout(timer); observer.disconnect(); };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
