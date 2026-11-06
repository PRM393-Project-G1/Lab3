/// Adds http:// when missing, since Tailscale addresses are plain HTTP, and
/// drops trailing slashes. Blank input stays blank.
String normalizeServerUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) return url;
  if (!url.contains('://')) url = 'http://$url';
  return url.replaceFirst(RegExp(r'/+$'), '');
}

/// True when [url] names a host, as `http://100.1.2.3:8000` does.
bool hasServerHost(String url) => Uri.tryParse(url)?.host.isNotEmpty ?? false;
