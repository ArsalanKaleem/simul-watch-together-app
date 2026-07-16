import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import '../utils/constants.dart';
// Conditional: the web build gets a real <iframe> platform view; every other
// platform gets a stub that returns null so dart:ui_web / package:web are
// never pulled into a non-web build.
import 'yt_web_player_stub.dart'
    if (dart.library.js_interop) 'yt_web_player_web.dart';
import 'player_file_host_stub.dart'
    if (dart.library.io) 'player_file_host_io.dart';
import 'yt_web_player_stub.dart' show YtWebHandle;

/// SIMUL Video Player — true cross-platform inline playback.
///
///   • Web                          -> <iframe> platform view + postMessage
///   • Android / iOS / macOS        -> webview_flutter
///   • Windows                      -> webview_windows (Edge WebView2)
///   • Anything else / init failure -> copy-link fallback card
///
/// The YouTube IFrame API + sync bridge is identical across engines; only the
/// JS<->Dart transport differs (FlutterBridge vs window.chrome.webview).
class VideoPlayerWidget extends StatefulWidget {
  final String videoId;
  final Function(bool isPlaying, double position) onPlayPause;
  final Function(double position) onSeek;
  final Function(double position, bool isPlaying) onPositionUpdate;
  final VoidCallback? onVideoEnded;

  /// Fired when the video cannot be played after all fallback sources have
  /// been tried (e.g. owner disabled embedding, video removed/private).
  /// Gives the parent a chance to toast/log; the widget itself also renders
  /// a graceful in-player card with Open/Copy actions.
  final Function(String reason)? onPlayerError;

  const VideoPlayerWidget({
    super.key,
    required this.videoId,
    required this.onPlayPause,
    required this.onSeek,
    required this.onPositionUpdate,
    this.onVideoEnded,
    this.onPlayerError,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

enum _Engine { web, flutterWebView, windowsWebView, none }

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  _Engine _engine = _Engine.none;

  // web (<iframe> platform view)
  YtWebHandle? _webHandle;
  // flutter webview
  WebViewController? _ctrl;
  // windows webview
  win.WebviewController? _winCtrl;
  StreamSubscription? _winSub;
  bool _winFailed = false;

  Timer? _positionTimer;
  Timer? _readyTimeout;
  bool _isPlaying = false;
  bool _playerReady = false;
  double _currentPosition = 0;
  bool _isSyncing = false;
  double _lastReported = -1;
  bool _copied = false;

  // Set when JS reports that every fallback source failed for this video.
  // Renders a graceful error card instead of a black/broken player.
  String? _fatalError;

  double get currentPosition => _currentPosition;
  bool get isPlaying => _isPlaying;

  // NOTE: kIsWeb is deliberately NOT in this list. webview_flutter has no
  // Flutter Web implementation — constructing a WebViewController on web
  // throws "A platform implementation for `webview_flutter` has not been
  // set", which is what black-screened the room. Web uses _Engine.web.
  static bool get _flutterWebViewSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebIframe();
      return;
    }
    if (_flutterWebViewSupported) {
      _engine = _Engine.flutterWebView;
      _initFlutterWebView();
    } else if (_isWindows) {
      _engine = _Engine.windowsWebView;
      _initWindowsWebView();
    } else {
      _engine = _Engine.none;
    }
  }

  // ── Engine init ─────────────────────────────────────────────────────────────

  void _initWebIframe() {
    final handle = createYtWebPlayer(
      videoId  : widget.videoId,
      onMessage: _handleMessage,
    );
    if (handle == null) {
      _engine = _Engine.none;
      return;
    }
    _webHandle = handle;
    _engine = _Engine.web;
    _armReadyTimeout();
  }

  void _initFlutterWebView() {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
      ..addJavaScriptChannel('FlutterBridge',
          onMessageReceived: (m) => _handleMessage(m.message))
      // baseUrl gives this in-memory document a real https origin. Without
      // it the origin is opaque, the embed request carries NO referrer, and
      // YouTube's 2025 enforcement answers with Error 153.
      ..loadHtmlString(_buildHtml(widget.videoId, windows: false),
          baseUrl: 'https://www.youtube-nocookie.com');
    _ctrl = ctrl;
    _armReadyTimeout();
  }

  Future<void> _initWindowsWebView() async {
    try {
      final c = win.WebviewController();
      await c.initialize();
      _winSub = c.webMessage.listen((dynamic m) {
        _handleMessage(m is String ? m : m.toString());
      });
      await c.setBackgroundColor(Colors.black);
      await c.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
      final html = _buildHtml(widget.videoId, windows: true);
      // webview_windows has no baseUrl equivalent, so an in-memory string
      // can never send a referrer → guaranteed Error 153. A file:// URL
      // doesn't fix it either (file URLs send no referrer). Serving the page
      // from a loopback HTTP server gives it a real origin, so the referrer
      // flows and YouTube serves the player. String load kept as a fallback.
      final hostedUrl = await hostPlayerHtml(html);
      if (hostedUrl != null) {
        await c.loadUrl(hostedUrl);
      } else {
        await c.loadStringContent(html);
      }
      _winCtrl = c;
      if (mounted) setState(() {});
      _armReadyTimeout();
    } catch (e) {
      debugPrint('Windows WebView init failed: $e');
      if (mounted) setState(() => _winFailed = true);
    }
  }

  void _armReadyTimeout() {
    _readyTimeout?.cancel();
    _readyTimeout = Timer(const Duration(seconds: 12), () {
      if (!_playerReady && mounted) _reload();
    });
  }

  int _reloadCount = 0;

  void _reload() {
    if (_engine == _Engine.web) {
      // The iframe's src is baked in when the view factory runs, so a new
      // video (or a stuck load) means building a fresh platform view.
      // Bounded so a permanently-unready player can't reload forever.
      if (_reloadCount >= 2) return;
      _reloadCount++;
      _webHandle?.dispose();
      _webHandle = null;
      _initWebIframe();
      if (mounted) setState(() {});
      return;
    }
    final html = _buildHtml(widget.videoId,
        windows: _engine == _Engine.windowsWebView);
    if (_engine == _Engine.flutterWebView) {
      _ctrl?.loadHtmlString(html, baseUrl: 'https://www.youtube-nocookie.com');
    } else if (_engine == _Engine.windowsWebView) {
      final win = _winCtrl;
      if (win != null) {
        hostPlayerHtml(html).then((hostedUrl) {
          if (!mounted) return;
          if (hostedUrl != null) {
            win.loadUrl(hostedUrl);
          } else {
            win.loadStringContent(html);
          }
        });
      }
    }
  }

  // ── Dart -> JS ──────────────────────────────────────────────────────────────

  void _runJs(String js) {
    if (_engine == _Engine.flutterWebView) {
      _ctrl?.runJavaScript(js);
    } else if (_engine == _Engine.windowsWebView) {
      _winCtrl?.executeScript(js);
    }
  }

  // ── JS -> Dart ──────────────────────────────────────────────────────────────

  void _handleMessage(String raw) {
    if (raw == 'ready') {
      _playerReady = true;
      _readyTimeout?.cancel();
      return;
    }
    if (raw.startsWith('state:')) {
      final s = raw.substring(6);
      final wasPlaying = _isPlaying;
      _isPlaying = s == 'playing';
      if (wasPlaying != _isPlaying && !_isSyncing) {
        widget.onPlayPause(_isPlaying, _currentPosition);
        if (_isPlaying) {
          _startTimer();
        } else {
          _stopTimer();
        }
      }
    } else if (raw.startsWith('pos:')) {
      final pos = double.tryParse(raw.substring(4)) ?? 0;
      final jump = (pos - _currentPosition).abs();
      if (jump > 2.0 && !_isSyncing) widget.onSeek(pos);
      _currentPosition = pos;
      if ((_currentPosition - _lastReported).abs() >= 1.0) {
        _lastReported = _currentPosition;
        widget.onPositionUpdate(_currentPosition, _isPlaying);
      }
    } else if (raw == 'ended') {
      _isPlaying = false;
      _stopTimer();
      widget.onVideoEnded?.call();
    } else if (raw.startsWith('fatal:')) {
      final code = raw.substring(6);
      final reason = switch (code) {
        'noembed'  => 'The video owner has disabled playback outside YouTube.',
        'notfound' => 'This video is unavailable (removed, private, or region-locked).',
        'badid'    => "That link doesn't point to a valid YouTube video.",
        'config'   => 'YouTube rejected the player (error 153). Try another '
            'video; if every video fails, update SIMUL.',
        _          => 'This video could not be played after several attempts.',
      };
      _readyTimeout?.cancel();
      _stopTimer();
      if (mounted) setState(() => _fatalError = reason);
      widget.onPlayerError?.call(reason);
    } else if (raw.startsWith('error:')) {
      // Non-fatal: the JS retry ladder is still walking through sources.
      debugPrint('YT player error (retrying): ${raw.substring(6)}');
    }
  }

  void _startTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // The web iframe streams currentTime to us automatically via
      // infoDelivery — only the WebView engines need polling.
      if (_engine != _Engine.web && _playerReady) _runJs('sendPos()');
    });
  }

  void _stopTimer() => _positionTimer?.cancel();

  // ── HTML ────────────────────────────────────────────────────────────────────

  String _buildHtml(String videoId, {required bool windows}) {
    final transport = windows
        ? 'window.chrome.webview.postMessage(m);'
        : 'FlutterBridge.postMessage(m);';
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  * { margin:0; padding:0; box-sizing:border-box }
  body { background:#000; overflow:hidden; width:100vw; height:100vh }
  #player, #player iframe { width:100%; height:100% }
</style>
</head>
<body>
<div id="player"></div>
<script>
  function post(m) { $transport }

  var tag = document.createElement('script');
  tag.src = 'https://www.youtube.com/iframe_api';
  var firstScript = document.getElementsByTagName('script')[0];
  firstScript.parentNode.insertBefore(tag, firstScript);

  var player;
  var lastState = -1;
  var blocking  = false;
  var playerReady = false;

  // ── Multi-source retry ladder ─────────────────────────────────────────
  // The page is loaded from a local string, so its real origin is opaque
  // ("about:blank"/null). Claiming a fake `origin` playerVar makes YouTube
  // reject playback for many videos — so we NEVER set origin, and instead
  // walk through progressively more permissive sources when the player
  // reports an error:
  //   attempt 0: privacy-enhanced host (youtube-nocookie.com)
  //   attempt 1: standard host (www.youtube.com) — some videos allow one
  //              host but not the other
  //   attempt 2: raw <iframe> embed (bypasses IFrame-API construction
  //              quirks in some WebView engines; JS API attaches after)
  // Errors 100 (not found/private) and 2 (bad id) are not retried — no
  // source can fix those. 101/150 (embedding disabled) IS retried once
  // across hosts because owners can disable per-domain, then reported
  // fatal if it persists.
  var attempt = 0;
  var HOSTS = ['https://www.youtube-nocookie.com', 'https://www.youtube.com'];

  function buildPlayer() {
    if (player && player.destroy) { try { player.destroy(); } catch(e) {} }
    document.getElementById('player').innerHTML = '';

    if (attempt <= 1) {
      player = new YT.Player('player', {
        videoId: '$videoId',
        host: HOSTS[attempt],
        playerVars: {
          autoplay:1, controls:1, rel:0, modestbranding:1,
          playsinline:1, enablejsapi:1, iv_load_policy:3
        },
        events: {
          onReady: onReady,
          onStateChange: onStateChange,
          onError: onError
        }
      });
    } else {
      // Raw iframe fallback: create the embed directly, then attach the API.
      var f = document.createElement('iframe');
      f.id = 'ytframe';
      f.setAttribute('allow',
        'autoplay; encrypted-media; picture-in-picture; fullscreen');
      f.setAttribute('frameborder', '0');
      f.src = 'https://www.youtube.com/embed/$videoId'
            + '?enablejsapi=1&autoplay=1&controls=1&rel=0&playsinline=1&iv_load_policy=3';
      document.getElementById('player').appendChild(f);
      player = new YT.Player('ytframe', {
        events: {
          onReady: onReady,
          onStateChange: onStateChange,
          onError: onError
        }
      });
    }
  }

  function onReady(e) { playerReady = true; post('ready'); }

  function onStateChange(e) {
    if (blocking) return;
    if (e.data === YT.PlayerState.PLAYING && lastState !== 1) {
      lastState = 1; post('state:playing');
    } else if (e.data === YT.PlayerState.PAUSED && lastState !== 2) {
      lastState = 2; post('state:paused');
    } else if (e.data === YT.PlayerState.ENDED) {
      post('ended');
    }
  }

  function onError(e) {
    var code = e.data;
    post('error:' + code);
    // Unrecoverable regardless of source:
    if (code === 100) { post('fatal:notfound'); return; }
    if (code === 2)   { post('fatal:badid');    return; }
    // Try the next source in the ladder:
    if (attempt < 2) {
      attempt++;
      setTimeout(buildPlayer, 350);
    } else {
      // All sources exhausted. 101/150 = embedding disabled by owner.
      if (code === 101 || code === 150) { post('fatal:noembed'); }
      else if (code === 153)             { post('fatal:config'); }
      else                               { post('fatal:unknown'); }
    }
  }

  function onYouTubeIframeAPIReady() { buildPlayer(); }

  function sendPos() {
    if (player && player.getCurrentTime) post('pos:' + player.getCurrentTime());
  }
  function playV()  { if (player && playerReady) { blocking=false; lastState=1; player.playVideo(); } }
  function pauseV() { if (player && playerReady) { blocking=false; lastState=2; player.pauseVideo(); } }
  function seekTo(s) {
    if (!player || !playerReady) return;
    blocking = true; player.seekTo(s, true);
    setTimeout(function(){ blocking = false; }, 1500);
  }
  function syncTo(s, play) {
    if (!player || !playerReady) return;
    blocking = true; player.seekTo(s, true);
    if (play) { lastState=1; player.playVideo(); } else { lastState=2; player.pauseVideo(); }
    setTimeout(function(){ blocking = false; }, 1500);
  }
</script>
</body>
</html>
''';
  }

  // ── Public API (RoomScreen via GlobalKey) ───────────────────────────────────

  void play() {
    _isSyncing = true;
    if (_engine == _Engine.web) {
      _webHandle?.play();
    } else if (_playerReady) {
      _runJs('playV()');
    }
    Future.delayed(const Duration(milliseconds: 300), () => _isSyncing = false);
  }

  void pause() {
    _isSyncing = true;
    if (_engine == _Engine.web) {
      _webHandle?.pause();
    } else if (_playerReady) {
      _runJs('pauseV()');
    }
    Future.delayed(const Duration(milliseconds: 300), () => _isSyncing = false);
  }

  void seekTo(double s) {
    _isSyncing = true;
    if (_engine == _Engine.web) {
      _webHandle?.seekTo(s);
    } else if (_playerReady) {
      _runJs('seekTo($s)');
    }
    Future.delayed(const Duration(milliseconds: 1500), () => _isSyncing = false);
  }

  void syncTo(double s, bool playing) {
    _isSyncing = true;
    _isPlaying = playing;
    if (_engine == _Engine.web) {
      _webHandle?.seekTo(s);
      if (playing) {
        _webHandle?.play();
      } else {
        _webHandle?.pause();
      }
    } else if (_playerReady) {
      _runJs('syncTo($s,$playing)');
    }
    Future.delayed(const Duration(milliseconds: 1500), () => _isSyncing = false);
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(
        text: 'https://www.youtube.com/watch?v=${widget.videoId}'));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2),
        () => mounted ? setState(() => _copied = false) : null);
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _stopTimer();
      _playerReady = false;
      _isPlaying = false;
      _currentPosition = 0;
      _lastReported = -1;
      _copied = false;
      _fatalError = null;
      _reloadCount = 0;
      if (_engine == _Engine.none) {
        setState(() {});
      } else if (_engine == _Engine.web) {
        // New video → new iframe (src can't be mutated meaningfully).
        _webHandle?.dispose();
        _webHandle = null;
        _initWebIframe();
        setState(() {});
      } else {
        _reload();
        _armReadyTimeout();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _readyTimeout?.cancel();
    _webHandle?.dispose();
    _winSub?.cancel();
    _winCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return _PlaybackErrorCard(
        videoId: widget.videoId,
        reason: _fatalError!,
        copied: _copied,
        onCopy: _copyLink,
      );
    }
    if (_engine == _Engine.web && _webHandle != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: HtmlElementView(viewType: _webHandle!.viewType),
      );
    }
    if (_engine == _Engine.flutterWebView && _ctrl != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: WebViewWidget(controller: _ctrl!),
      );
    }
    if (_engine == _Engine.windowsWebView && !_winFailed) {
      final ready = _winCtrl != null && _winCtrl!.value.isInitialized;
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ready
            ? win.Webview(_winCtrl!)
            : Container(
                color: SimulColors.black,
                child: const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: SimulColors.white),
                ),
              ),
      );
    }
    return _DesktopFallbackPlayer(
      videoId: widget.videoId,
      copied: _copied,
      onCopy: _copyLink,
    );
  }
}

/// Last-resort card (Linux, or Windows where WebView2 runtime is missing).
class _DesktopFallbackPlayer extends StatelessWidget {
  final String videoId;
  final bool copied;
  final VoidCallback onCopy;
  const _DesktopFallbackPlayer({
    required this.videoId,
    required this.copied,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: SimulColors.surface),
            ),
            Container(color: Colors.black.withValues(alpha: 0.58)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Inline playback unavailable here. Copy the link to '
                      'watch in your browser.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SimulColors.faint, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: onCopy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: copied
                            ? SimulColors.success.withValues(alpha: 0.15)
                            : SimulColors.white,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 15,
                            color: copied
                                ? SimulColors.success
                                : SimulColors.black),
                        const SizedBox(width: 7),
                        Text(copied ? 'Copied!' : 'Copy video link',
                            style: TextStyle(
                                color: copied
                                    ? SimulColors.success
                                    : SimulColors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a video cannot be played after all fallback sources were tried
/// (embedding disabled by owner, removed/private video, invalid link). Keeps
/// the room usable: explains why, and offers copy so people can watch on
/// YouTube and stay in the room for voice/chat.
class _PlaybackErrorCard extends StatelessWidget {
  final String videoId;
  final String reason;
  final bool copied;
  final VoidCallback onCopy;
  const _PlaybackErrorCard({
    required this.videoId,
    required this.reason,
    required this.copied,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: SimulColors.surface),
            ),
            Container(color: Colors.black.withValues(alpha: 0.72)),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: SimulColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_disabled_rounded,
                          color: SimulColors.warning, size: 22),
                    ),
                    const SizedBox(height: 12),
                    const Text("This video can't be played here",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: SimulColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(reason,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: SimulColors.faint, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 6),
                    const Text('Try pasting a different link below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: SimulColors.subtle, fontSize: 11)),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onCopy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: copied
                              ? SimulColors.success.withValues(alpha: 0.15)
                              : SimulColors.white,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(copied ? Icons.check_rounded : Icons.copy_rounded,
                              size: 15,
                              color: copied
                                  ? SimulColors.success
                                  : SimulColors.black),
                          const SizedBox(width: 7),
                          Text(copied ? 'Copied!' : 'Copy YouTube link',
                              style: TextStyle(
                                  color: copied
                                      ? SimulColors.success
                                      : SimulColors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
