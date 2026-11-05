// Current format only. An old ID such as `hep-th/9901001` has a slash, which
// Firestore document IDs, routes and file names cannot hold.
final _idPattern = RegExp(r'^\d{4}\.\d{4,5}(?:v\d+)?$');
final _urlPattern = RegExp(
  r'arxiv\.org/(?:abs|pdf|html)/([^\s?#]+?)(?:\.pdf)?(?:[?#].*)?$',
  caseSensitive: false,
);

/// Normalises what a user typed or shared to a bare arXiv ID without version.
///
/// Accepts `1706.03762`, `arXiv:1706.03762v5`, `arxiv.org/abs/...` and
/// `arxiv.org/pdf/....pdf`. Returns null when the input is not a valid ID.
String? parseArxivId(String input) {
  var value = input.trim();
  if (value.isEmpty) return null;
  final url = _urlPattern.firstMatch(value);
  if (url != null) value = url.group(1)!;
  value = value.replaceFirst(RegExp(r'^arxiv:', caseSensitive: false), '');
  if (!_idPattern.hasMatch(value)) return null;
  return value.replaceFirst(RegExp(r'v\d+$'), '');
}
