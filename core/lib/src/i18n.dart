/// en/tr, strings inline: `tr('Blocks', 'Engeller')`
enum Lang { en, tr }

Lang currentLang = Lang.tr;

bool get isTr => currentLang == Lang.tr;

String tr(String en, String turkce) => currentLang == Lang.tr ? turkce : en;

/// Türkçe sürüm: sistem dili İngilizce değilse Türkçe açılır
Lang langForLocale(String locale) => locale.toLowerCase().startsWith('en') ? Lang.en : Lang.tr;
