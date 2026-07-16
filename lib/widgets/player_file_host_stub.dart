// Non-io platforms (web): no local server needed — the web engine embeds a
// real <iframe> in the page, which already has a proper origin.
Future<String?> hostPlayerHtml(String html) async => null;
void disposePlayerHost() {}
