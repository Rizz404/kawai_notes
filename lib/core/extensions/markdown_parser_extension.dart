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
}
