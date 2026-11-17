// talks to the app via the helper, stores rules, blocks sites, reports back
import { type LocalData, localRules, startingData } from './local';
import { SiteRule } from './match';
import type { Rules, Saved, ToBackground } from './types';

const HOST = 'com.itszedk.nolook';

const browserName = (() => {
  const ua = navigator.userAgent;
  if (ua.includes('Firefox/')) return 'Firefox';
  if (ua.includes('Edg/')) return 'Edge';
  // chromium forks say Chrome, check the brand list
  const brands = ((navigator as { userAgentData?: { brands?: { brand: string }[] } }).userAgentData?.brands ?? []).map((b) => b.brand);
  if ('brave' in navigator || brands.includes('Brave')) return 'Brave';
  if (brands.some((b) => b.startsWith('Opera')) || ua.includes('OPR/')) return 'Opera';
  if (brands.includes('Vivaldi') || ua.includes('Vivaldi/')) return 'Vivaldi';
  return 'Chrome';
})();

let port: chrome.runtime.Port | null = null;
let rules: Rules = { type: 'rules', blocks: [] };
let mode: 'app' | 'local' = 'local';
let appSeen = false;
let retry: ReturnType<typeof setTimeout> | undefined;
/** fast retries first, then back off */
let failures = 0;
const retryAfter = () => [1_000, 3_000, 10_000][failures++] ?? 30_000;

/** per tab counts for the popup + badge */
const tabCounts = new Map<number, Record<string, number>>();

async function save(patch: Saved) {
  await chrome.storage.local.set(patch);
}

function connect() {
  clearTimeout(retry);
  if (port) return;
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch (e) {
    void save({ connected: false, problem: String(e) });
    retry = setTimeout(connect, retryAfter());
    return;
  }
  port.onMessage.addListener((m: Rules | { type: string }) => {
    if (m.type === 'rules') void onRules(m as Rules);
  });
  port.onDisconnect.addListener(() => {
    const problem = chrome.runtime.lastError?.message ?? 'Disconnected';
    port = null;
    void save({ connected: false, problem });
    // no app, use local blocks
    if (!appSeen) void useLocal();
    // helper missing/crashed, keep the last rules and retry
    retry = setTimeout(connect, retryAfter());
  });
  port.postMessage({ type: 'hello', browser: browserName });
}

function post(message: object) {
  if (!port) connect();
  try {
    port?.postMessage(message);
  } catch {
    port = null;
  }
}

async function onRules(r: Rules) {
  failures = 0;
  rules = r;
  mode = 'app';
  appSeen = true;
  // site rules first
  await updateSiteRules();
  await save({ rules: r, connected: true, problem: '', mode, appSeen });
  await checkOpenTabs();
}

async function localData(): Promise<LocalData> {
  const s = (await chrome.storage.local.get('local')) as Saved;
  if (s.local) return s.local;
  const d = startingData();
  await save({ local: d });
  return d;
}

/** local blocks -> rules */
async function useLocal() {
  if (appSeen) return;
  mode = 'local';
  rules = localRules(await localData());
  await updateSiteRules();
  await save({ rules, mode });
  await checkOpenTabs();
}

async function changeLocal(change: (d: LocalData) => void) {
  const d = await localData();
  change(d);
  await save({ local: d });
}

// popup edited local blocks
chrome.storage.onChanged.addListener((changes) => {
  if (changes.local && mode === 'local') void useLocal();
});

const blockedPage = chrome.runtime.getURL('blocked.html');

function blockFor(url: string): { blockId: string; site: string } | null {
  if (!/^https?:/.test(url)) return null;
  for (const b of rules.blocks) {
    if (!b.active) continue;
    for (const s of b.sites) {
      if (SiteRule.parse(s)?.matches(url)) return { blockId: b.id, site: s };
    }
  }
  return null;
}

function blockedUrl(blockId: string, url: string) {
  return `${blockedPage}?b=${encodeURIComponent(blockId)}#${url}`;
}

/** dnr redirect per site */
async function updateSiteRules() {
  const add: chrome.declarativeNetRequest.Rule[] = [];
  let id = 1;
  for (const b of rules.blocks) {
    if (!b.active) continue;
    for (const s of b.sites) {
      const rule = SiteRule.parse(s);
      if (!rule) continue;
      add.push({
        id: id++,
        priority: 1,
        action: {
          type: 'redirect' as chrome.declarativeNetRequest.RuleActionType,
          redirect: { regexSubstitution: `${blockedPage}?b=${encodeURIComponent(b.id)}#\\0` },
        },
        condition: {
          regexFilter: rule.toRegex(),
          isUrlFilterCaseSensitive: false,
          resourceTypes: ['main_frame' as chrome.declarativeNetRequest.ResourceType],
        },
      });
    }
  }
  const old = await chrome.declarativeNetRequest.getDynamicRules();
  try {
    await chrome.declarativeNetRequest.updateDynamicRules({ removeRuleIds: old.map((r) => r.id), addRules: add });
  } catch (e) {
    // rule can get refused (regex too big), the url check below still catches it
    console.warn('NoLook: some site rules were not accepted', e);
  }
}

/** spa navigation */
chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (info.url) void checkTab(tabId, info.url);
});

async function checkTab(tabId: number, url: string) {
  const hit = blockFor(url);
  if (hit) await chrome.tabs.update(tabId, { url: blockedUrl(hit.blockId, url) }).catch(() => undefined);
}

async function checkOpenTabs() {
  for (const t of await chrome.tabs.query({})) {
    if (t.id !== undefined && t.url) await checkTab(t.id, t.url);
  }
}

function setBadge(tabId: number) {
  const total = Object.values(tabCounts.get(tabId) ?? {}).reduce((a, b) => a + b, 0);
  void chrome.action.setBadgeText({ tabId, text: total ? String(total) : '' }).catch(() => undefined);
}
void chrome.action.setBadgeBackgroundColor({ color: '#305f9b' }).catch(() => undefined);

chrome.tabs.onRemoved.addListener((tabId) => tabCounts.delete(tabId));
chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (info.status === 'loading') {
    tabCounts.delete(tabId);
    setBadge(tabId);
  }
});

chrome.runtime.onMessage.addListener((m: ToBackground, sender, reply) => {
  const tabId = sender.tab?.id;
  switch (m.type) {
    case 'hidden': {
      if (mode === 'local') {
        if (tabId !== undefined) {
          const now = tabCounts.get(tabId) ?? {};
          for (const [id, n] of Object.entries(m.counts)) now[id] = (now[id] ?? 0) + n;
          tabCounts.set(tabId, now);
          setBadge(tabId);
        }
        break;
      }
      if (tabId !== undefined) {
        const now = tabCounts.get(tabId) ?? {};
        for (const [id, n] of Object.entries(m.counts)) now[id] = (now[id] ?? 0) + n;
        tabCounts.set(tabId, now);
        setBadge(tabId);
      }
      for (const [blockId, count] of Object.entries(m.counts)) {
        if (count > 0) post({ type: 'event', kind: 'blurred', blockId, target: m.target, matched: m.matched[blockId] ?? [], count });
      }
      break;
    }
    case 'blockedPage':
      if (mode === 'app') post({ type: 'event', kind: 'blocked', blockId: m.blockId, target: m.target, count: 1 });
      break;
    case 'unlock':
    case 'toggle':
      if (mode === 'local') {
        void changeLocal((d) => d.blocks.filter((b) => b.id === m.blockId).forEach((b) => (b.on = !b.on)));
      } else {
        post({ type: m.type, blockId: m.blockId });
      }
      break;
    case 'newBlock':
      if (mode === 'local') {
        // no app: add to a "Blocked sites" block
        void changeLocal((d) => {
          const lang = rules.settings?.lang ?? 'en';
          let b = d.blocks.find((x) => x.id === 'sites');
          if (!b) {
            b = { id: 'sites', name: lang === 'tr' ? 'Engellenen siteler' : 'Blocked sites', color: 'violet', iconText: null, iconName: 'block', on: true, keywords: [], spoilerWords: [], topicWords: [], sites: [] };
            d.blocks.push(b);
          }
          b.on = true;
          if (!b.sites.includes(m.site)) b.sites.push(m.site);
        });
      } else {
        post({ type: 'newBlock', site: m.site });
      }
      break;
    case 'open':
      post({ type: 'open', tab: m.tab });
      break;
    case 'setting':
      if (mode === 'local') {
        void changeLocal((d) => {
          (d.settings as Record<string, unknown>)[m.key] = m.value;
        });
      } else {
        post({ type: 'setting', key: m.key, value: m.value });
      }
      break;
    case 'tabInfo':
      reply({ counts: tabCounts.get(m.tabId) ?? {} });
      return true;
  }
  return false;
});

// reconnect when the worker restarts
chrome.alarms.create('nolook-keepalive', { periodInMinutes: 1 });
chrome.alarms.onAlarm.addListener(() => connect());
chrome.runtime.onStartup.addListener(() => connect());
chrome.runtime.onInstalled.addListener(() => connect());

void chrome.storage.local.get(['rules', 'mode', 'appSeen']).then((s: Saved) => {
  if (s.rules) rules = s.rules;
  // older versions only stored app rules
  appSeen = !!s.appSeen || (!!s.rules && !s.mode);
  mode = s.mode ?? (appSeen ? 'app' : 'local');
  if (!appSeen) void useLocal();
  connect();
});
