// io platforms: writes the player HTML to a real file so the WebView loads it
// from a file:// URL instead of an opaque in-memory string.
//
// WHY: YouTube's Oct-2025 "Required Minimum Functionality" enforcement makes
// the embed player refuse to load (Error 153) when the request carries no
// referrer. A document created via loadStringContent has an opaque origin, so
// no referrer can ever be sent. A real file URL plus the
//   <meta name="referrer" content="strict-origin-when-cross-origin">
// tag in the page restores a referrer value (the community-verified fix for
// OBS browser sources, which hit the identical failure).
import 'dart:io';

Future<String?> writePlayerHtmlToFile(String html) async {
  try {
    final dir = await Directory.systemTemp.createTemp('simul_player');
    final f = File('${dir.path}${Platform.pathSeparator}player.html');
    await f.writeAsString(html);
    return Uri.file(f.path).toString();
  } catch (_) {
    return null;
  }
}
