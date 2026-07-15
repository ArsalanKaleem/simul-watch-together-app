// lib/widgets/yt_web_player_web.dart
//
// WEB-ONLY YouTube player.
//
// Why this file exists:
//   `webview_flutter` has NO Flutter Web implementation. Constructing a
//   WebViewController on web throws
//       "A platform implementation for `webview_flutter` has not been set"
//   from initState, which killed the whole subtree (black screen + a cascade
//   of "Cannot hit test a render box that has never been laid out").
//
// On web we don't need a WebView at all — we're already in a browser. We
// register a real <iframe> as a platform view and drive it with YouTube's
// postMessage API:
//   • send  {"event":"listening"}                     → start receiving updates
//   • send  {"event":"command","func":"playVideo"}    → control playback
//   • recv  {"event":"infoDelivery","info":{...}}     → state + currentTime
//
// Because the iframe is hosted in the app's own page, `origin` is the app's
// REAL origin, which is what YouTube expects (the old code passed a fake
// origin, which is why so many videos refused to play).
//
// Emits the exact same message strings the shared _handleMessage parser
// already understands, so the sync logic is unchanged across platforms.

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'yt_web_player_stub.dart' show YtWebHandle;

int _seq = 0;

class _WebYtHandle implements YtWebHandle {
  @override
  final String viewType;

  final void Function(String) _onMessage;
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;
  bool _disposed = false;
  bool _reportedReady = false;
  int _lastState = -99;

  _WebYtHandle(this.viewType, this._onMessage);

  void _post(Map<String, dynamic> msg) {
    final w = _frame?.contentWindow;
    if (w == null) return;
    try {
      w.postMessage(jsonEncode(msg).toJS, '*'.toJS);
    } catch (_) {
      // iframe not ready yet — the listening retries below cover this.
    }
  }

  void _startListening() {
    _post({'event': 'listening', 'id': 1, 'channel': 'widget'});
  }

  void attachFrame(web.HTMLIFrameElement f) {
    _frame = f;

    // YouTube only starts posting updates once we say we're listening, and
    // the iframe may not be ready the instant onload fires — retry briefly.
    f.onload = ((web.Event _) {
      _startListening();
      for (final ms in const [200, 600, 1200, 2500]) {
        Future.delayed(Duration(milliseconds: ms), () {
          if (!_disposed) _startListening();
        });
      }
    }).toJS;

    final listener = ((web.Event e) {
      if (_disposed) return;
      if (e is! web.MessageEvent) return;
      final data = e.data;
      if (data == null) return;

      Object? decoded;
      try {
        final dart = data.dartify();
        if (dart is! String) return;
        decoded = jsonDecode(dart);
      } catch (_) {
        return;
      }
      if (decoded is! Map) return;

      final event = decoded['event'];
      final info = decoded['info'];

      if (event == 'onReady' || event == 'initialDelivery') {
        if (!_reportedReady) {
          _reportedReady = true;
          _onMessage('ready');
        }
      }

      if (info is Map) {
        // Errors arrive here as well as via onError.
        final err = info['errorCode'];
        if (err is num) _emitError(err.toInt());

        final state = info['playerState'];
        if (state is num) {
          if (!_reportedReady) {
            _reportedReady = true;
            _onMessage('ready');
          }
          final s = state.toInt();
          if (s != _lastState) {
            _lastState = s;
            // -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued
            if (s == 1) {
              _onMessage('state:playing');
            } else if (s == 2) {
              _onMessage('state:paused');
            } else if (s == 0) {
              _onMessage('ended');
            }
          }
        }

        final t = info['currentTime'];
        if (t is num) _onMessage('pos:${t.toDouble()}');
      }

      if (event == 'onError' && info is num) _emitError(info.toInt());
    }).toJS;

    _listener = listener;
    web.window.addEventListener('message', listener);
  }

  void _emitError(int code) {
    _onMessage('error:$code');
    // Mirrors the shared error semantics used by the WebView engines.
    switch (code) {
      case 2:
        _onMessage('fatal:badid');
      case 100:
        _onMessage('fatal:notfound');
      case 101:
      case 150:
        _onMessage('fatal:noembed');
      case 153:
        _onMessage('fatal:config');
    }
  }

  @override
  void play() => _post({'event': 'command', 'func': 'playVideo', 'args': []});

  @override
  void pause() => _post({'event': 'command', 'func': 'pauseVideo', 'args': []});

  @override
  void seekTo(double seconds) => _post(
      {'event': 'command', 'func': 'seekTo', 'args': [seconds, true]});

  @override
  void dispose() {
    _disposed = true;
    final l = _listener;
    if (l != null) web.window.removeEventListener('message', l);
    _listener = null;
    _frame = null;
  }
}

YtWebHandle? createYtWebPlayer({
  required String videoId,
  required void Function(String msg) onMessage,
}) {
  final viewType = 'simul-yt-${_seq++}';
  final handle = _WebYtHandle(viewType, onMessage);

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final f = web.document.createElement('iframe') as web.HTMLIFrameElement;
    final origin = web.window.location.origin;
    f.src = 'https://www.youtube.com/embed/$videoId'
        '?enablejsapi=1&autoplay=1&controls=1&rel=0&playsinline=1'
        '&iv_load_policy=3&origin=$origin';
    f.allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen';
    // YouTube's 2025 Required-Minimum-Functionality enforcement rejects
    // embeds whose requests carry no referrer (Error 153). Browsers default
    // to this policy anyway, but hosting pages/CDNs can override it — set it
    // explicitly on the frame so the referrer always flows.
    f.referrerPolicy = 'strict-origin-when-cross-origin';
    f.setAttribute('frameborder', '0');
    f.setAttribute('allowfullscreen', 'true');
    f.style.border = 'none';
    f.style.width = '100%';
    f.style.height = '100%';
    handle.attachFrame(f);
    return f;
  });

  return handle;
}
