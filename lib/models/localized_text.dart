import 'dart:ui';

/// Bundled content text that carries its own English and Thai versions.
/// Thai is used for a `th` locale when present and non-empty; otherwise
/// English.
class LocalizedText {
  const LocalizedText({required this.en, this.th});

  final String en;
  final String? th;

  factory LocalizedText.fromJson(Map<String, dynamic> json) =>
      LocalizedText(en: json['en'] as String, th: json['th'] as String?);

  String resolve(Locale locale) {
    final thai = th;
    return locale.languageCode == 'th' && thai != null && thai.isNotEmpty
        ? thai
        : en;
  }
}

/// List counterpart of [LocalizedText] (steps, tips, mistakes).
class LocalizedList {
  const LocalizedList({required this.en, this.th});

  final List<String> en;
  final List<String>? th;

  factory LocalizedList.fromJson(Map<String, dynamic> json) => LocalizedList(
    en: (json['en'] as List).cast<String>(),
    th: (json['th'] as List?)?.cast<String>(),
  );

  List<String> resolve(Locale locale) {
    final thai = th;
    return locale.languageCode == 'th' && thai != null && thai.isNotEmpty
        ? thai
        : en;
  }
}
