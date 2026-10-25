/* SPDX-License-Identifier: MIT
 * Runs only in Quietly's isolated WKContentWorld on Instagram's main frame.
 * Uses URL/element structure, never password fields or message contents.
 */
(() => {
  "use strict";
  if (!["instagram.com", "www.instagram.com"].includes(location.hostname) ||
      location.protocol !== "https:" || window.top !== window) return;
  if (window.__quietlyInstalled) return;
  window.__quietlyInstalled = true;

  const options = Object.assign({ blockReels: true, blockExplore: true, hideAds: true, feedMode: "following", postLimit: 12, friendUsernames: [] }, window.__quietlyOptions || {});
  const friends = new Set(options.friendUsernames.map(name => name.toLowerCase()));
  options.postLimit = Math.min(30, Math.max(3, Number(options.postLimit) || 12));
  let lastPath = "";
  let lastReport = "";
  let scheduled = false;
  let nextPostIndex = 0;
  let unknownPostID = 0;
  const posts = new Map();
  const unknownPosts = new WeakMap();
  let stopped = false;
  let followingRequested = false;
  const handedOffViewers = new WeakSet();
  let inlineViewer = null;
  let touchStart = null;
  let verticalDrag = false;

  function report(body) {
    try { window.webkit?.messageHandlers?.quietly?.postMessage(body); } catch (_) {}
  }
  function reasonFor(url) {
    if (url.protocol !== "https:" || !["instagram.com", "www.instagram.com"].includes(url.hostname)) return null;
    let route = url.pathname;
    try { route = decodeURIComponent(route); } catch (_) {}
    const parts = route.split("/").filter(Boolean);
    const first = parts[0]?.toLowerCase();
    if (options.blockReels && (["reel", "reels"].includes(first) || parts[1] === "reel")) return "Reels are paused";
    if (options.blockExplore && first === "explore") return "Explore is paused";
    return null;
  }
  function hrefURL(link) {
    try { return new URL(link.getAttribute("href"), location.href); } catch (_) { return null; }
  }
  function postID(url) {
    if (!url || url.protocol !== "https:" || !["instagram.com", "www.instagram.com"].includes(url.hostname)) return null;
    const match = url.pathname.match(/^\/(?:[a-zA-Z0-9._]+\/)?(?:p|reel|reels)\/([A-Za-z0-9_-]{1,64})\/?$/);
    return match?.[1] || null;
  }
  function profileName(url) {
    if (!url || url.protocol !== "https:" || !["instagram.com", "www.instagram.com"].includes(url.hostname)) return null;
    const name = url.pathname.match(/^\/([a-zA-Z0-9._]+)(?:\/(?:reels|tagged))?\/?$/)?.[1].toLowerCase();
    const reserved = new Set(["accounts", "about", "api", "challenge", "direct", "directory", "explore", "legal", "p", "reel", "reels", "stories", "web", "oauth", "share"]);
    return name && !reserved.has(name) && /^[a-z0-9_][a-z0-9._]{0,29}$/.test(name) && !name.endsWith(".") && !name.includes("..") ? name : null;
  }
  function profileSource() {
    const profile = profileName(new URL(location.href));
    if (!profile) return null;
    if (friends.has(profile)) return { context: "profile", friend: profile };
    // Read only visible profile controls, never private account state or cookies.
    // Exclude post/comment headers: a caption saying “Following” proves nothing.
    const headers = [...document.querySelectorAll("main header, [role=main] header")]
      .filter(header => !header.closest("article, [role=dialog]"));
    const visible = node => node.getClientRects().length > 0 && getComputedStyle(node).visibility !== "hidden";
    const controls = headers.flatMap(header => [...header.querySelectorAll("a[href], button, [role=button]")]).filter(visible);
    if (controls.some(control => {
      const url = control.matches("a[href]") && hrefURL(control);
      return url && ["instagram.com", "www.instagram.com"].includes(url.hostname) && url.pathname === "/accounts/edit/";
    })) return { context: "own-profile", friend: profile };
    const followingLabels = new Set(["following", "siguiendo", "urmărești", "urmaresti", "követed", "abonniert", "abonné(e)", "suivi(e)", "segui già", "seguindo"]);
    if (options.feedMode === "following" && controls.some(control =>
      followingLabels.has((control.getAttribute("aria-label") || control.textContent).trim().toLowerCase())
    )) return { context: "followed-profile", friend: profile };
    return null;
  }
  function articleHeader(article) {
    if (!article) return null;
    const semanticHeader = article.querySelector(":scope > header");
    if (semanticHeader) return semanticHeader;
    // The current mobile layout wraps header, media and actions in three divs.
    // Require the avatar/author area before a separate media area, so caption
    // mentions and comment authors cannot be mistaken for the post's author.
    const wrapper = article.firstElementChild;
    const header = wrapper?.firstElementChild;
    if (wrapper?.tagName === "DIV" && wrapper.children.length >= 2 &&
        header?.querySelector("img") && header.querySelector("a[href]") &&
        [...wrapper.children].slice(1).some(node => node.querySelector("img,video"))) return header;
    return null;
  }
  function articleFriend(article) {
    // Only the author area counts. Mentions in captions/comments never grant access.
    const author = [...(articleHeader(article)?.querySelectorAll("a[href]") || [])].map(hrefURL).map(profileName).find(Boolean);
    return friends.has(author) ? author : null;
  }
  function isFeedPost(article) {
    // Instagram also serves its sign-in article at /. Never treat the entire
    // home document as a timeline or inspect the contents of credential fields.
    if (article.querySelector('input[type="password"], input[autocomplete="current-password"]')) return false;
    if (articleHeader(article) || [...article.querySelectorAll("a[href]")].some(link => postID(hrefURL(link)))) return true;
    return !article.querySelector('a[href*="/accounts/login"], a[href*="/accounts/emailsignup"]');
  }
  const sponsoredLabels = new Set(["sponsored", "publicidad", "gesponsert", "sponsorisé", "sponsorizzato", "patrocinado", "hirdetés"]);
  function isSponsored(article) {
    const header = articleHeader(article);
    if (!header) return false;
    return [...header.querySelectorAll("span, [aria-label]")].some(node => {
      // A username or caption mentioning an ad is not an advertising label.
      if (node.closest("a[href]")) return false;
      const label = (node.getAttribute("aria-label") || node.textContent).replace(/[\u200B-\u200D\uFEFF]/g, "").trim().toLowerCase();
      return sponsoredLabels.has(label);
    });
  }
  function isFollowingFeed() {
    return location.pathname === "/" && new URL(location.href).searchParams.get("variant") === "following";
  }
  function sourceFor(link) {
    if (location.pathname.startsWith("/direct/")) return { context: "dm", friend: "" };
    if (location.pathname.startsWith("/stories/")) return { context: "story", friend: "" };
    const profile = profileSource();
    if (profile) return profile;
    if (location.pathname === "/") {
      const article = link.closest("article");
      if (options.hideAds && article && isSponsored(article)) return null;
      if (options.feedMode === "following" && isFollowingFeed() && article && isFeedPost(article)) return { context: "following", friend: "" };
      const friend = articleFriend(article);
      if (friend) return { context: "feed", friend };
    }
    return null;
  }
  function pauseVideos() {
    document.querySelectorAll("video").forEach(video => video.pause());
  }

  function handOffDMViewer() {
    const context = location.pathname.startsWith("/direct/") ? { context: "dm-viewer", friend: "" } : profileSource();
    if (!options.blockReels || !context) {
      if (inlineViewer) {
        inlineViewer = null;
        document.querySelectorAll("[data-quietly-dm-path], [data-quietly-dm-pruned], [data-quietly-dm-card], [data-quietly-dm-handoff]").forEach(node => {
          for (const name of ["path", "pruned", "card", "handoff"]) node.removeAttribute(`data-quietly-dm-${name}`);
        });
        report({ type: "inlinePost", state: "closed" });
      }
      return;
    }
    if (inlineViewer) {
      const { scroller, card, video } = inlineViewer;
      if (!scroller.isConnected) {
        inlineViewer = null;
        report({ type: "inlinePost", state: "closed" });
      } else {
        const source = video.getAttribute("src") || video.currentSrc || "";
        if (!card.isConnected || !card.contains(video) || card.querySelectorAll("video").length !== 1 ||
            (inlineViewer.source && source && source !== inlineViewer.source)) inlineViewer.failed = true;
        if (!inlineViewer.source && source) inlineViewer.source = source;
        if (inlineViewer.failed) {
          scroller.setAttribute("data-quietly-dm-handoff", "true");
          pauseVideos();
          return "One shared post at a time";
        }
        // Only the selected media card survives, even when new cards are loaded.
        let branch = card;
        while (branch !== scroller && branch.parentElement) {
          const parent = branch.parentElement;
          for (const sibling of parent.children) {
            if (sibling !== branch && !["STYLE", "SCRIPT"].includes(sibling.tagName)) sibling.setAttribute("data-quietly-dm-pruned", "true");
          }
          parent.setAttribute("data-quietly-dm-path", "true");
          branch = parent;
        }
        document.querySelectorAll("video").forEach(other => { if (other !== video) other.pause(); });
        return;
      }
    }
    // DM and profile attachment buttons can mount a Reel list without an anchor click,
    // article, dialog role, or URL change. Inspect only its visible media and
    // post permalinks, never the conversation text or page's private data.
    for (const video of document.querySelectorAll("video")) {
      const rect = video.getBoundingClientRect();
      if (rect.width < 160 || rect.height < Math.min(300, innerHeight * 0.6) ||
          rect.top >= innerHeight || rect.bottom <= 0) continue;
      let id = null;
      let card = null;
      for (let parent = video.parentElement; parent && parent !== document.body; parent = parent.parentElement) {
        const ids = [...new Set([...parent.querySelectorAll("a[href]")].map(hrefURL).map(postID).filter(Boolean))];
        if (!id && ids.length === 1) id = ids[0];
        const css = getComputedStyle(parent);
        const isViewer = ["auto", "scroll"].includes(css.overflowY) &&
          parent.clientHeight >= Math.min(300, innerHeight * 0.6) &&
          (parent.scrollHeight > parent.clientHeight + 80 || css.scrollSnapType.startsWith("y"));
        // Keep the whole selected Reel, including its playback/report controls.
        // Stopping at the video's immediate parent would prune those controls.
        if (!isViewer && parent.querySelectorAll("video").length === 1 &&
            parent.querySelector("a[href],button,[role=button]")) card = parent;
        const reelControls = parent.querySelector('a[href*="/reels/audio/"], a[href*="/reel/"]');
        if (!isViewer || (!ids.length && !reelControls)) continue;
        if (!id && card && card !== parent) {
          inlineViewer = { scroller: parent, card, video, source: video.getAttribute("src") || video.currentSrc || "", failed: false };
          card.setAttribute("data-quietly-dm-card", "true");
          report({ type: "inlinePost", state: "ready", ...context });
          return handOffDMViewer();
        }
        parent.setAttribute("data-quietly-dm-handoff", "true");
        pauseVideos();
        if (!handedOffViewers.has(parent)) {
          handedOffViewers.add(parent);
          if (id) report({ type: "openPost", id, ...context, inline: "true" });
        }
        return id ? null : "One shared post at a time";
      }
    }
  }

  const style = document.createElement("style");
  style.id = "quietly-styles";
  style.textContent = `
    [data-quietly-hidden] { display: none !important; }
    [data-quietly-dm-handoff] { visibility: hidden !important; pointer-events: none !important; }
    [data-quietly-dm-pruned] { display: none !important; }
    [data-quietly-dm-path] {
      overflow-y: hidden !important; scroll-snap-type: none !important;
    }
    html[data-quietly-route-blocked] body { visibility: hidden !important; }
    #quietly-feed-end {
      box-sizing: border-box; padding: 32px 24px; margin: 16px auto;
      max-width: 600px; border-radius: 18px; background: #edf3e9;
      color: #214d3b; font: 16px/1.6 -apple-system, system-ui, sans-serif;
      text-align: center;
    }
  `;
  const sentinel = document.createElement("div");
  sentinel.id = "quietly-feed-end";
  sentinel.setAttribute("role", "status");

  function hide(element, reason) {
    if (element.getAttribute("data-quietly-hidden") !== reason) {
      element.setAttribute("data-quietly-hidden", reason);
    }
    element.querySelectorAll("video").forEach(video => video.pause());
  }
  function show(element) { element.removeAttribute("data-quietly-hidden"); }

  function postIdentity(article) {
    const id = [...article.querySelectorAll("a[href]")].map(hrefURL).map(postID).find(Boolean);
    if (id) return id;
    if (!unknownPosts.has(article)) unknownPosts.set(article, `unknown-${++unknownPostID}`);
    return unknownPosts.get(article);
  }

  function apply() {
    scheduled = false;
    if (!document.documentElement) return;
    if (!style.isConnected) document.documentElement.append(style);
    const path = location.pathname;
    const route = path + location.search;
    const dmBoundary = handOffDMViewer();
    if (route !== lastPath) {
      lastPath = route;
      followingRequested = false;
      sentinel.remove();
      // Keep the post budget across SPA route changes and DOM recycling.
      document.querySelectorAll('[data-quietly-hidden="feed"]').forEach(show);
    }
    const blockedReason = dmBoundary || reasonFor(new URL(location.href));
    if (blockedReason) {
      document.documentElement.setAttribute("data-quietly-route-blocked", "true");
      pauseVideos();
    } else {
      document.documentElement.removeAttribute("data-quietly-route-blocked");
    }
    if (lastReport !== (blockedReason || "clear")) {
      lastReport = blockedReason || "clear";
      report({ type: "route", reason: blockedReason || "" });
    }

    // Individual posts from DMs/friends open in a separate, bounded viewer.
    document.querySelectorAll("a[href]").forEach(link => {
      const url = hrefURL(link);
      const blocked = url && reasonFor(url);
      const sharedPost = postID(url) && sourceFor(link);
      if (blocked && !sharedPost) hide(link, "navigation");
      else if (link.getAttribute("data-quietly-hidden") === "navigation") show(link);
    });

    // Only the home timeline is bounded. Profiles, login and inbox remain intact.
    const isHome = path === "/";
    const articles = [...document.querySelectorAll("main article, [role=main] article")];
    for (const article of articles) {
      if (!path.startsWith("/direct/") && options.hideAds && isSponsored(article)) hide(article, "ad");
      else if (article.getAttribute("data-quietly-hidden") === "ad") show(article);
    }
    if (!isHome) {
      document.querySelectorAll('[data-quietly-hidden="feed"]').forEach(show);
      sentinel.remove();
      return;
    }
    const following = options.feedMode === "following" && isFollowingFeed();
    if (options.feedMode === "following" && !following && !followingRequested && articles.some(isFeedPost)) {
      followingRequested = true;
      // Use Instagram's own visible Following destination. No private API or
      // scraping of the account's Following list is involved.
      location.replace("/?variant=following");
    }
    let firstHidden = null;
    for (const article of articles) {
      if (article.getAttribute("data-quietly-hidden") === "ad") continue;
      if (!isFeedPost(article)) {
        if (article.getAttribute("data-quietly-hidden") === "feed") show(article);
        continue;
      }
      if (following || articleFriend(article)) {
        if (article.getAttribute("data-quietly-hidden") === "feed") show(article);
        continue;
      }
      const key = postIdentity(article);
      if (!posts.has(key)) posts.set(key, ++nextPostIndex);
      if (options.feedMode !== "limited" || posts.get(key) > options.postLimit) {
        hide(article, "feed");
        firstHidden ||= article;
      } else if (article.getAttribute("data-quietly-hidden") === "feed") show(article);
    }
    if (firstHidden) {
      const label = options.feedMode === "following" ? "Opening posts from people you follow…" : options.feedMode === "hidden"
        ? (friends.size ? "Other feed posts are hidden. Posts with a recognized friend author stay visible." : "Your feed is taking a breather. Messages, profiles and stories are still yours to visit.")
        : "That’s your catch-up. You’ve reached your post limit for this page visit. A good moment to step away.";
      if (sentinel.textContent !== label) sentinel.textContent = label;
      if (firstHidden.previousElementSibling !== sentinel) firstHidden.before(sentinel);
    } else sentinel.remove();
    if (stopped) pauseVideos();
  }

  function schedule() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(apply);
  }
  document.addEventListener("click", event => {
    const link = event.target instanceof Element ? event.target.closest("a[href]") : null;
    if (!link) return;
    const url = hrefURL(link);
    const id = postID(url);
    const source = id && sourceFor(link);
    if (source && event.isTrusted) {
      event.preventDefault();
      event.stopImmediatePropagation();
      report({ type: "openPost", id, ...source });
      return;
    }
    const reason = url && reasonFor(url);
    if (reason) {
      event.preventDefault();
      event.stopImmediatePropagation();
      report({ type: "blockedLink", reason });
    }
  }, true);
  document.addEventListener("play", event => {
    handOffDMViewer();
    if (stopped || reasonFor(new URL(location.href)) || event.target.closest?.("[data-quietly-hidden], [data-quietly-dm-handoff], [data-quietly-dm-pruned]") ||
        (inlineViewer && event.target !== inlineViewer.video)) {
      event.target.pause?.();
    }
  }, true);
  // Stop vertical paging before Instagram's gesture handlers see the move.
  // Horizontal gestures and ordinary taps remain available.
  window.addEventListener("touchstart", event => {
    const touch = event.touches[0];
    touchStart = inlineViewer?.scroller.contains(event.target) && touch ? { x: touch.clientX, y: touch.clientY } : null;
    verticalDrag = false;
  }, { capture: true, passive: true });
  window.addEventListener("touchmove", event => {
    const touch = event.touches[0];
    if (!touchStart || !touch || !inlineViewer) return;
    if (Math.abs(touch.clientY - touchStart.y) > Math.abs(touch.clientX - touchStart.x)) {
      verticalDrag = true;
      event.preventDefault(); event.stopImmediatePropagation();
    }
  }, { capture: true, passive: false });
  window.addEventListener("touchend", event => {
    if (verticalDrag && inlineViewer) { event.preventDefault(); event.stopImmediatePropagation(); }
    touchStart = null; verticalDrag = false;
  }, { capture: true, passive: false });
  window.addEventListener("wheel", event => {
    if (inlineViewer?.scroller.contains(event.target) && Math.abs(event.deltaY) > Math.abs(event.deltaX)) {
      event.preventDefault(); event.stopImmediatePropagation();
    }
  }, { capture: true, passive: false });
  window.addEventListener("keydown", event => {
    if (inlineViewer && ["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End"].includes(event.key)) {
      event.preventDefault(); event.stopImmediatePropagation();
    }
  }, true);
  window.__quietlyPause = () => { stopped = true; pauseVideos(); };
  new MutationObserver(schedule).observe(document, {
    childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["href", "aria-label", "src"]
  });
  window.addEventListener("popstate", schedule);
  window.addEventListener("pageshow", schedule);
  document.addEventListener("loadedmetadata", schedule, true);
  // pushState runs in Instagram's page world, not in our isolated world.
  setInterval(() => { if (location.pathname + location.search !== lastPath) schedule(); }, 500);
  schedule();
})();
