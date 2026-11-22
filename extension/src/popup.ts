// toolbar popup. without the app it edits local blocks (local.ts)
import { setHtml } from './dom';
import { type LocalBlock, type Preset, emptyBlock, fromPreset, langOf, presets, summary } from './local';
import type { Rules, Saved, SettingKey, TabInfo } from './types';
import { stringsFor } from './strings';
import { blockIcon, brandmark, esc, icon, lockLineHtml, send } from './ui';

const app = document.getElementById('app')!;

const appUrl = 'https://github.com/ronaldinho62/NoLook-TR/releases/latest';

/**
 * main, settings, and (no app) chooser + editor
 */
let view: 'main' | 'settings' | 'pick' | 'block' = 'main';
let firstRender = true;

/** draft, kept if the popup closes */
let draft: NonNullable<Saved['draft']> | undefined;

/** optimistic changes */
const pending: Partial<Record<SettingKey, string | boolean>> = {};

async function load(): Promise<Saved> {
  return (await chrome.storage.local.get(['rules', 'connected', 'problem', 'mode', 'local', 'nudgeHidden', 'draft'])) as Saved;
}

function keepDraft() {
  if (draft) void chrome.storage.local.set({ draft });
}

function openEditor(block: LocalBlock, isNew: boolean) {
  draft = { block, isNew };
  keepDraft();
  view = 'block';
  void render();
}

async function closeEditor() {
  draft = undefined;
  await chrome.storage.local.remove('draft');
  view = 'main';
  void render();
}

function presetRows(lang: 'en' | 'tr'): string {
  return presets
    .map((p) => {
      const b = fromPreset(p, lang);
      return `<div class="bl pick" data-preset="${esc(p.id)}">
        <span class="ic c-${b.color}">${blockIcon({ ...b, iconName: null })}</span>
        <div class="tx"><div class="t">${esc(b.name)}</div><div class="s">${esc(summary(b, lang))}</div></div>
        <span class="go">${icon('add', 20)}</span>
      </div>`;
    })
    .join('');
}

function wirePresetRows(lang: 'en' | 'tr') {
  app.querySelectorAll<HTMLElement>('.bl.pick[data-preset]').forEach((row) =>
    row.addEventListener('click', () => {
      const p = presets.find((x) => x.id === row.dataset.preset) as Preset | undefined;
      openEditor(p ? fromPreset(p, lang) : emptyBlock(), true);
    }),
  );
}

async function render() {
  const saved = await load();
  const local = saved.mode === 'local' && !!saved.local;
  // restore the draft
  if (firstRender && local && saved.draft) {
    draft = saved.draft;
    view = 'block';
  }
  firstRender = false;
  if (view === 'settings') return renderSettings(saved);
  if (view === 'pick' && local) return renderPick(saved);
  if (view === 'block' && local && draft) return renderBlock(saved);
  view = 'main';
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  let host = '';
  try {
    const u = new URL(tab?.url ?? '');
    if (u.protocol === 'http:' || u.protocol === 'https:') host = u.hostname.replace(/^www\./, '');
  } catch {
    /* not a web page */
  }
  const info = (tab?.id !== undefined ? await send({ type: 'tabInfo', tabId: tab.id }) : undefined) as TabInfo | undefined;
  const counts = info?.counts ?? {};
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  const blocks = saved.rules?.blocks ?? [];
  const t = stringsFor(saved.rules);
  const lang = local ? langOf(saved.local!.settings) : 'en';
  document.documentElement.lang = saved.rules?.settings?.lang ?? 'en';

  const here = host
    ? `<div class="here">
        <div class="site">${icon('language', 16)}${esc(host)}</div>
        <div class="n">${total}</div>
        <div class="l">${esc(t.hiddenOnPage(total))}</div>
        ${total ? `<div class="chips">${blocks
          .filter((b) => counts[b.id])
          .map((b) => `<span class="chip">${esc(b.name)}: ${counts[b.id]}</span>`)
          .join('')}</div>` : ''}
      </div>`
    : '';

  // only if the app connected before
  const problem =
    local || saved.connected !== false
      ? ''
      : `<div class="problem"><b>${esc(t.notConnected)}</b>${esc(t.notConnectedText)}</div>`;

  const nudge =
    local && !saved.nudgeHidden
      ? `<div class="nudge">
          <div class="nt">${icon('download', 20)}<b>${esc(t.getApp)}</b></div>
          <div class="ns">${esc(t.getAppText)}</div>
          <div class="nb"><button class="btn tonal small" id="get-app">${esc(t.getAppButton)}</button><button class="btn text small" id="not-now">${esc(t.notNow)}</button></div>
        </div>`
      : '';

  setHtml(app, `
    <div class="ptop">${brandmark}<button class="icon-btn" id="settings" title="${esc(t.settings)}">${icon('settings')}</button></div>
    ${problem}${here}
    <div class="list">
      <h4>${esc(t.yourBlocks)}</h4>
      ${blocks.length ? '' : `<div class="empty">${esc(local ? t.noBlocksLocal : t.noBlocks)}</div>${local ? presetRows(lang) : ''}`}
      ${blocks
        .map(
          (b) => `<div class="bl${local ? ' edit' : ''}" data-id="${esc(b.id)}">
            <span class="ic c-${b.color}">${blockIcon(b)}</span>
            <div class="tx"><div class="t">${esc(b.name)}</div><div class="s">${lockLineHtml(b.lockLine, b.lockBold)}</div></div>
            <button class="switch" role="switch" data-id="${esc(b.id)}" aria-checked="${b.on}" data-locked="${b.locked}"
              title="${esc(b.locked ? t.lockedTap : b.on ? t.turnOff : t.turnOn)}"><span class="th">${icon('lock', 14, true)}</span></button>
          </div>`,
        )
        .join('')}
    </div>
    ${nudge}
    <div class="pexc" id="pexc" hidden><button class="btn outlined has-ic" id="exc-page"></button><div class="exc-msg" id="exc-page-msg"></div></div>
    <div class="pfoot">
      <button class="btn tonal has-ic" id="block-site" ${host ? '' : 'disabled'}>${icon('add', 18)}${esc(t.blockSite)}</button>
      ${local
        ? `<button class="btn outlined has-ic" id="new">${icon('add', 18)}${esc(t.newBlock)}</button>`
        : `<button class="btn outlined" id="open">${esc(t.openApp)}</button>`}
    </div>`);

  app.querySelectorAll<HTMLButtonElement>('.switch').forEach((s) =>
    s.addEventListener('click', (e) => {
      e.stopPropagation();
      // the app decides, locked ones open unlock in the app
      void send({ type: s.dataset.locked === 'true' ? 'unlock' : 'toggle', blockId: s.dataset.id });
      if (s.dataset.locked === 'true') window.close();
    }),
  );
  if (local) {
    app.querySelectorAll<HTMLElement>('.bl.edit').forEach((row) =>
      row.addEventListener('click', () => {
        const b = saved.local!.blocks.find((x) => x.id === row.dataset.id);
        if (b) openEditor(structuredClone(b), false);
      }),
    );
    wirePresetRows(lang);
    document.getElementById('new')!.addEventListener('click', () => {
      view = 'pick';
      void render();
    });
    document.getElementById('get-app')?.addEventListener('click', () => void chrome.tabs.create({ url: appUrl }).then(() => window.close()));
    document.getElementById('not-now')?.addEventListener('click', () => void chrome.storage.local.set({ nudgeHidden: true }));
  } else {
    document.getElementById('open')!.addEventListener('click', () => void send({ type: 'open' }).then(() => window.close()));
  }
  document.getElementById('settings')!.addEventListener('click', () => {
    view = 'settings';
    void render();
  });
  void wirePageException(saved);
  document.getElementById('block-site')!.addEventListener('click', () => {
    void send({ type: 'newBlock', site: host }).then(() => {
      if (!local) window.close();
    });
  });
}

/** açık sekmedeki kanal/profil (youtube kanalı, videonun sahibi, X profili), yoksa null */
async function pageCandidate(): Promise<string | null> {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab?.id === undefined) return null;
    return ((await chrome.tabs.sendMessage(tab.id, { type: 'exceptionCandidate' })) as { site: string | null } | undefined)?.site ?? null;
  } catch {
    // içerik betiği yok (yeni sekme, chrome:// sayfası)
    return null;
  }
}

/** ana görünüm: "Bu siteyi engelle"nin üstünde, sayfanın kanalını istisnalara ekle/çıkar */
async function wirePageException(saved: Saved) {
  const t = stringsFor(saved.rules);
  const site = await pageCandidate();
  const row = document.getElementById('pexc');
  const btn = document.getElementById('exc-page') as HTMLButtonElement | null;
  const msg = document.getElementById('exc-page-msg');
  if (!site || !row || !btn || !msg) return;
  const listed = (saved.rules?.settings?.exceptions ?? []).some((e) => e.toLowerCase() === site.toLowerCase());
  setHtml(btn, `${icon(listed ? 'close' : 'add', 18)}<span>${esc(listed ? t.removePageException(site) : t.addPageException(site))}</span>`);
  btn.title = listed ? t.removePageException(site) : t.addPageException(site);
  row.hidden = false;
  btn.addEventListener('click', async () => {
    btn.disabled = true;
    await send({ type: 'exception', site, remove: listed });
    msg.textContent = listed ? t.exceptionRemoved(site) : t.exceptionAdded(site);
  });
}

function renderPick(saved: Saved) {
  const t = stringsFor(saved.rules);
  const lang = langOf(saved.local!.settings);
  setHtml(app, `
    <div class="ptop sub"><button class="icon-btn" id="back" title="${esc(t.back)}">${icon('arrow_back')}</button><div class="ttl">${esc(t.newBlock)}</div></div>
    <div class="note">${esc(t.startFrom)}</div>
    <div class="list">
      <div class="bl pick" data-preset="">
        <span class="ic c-grey">${icon('add', 20)}</span>
        <div class="tx"><div class="t">${esc(t.emptyBlock)}</div><div class="s">${esc(t.emptyBlockText)}</div></div>
      </div>
      <h4>${esc(t.presets)}</h4>
      ${presetRows(lang)}
    </div>`);
  wirePresetRows(lang);
  document.getElementById('back')!.addEventListener('click', () => {
    view = 'main';
    void render();
  });
}

/** strip scheme, www, trailing / */
function cleanSite(v: string): string {
  return v.trim().replace(/^https?:\/\//i, '').replace(/^www\./i, '').replace(/\/$/, '');
}

/** local block editor */
function renderBlock(saved: Saved) {
  const t = stringsFor(saved.rules);
  const { block: b, isNew } = draft!;
  const chips = (list: string[], kind: string) =>
    list
      .map((v, i) => `<span class="chip ed">${esc(v)}<button class="x" data-kind="${kind}" data-i="${i}" title="${esc(t.remove)}">${icon('close', 14)}</button></span>`)
      .join('');
  const context = b.spoilerWords.length + b.topicWords.length;
  const adder = (id: string, placeholder: string) =>
    `<div class="adder"><input id="${id}" placeholder="${esc(placeholder)}"><button class="icon-btn" data-for="${id}" title="${esc(t.add)}">${icon('add')}</button></div>`;

  setHtml(app, `
    <div class="ptop sub"><button class="icon-btn" id="back" title="${esc(t.cancel)}">${icon('arrow_back')}</button><div class="ttl">${esc(isNew ? t.newBlock : t.editBlock)}</div>
      ${isNew ? '' : `<button class="icon-btn" id="delete" title="${esc(t.deleteBlock)}">${icon('delete')}</button>`}</div>
    <div class="form">
      <label class="field"><span>${esc(t.name)}</span><input id="name" value="${esc(b.name)}" placeholder="${esc(t.namePlaceholder)}" maxlength="40"></label>
      <div class="lbl">${esc(t.keywords)} <span class="cnt">${b.keywords.length}</span></div>
      ${adder('add-keyword', t.addKeyword)}
      <div class="chips">${chips(b.keywords, 'keywords')}</div>
      ${context ? `<div class="hint">${esc(t.contextWords(context))}</div>` : ''}
      <div class="lbl">${esc(t.sites)} <span class="cnt">${b.sites.length}</span></div>
      ${adder('add-site', t.addSite)}
      <div class="chips">${chips(b.sites, 'sites')}</div>
      <div class="hint">${esc(t.appExtras)}</div>
    </div>
    <div class="pfoot stick"><button class="btn outlined" id="cancel">${esc(t.cancel)}</button><button class="btn filled" id="save">${esc(isNew ? t.create : t.save)}</button></div>`);

  const name = document.getElementById('name') as HTMLInputElement;
  name.addEventListener('input', () => {
    b.name = name.value;
    keepDraft();
  });
  const addFrom = (id: 'add-keyword' | 'add-site'): boolean => {
    const input = document.getElementById(id) as HTMLInputElement;
    const key = id === 'add-keyword' ? 'keywords' : 'sites';
    const v = key === 'sites' ? cleanSite(input.value) : input.value.trim();
    input.value = '';
    if (!v || b[key].some((y) => y.toLowerCase() === v.toLowerCase())) return false;
    b[key].unshift(v);
    return true;
  };
  for (const id of ['add-keyword', 'add-site'] as const) {
    const again = () => {
      addFrom(id);
      keepDraft();
      renderBlock(saved);
      document.getElementById(id)?.focus();
    };
    document.getElementById(id)!.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') again();
    });
    app.querySelector(`[data-for="${id}"]`)!.addEventListener('click', again);
  }
  app.querySelectorAll<HTMLButtonElement>('.x').forEach((btn) =>
    btn.addEventListener('click', () => {
      const kind = btn.dataset.kind as 'keywords' | 'sites';
      b[kind].splice(Number(btn.dataset.i), 1);
      keepDraft();
      renderBlock(saved);
    }),
  );
  document.getElementById('save')!.addEventListener('click', async () => {
    // include unsubmitted input
    addFrom('add-keyword');
    addFrom('add-site');
    b.name = b.name.trim() || t.newBlock;
    const { local } = (await chrome.storage.local.get('local')) as Saved;
    if (local) {
      const i = local.blocks.findIndex((x) => x.id === b.id);
      // keep the current on/off
      if (i >= 0) local.blocks[i] = { ...b, on: local.blocks[i].on };
      else local.blocks.push(b);
      await chrome.storage.local.set({ local });
    }
    await closeEditor();
  });
  document.getElementById('cancel')!.addEventListener('click', () => void closeEditor());
  document.getElementById('back')!.addEventListener('click', () => void closeEditor());
  document.getElementById('delete')?.addEventListener('click', async () => {
    const { local } = (await chrome.storage.local.get('local')) as Saved;
    if (local) {
      local.blocks = local.blocks.filter((x) => x.id !== b.id);
      await chrome.storage.local.set({ local });
    }
    await closeEditor();
  });
}

/** mini settings */
function renderSettings(saved: Saved) {
  const rules: Rules | undefined = saved.rules;
  const t = stringsFor(rules);
  const local = saved.mode === 'local';
  const s = rules?.settings;
  const value = <T extends string | boolean>(key: SettingKey, fallback: T): T => ((pending[key] ?? (s as Record<string, unknown> | undefined)?.[key] ?? fallback) as T);
  const seg = (key: SettingKey, options: [string | boolean, string][], current: string | boolean) =>
    `<div class="seg" data-key="${key}">${options
      .map(([v, label]) => `<button data-value="${String(v)}" aria-pressed="${v === current}">${esc(label)}</button>`)
      .join('')}</div>`;
  const ready = !!s;

  setHtml(app, `
    <div class="ptop sub"><button class="icon-btn" id="back" title="${esc(t.back)}">${icon('arrow_back')}</button><div class="ttl">${esc(t.settings)}</div></div>
    ${ready ? `<div class="sets">
      <div class="set"><div class="lbl">${esc(t.language)}</div>${seg('language', [['system', t.system], ['en', 'English'], ['tr', 'Türkçe']], value('language', 'system'))}</div>
      <div class="set"><div class="lbl">${esc(t.blur)}</div>${seg('blurStrength', [['light', t.light], ['strong', t.strong]], value('blurStrength', 'strong'))}</div>
      <div class="set"><div class="lbl">${esc(t.revealWith)}</div>${seg('twoClickReveal', [[false, t.oneClick], [true, t.twoClicks]], value('twoClickReveal', false))}</div>
      <div class="set row"><div><div class="lbl">${esc(t.sayKeyword)}</div><div class="sub">${esc(t.sayKeywordSub)}</div></div>
        <button class="switch" role="switch" id="say" aria-checked="${value('sayKeyword', true)}"><span class="th"></span></button></div>
      <div class="set"><div class="lbl">${esc(t.exceptions)}</div><div class="sub">${esc(t.exceptionsSub)}</div>
        ${(s?.exceptions ?? []).map((e) => `<div class="exc"><span>${esc(e)}</span><button class="icon-btn exc-rm" data-site="${esc(e)}" title="${esc(t.remove)}">${icon('close', 18)}</button></div>`).join('')}
        <button class="btn outlined has-ic" id="exc-add">${icon('add', 18)}${esc(t.addException)}</button>
        <div class="exc-msg" id="exc-msg"></div></div>
    </div>` : `<div class="note">${esc(t.settingsNeedApp)}</div>`}
    <div class="pfoot"><button class="btn outlined has-ic" id="more">${icon(local ? 'download' : 'open_in_new', 18)}${esc(local ? t.getApp : t.moreSettings)}</button></div>`);

  const change = (key: SettingKey, v: string | boolean) => {
    pending[key] = v;
    void send({ type: 'setting', key, value: v });
    renderSettings(saved);
  };
  app.querySelectorAll<HTMLElement>('.seg').forEach((g) =>
    g.querySelectorAll<HTMLButtonElement>('button').forEach((b) =>
      b.addEventListener('click', () => {
        const raw = b.dataset.value!;
        change(g.dataset.key as SettingKey, raw === 'true' ? true : raw === 'false' ? false : raw);
      }),
    ),
  );
  document.getElementById('say')?.addEventListener('click', () => change('sayKeyword', !value('sayKeyword', true)));
  app.querySelectorAll<HTMLElement>('.exc-rm').forEach((b) =>
    b.addEventListener('click', () => void send({ type: 'exception', site: b.dataset.site!, remove: true })),
  );
  document.getElementById('exc-add')?.addEventListener('click', async () => {
    const msg = document.getElementById('exc-msg')!;
    const site = await pageCandidate();
    if (!site) {
      msg.textContent = t.noException;
      return;
    }
    await send({ type: 'exception', site });
    msg.textContent = t.exceptionAdded(site);
  });
  document.getElementById('back')!.addEventListener('click', () => {
    view = 'main';
    void render();
  });
  document.getElementById('more')!.addEventListener('click', () =>
    local
      ? void chrome.tabs.create({ url: appUrl }).then(() => window.close())
      : void send({ type: 'open', tab: 'settings' }).then(() => window.close()),
  );
}

void render();
chrome.storage.onChanged.addListener((changes) => {
  // the app wins over optimistic state
  if (changes.rules) for (const k of Object.keys(pending)) delete pending[k as SettingKey];
  // don't redraw the editor/chooser, it'd lose input
  if (view === 'block' || view === 'pick') return;
  void render();
});
