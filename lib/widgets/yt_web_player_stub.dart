// lib/widgets/yt_web_player_stub.dart
//
// Non-web implementation (Android / iOS / macOS / Windows / Linux).
//
// On those platforms the player uses a real WebView (webview_flutter or
// webview_windows), so this stub simply reports "not available" and the
// widget falls back to its WebView engines. It exists so that
// video_player_widget.dart can use a conditional import and never pull
// dart:ui_web / package:web into a non-web build.

/// Handle to a YouTube iframe hosted directly in the page (web only).
abstract class YtWebHandle {
  /// The platform-view type id to hand to [HtmlElementView].
  String get viewType;

  void play();
  void pause();
  void seekTo(double seconds);
  void dispose();
}

/// Returns null on every non-web platform.
YtWebHandle? createYtWebPlayer({
  required String videoId,
  required void Function(String msg) onMessage,
}) =>
    null;
