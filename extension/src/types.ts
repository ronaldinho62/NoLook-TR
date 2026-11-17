// mirrors BrowserRules in core/lib/src/rules.dart

export interface RuleBlock {
  id: string;
  name: string;
  color: 'teal' | 'violet' | 'peach' | 'grey';
  iconText: string | null;
  iconName: string | null;
  /** on and not paused */
  on: boolean;
  /** on + in schedule */
  active: boolean;
  locked: boolean;
  lockLine: string;
  /** bold part of lockLine */
  lockBold?: string;
  keywords: string[];
  spoilerWords?: string[];
  topicWords?: string[];
  sites: string[];
  matchMode: 'blur' | 'hide';
}

export interface Rules {
  type: 'rules';
  at?: string;
  settings?: {
    blurStrength: 'light' | 'strong';
    twoClickReveal: boolean;
    sayKeyword: boolean;
    lang?: 'en' | 'tr';
    /** 'system' | 'en' | 'tr' */
    language?: 'system' | 'en' | 'tr';
  };
  blocks: RuleBlock[];
}

/** in storage.local */
export interface Saved {
  rules?: Rules;
  connected?: boolean;
  problem?: string;
  mode?: 'app' | 'local';
  appSeen?: boolean;
  /** see local.ts */
  local?: import('./local').LocalData;
  nudgeHidden?: boolean;
  /** popup draft */
  draft?: { block: import('./local').LocalBlock; isNew: boolean };
}

export type ToBackground =
  | { type: 'hidden'; counts: Record<string, number>; matched: Record<string, string[]>; target: string }
  | { type: 'blockedPage'; blockId: string; target: string }
  | { type: 'unlock'; blockId: string }
  | { type: 'toggle'; blockId: string }
  | { type: 'newBlock'; site: string }
  | { type: 'open'; tab?: 'settings' }
  | { type: 'setting'; key: SettingKey; value: string | boolean }
  | { type: 'tabInfo'; tabId: number };

export interface TabInfo {
  counts: Record<string, number>;
}

export type SettingKey = 'language' | 'blurStrength' | 'twoClickReveal' | 'sayKeyword';
