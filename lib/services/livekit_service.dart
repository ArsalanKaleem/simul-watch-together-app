// lib/services/livekit_service.dart
//
// SIMUL LiveKit Service.
//
// Fixes in this version:
//  • Screen-share AUDIO is now captured & published (captureScreenAudio: true),
//    so tab/desktop audio reaches the room.
//  • Remote audio (mic AND screen-share) is un-blocked on web via startAudio()
//    — browsers refuse to autoplay audio until a user gesture, which is why
//    "the microphone sound doesn't come". We call it after connect, on mic
//    toggle, and expose enableAudioPlayback() for a manual "Enable sound"
//    button (see isAudioBlocked).
//  • The viewer can locally mute the incoming screen-share audio from their own
//    window (toggleRemoteScreenAudioMute) without affecting anyone else — this
//    is subscriber-side control, done by disabling the received MediaStreamTrack.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

import 'app_settings_service.dart';
import 'livekit_token.dart';

enum SimulRole { host, viewer }

class LiveKitService extends ChangeNotifier {
  LiveKitService();

  // Injected (via ProxyProvider) so connect() always reads the latest values
  // the user saved on the Settings screen.
  AppSettingsService? _settings;
  void attachSettings(AppSettingsService s) => _settings = s;

  /// Effective LiveKit websocket URL from user settings (falls back to dev).
  String get liveKitUrl => _settings?.liveKitUrl ?? '';

  // ── State ──────────────────────────────────────────────────────────────
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  SimulRole _role = SimulRole.viewer;
  bool _connected = false;
  String? _lastError;

  bool _micOn    = false;
  bool _micMuted = false;
  bool _sharing  = false;

  /// True when the browser is blocking audio playback (autoplay policy) and a
  /// user gesture is required. UI can show an "Enable sound" button.
  bool _audioBlocked = false;

  final Map<String, RemoteParticipant> _remoteParticipants = {};
  VideoTrack? _remoteScreenTrack;
  AudioTrack? _remoteScreenAudio;
  bool _remoteScreenAudioMuted = false; // local (per-viewer) mute
  final Set<String> _speakingParticipants = {};

  // ── Getters ────────────────────────────────────────────────────────────
  bool get isConnected  => _connected;
  bool get isSharing    => _sharing;
  bool get isMicOn      => _micOn;
  bool get isMicMuted   => _micMuted;
  bool get isAudioBlocked => _audioBlocked;
  String? get lastError => _lastError;
  SimulRole get role    => _role;
  Room? get room        => _room;

  List<RemoteParticipant> get remoteParticipants =>
      List.unmodifiable(_remoteParticipants.values);
  VideoTrack? get remoteScreenTrack => _remoteScreenTrack;
  AudioTrack? get remoteScreenAudio => _remoteScreenAudio;
  bool get hasRemoteShare      => _remoteScreenTrack != null;
  bool get hasRemoteScreenAudio => _remoteScreenAudio != null;
  bool get isRemoteScreenAudioMuted => _remoteScreenAudioMuted;
  Set<String> get speakingParticipants =>
      Set.unmodifiable(_speakingParticipants);

  /// Local participant's own screen-share track, for the host's own preview.
  VideoTrack? get localScreenTrack {
    final lp = _room?.localParticipant;
    if (lp == null) return null;
    for (final pub in lp.videoTrackPublications) {
      if (pub.source == TrackSource.screenShareVideo && pub.track != null) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  // ── Connect ────────────────────────────────────────────────────────────

  Future<void> connect({
    required String roomId,
    required String userId,
    required String displayName,
    required SimulRole role,
  }) async {
    if (_connected) await disconnect();
    _role = role;
    _lastError = null;

    final settings = _settings;
    if (settings == null || !settings.isConfigured) {
      _lastError = 'LiveKit is not configured. Open Settings and add your '
          'LiveKit URL and API key/secret.';
      notifyListeners();
      throw Exception(_lastError);
    }

    try {
      final token = await _fetchToken(
        roomId     : roomId,
        userId     : userId,
        displayName: displayName,
        canPublish : true,
      );

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast      : true,
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
            videoEncoding: VideoEncoding(
              maxBitrate  : 2500000,
              maxFramerate: 30,
            ),
          ),
        ),
      );

      _listener = _room!.createListener();
      _attachListeners();

      await _room!.connect(liveKitUrl, token);

      _connected = true;
      notifyListeners();
      debugPrint('[LiveKit] connected to room $roomId as ${role.name}');

      // Try to unblock audio right away (join is usually a user gesture).
      // If the browser still blocks it, isAudioBlocked flips to true and the
      // UI can offer an "Enable sound" button.
      await enableAudioPlayback();
    } catch (e) {
      _lastError = e.toString();
      _connected = false;
      debugPrint('[LiveKit] connect FAILED: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<String> _fetchToken({
    required String roomId,
    required String userId,
    required String displayName,
    required bool canPublish,
  }) async {
    final settings = _settings!;

    // Preferred path: mint the token on-device from the user's own key/secret.
    if (settings.canMintLocally) {
      return LiveKitToken.mint(
        apiKey: settings.apiKey,
        apiSecret: settings.apiSecret,
        identity: userId,
        name: displayName,
        room: roomId,
        canPublish: canPublish,
      );
    }

    // Fallback path: ask a token server for the token.
    final tokenEndpoint = settings.tokenUrl;
    final uri = Uri.parse(tokenEndpoint).replace(queryParameters: {
      'room'      : roomId,
      'identity'  : userId,
      'name'      : displayName,
      'canPublish': canPublish.toString(),
    });

    final response = await http.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception(
        'Token server did not respond within 10s. Is it running at $tokenEndpoint ?',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Token server returned ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String?;

    if (token == null || token.isEmpty) {
      throw Exception('Token server response missing "token": ${response.body}');
    }

    return token;
  }

  // ── Web audio autoplay unblock ─────────────────────────────────────────
  //
  // On web, remote audio (other people's mic + shared tab audio) will not play
  // until the user interacts with the page. room.startAudio() resumes it and
  // MUST be triggered from a click/tap. We call it optimistically and also
  // whenever the user taps mic — but expose it publicly so the UI can wire an
  // "Enable sound" button when isAudioBlocked is true.
  Future<void> enableAudioPlayback() async {
    final room = _room;
    if (room == null) return;
    try {
      await room.startAudio();
      _audioBlocked = false;
    } catch (e) {
      debugPrint('[LiveKit] startAudio blocked (needs user gesture): $e');
      _audioBlocked = true;
    }
    notifyListeners();
  }

  // ── Event listeners ────────────────────────────────────────────────────

  void _attachListeners() {
    _listener!
      ..on<RoomDisconnectedEvent>((e) {
        debugPrint('[LiveKit] disconnected: ${e.reason}');
        _connected = false;
        notifyListeners();
      })
      ..on<RoomReconnectingEvent>((_) {
        debugPrint('[LiveKit] reconnecting…');
        notifyListeners();
      })
      ..on<RoomReconnectedEvent>((_) {
        debugPrint('[LiveKit] reconnected');
        _connected = true;
        notifyListeners();
      })
      ..on<ParticipantConnectedEvent>((e) {
        _remoteParticipants[e.participant.identity] = e.participant;
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((e) {
        _remoteParticipants.remove(e.participant.identity);
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((e) {
        if (e.publication.source == TrackSource.screenShareVideo &&
            e.track is VideoTrack) {
          _remoteScreenTrack = e.track as VideoTrack;
        }
        if (e.publication.source == TrackSource.screenShareAudio &&
            e.track is AudioTrack) {
          _remoteScreenAudio = e.track as AudioTrack;
          // Re-apply the viewer's local mute preference to the fresh track.
          _applyRemoteScreenAudioMute();
        }
        // A new audio track arrived — make sure the browser is actually
        // playing it (no-op on native platforms).
        enableAudioPlayback();
        notifyListeners();
      })
      ..on<TrackUnsubscribedEvent>((e) {
        if (e.publication.source == TrackSource.screenShareVideo) {
          _remoteScreenTrack = null;
        }
        if (e.publication.source == TrackSource.screenShareAudio) {
          _remoteScreenAudio = null;
        }
        notifyListeners();
      })
      ..on<ActiveSpeakersChangedEvent>((e) {
        _speakingParticipants
          ..clear()
          ..addAll(e.speakers.map((p) => p.identity));
        notifyListeners();
      });

    for (final p in _room!.remoteParticipants.values) {
      _remoteParticipants[p.identity] = p;
    }
  }

  // ── Microphone (voice chat) ───────────────────────────────────────────

  Future<void> startMic() async {
    if (_room?.localParticipant == null) return;
    try {
      await _room!.localParticipant!.setMicrophoneEnabled(true);
      _micOn = true;
      _micMuted = false;
      // Tapping mic is a user gesture → also unblock hearing others.
      await enableAudioPlayback();
      notifyListeners();
    } catch (e) {
      debugPrint('[LiveKit] startMic error: $e');
      _lastError = 'Microphone error: $e';
      notifyListeners();
    }
  }

  Future<void> stopMic() async {
    if (_room?.localParticipant == null) return;
    await _room!.localParticipant!.setMicrophoneEnabled(false);
    _micOn = false;
    notifyListeners();
  }

  Future<void> muteMic() async {
    if (_room?.localParticipant == null) return;
    await _room!.localParticipant!.setMicrophoneEnabled(false);
    _micMuted = true;
    notifyListeners();
  }

  Future<void> unmuteMic() async {
    if (_room?.localParticipant == null) return;
    await _room!.localParticipant!.setMicrophoneEnabled(true);
    _micMuted = false;
    await enableAudioPlayback();
    notifyListeners();
  }

  /// mic not started → start it. Started → toggle mute.
  Future<void> toggleMic() async {
    if (!_micOn) {
      await startMic();
    } else if (!_micMuted) {
      await muteMic();
    } else {
      await unmuteMic();
    }
  }

  // ── Remote screen-share audio: per-viewer local mute ──────────────────
  //
  // Gives the person being shared with authority over the shared audio in
  // THEIR OWN window. Disabling the received MediaStreamTrack silences it
  // locally only; it does not stop the sender or affect other viewers.
  //
  // NOTE: the LiveKit Flutter SDK doesn't expose per-track *gain* (a 0–100 %
  // slider) the way the JS SDK does, so this is an on/off local mute — which
  // is the supported subscriber-side control. See GUIDE.md for a fuller
  // volume-slider option on web.
  void _applyRemoteScreenAudioMute() {
    final t = _remoteScreenAudio;
    if (t == null) return;
    try {
      t.mediaStreamTrack.enabled = !_remoteScreenAudioMuted;
    } catch (e) {
      debugPrint('[LiveKit] could not apply screen-audio mute: $e');
    }
  }

  void setRemoteScreenAudioMuted(bool muted) {
    _remoteScreenAudioMuted = muted;
    _applyRemoteScreenAudioMute();
    notifyListeners();
  }

  void toggleRemoteScreenAudioMute() =>
      setRemoteScreenAudioMuted(!_remoteScreenAudioMuted);

  // ── Screen / tab share ────────────────────────────────────────────────

  Future<bool> startScreenShare() async {
    if (_room?.localParticipant == null) return false;
    try {
      // captureScreenAudio: true → publishes the tab/desktop audio alongside
      // the video (works on web + desktop; ignored where unsupported).
      await _room!.localParticipant!.setScreenShareEnabled(
        true,
        captureScreenAudio: true,
        screenShareCaptureOptions: const ScreenShareCaptureOptions(
          captureScreenAudio: true,
          maxFrameRate: 30.0,
        ),
      );
      _sharing = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[LiveKit] startScreenShare error: $e');
      _lastError = 'Screen share error: $e';
      _sharing = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopScreenShare() async {
    if (_room?.localParticipant == null) return;
    await _room!.localParticipant!.setScreenShareEnabled(false);
    _sharing = false;
    notifyListeners();
  }

  Future<void> toggleScreenShare() async {
    if (_sharing) {
      await stopScreenShare();
    } else {
      await startScreenShare();
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    try {
      await _room?.disconnect();
    } catch (_) {}
    try {
      await _listener?.dispose();
    } catch (_) {}
    _listener = null;
    _room = null;
    _connected = false;
    _sharing = false;
    _micOn = false;
    _micMuted = false;
    _audioBlocked = false;
    _remoteScreenTrack = null;
    _remoteScreenAudio = null;
    _remoteScreenAudioMuted = false;
    _remoteParticipants.clear();
    _speakingParticipants.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
