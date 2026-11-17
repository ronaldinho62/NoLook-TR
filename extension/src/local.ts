// local blocks for when the app isn't installed, replaced by app blocks once it connects
import presetList from './presets.gen.json';
import type { RuleBlock, Rules } from './types';

export interface LocalBlock {
  id: string;
  name: string;
  color: RuleBlock['color'];
  iconText: string | null;
  /** material symbols name, wins over iconText */
  iconName?: string | null;
  on: boolean;
  keywords: string[];
  spoilerWords: string[];
  topicWords: string[];
  sites: string[];
}

export interface LocalData {
  blocks: LocalBlock[];
  settings: NonNullable<Rules['settings']>;
}

type Lang = 'en' | 'tr';

export function browserLang(): Lang {
  return navigator.language.toLowerCase().startsWith('en') ? 'en' : 'tr';
}

export function langOf(settings: LocalData['settings']): Lang {
  return settings.language === 'en' || settings.language === 'tr' ? settings.language : browserLang();
}

export function newId(): string {
  return Math.random().toString(36).slice(2, 10);
}

/** empty, the popup offers presets */
export function startingData(): LocalData {
  return {
    blocks: [],
    settings: { blurStrength: 'strong', twoClickReveal: false, sayKeyword: true, language: 'system' },
  };
}

export const presets = presetList;
export type Preset = (typeof presetList)[number];

export function fromPreset(p: Preset, lang: Lang): LocalBlock {
  return {
    id: newId(),
    name: p.name[lang],
    color: p.color as RuleBlock['color'],
    iconText: p.iconText,
    on: true,
    keywords: [...p.keywords],
    spoilerWords: [...p.spoilerWords],
    topicWords: [...p.topicWords],
    sites: [...p.sites],
  };
}

export function emptyBlock(): LocalBlock {
  return { id: newId(), name: '', color: 'grey', iconText: null, on: true, keywords: [], spoilerWords: [], topicWords: [], sites: [] };
}

/** "37 keywords, 11 sites" */
export function summary(b: LocalBlock, lang: Lang): string {
  // count like the app
  const k = b.keywords.length + b.spoilerWords.length + b.topicWords.length;
  const s = b.sites.length;
  if (lang === 'tr') return [k && `${k} anahtar kelime`, s && `${s} site`].filter(Boolean).join(', ') || 'Boş';
  return [k && `${k} keyword${k === 1 ? '' : 's'}`, s && `${s} site${s === 1 ? '' : 's'}`].filter(Boolean).join(', ') || 'Empty';
}

export function localRules(d: LocalData): Rules {
  const lang = langOf(d.settings);
  return {
    type: 'rules',
    at: new Date().toISOString(),
    settings: { ...d.settings, lang },
    blocks: d.blocks.map((b) => ({
      id: b.id,
      name: b.name,
      color: b.color,
      iconText: b.iconText,
      iconName: b.iconName ?? null,
      on: b.on,
      active: b.on,
      locked: false,
      lockLine: summary(b, lang),
      keywords: b.keywords,
      spoilerWords: b.spoilerWords,
      topicWords: b.topicWords,
      sites: b.sites,
      matchMode: 'blur',
    })),
  };
}
