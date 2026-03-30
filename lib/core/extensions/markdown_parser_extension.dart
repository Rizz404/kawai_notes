extension MarkdownParserExtension on String {
  List<String> extractTags() {
    final regex = RegExp(r'(^|\s)#([a-zA-Z0-9_]+)');
    final matches = regex.allMatches(this);
    return matches.map((m) => m.group(2)!).toSet().toList();
  }

  List<String> extractLinks() {
    final regex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = regex.allMatches(this);
    return matches.map((m) => m.group(1)!).toSet().toList();
  }

  String toPlainText() {
    var text = this;
    text = text.replaceAllMapped(
      RegExp(r'^#{1,6}\s+(.*)$', multiLine: true),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m[1] ?? '',
    );
    text = text.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (m) => '');
    text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(RegExp(r'```.*?```', dotAll: true), (m) => '');
    text = text.replaceAllMapped(
      RegExp(r'^\s*>\s+', multiLine: true),
      (m) => '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true),
      (m) => '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*[-*+]\s+', multiLine: true),
      (m) => '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*\d+\.\s+', multiLine: true),
      (m) => '',
    );
    text = text.replaceAll(RegExp(r'\n+'), ' ');
    return text.trim();
  }
}
