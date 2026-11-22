// finds matches and blurs the containing post
// DOM api not html strings, for Trusted Types sites (youtube)
import { hiddenIcon } from './icons.gen';
import { BlockMatcher, SiteRule, normalizeSite } from './match';
import { stringsFor, type Strings } from './strings';
import type { RuleBlock, Rules, Saved, ToContent } from './types';

interface Active {
  block: RuleBlock;
  matcher: BlockMatcher;
}
type Hit = { block: RuleBlock; keywords: string[] };

let active: Active[] = [];
let settings: NonNullable<Rules['settings']> = { blurStrength: 'strong', twoClickReveal: false, sayKeyword: true };
let t: Strings = stringsFor(undefined);
let observer: MutationObserver | null = null;

/** hidden count + unsent counts */
let hiddenTotal = 0;
let unsent: Record<string, number> = {};
let unsentMatched: Record<string, Set<string>> = {};
let sendTimer: ReturnType<typeof setTimeout> | undefined;

const SKIP = new Set(['TITLE', 'SCRIPT', 'STYLE', 'NOSCRIPT', 'TEXTAREA', 'INPUT', 'SELECT', 'OPTION', 'CODE', 'PRE', 'SVG', 'TEMPLATE', 'IFRAME']);

/**
 * Known post containers, checked first so the whole card gets covered.
 */
const SITE_CONTAINERS = [
  // X / Twitter
  '[data-testid="tweet"]',
  '[data-testid="cellInnerDiv"]',
  // YouTube
  'yt-lockup-view-model',
  'ytd-rich-item-renderer',
  'ytd-rich-grid-media',
  'ytd-video-renderer',
  'ytd-compact-video-renderer',
  'ytd-grid-video-renderer',
  'ytd-playlist-video-renderer',
  'ytd-playlist-renderer',
  'ytd-radio-renderer',
  'ytd-movie-renderer',
  'ytd-reel-item-renderer',
  'ytm-shorts-lockup-view-model',
  'ytm-shorts-lockup-view-model-v2',
  'ytd-reel-video-renderer',
  'ytd-post-renderer',
  'ytd-backstage-post-thread-renderer',
  'ytd-comment-view-model',
  'ytd-comment-thread-renderer',
  'ytd-notification-renderer',
  'ytd-watch-metadata',
  // yt player overlays
  '.ytp-videowall-still',
  '.ytp-ce-element',
  '.ytp-autonav-endscreen-upnext-container',
  // Facebook
  '[aria-posinset]',
  '[data-pagelet^="FeedUnit"]',
  // Reddit
  'shreddit-post',
  'shreddit-comment',
  'faceplate-tracker[noun="post"]',
].join(',');

/** generic fallback */
const GENERIC_CONTAINERS = ['article', '[role="article"]', '[role="listitem"]', 'li'].join(',');

const isYouTube = /(^|\.)youtube\.com$/.test(location.hostname);
const isTikTok = /(^|\.)tiktok\.com$/.test(location.hostname);

/** tiktok caption layer (outside the video box) */
const TIKTOK_LAYER = '[data-e2e="anchoring-description-layer"]';

/** centred tiktok video */
function tiktokOnScreen(): HTMLElement | null {
  const mid = innerHeight / 2;
  for (const a of document.querySelectorAll<HTMLElement>('article[data-e2e="recommend-list-item-container"], section[data-e2e="feed-video"]')) {
    const r = a.getBoundingClientRect();
    if (r.top <= mid && r.bottom >= mid) return a;
  }
  return null;
}

// İstisnalar: listedeki kanal/profillerin içerikleri gizlenmez (ör. youtube.com/@kanal, x.com/hesap)

const isX = /(^|\.)(x|twitter)\.com$/.test(location.hostname);
let exceptions: SiteRule[] = [];

function excepted(url: string | null | undefined): boolean {
  return !!url && exceptions.some((e) => e.matches(url));
}

/** youtube izleme sayfasında videonun sahibi olan kanalın linki */
function ownerLink(): HTMLAnchorElement | null {
  return document.querySelector<HTMLAnchorElement>('ytd-watch-metadata #owner a[href], ytd-video-owner-renderer a[href]');
}

/** sayfanın kendisi istisna mı: kendi kanal sayfan. X'te profil sayfasında başkalarının retweetleri de olduğu için gönderi gönderi bakılır */
let exceptedFor = '';
let exceptedPage = false;
function pageExcepted(): boolean {
  if (!exceptions.length || isX) return false;
  if (exceptedFor !== location.href) {
    exceptedFor = location.href;
    exceptedPage = excepted(location.href);
  }
  return exceptedPage;
}

/** gönderinin/videonun yazarı istisna listesinde mi */
function containerExcepted(c: Element): boolean {
  if (!exceptions.length) return false;
  // izleme sayfası: oynatıcı ve video bilgisi, videonun sahibine göre
  if (isYouTube && location.pathname === '/watch' && (c === playerBox() || c.closest('ytd-watch-metadata') || c.querySelector('ytd-watch-metadata'))) {
    return excepted(ownerLink()?.href);
  }
  // X: yalnızca gönderinin yazarı (bahsedilen ya da alıntılanan hesaplar değil)
  if (isX) {
    const author = c.querySelector('[data-testid="User-Name"]');
    if (author) return [...author.querySelectorAll<HTMLAnchorElement>('a[href]')].some((a) => excepted(a.href));
  }
  return [...c.querySelectorAll<HTMLAnchorElement>('a[href]')].some((a) => excepted(a.href));
}

/** iki parçalı profil yolları: youtube.com/channel/UC.., reddit.com/r/x, reddit.com/user/x */
const TWO_PART = new Set(['channel', 'c', 'user', 'u', 'r']);
/** profil olmayan sayfalar */
const NOT_PROFILE = new Set(['watch', 'results', 'feed', 'shorts', 'playlist', 'home', 'explore', 'search', 'notifications', 'messages', 'i', 'settings', 'hashtag', 'compose', 'gaming', 'premium']);

function profileOf(url: string): string | null {
  try {
    const u = new URL(url);
    const parts = u.pathname.split('/').filter(Boolean);
    const first = parts[0];
    if (!first || NOT_PROFILE.has(first.toLowerCase())) return null;
    const path = TWO_PART.has(first.toLowerCase()) ? (parts[1] ? `${first}/${parts[1]}` : null) : first;
    return path ? normalizeSite(`${u.host}/${path}`) : null;
  } catch {
    return null;
  }
}

/** bu sayfadaki kanal/profil, popup'taki "Bu kanalı istisna yap" için */
function exceptionCandidate(): string | null {
  if (isYouTube && location.pathname === '/watch') {
    const owner = ownerLink();
    return owner ? profileOf(owner.href) : null;
  }
  if (isYouTube && location.pathname.startsWith('/shorts')) {
    const owner = document.querySelector<HTMLAnchorElement>('ytd-reel-video-renderer[is-active] a[href^="/@"], ytd-reel-video-renderer a[href^="/@"]');
    return owner ? profileOf(owner.href) : null;
  }
  return profileOf(location.href);
}

chrome.runtime.onMessage.addListener((m: ToContent, _sender, reply) => {
  if (m?.type !== 'exceptionCandidate' || window.top !== window) return false;
  reply({ site: exceptionCandidate() });
  return false;
});

function load(rules: Rules | undefined) {
  settings = rules?.settings ?? settings;
  t = stringsFor(rules);
  active = (rules?.blocks ?? [])
    .filter((b) => b.active)
    .map((block) => ({ block, matcher: new BlockMatcher(block) }))
    .filter((a) => !a.matcher.isEmpty);
  exceptedFor = '';
  exceptions = (settings.exceptions ?? []).map((e) => SiteRule.parse(e)).filter((e): e is SiteRule => !!e && e.path !== '');
  document.documentElement.style.setProperty('--nl-blur', settings.blurStrength === 'light' ? '7px' : '14px');
}

function matchAll(text: string): Hit[] {
  const out: Hit[] = [];
  for (const a of active) {
    const k = a.matcher.find(text);
    if (k.length) out.push({ block: a.block, keywords: k });
  }
  return out;
}

/**
 * keyword = hide now, spoiler word = only if the whole post is on topic.
 */
function checkPiece(text: string, at: Element) {
  const strong: Hit[] = [];
  const maybe: Active[] = [];
  for (const a of active) {
    const k = a.matcher.keywords.find(text);
    if (k.length) strong.push({ block: a.block, keywords: k });
    else if (a.matcher.spoilers.any(text)) maybe.push(a);
  }
  if (!strong.length && !maybe.length) return;
  if (pageExcepted()) return;
  const c = containerFor(at);
  if (!c || containerExcepted(c)) return;
  let hits = strong;
  if (maybe.length) {
    const post = postText(c);
    for (const a of maybe) {
      const k = a.matcher.find(post);
      if (k.length) hits = [...hits, { block: a.block, keywords: k }];
    }
  }
  if (!hits.length) return;
  hide(c, hits);
  // tiktok: blur the caption too, one Show for both
  const layer = isTikTok ? at.closest<HTMLElement>(TIKTOK_LAYER) : null;
  if (layer && layer !== c && !layer.closest('[data-nl-hidden], [data-nl-revealed]')) cover(layer, [], undefined, true);
}

/** text + aria/alt labels */
function postText(c: Element): string {
  let text = c.textContent ?? '';
  c.querySelectorAll('[aria-label], img[alt], [title]').forEach((e) => {
    text += ' ' + (e.getAttribute('aria-label') ?? e.getAttribute('alt') ?? e.getAttribute('title') ?? '');
  });
  return text.slice(0, 8000);
}

function el<K extends keyof HTMLElementTagNameMap>(tag: K, cls?: string, text?: string): HTMLElementTagNameMap[K] {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

function icon(size = 20): SVGSVGElement {
  const ns = 'http://www.w3.org/2000/svg';
  const s = document.createElementNS(ns, 'svg');
  s.setAttribute('width', String(size));
  s.setAttribute('height', String(size));
  s.setAttribute('viewBox', '0 -960 960 960');
  s.setAttribute('aria-hidden', 'true');
  const p = document.createElementNS(ns, 'path');
  p.setAttribute('fill', 'currentColor');
  p.setAttribute('d', hiddenIcon);
  s.appendChild(p);
  return s;
}

/**
 * reels style feeds: the caption shares a box with the video a few levels up, cover the box.
 */
function videoBox(node: Element, viewport: number): HTMLElement | null {
  let cur = node.parentElement;
  for (let i = 0; cur && i < 20; i++, cur = cur.parentElement) {
    if (cur === document.body || cur === document.documentElement) return null;
    const videos = cur.querySelectorAll('video');
    if (videos.length > 1) return null;
    if (videos.length === 1) {
      // box has to hug the video
      const box = cur.getBoundingClientRect();
      const v = videos[0].getBoundingClientRect();
      return v.height >= viewport * 0.5 && box.height < viewport * 1.5 && box.width <= v.width * 1.6 ? cur : null;
    }
  }
  return null;
}

/** known container or the nearest decent sized block */
function containerFor(node: Element): HTMLElement | null {
  const viewport = window.innerHeight || 800;
  // anything in the yt player = whole player
  if (isYouTube) {
    const player = node.closest('#movie_player');
    if (player && !node.closest('.ytp-videowall-still, .ytp-ce-element, .ytp-autonav-endscreen-upnext-container')) {
      return playerBox() ?? (player as HTMLElement);
    }
  }
  if (isTikTok && node.closest(TIKTOK_LAYER)) {
    const video = tiktokOnScreen();
    if (video) return video;
  }
  const fits = (e: Element | null): e is HTMLElement =>
    !!e && e !== document.body && e.getBoundingClientRect().height < viewport * 1.5;
  const known = node.closest(SITE_CONTAINERS);
  if (fits(known)) return known;
  const video = videoBox(node, viewport);
  if (video) return video;
  const generic = node.closest(GENERIC_CONTAINERS);
  if (fits(generic) && generic.getBoundingClientRect().width >= 160) return generic;
  let cur: HTMLElement | null = node as HTMLElement;
  for (let i = 0; cur && i < 8; i++) {
    if (cur === document.body || cur === document.documentElement || cur.tagName === 'MAIN') break;
    const r = cur.getBoundingClientRect();
    const display = getComputedStyle(cur).display;
    if (display !== 'inline' && display !== 'contents' && r.width >= 160 && r.height >= 36) {
      return r.height > viewport * 0.9 ? null : cur;
    }
    cur = cur.parentElement;
  }
  return node instanceof HTMLElement && node !== document.body ? node : null;
}

function hide(target: HTMLElement, hits: Hit[]) {
  if (target.closest('[data-nl-hidden], [data-nl-revealed], [data-nl-gone]')) return;
  const keywords = [...new Set(hits.flatMap((h) => h.keywords))];
  if (hits.some((h) => h.block.matchMode === 'hide')) {
    target.setAttribute('data-nl-gone', '');
  } else {
    cover(target, keywords, target === playerBox() ? () => (playerKeepPaused = false) : undefined);
  }
  // offscreen stuff gets covered but not counted
  const r = target.getBoundingClientRect();
  if (r.width > 0 && r.height > 0) hiddenTotal++;
  for (const h of hits) {
    unsent[h.block.id] = (unsent[h.block.id] ?? 0) + 1;
    const set = (unsentMatched[h.block.id] ??= new Set());
    for (const k of h.keywords) set.add(k);
  }
  if (isYouTube && location.pathname === '/watch' && isVideoItself(target)) coverPlayer(keywords);
  queueSend();
  showToast();
}

/**
 * mark children for blur. display: contents wrappers (facebook) have no box, go a level deeper.
 */
function markBlur(target: HTMLElement) {
  const visit = (e: Element, depth: number) => {
    for (const c of e.children) {
      if (c.classList.contains('nl-cover')) continue;
      if (depth < 6 && getComputedStyle(c).display === 'contents') visit(c, depth + 1);
      else if (!c.hasAttribute('data-nl-blur')) c.setAttribute('data-nl-blur', '');
    }
  };
  visit(target, 0);
}

function cover(target: HTMLElement, keywords: string[], onShow?: () => void, quiet = false) {
  // already covered inside, cover the parent
  target.querySelectorAll<HTMLElement>('[data-nl-hidden]').forEach(uncover);
  // attr not class, X rewrites classes on hover and kills the blur
  target.setAttribute('data-nl-hidden', '');
  target.setAttribute('data-nl-sig', sig(target));
  const style = getComputedStyle(target);
  if (style.position === 'static') target.setAttribute('data-nl-pos', '');
  // bare text nodes can't be filtered, content.css uses a text-shadow instead
  target.style.setProperty('--nl-text', style.color);
  markBlur(target);
  const c = el('div', 'nl-cover');
  if (quiet) {
    target.setAttribute('data-nl-quiet', '');
    for (const type of ['mousedown', 'mouseup', 'pointerdown', 'pointerup', 'touchstart', 'click']) c.addEventListener(type, (e) => e.stopPropagation(), true);
    target.appendChild(c);
    return;
  }
  const pill = el('div', 'nl-pill');
  const why = el('span', 'nl-why', t.hiddenBy);
  if (settings.sayKeyword && keywords.length) {
    why.appendChild(el('small', undefined, t.matched(keywords.map((k) => `"${k}"`).join(', '))));
  }
  const button = el('button', undefined, t.show);
  button.type = 'button';
  pill.append(icon(), why, button);
  c.appendChild(pill);
  let armed = !settings.twoClickReveal;
  // don't let Show click through
  const stop = (e: Event) => {
    e.preventDefault();
    e.stopPropagation();
  };
  for (const type of ['mousedown', 'mouseup', 'pointerdown', 'pointerup', 'touchstart']) c.addEventListener(type, (e) => e.stopPropagation(), true);
  c.addEventListener('click', (e) => {
    stop(e);
    if (e.target !== button) return;
    if (!armed) {
      armed = true;
      button.textContent = t.showAgain;
      return;
    }
    reveal(target);
    // linked parts (tiktok caption)
    document.querySelectorAll<HTMLElement>('[data-nl-quiet][data-nl-hidden]').forEach(reveal);
    onShow?.();
  }, true);
  target.appendChild(c);
  // pause covered videos
  target.querySelectorAll('video').forEach(stopVideo);
}

/** paused by us */
const pausedByUs = new WeakSet<HTMLVideoElement>();
function stopVideo(v: HTMLVideoElement) {
  if (v.paused) return;
  v.pause();
  pausedByUs.add(v);
}
function resumeVideos(box: Element) {
  box.querySelectorAll('video').forEach((v) => {
    if (pausedByUs.has(v) && v.isConnected && v.getBoundingClientRect().height > 0) void v.play().catch(() => undefined);
    pausedByUs.delete(v);
  });
}

function uncover(target: HTMLElement) {
  target.style.removeProperty('--nl-text');
  target.querySelectorAll('[data-nl-blur]').forEach((e) => e.removeAttribute('data-nl-blur'));
  target.removeAttribute('data-nl-hidden');
  target.removeAttribute('data-nl-sig');
  target.removeAttribute('data-nl-quiet');
  target.removeAttribute('data-nl-pos');
  target.querySelectorAll(':scope > .nl-cover').forEach((c) => c.remove());
}

function reveal(target: HTMLElement) {
  uncover(target);
  resumeVideos(target);
  target.setAttribute('data-nl-revealed', '');
  target.setAttribute('data-nl-sig', sig(target));
  shownWords.set(target, words(target));
}

/**
 * words of a shown post. only re-cover once most are gone, sites keep editing posts
 * and feeds reuse boxes for the next video.
 */
const shownWords = new WeakMap<Element, Set<string>>();
function words(c: Element): Set<string> {
  let text = ownText(c);
  c.querySelectorAll('video').forEach((v) => (text += ' ' + (v.currentSrc || v.src)));
  return new Set((text.toLowerCase().match(/[\p{L}\p{N}]{3,}/gu) ?? []).slice(0, 600));
}
function samePost(c: Element): boolean {
  const before = shownWords.get(c);
  if (!before || before.size < 4) return false;
  const now = words(c);
  let kept = 0;
  for (const w of before) if (now.has(w)) kept++;
  return kept / before.size >= 0.6;
}

/** text minus our pill */
function ownText(c: Element): string {
  let text = '';
  const walker = document.createTreeWalker(c, NodeFilter.SHOW_TEXT, {
    acceptNode: (n) => (n.parentElement?.closest('.nl-cover') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT),
  });
  for (let n = walker.nextNode(); n && text.length < 8000; n = walker.nextNode()) text += n.nodeValue + ' ';
  c.querySelectorAll('[aria-label], img[alt], [title]').forEach((e) => {
    if (!e.closest('.nl-cover')) text += ' ' + (e.getAttribute('aria-label') ?? e.getAttribute('alt') ?? e.getAttribute('title') ?? '');
  });
  return text.slice(0, 8000);
}

/** fingerprint to spot box reuse */
function sig(c: Element): string {
  // include video srcs, some boxes have no text
  let text = ownText(c);
  c.querySelectorAll('video').forEach((v) => (text += ' ' + (v.currentSrc || v.src) + ' ' + (v.parentElement?.closest('[id]')?.id ?? '')));
  let h = 5381;
  for (let i = 0; i < text.length; i++) h = ((h << 5) + h + text.charCodeAt(i)) | 0;
  return `${text.length}:${h}`;
}

/**
 * box reuse (shorts/tiktok/reels): recheck covered boxes, reset shown ones.
 */
const changed = new Set<HTMLElement>();
let recheckTimer: ReturnType<typeof setTimeout> | undefined;
function noteChange(n: Node) {
  const e = n instanceof Element ? n : n.parentElement;
  const box = e?.closest<HTMLElement>('[data-nl-hidden], [data-nl-revealed]');
  if (!box || e?.closest('.nl-cover')) return;
  changed.add(box);
  clearTimeout(recheckTimer);
  recheckTimer = setTimeout(recheck, 250);
}

function recheck() {
  const boxes = [...changed];
  changed.clear();
  for (const box of boxes) {
    if (!box.isConnected || box === playerBox()) continue;
    const now = sig(box);
    if (now === box.getAttribute('data-nl-sig')) {
      // same post, new parts
      if (box.hasAttribute('data-nl-hidden')) markBlur(box);
      continue;
    }
    if (box.hasAttribute('data-nl-revealed') && samePost(box)) {
      box.setAttribute('data-nl-sig', now);
    } else if (box.hasAttribute('data-nl-revealed')) {
      shownWords.delete(box);
      box.removeAttribute('data-nl-revealed');
      box.removeAttribute('data-nl-sig');
      scan(box);
    } else if (matchAll(ownText(box)).length) {
      box.setAttribute('data-nl-sig', now);
    } else {
      uncover(box);
      scan(box);
      if (!box.hasAttribute('data-nl-hidden')) resumeVideos(box);
    }
  }
}

/** yt watch player */
function playerBox(): HTMLElement | null {
  return document.querySelector<HTMLElement>('ytd-watch-flexy #player, ytd-watch-flexy #player-container-outer, ytd-watch-flexy #player-container');
}

function isVideoItself(target: HTMLElement): boolean {
  return (
    target === playerBox() ||
    !!target.closest('ytd-watch-metadata, ytd-watch-flexy #below > .box, ytd-watch-flexy #above-the-fold') ||
    !!target.querySelector('ytd-watch-metadata, #above-the-fold')
  );
}

/** cover + pause the watch page video */
let playerKeepPaused = false;
function coverPlayer(keywords: string[]) {
  const player = playerBox();
  if (!player || player.closest('[data-nl-revealed]')) return;
  playerKeepPaused = true;
  pauseVideo();
  if (player.hasAttribute('data-nl-hidden')) return;
  cover(player, keywords, () => {
    playerKeepPaused = false;
  });
}

function pauseVideo() {
  document.querySelectorAll('video').forEach((v) => {
    if (!v.paused) v.pause();
  });
}

// autoplay, keep it paused
document.addEventListener('play', (e) => {
  if (!(e.target instanceof HTMLVideoElement)) return;
  if (playerKeepPaused || e.target.closest('[data-nl-hidden]')) stopVideo(e.target);
}, true);

// yt spa nav, reset
document.addEventListener('yt-navigate-finish', () => {
  playerKeepPaused = false;
  document.querySelectorAll<HTMLElement>('[data-nl-revealed]').forEach((e) => e.removeAttribute('data-nl-revealed'));
  document.querySelectorAll<HTMLElement>('#player-container[data-nl-hidden], #player[data-nl-hidden]').forEach(uncover);
  if (active.length && document.body && observer) scan(document.body);
});

function queueSend() {
  clearTimeout(sendTimer);
  sendTimer = setTimeout(() => {
    const counts = unsent;
    const matched: Record<string, string[]> = {};
    for (const [id, set] of Object.entries(unsentMatched)) matched[id] = [...set];
    unsent = {};
    unsentMatched = {};
    void chrome.runtime
      .sendMessage({ type: 'hidden', counts, matched, target: location.hostname.replace(/^www\./, '') })
      .catch(() => undefined);
  }, 1500);
}

function scan(root: Node) {
  if (!active.length) return;
  if (root.nodeType === Node.TEXT_NODE) {
    check(root as Text);
    return;
  }
  if (!(root instanceof Element) || SKIP.has(root.tagName) || root.closest('head, .nl-cover, .nl-toast')) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode: (n) => {
      const p = n.parentElement;
      if (!p || SKIP.has(p.tagName) || (n.nodeValue?.trim().length ?? 0) < 2) return NodeFilter.FILTER_REJECT;
      return NodeFilter.FILTER_ACCEPT;
    },
  });
  for (let n = walker.nextNode(); n; n = walker.nextNode()) check(n as Text);
  // alt/aria labels
  const labelled = 'img[alt], a[aria-label], a[title], [role="img"][aria-label]';
  const all = root.matches(labelled) ? [root, ...root.querySelectorAll(labelled)] : [...root.querySelectorAll(labelled)];
  for (const e of all) {
    const text = e.getAttribute('alt') || e.getAttribute('aria-label') || e.getAttribute('title') || '';
    if (!text || e.closest('[data-nl-hidden], .nl-cover, [data-nl-revealed], [data-nl-gone]')) continue;
    checkPiece(text, e);
  }
}

function check(node: Text) {
  const text = node.nodeValue ?? '';
  const parent = node.parentElement;
  // skip <head>
  if (!parent || SKIP.has(parent.tagName) || parent.closest('head, [data-nl-hidden], .nl-cover, .nl-toast, [data-nl-revealed], [data-nl-gone]')) return;
  checkPiece(text, parent);
}

let pending: Node[] = [];
let scheduled = false;
function flush() {
  scheduled = false;
  const nodes = pending;
  pending = [];
  for (const n of nodes) if (n.isConnected) scan(n);
  releaseOwnVideo();
}

/** izleme sayfası: videonun sahibi sonradan yüklenir, kendi videonsa erken örtüleni geri aç */
function releaseOwnVideo() {
  if (!exceptions.length || !isYouTube || location.pathname !== '/watch' || !excepted(ownerLink()?.href)) return;
  for (const e of [playerBox(), document.querySelector<HTMLElement>('ytd-watch-metadata')]) {
    if (e?.hasAttribute('data-nl-hidden')) {
      playerKeepPaused = false;
      reveal(e);
    }
  }
}

/**
 * only the visible tab observes, background tabs rescan when shown.
 */
let stale = true;
const onScreen = () => document.visibilityState === 'visible';

function start() {
  if (!document.body) {
    document.addEventListener('DOMContentLoaded', start, { once: true });
    return;
  }
  observer?.disconnect();
  observer = null;
  if (!onScreen()) {
    stale = true;
    return;
  }
  stale = false;
  scan(document.body);
  observer = new MutationObserver((records) => {
    for (const r of records) {
      noteChange(r.target);
      if (r.type === 'characterData') pending.push(r.target);
      else if (r.type === 'attributes') pending.push(r.target);
      else r.addedNodes.forEach((n) => pending.push(n));
    }
    if (!scheduled && pending.length) {
      scheduled = true;
      requestAnimationFrame(flush);
    }
  });
  // yt reuses cards, watch attributes too
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
    attributeFilter: ['aria-label', 'title', 'alt'],
  });
}

document.addEventListener('visibilitychange', () => {
  if (!active.length) return;
  if (onScreen()) {
    if (stale || !observer) start();
  } else {
    observer?.disconnect();
    observer = null;
    pending = [];
    stale = true;
  }
});

/** reset */
function reset() {
  document.querySelectorAll('.nl-cover').forEach((c) => c.remove());
  document.querySelectorAll<HTMLElement>('[data-nl-hidden]').forEach((e) => {
    e.removeAttribute('data-nl-hidden');
    e.removeAttribute('data-nl-pos');
    e.style.removeProperty('--nl-text');
  });
  document.querySelectorAll('[data-nl-gone]').forEach((e) => e.removeAttribute('data-nl-gone'));
  document.querySelectorAll('[data-nl-blur]').forEach((e) => e.removeAttribute('data-nl-blur'));
  playerKeepPaused = false;
  hiddenTotal = 0;
}

let toast: HTMLElement | null = null;
let toastTimer: ReturnType<typeof setTimeout> | undefined;
function showToast() {
  if (window.top !== window) return;
  if (!toast) {
    toast = el('div', 'nl-toast');
    const button = el('button', undefined, t.showAll);
    button.type = 'button';
    toast.append(icon(), el('span'), button);
    button.addEventListener('click', () => {
      document.querySelectorAll<HTMLElement>('[data-nl-hidden]').forEach(reveal);
      document.querySelectorAll<HTMLElement>('[data-nl-gone]').forEach((e) => {
        e.removeAttribute('data-nl-gone');
        e.setAttribute('data-nl-revealed', '');
      });
      playerKeepPaused = false;
      toast?.remove();
      toast = null;
    });
    document.body.appendChild(toast);
  }
  toast.querySelector('span')!.textContent = t.hidOnPage(hiddenTotal);
  toast.classList.add('nl-show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast?.classList.remove('nl-show'), 6000);
}

void chrome.storage.local.get('rules').then((s: Saved) => {
  load(s.rules);
  if (active.length) start();
});

chrome.storage.onChanged.addListener((changes) => {
  if (!changes.rules) return;
  const key = () =>
    JSON.stringify([active.map((a) => [a.block.id, a.block.keywords, a.block.spoilerWords, a.block.topicWords, a.block.matchMode]), settings]);
  const before = key();
  load(changes.rules.newValue as Rules | undefined);
  if (before === key()) return;
  reset();
  if (active.length) start();
  else {
    observer?.disconnect();
    observer = null;
  }
});
