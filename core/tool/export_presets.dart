// presets for the extension (used without the app)
// Run from core/: dart run tool/export_presets.dart
import 'dart:convert';
import 'dart:io';

import 'package:nolook_core/nolook_core.dart';

String presetsJson() {
  Map<String, Object> one(Preset p, Preset turkce) => {
        'id': p.id,
        'name': {'en': p.name, 'tr': turkce.name},
        'iconText': p.iconText,
        'color': p.color.name,
        'keywords': p.keywords,
        'spoilerWords': p.spoilerWords,
        'topicWords': p.topicWords,
        'sites': p.sites,
      };
  final before = currentLang;
  currentLang = Lang.en;
  final en = presets;
  currentLang = Lang.tr;
  final turkce = presets;
  currentLang = before;
  return '${const JsonEncoder.withIndent('  ').convert([for (var i = 0; i < en.length; i++) one(en[i], turkce[i])])}\n';
}

void main() {
  File('../extension/src/presets.gen.json').writeAsStringSync(presetsJson());
  print('Wrote extension/src/presets.gen.json');
}
