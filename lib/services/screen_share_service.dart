import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// SIMUL Tab/Screen Share Service
///
/// Works on Web and Desktop (Windows/macOS/Linux) via the WebRTC
/// `getDisplayMedia` API.  Mobile platforms are gracefully excluded –
/// `isSupported` returns false there so the UI hides the button.
///
/// Architecture:
///  - Caller starts sharing → local MediaStream (display) is captured.
///  - The stream is broadcast to all peers already in the room through
///    the existing WebRTC signalling in WebRTCService.
///  - A Firestore flag `rooms/{id}/shareActive` lets late-joiners know
///    a share is in progress so they can request the stream on connect.
///
/// This service is intentionally decoupled from WebRTCService so it
/// can be developed and tested independently.
class ScreenShareService extends ChangeNotifier {
  MediaStream? _displayStream;
  bool _isSharing = false;

  bool get isSharing     => _isSharing;
  MediaStream? get stream => _displayStream;

  /// True on web and desktop; false on mobile (Android / iOS).
  static bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS   ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Start capturing the screen / tab.
  ///
  /// On web, the browser shows the native "Choose what to share" picker
  /// (tab, window, or entire screen).
  /// On desktop, the OS-level screen picker is shown.
  ///
  /// Returns true on success, false if the user cancelled or an error occurred.
  Future<bool> startSharing() async {
    if (!isSupported) return false;
    try {
      _displayStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'cursor'    : 'always',
          'frameRate' : {'ideal': 30, 'max': 60},
        },
        'audio': true, // capture tab audio when available (Chrome on web)
      });

      // Listen for the user stopping via the browser's built-in "Stop sharing" button
      _displayStream!.getVideoTracks().first.onEnded = () {
        stopSharing();
      };

      _isSharing = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ScreenShare startSharing error: $e');
      _isSharing = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop capturing and release all tracks.
  Future<void> stopSharing() async {
    _displayStream?.getTracks().forEach((t) => t.stop());
    _displayStream = null;
    _isSharing     = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopSharing();
    super.dispose();
  }
}
