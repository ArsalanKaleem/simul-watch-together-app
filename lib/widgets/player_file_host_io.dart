// io platforms: serves the player page from a real loopback HTTP server.
//
// WHY THIS EXISTS
// ---------------
// YouTube's Oct-2025 "Required Minimum Functionality" enforcement makes the
// embed player refuse to load (Error 153) unless the request carries a
// referrer. That means the page hosting the iframe must have a REAL origin:
//
//   • loadStringContent(...)  → origin is opaque  → no referrer → 153
//   • file:///.../player.html → still not a web origin; browsers send no
//     referrer for file URLs → 153 (this is why the temp-file attempt only
//     half-worked, and why the OBS/StackOverflow threads say local files
//     "have to be opened through a webserver")
//   • http://127.0.0.1:PORT/  → a real origin → referrer IS sent → works
//
// So we run a tiny loopback server (localhost only, ephemeral port) that
// serves the player HTML with the Referrer-Policy header the accepted
// StackOverflow answer prescribes. Nothing is exposed off-machine.
import 'dart:io';

HttpServer? _server;
String _html = '';

Future<String?> hostPlayerHtml(String html) async {
  _html = html;
  try {
    if (_server == null) {
      // Port 0 = OS picks a free ephemeral port. Loopback only.
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen((req) async {
        try {
          req.response.headers
            ..set('Content-Type', 'text/html; charset=utf-8')
            // The header form of the fix (works even if the meta tag is
            // ignored). Mirrors the accepted answer on the 153 thread.
            ..set('Referrer-Policy', 'strict-origin-when-cross-origin')
            ..set('Cache-Control', 'no-store');
          req.response.write(_html);
        } catch (_) {
          // fall through to close
        }
        await req.response.close();
      }, onError: (_) {});
    }
    // Cache-busting query so a reload always re-fetches the latest HTML.
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'http://127.0.0.1:${_server!.port}/player.html?ts=$ts';
  } catch (_) {
    return null; // caller falls back to the in-memory string load
  }
}

void disposePlayerHost() {
  _server?.close(force: true);
  _server = null;
}
