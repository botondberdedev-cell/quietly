const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const playwright = require("playwright");

const script = fs.readFileSync(path.join(__dirname, "../Quietly/Resources/filters.js"), "utf8");
const singleScript = fs.readFileSync(path.join(__dirname, "../Quietly/Resources/single-post.js"), "utf8");
const alertsScript = fs.readFileSync(path.join(__dirname, "../Quietly/Resources/message-alerts.js"), "utf8");
let browser;
before(async () => {
  const engine = process.env.TEST_BROWSER || "chromium";
  assert.ok(["chromium", "webkit"].includes(engine), "Use chromium or webkit");
  browser = await playwright[engine].launch({ headless: true });
});
after(async () => { await browser?.close(); });

const article = id => `<article id="post-${id}"><a href="/p/${id}/">A photo</a><p>Fixture ${id}</p></article>`;
const mobileArticle = (id, label = "", caption = "A fixture", author = "friend") => `<article id="${id}"><div><div><div><a href="/${author}/"><img alt="Avatar">${author}</a><span class="disclosure">${label}</span></div></div><div><img alt="Photo"></div><div><p>${caption}</p><a href="/reel/${id}/">View post</a></div></div></article>`;

async function fixture(t, { pathname = "/", options = {}, html = "", host = "www.instagram.com" } = {}) {
  options = { feedMode: "hidden", ...options };
  const context = await browser.newContext();
  t.after(() => context.close());
  // Every request is intercepted: tests never contact Instagram or send credentials.
  await context.route("**/*", route => route.fulfill({
    contentType: "text/html; charset=utf-8", body: `<!doctype html><html><head><meta charset="utf-8"></head><body>${html}</body></html>`
  }));
  await context.addInitScript(({ options, script }) => {
    window.__quietlyOptions = options;
    window.reports = [];
    window.webkit = { messageHandlers: { quietly: { postMessage: body => window.reports.push(body) } } };
    (0, eval)(script);
  }, { options, script: options.messageAlertFixture ? alertsScript : options.singlePostID ? singleScript : script });
  const page = await context.newPage();
  await page.goto(`https://${host}${pathname}`);
  if (host === "www.instagram.com") {
    if (options.messageAlertFixture) await page.waitForFunction(() => window.reports.some(r => r.type === "inboxCount"));
    else await page.waitForSelector(options.singlePostID ? "#quietly-single-styles" : "#quietly-styles", { state: "attached" });
  }
  return page;
}

test("home feed hides, while stories and messages links remain", async t => {
  const page = await fixture(t, { html: `<nav><a id="reels" href="/reels/">Reels</a><a id="explore" href="/explore/">Explore</a><a id="messages" href="/direct/inbox/">Messages</a></nav><main><a id="story" href="/stories/friend/">Story</a>${article(1)}</main>` });
  assert.equal(await page.locator("#reels").isVisible(), false);
  assert.equal(await page.locator("#explore").isVisible(), false);
  assert.equal(await page.locator("#post-1").isVisible(), false);
  assert.equal(await page.locator("#story").isVisible(), true);
  assert.equal(await page.locator("#messages").isVisible(), true);
  assert.equal(await page.locator("#quietly-feed-end").count(), 1);
});

test("finite feed bounds initial, appended and recycled posts", async t => {
  const page = await fixture(t, { options: { feedMode: "limited", postLimit: 3 }, html: `<main>${[1,2,3,4].map(article).join("")}</main>` });
  assert.equal(await page.locator("article:visible").count(), 3);
  await page.locator("main").evaluate((main, html) => main.insertAdjacentHTML("beforeend", html), article(5));
  await page.waitForFunction(() => document.querySelector("#post-5").hasAttribute("data-quietly-hidden"));
  assert.equal(await page.locator("article:visible").count(), 3);
  // Instagram can recycle an article DOM node instead of appending a new one.
  await page.locator("#post-1 a").evaluate(a => a.setAttribute("href", "/p/6/"));
  await page.waitForFunction(() => document.querySelector("#post-1").hasAttribute("data-quietly-hidden"));
  assert.equal(await page.locator("article:visible").count(), 2);
});

test("finite feed tracks username-prefixed permalinks and canonical aliases", async t => {
  const html = `<main>${[1,2,3,4].map(id=>`<article id="p${id}"><p>Media fixture</p><a href="/friend/reel/${id}/">Post</a></article>`).join("")}</main>`;
  const page = await fixture(t, { options: { feedMode: "limited", postLimit: 3 }, html });
  assert.equal(await page.locator("article:visible").count(), 3);
  await page.locator("#p1 a").evaluate(a => { a.href = "/p/1/"; });
  assert.equal(await page.locator("#p1").isVisible(), true);
  await page.locator("#p1 a").evaluate(a => { a.href = "/friend/reel/5/"; });
  await page.waitForFunction(() => document.querySelector("#p1").hasAttribute("data-quietly-hidden"));
});

test("SPA navigation blocks Reels and restores the inbox", async t => {
  const page = await fixture(t, { pathname: "/direct/inbox/", html: `<main>${article(1)}</main>` });
  assert.equal(await page.locator("article").isVisible(), true);
  await page.evaluate(() => history.pushState({}, "", "/reels/"));
  await page.waitForFunction(() => document.documentElement.hasAttribute("data-quietly-route-blocked"));
  assert.equal(await page.locator("article").isVisible(), false);
  await page.evaluate(() => history.pushState({}, "", "/direct/inbox/"));
  await page.waitForFunction(() => !document.documentElement.hasAttribute("data-quietly-route-blocked"));
  assert.equal(await page.locator("article").isVisible(), true);
});

test("shared Reels open a single post without navigating away from the conversation", async t => {
  const page = await fixture(t, { pathname: "/direct/t/123/", html: '<main><a id="shared" href="/reel/abc/">Shared video</a></main>' });
  assert.equal(await page.locator("#shared").isVisible(), true);
  await page.locator("#shared").click();
  assert.match(page.url(), /\/direct\/t\/123\/$/);
  const reports = await page.evaluate(() => window.reports);
  assert.ok(reports.some(r => r.type === "openPost" && r.id === "abc" && r.context === "dm"));
});

test("DM photos and target-blank Reel links also use the bounded viewer", async t => {
  const page = await fixture(t, { pathname: "/direct/t/123/", html: '<a id="photo" href="/p/photo_1/">Photo</a><a id="reel" target="_blank" href="/reels/video-2/?igsh=test">Video</a>' });
  await page.locator("#photo").click();
  await page.locator("#reel").click();
  assert.deepEqual(await page.evaluate(() => window.reports.filter(r => r.type === "openPost").map(r => r.id)), ["photo_1", "video-2"]);
  assert.match(page.url(), /\/direct\/t\/123\/$/);
});

const dmViewer = `<div id="dm-viewer" style="height:500px;overflow-y:scroll;scroll-snap-type:y mandatory">
  <div style="height:500px"><div><video width="320" height="450"></video><a href="/friend/reel/shared_1/">Post</a><a href="/p/shared_1/">Comments</a></div></div>
  <div style="height:500px"><video width="320" height="450"></video><a href="/reel/next_2/">Next</a></div>
  </div>`;

test("a DM attachment button cannot expose an in-page Reel list without changing the URL", async t => {
  const page = await fixture(t, { pathname: "/direct/t/123/", html: '<button id="attachment">Shared Reel</button><main id="conversation">Conversation fixture</main>' });
  await page.locator("#attachment").evaluate((button, markup) => button.addEventListener("click", () => {
    document.querySelector("#conversation").innerHTML = markup;
  }), dmViewer);
  await page.locator("#attachment").click();
  await page.waitForFunction(() => window.reports.some(r => r.context === "dm-viewer"));
  assert.deepEqual(await page.evaluate(() => window.reports.filter(r => r.context === "dm-viewer").map(r => r.id)), ["shared_1"]);
  assert.equal(await page.locator("#dm-viewer").isVisible(), false);
  assert.match(page.url(), /\/direct\/t\/123\/$/);
  await page.locator("#dm-viewer").evaluate(e => e.append(document.createElement("span")));
  await page.waitForTimeout(50);
  assert.equal(await page.evaluate(() => window.reports.filter(r => r.context === "dm-viewer").length), 1);
});

test("DM video handoff ignores ordinary attachments, Stories and disabled Reel filtering", async t => {
  for (const config of [
    { pathname: "/direct/t/123/", html: '<div style="height:500px;overflow-y:scroll"><video width="320" height="450"></video><div style="height:1000px">Messages</div></div>' },
    { pathname: "/stories/friend/1/", html: dmViewer },
    { pathname: "/direct/t/123/", options: { blockReels: false }, html: dmViewer }
  ]) {
    const page = await fixture(t, config);
    assert.equal(await page.locator("[data-quietly-dm-handoff]").count(), 0);
    assert.equal(await page.evaluate(() => window.reports.filter(r => r.context === "dm-viewer").length), 0);
  }
});

const inlineDMViewer = `<div id="inline-viewer" style="height:500px;overflow-y:scroll;scroll-snap-type:y mandatory"><div>
  <section id="shared-card" style="height:500px"><video id="shared-media" width="320" height="450" src="/fixture-a.mp4"></video><a href="/creator/reels/">Creator</a><a href="/reels/audio/123/">Audio</a></section>
  <section id="next-card" style="height:500px"><video id="other-media" width="320" height="450"></video><a href="/other/reels/">Next creator</a><a href="/reels/audio/456/">Audio</a></section>
  </div></div>`;

test("DM Reel viewer without permalinks keeps one media card and stops vertical paging", async t => {
  const page = await fixture(t, { pathname: "/direct/t/123/", html: inlineDMViewer });
  await page.waitForFunction(() => window.reports.some(r => r.type === "inlinePost" && r.state === "ready"));
  assert.equal(await page.locator("#shared-card").isVisible(), true);
  assert.equal(await page.locator("#next-card").isVisible(), false);
  const result = await page.evaluate(() => {
    const current = document.querySelector("#shared-media"), other = document.querySelector("#other-media");
    let wheelReachedPage = false;
    document.addEventListener("wheel", () => { wheelReachedPage = true; });
    const wheel = new WheelEvent("wheel", { bubbles: true, cancelable: true, deltaY: 200 });
    current.dispatchEvent(wheel);
    current.pause = () => { current.wasPaused = true; };
    other.pause = () => { other.wasPaused = true; };
    current.dispatchEvent(new Event("play", { bubbles: true }));
    other.dispatchEvent(new Event("play", { bubbles: true }));
    return { canceled: wheel.defaultPrevented, wheelReachedPage, currentPaused: !!current.wasPaused, otherPaused: !!other.wasPaused };
  });
  assert.deepEqual(result, { canceled: true, wheelReachedPage: false, currentPaused: false, otherPaused: true });
  await page.locator("#inline-viewer > div").evaluate(e => e.insertAdjacentHTML("beforeend", '<section id="appended"><video></video>Another Reel</section>'));
  await page.waitForFunction(() => document.querySelector("#appended").hasAttribute("data-quietly-dm-pruned"));
});

test("recycled DM video sources fail closed, and closing restores normal message scrolling", async t => {
  const page = await fixture(t, { pathname: "/direct/t/123/", html: inlineDMViewer });
  await page.waitForFunction(() => window.reports.some(r => r.type === "inlinePost"));
  await page.locator("#shared-media").evaluate(v => { v.src = "/different-reel.mp4"; });
  await page.waitForFunction(() => document.querySelector("#inline-viewer").hasAttribute("data-quietly-dm-handoff"));
  assert.equal(await page.locator("#shared-card").isVisible(), false);
  assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "route" && r.reason === "One shared post at a time")));
  await page.locator("#inline-viewer").evaluate(e => e.remove());
  await page.waitForFunction(() => window.reports.some(r => r.type === "inlinePost" && r.state === "closed"));
  assert.equal(await page.evaluate(() => {
    const event = new WheelEvent("wheel", { bubbles: true, cancelable: true, deltaY: 200 });
    document.body.dispatchEvent(event); return event.defaultPrevented;
  }), false);
});

test("leaving a DM Reel for Stories removes the inline playback lock", async t => {
  const page = await fixture(t, { pathname: "/direct/t/123/", html: inlineDMViewer });
  await page.waitForFunction(() => window.reports.some(r => r.type === "inlinePost"));
  await page.evaluate(() => history.pushState({}, "", "/stories/friend/1/"));
  await page.waitForFunction(() => window.reports.some(r => r.type === "inlinePost" && r.state === "closed"));
  assert.equal(await page.locator("[data-quietly-dm-pruned]").count(), 0);
});

test("friend profile Reels are allowed without unlocking the Reels tab", async t => {
  const page = await fixture(t, { pathname: "/alice/reels/", options: { friendUsernames: ["alice"] }, html: '<a id="item" href="/alice/reel/video/">Alice’s video</a><a id="feed" href="/reels/">Reels feed</a>' });
  assert.equal(await page.locator("#item").isVisible(), true);
  assert.equal(await page.locator("#feed").isVisible(), false);
  await page.locator("#item").click();
  assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "openPost" && r.id === "video" && r.friend === "alice")));
  const stranger = await fixture(t, { pathname: "/stranger/", options: { friendUsernames: ["alice"] }, html: '<a id="item" href="/reel/video/">A video</a>' });
  assert.equal(await stranger.locator("#item").isVisible(), false);
});

test("friend authors bypass hidden feed and post budget; caption mentions do not", async t => {
  const friendPost = '<article id="friend"><header><a href="/alice">Alice</a></header><a id="friend-reel" href="/reel/friend_video/">Video</a></article>';
  const strangerPost = '<article id="stranger"><header><a href="/other/">Other</a></header><p>Mentioning <a href="/alice/">Alice</a></p><a href="/reel/other_video/">Video</a></article>';
  const commentHeader = '<article id="comment-header"><a href="/p/third/">Third post</a><aside><header><a href="/alice/">Alice commented</a></header></aside></article>';
  const page = await fixture(t, { options: { friendUsernames: ["alice"] }, html: `<main>${friendPost}${strangerPost}${commentHeader}</main>` });
  assert.equal(await page.locator("#friend").isVisible(), true);
  assert.equal(await page.locator("#stranger").isVisible(), false);
  assert.equal(await page.locator("#comment-header").isVisible(), false);
  await page.locator("#friend-reel").click();
  assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "openPost" && r.context === "feed" && r.friend === "alice")));
  const limited = await fixture(t, { options: { friendUsernames: ["alice"], feedMode: "limited", postLimit: 3 }, html: `<main>${friendPost}${[1,2,3,4].map(article).join("")}</main>` });
  assert.equal(await limited.locator("article:visible").count(), 4);
});

test("own uploads stay visible in the profile and Reels grid, with no access to the endless feed", async t => {
  for (const pathname of ["/myself/", "/myself/reels/"]) {
    const page = await fixture(t, { pathname, html: '<main><header><a href="/accounts/edit/">Edit profile</a></header><a id="upload" href="/myself/reel/Own1/">My video</a><a id="feed" href="/reels/">Reels</a></main>' });
    assert.equal(await page.locator("#upload").isVisible(), true);
    assert.equal(await page.locator("#feed").isVisible(), false);
    await page.locator("#upload").click();
    assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "openPost" && r.id === "Own1" && r.context === "own-profile" && r.friend === "myself")));
    assert.equal(new URL(page.url()).pathname, pathname);
  }
});

test("followed profiles allow selected Reels without manually saving each friend", async t => {
  for (const label of ["Following", "Siguiendo", "Urmărești", "Követed"]) {
    const page = await fixture(t, { pathname: "/alice/reels/", options: { feedMode: "following" }, html: `<main><header><button>${label}</button></header><a id="upload" href="/reel/Friend1/">Video</a><a id="feed" href="/reels/">Feed</a></main>` });
    assert.equal(await page.locator("#upload").isVisible(), true);
    await page.locator("#upload").click();
    assert.ok(await page.evaluate(() => window.reports.some(r => r.context === "followed-profile" && r.friend === "alice")));
    assert.equal(await page.locator("#feed").isVisible(), false);
  }
});

test("profile exceptions exclude suggested accounts, captions, hidden controls and reserved routes", async t => {
  for (const config of [
    { html: '<main><header><button>Follow</button></header></main>' },
    { html: '<main><article><header><button>Following</button><a href="/accounts/edit/">Edit profile</a></header></article></main>' },
    { html: '<main><header style="display:none"><button>Following</button></header></main>' },
    { html: '<main><header><a href="https://evil.example/accounts/edit/">Edit profile</a></header></main>' },
    { pathname: '/explore/', html: '<main><header><a href="/accounts/edit/">Edit profile</a></header></main>' },
    { options: { feedMode: 'hidden' }, html: '<main><header><button>Following</button></header></main>' }
  ]) {
    const page = await fixture(t, { pathname: "/stranger/", ...config, options: { feedMode: "following", ...config.options }, html: `${config.html}<a id="upload" href="/reel/Other1/">Video</a>` });
    assert.equal(await page.locator("#upload").isVisible(), false);
    assert.equal(await page.evaluate(() => window.reports.some(r => r.type === "openPost")), false);
  }
});

test("following state updates dynamically and cannot leak across SPA profiles", async t => {
  const page = await fixture(t, { pathname: "/alice/", options: { feedMode: "following" }, html: '<main><header><button id="relationship">Follow</button></header><a id="upload" href="/reel/Friend1/">Video</a></main>' });
  assert.equal(await page.locator("#upload").isVisible(), false);
  await page.locator("#relationship").evaluate(e => { e.textContent = 'Following'; });
  await page.waitForFunction(() => !document.querySelector('#upload').hasAttribute('data-quietly-hidden'));
  await page.evaluate(() => { history.pushState({}, '', '/stranger/'); document.querySelector('#relationship').textContent = 'Follow'; });
  await page.waitForFunction(() => document.querySelector('#upload').hasAttribute('data-quietly-hidden'));
});

test("profile video buttons cannot expose an inline endless Reel player", async t => {
  const page = await fixture(t, { pathname: "/myself/reels/", html: `<main><header><a href="/accounts/edit/">Edit profile</a></header>${inlineDMViewer}</main>` });
  await page.waitForFunction(() => window.reports.some(r => r.type === 'inlinePost' && r.state === 'ready'));
  assert.equal(await page.locator('#shared-card').isVisible(), true);
  assert.equal(await page.locator('#next-card').isVisible(), false);
  assert.equal(await page.locator('#shared-media').evaluate(v => {
    const wheel = new WheelEvent('wheel', { bubbles: true, cancelable: true, deltaY: 400 });
    v.dispatchEvent(wheel); return wheel.defaultPrevented;
  }), true);
});

test("single-post viewer exposes the selected card, never its neighbors or site navigation", async t => {
  const page = await fixture(t, { pathname: "/p/chosen/", options: { singlePostID: "chosen" }, html: `<nav><a id="feed" href="/reels/">Reels</a></nav><main>${article("before")}${article("chosen")}${article("next")}</main>` });
  assert.equal(await page.locator("#post-chosen").isVisible(), true);
  assert.equal(await page.locator("#post-before").isVisible(), false);
  assert.equal(await page.locator("#post-next").isVisible(), false);
  assert.equal(await page.locator("#feed").isVisible(), false);
  await page.locator("main").evaluate((main, html) => main.insertAdjacentHTML("beforeend", html), article("later"));
  assert.equal(await page.locator("#post-later").isVisible(), false);
  assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "postState" && r.state === "ready")));
});

test("single-post viewer fails closed on route changes and recycled post nodes", async t => {
  const page = await fixture(t, { pathname: "/reel/chosen/", options: { singlePostID: "chosen" }, html: `<main>${article("chosen")}</main>` });
  await page.locator("#post-chosen a").evaluate(a => a.setAttribute("href", "/reel/next/"));
  await page.waitForFunction(() => !document.querySelector("[data-quietly-selected]"));
  assert.equal(await page.locator("article").isVisible(), false);
  await page.locator("#post-chosen a").evaluate(a => a.setAttribute("href", "/reel/chosen/"));
  await page.waitForSelector("[data-quietly-selected]");
  await page.evaluate(() => history.pushState({}, "", "/reel/next/"));
  await page.waitForFunction(() => !document.querySelector("[data-quietly-selected]"));
  assert.equal(await page.locator("article").isVisible(), false);
});

test("unrecognized single-post layouts stay hidden and links cannot launch another page", async t => {
  const unknown = await fixture(t, { pathname: "/p/chosen/", options: { singlePostID: "chosen" }, html: '<main><div id="unknown">Unrecognized infinite video feed</div></main>' });
  assert.equal(await unknown.locator("#unknown").isVisible(), false);
  const page = await fixture(t, { pathname: "/p/chosen/", options: { singlePostID: "chosen" }, html: `<main><article id="chosen"><a href="/p/chosen/">Selected</a><a id="profile" href="/alice/">Alice</a><button id="comment">Comment</button><a id="carousel" href="/p/chosen/?img_index=2">Next image</a></article></main>` });
  await page.locator("#profile").click();
  assert.match(page.url(), /\/p\/chosen\/$/);
  assert.equal(await page.locator("#comment").isVisible(), true);
  await page.locator("#carousel").click();
  await page.waitForURL("**/p/chosen/?img_index=2");
  assert.equal(await page.locator("#chosen").isVisible(), true);
});

test("single-post media guard pauses other videos and stops the selected video at session end", async t => {
  const page = await fixture(t, { pathname: "/p/chosen/", options: { singlePostID: "chosen" }, html: `<main><article><a href="/p/chosen/">Chosen</a><video id="selected"></video></article><article><a href="/p/next/">Next</a><video id="other"></video></article></main>` });
  const result = await page.evaluate(() => {
    const selected = document.querySelector("#selected");
    const other = document.querySelector("#other");
    selected.pause = () => { selected.wasPaused = true; };
    other.pause = () => { other.wasPaused = true; };
    selected.dispatchEvent(new Event("play", { bubbles: true }));
    other.dispatchEvent(new Event("play", { bubbles: true }));
    const before = [!!selected.wasPaused, !!other.wasPaused];
    window.__quietlyPause();
    return { before, after: !!selected.wasPaused };
  });
  assert.deepEqual(result, { before: [false, true], after: true });
});

test("login, profile and inbox articles are not mistaken for home posts", async t => {
  for (const pathname of ["/accounts/login/", "/friend/", "/direct/inbox/"]) {
    const page = await fixture(t, { pathname, html: `<main>${article(1)}</main>` });
    assert.equal(await page.locator("article").isVisible(), true);
    assert.equal(await page.locator("#quietly-feed-end").count(), 0);
  }
});

test("login served at the home URL stays usable and does not consume the post budget", async t => {
  const login = '<article id="login"><form><input name="username"><input type="password" autocomplete="current-password"><button>Log in</button></form></article>';
  const page = await fixture(t, { options: { feedMode: "limited", postLimit: 3 }, html: `<main>${login}${[1,2,3,4].map(article).join("")}</main>` });
  assert.equal(await page.locator("#login").isVisible(), true);
  assert.equal(await page.locator("#post-3").isVisible(), true);
  assert.equal(await page.locator("#post-4").isVisible(), false);
  // A logged-out app can replace an existing post node with its sign-in UI.
  await page.locator("#post-4").evaluate(node => { node.innerHTML = '<input type="password"><button>Log in</button>'; });
  await page.waitForFunction(() => !document.querySelector("#post-4").hasAttribute("data-quietly-hidden"));
  const landing = await fixture(t, { html: '<main><article id="landing"><a href="/accounts/login/">Log in</a></article></main>' });
  assert.equal(await landing.locator("#landing").isVisible(), true);
  assert.equal(await landing.locator("#quietly-feed-end").count(), 0);
});

test("Following keeps Stories and followed posts, while hiding sponsored cards", async t => {
  const page = await fixture(t, { pathname: "/?variant=following", options: { feedMode: "following" }, html: `<nav><a id="reels" href="/reels/">Reels</a></nav><main><a id="story" href="/stories/friend/1/">Story</a>${mobileArticle("friend1")}${mobileArticle("advert", "Publicidad")}${mobileArticle("friend2", "", "A caption mentioning Sponsored")}</main>` });
  assert.equal(await page.locator("#story").isVisible(), true);
  assert.equal(await page.locator("#friend1").isVisible(), true);
  assert.equal(await page.locator("#friend2").isVisible(), true);
  assert.equal(await page.locator("#advert").isVisible(), false);
  assert.equal(await page.locator("#reels").isVisible(), false);
  await page.locator('#friend1 a[href^="/reel/"]').click();
  assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "openPost" && r.context === "following" && r.id === "friend1")));
  assert.equal(await page.locator("#quietly-feed-end").count(), 0);
});

test("ad labels update dynamically and override saved-friend exceptions without hiding captions", async t => {
  const page = await fixture(t, { options: { friendUsernames: ["friend", "sponsored"] }, html: `<main>${mobileArticle("dynamic")}${mobileArticle("caption", "", "Publicidad")}${mobileArticle("username", "", "Hello", "sponsored")}</main>` });
  assert.equal(await page.locator("#dynamic").isVisible(), true);
  await page.locator("#dynamic .disclosure").evaluate(e => { e.textContent = "Spon\u200bsored"; });
  await page.waitForFunction(() => document.querySelector("#dynamic").getAttribute("data-quietly-hidden") === "ad");
  assert.equal(await page.locator("#caption").isVisible(), true);
  assert.equal(await page.locator("#username").isVisible(), true);
  await page.locator("#dynamic .disclosure").evaluate(e => { e.firstChild.nodeValue = ""; });
  await page.waitForFunction(() => !document.querySelector("#dynamic").hasAttribute("data-quietly-hidden"));
  const unfiltered = await fixture(t, { pathname: "/?variant=following", options: { feedMode: "following", hideAds: false }, html: `<main>${mobileArticle("advert", "Sponsored")}</main>` });
  assert.equal(await unfiltered.locator("#advert").isVisible(), true);
});

test("Following mode redirects an ordinary timeline and notices query-only route changes", async t => {
  const page = await fixture(t, { options: { feedMode: "following" }, html: `<main>${mobileArticle("post1")}</main>` });
  await page.waitForURL("**/?variant=following");
  assert.equal(await page.locator("#post1").isVisible(), true);
  await page.evaluate(() => history.pushState({}, "", "/"));
  await page.waitForURL("**/?variant=following");
  const login = await fixture(t, { options: { feedMode: "following" }, html: '<main><article><input type="password"><button>Log in</button></article></main>' });
  assert.equal(new URL(login.url()).search, "");
  assert.equal(await login.locator("article").isVisible(), true);
});

test("a post shared in Stories uses the bounded viewer", async t => {
  const page = await fixture(t, { pathname: "/stories/friend/123/", html: '<a id="share" href="/reel/shared1/">Shared post</a>' });
  await page.locator("#share").click();
  assert.ok(await page.evaluate(() => window.reports.some(r => r.type === "openPost" && r.context === "story" && r.id === "shared1")));
});

test("disabled filters leave Reels and Explore available", async t => {
  const page = await fixture(t, { pathname: "/reels/", options: { blockReels: false, blockExplore: false }, html: '<a id="reels" href="/reels/">Reels</a><a id="explore" href="/explore/">Explore</a>' });
  assert.equal(await page.locator("#reels").isVisible(), true);
  assert.equal(await page.locator("#explore").isVisible(), true);
  assert.equal(await page.locator("html[data-quietly-route-blocked]").count(), 0);
});

test("lookalike domains never receive filtering or native messages", async t => {
  const page = await fixture(t, { host: "instagram.com.evil.example", html: `<main>${article(1)}</main>` });
  assert.equal(await page.locator("#quietly-styles").count(), 0);
  assert.deepEqual(await page.evaluate(() => window.reports), []);
});

test("script reinjection is idempotent and bridge excludes page contents", async t => {
  const page = await fixture(t, { html: `<main>${article(1)}</main>` });
  await page.evaluate(script => (0, eval)(script), script);
  assert.equal(await page.locator("#quietly-styles").count(), 1);
  const reports = await page.evaluate(() => window.reports);
  assert.ok(reports.length > 0);
  assert.ok(reports.every(r => Object.keys(r).sort().join(",") === "reason,type"));
});

test("message alerts read only visible inbox indicators, including Spanish and duplicate navigation", async t => {
  const page = await fixture(t, { options: { messageAlertFixture: true }, html: `<nav>
    <a href='/direct/inbox/' aria-label='Messages'><span id='badge'>2</span></a>
    <a href='/direct/inbox/' aria-label='2 mensajes sin leer'>Mensajes</a>
    <a href='/direct/inbox/' style='display:none'>99</a>
    <a href='/accounts/activity/'>Notifications 99</a></nav>
    <article><a href='/direct/inbox/'>88</a><p>Private content fixture must never enter the bridge</p></article>` });
  assert.deepEqual(await page.evaluate(() => window.reports), [{ type: 'inboxCount', count: '2' }]);
  await page.locator('#badge').evaluate(e => e.textContent = '3');
  await page.waitForFunction(() => window.reports.at(-1).count === '3');
  assert.deepEqual(await page.evaluate(() => Object.keys(window.reports.at(-1)).sort()), ['count', 'type']);
});

test("message alerts distinguish zero from unknown and handle badge removal and login", async t => {
  const page = await fixture(t, { options: { messageAlertFixture: true }, html: "<nav><a id='inbox' href='/direct/inbox/' aria-label='Messages'></a></nav>" });
  assert.equal(await page.evaluate(() => window.reports.at(-1).count), '0');
  await page.locator('#inbox').evaluate(e => e.innerHTML = '<span>1</span>');
  await page.waitForFunction(() => window.reports.at(-1).count === '1');
  await page.locator('#inbox').evaluate(e => e.innerHTML = '');
  await page.waitForFunction(() => window.reports.at(-1).count === '0');
  await page.locator('#inbox').evaluate(e => e.removeAttribute('aria-label'));
  await page.waitForFunction(() => window.reports.at(-1).count === 'unknown');
  await page.evaluate(() => { history.pushState({}, '', '/accounts/login/'); document.querySelector('#inbox').textContent = '4'; });
  await page.waitForTimeout(700);
  assert.equal(await page.evaluate(() => window.reports.at(-1).count), 'unknown');
});

test("message alerts do not use page titles, other hosts or giant/malformed counts", async t => {
  for (const html of ["<title>(9) Instagram</title><p>9 unread messages</p>", "<a href='https://evil.example/direct/inbox/'>9</a>", "<a href='/direct/inbox/'>10000</a>", "<a href='/direct/inbox/'>2.5</a>"]) {
    const page = await fixture(t, { options: { messageAlertFixture: true }, html });
    assert.deepEqual(await page.evaluate(() => window.reports), [{ type: 'inboxCount', count: 'unknown' }]);
  }
  const outsider = await fixture(t, { host: 'evil.example', options: { messageAlertFixture: true }, html: "<a href='/direct/inbox/'>9</a>" });
  await outsider.waitForTimeout(700);
  assert.deepEqual(await outsider.evaluate(() => window.reports), []);
});

test("ending a visit stops unread observation", async t => {
  const page = await fixture(t, { options: { messageAlertFixture: true }, html: "<a id='inbox' href='/direct/inbox/' aria-label='Messages'>1</a>" });
  await page.evaluate(() => { window.__quietlyStopMessageAlerts(); document.querySelector('#inbox').textContent = '2'; });
  await page.waitForTimeout(800);
  assert.deepEqual(await page.evaluate(() => window.reports), [{ type: 'inboxCount', count: '1' }]);
});
