// port of core/lib/src/match.dart

/** normalise, null if not a site */
export function normalizeSite(input: string): string | null {
  let s = input.trim();
  s = s.replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, '');
  s = s.replace(/^www\./i, '');
  s = s.replace(/#.*$/, '');
  while (s.endsWith('/')) s = s.slice(0, -1);
  if (!s || s.includes(' ')) return null;
  const slash = s.search(/[/?]/);
  const host = (slash === -1 ? s : s.slice(0, slash)).toLowerCase();
  if (!/^[a-z0-9-]+(\.[a-z0-9-]+)+(:\d+)?$/.test(host)) return null;
  return host + (slash === -1 ? '' : s.slice(slash));
}

export class SiteRule {
  private constructor(
    readonly text: string,
    readonly host: string,
    /** lowercase, "" = whole site */
    readonly path: string,
  ) {}

  static parse(input: string): SiteRule | null {
    const text = normalizeSite(input);
    if (text === null) return null;
    const slash = text.search(/[/?]/);
    const host = slash === -1 ? text : text.slice(0, slash);
    let path = slash === -1 ? '' : text.slice(slash).toLowerCase();
    if (path.startsWith('?')) path = '/' + path;
    return new SiteRule(text, host, path);
  }

  matches(url: string): boolean {
    let u: URL;
    try {
      u = new URL(url);
    } catch {
      return false;
    }
    if (!u.hostname) return false;
    const h = u.hostname.toLowerCase();
    const hostOnly = this.host.split(':')[0];
    if (h !== hostOnly && !h.endsWith('.' + hostOnly)) return false;
    if (!this.path) return true;
    let full = (u.pathname || '/').toLowerCase();
    if (u.search.length > 1) full += u.search.toLowerCase();
    // compare raw (no decoding), same as dart
    if (!full.startsWith(this.path)) return false;
    if (this.path.includes('?') || full.length === this.path.length) return true;
    return '/?#'.includes(full[this.path.length]);
  }

  /** RE2 for dnr, case insensitive */
  toRegex(): string {
    const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const hostOnly = this.host.split(':')[0];
    const start = `^https?://([^/?#]*\\.)?${esc(hostOnly)}(:[0-9]+)?`;
    if (!this.path) return `${start}([/?#].*)?$`;
    if (this.path.includes('?')) return `${start}${esc(this.path)}.*$`;
    return `${start}${esc(this.path)}([/?#].*)?$`;
  }
}

/** same as dart patternFor */
const dotted: Record<string, string> = { i: '[iİ]', I: '[Iı]', ı: '[ıI]', İ: '[İi]' };

export function keywordPattern(keyword: string): string {
  let k = keyword.trim().replace(/’/g, "'");
  // "final*": Türkçe ekli halleri de yakala (finali, finalde)
  const bare = k.replace(/\*+$/, '');
  const stem = bare !== k && bare.trim().length > 0;
  if (stem) k = bare;
  const parts = k
    .split(/[\s\-_]+/)
    .filter((p) => p.length > 0)
    .map((p) =>
      p
        .replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
        .replace(/[iIıİ]/g, (c) => dotted[c])
        .replace(/'/g, "['’]"),
    );
  return '(?<![\\p{L}\\p{N}])' + parts.join('[\\s\\-_.]*') + (stem ? '' : "(?:['’]s|s|es)?(?![\\p{L}\\p{N}])");
}

export class KeywordMatcher {
  private entries: [string, RegExp][];
  /** combined pattern for a fast no-match */
  private all: RegExp | null;

  constructor(keywords: Iterable<string>) {
    const seen = new Set<string>();
    this.entries = [];
    for (const raw of keywords) {
      const k = raw.trim();
      if (!k || seen.has(k)) continue;
      seen.add(k);
      this.entries.push([k, new RegExp(keywordPattern(k), 'iu')]);
    }
    this.all = this.entries.length ? new RegExp(this.entries.map(([, re]) => `(?:${re.source})`).join('|'), 'iu') : null;
  }

  get isEmpty(): boolean {
    return this.entries.length === 0;
  }

  find(text: string): string[] {
    if (!this.all?.test(text)) return [];
    return this.entries.filter(([, re]) => re.test(text)).map(([k]) => k);
  }

  any(text: string): boolean {
    return !!this.all?.test(text);
  }
}

/** same as dart BlockMatcher */
export class BlockMatcher {
  readonly keywords: KeywordMatcher;
  readonly spoilers: KeywordMatcher;
  readonly topics: KeywordMatcher;

  constructor(lists: { keywords?: string[]; spoilerWords?: string[]; topicWords?: string[] }) {
    this.keywords = new KeywordMatcher(lists.keywords ?? []);
    this.spoilers = new KeywordMatcher(lists.spoilerWords ?? []);
    this.topics = new KeywordMatcher(lists.topicWords ?? []);
  }

  get isEmpty(): boolean {
    return this.keywords.isEmpty && this.spoilers.isEmpty;
  }

  find(text: string): string[] {
    const k = this.keywords.find(text);
    const s = this.spoilers.find(text);
    if (!s.length) return k;
    if (!k.length && !this.topics.any(text)) return k;
    return [...k, ...s];
  }
}
