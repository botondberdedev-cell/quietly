/* SPDX-License-Identifier: MIT
 * Shows one explicitly selected post in an isolated WKContentWorld.
 * If the post cannot be identified, keep it hidden rather than exposing a feed.
 */
(() => {
  "use strict";
  if (location.protocol !== "https:" || !["instagram.com", "www.instagram.com"].includes(location.hostname) || window.top !== window) return;
  const expected = window.__quietlyOptions?.singlePostID;
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(expected || "") || window.__quietlySingleInstalled) return;
  window.__quietlySingleInstalled = true;
  let chosen = null;
  let stopped = false;
  let lastState = "";
  let timedOut = false;

  function report(state) {
    if (state === lastState) return;
    lastState = state;
    try { window.webkit?.messageHandlers?.quietly?.postMessage({ type: "postState", state }); } catch (_) {}
  }
  function postID(url) {
    if (url.protocol !== "https:" || !["instagram.com", "www.instagram.com"].includes(url.hostname)) return null;
    return url.pathname.match(/^\/(?:[a-zA-Z0-9._]+\/)?(?:p|reel|reels)\/([A-Za-z0-9_-]{1,64})\/?$/)?.[1] || null;
  }
  function idForLink(link) {
    try { return postID(new URL(link.getAttribute("href"), location.href)); } catch (_) { return null; }
  }
  const style = document.createElement("style");
  style.id = "quietly-single-styles";
  style.textContent = `
    html body, html body * { visibility: hidden !important; }
    html [data-quietly-selected], html [data-quietly-selected] * { visibility: visible !important; }
    html [data-quietly-pruned] { display: none !important; }
    html [data-quietly-path], html [data-quietly-selected] {
      overflow: visible !important; height: auto !important; max-height: none !important;
      scroll-snap-type: none !important; transform: none !important;
    }
  `;
  function refresh() {
    if (!document.documentElement) return;
    if (!style.isConnected) document.documentElement.append(style);
    const routeMatches = postID(new URL(location.href)) === expected;
    const candidates = [...document.querySelectorAll("article")];
    const card = routeMatches && candidates.find(article => {
      const ids = [...article.querySelectorAll("a[href]")].map(idForLink).filter(Boolean);
      return ids.includes(expected) && ids.every(id => id === expected);
    });
    // Clear the old card before considering a recycled article or a new route.
    document.querySelectorAll("[data-quietly-selected]").forEach(node => {
      if (node !== card) node.removeAttribute("data-quietly-selected");
    });
    document.querySelectorAll("[data-quietly-pruned], [data-quietly-path]").forEach(node => {
      node.removeAttribute("data-quietly-pruned");
      node.removeAttribute("data-quietly-path");
    });
    chosen = card || null;
    if (chosen && !stopped) {
      chosen.setAttribute("data-quietly-selected", "true");
      // Hide each sibling along the path to body: navigation and next posts vanish.
      let branch = chosen;
      while (branch.parentElement) {
        const parent = branch.parentElement;
        for (const sibling of parent.children) {
          if (sibling !== branch && !["STYLE", "SCRIPT", "HEAD"].includes(sibling.tagName)) {
            sibling.setAttribute("data-quietly-pruned", "true");
          }
        }
        parent.setAttribute("data-quietly-path", "true");
        if (parent === document.body) break;
        branch = parent;
      }
      report("ready");
    } else {
      chosen?.removeAttribute("data-quietly-selected");
      report(!routeMatches || timedOut || stopped ? "unavailable" : "loading");
    }
    document.querySelectorAll("video").forEach(video => {
      if (stopped || !chosen?.contains(video)) video.pause();
    });
  }
  // Same-post links can select carousel images. Other destinations stay blocked.
  document.addEventListener("click", event => {
    const link = event.target instanceof Element ? event.target.closest("a[href]") : null;
    if (link && idForLink(link) !== expected) { event.preventDefault(); event.stopImmediatePropagation(); }
  }, true);
  document.addEventListener("play", event => {
    if (stopped || postID(new URL(location.href)) !== expected || !chosen?.contains(event.target)) event.target.pause?.();
  }, true);
  window.__quietlyPause = () => { stopped = true; refresh(); };
  new MutationObserver(refresh).observe(document, {
    childList: true, subtree: true, attributes: true, attributeFilter: ["href", "src"]
  });
  window.addEventListener("popstate", refresh);
  let path = location.pathname;
  setInterval(() => {
    if (path !== location.pathname) { path = location.pathname; refresh(); }
  }, 100);
  setTimeout(() => { timedOut = true; refresh(); }, 8000);
  refresh();
})();
