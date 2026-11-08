/// Strips query parameters and fragments (auth codes, tokens, note ids)
/// from a URI so it can be logged safely.
String redactUriForLog(Uri uri) {
  final hasSensitive = uri.hasQuery || uri.hasFragment;
  final base = uri.replace(query: '', fragment: '').toString();
  final clean = base.replaceAll(RegExp(r'[?#]+$'), '');
  return hasSensitive ? '$clean?<redacted>' : clean;
}
