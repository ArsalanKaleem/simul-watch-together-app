// lib/services/livekit_service.dart
//
// SIMUL LiveKit Service — replaces WebRTCService + ScreenShareService +
// the old mediasoup SfuService entirely. No custom SDP, no RTP parsing,
// no Socket.IO signalling — the LiveKit SDK handles all of it.
//
// Firebase (auth, Firestore, room metadata) and YouTubeSyncService are
// completely untouched by this file.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';

enum SimulRole { host, viewer }

class LiveKitService extends ChangeNotifier {
  final String liveKitUrl;
  final String tokenEndpoint;

  LiveKitService({
    required this.liveKitUrl,
    required this.tokenEndpoint,
  });

  // ── State ──────────────────────────────────────────────────────────────
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  SimulRole _role = SimulRole.viewer;
  bool _connected = false;
  String? _lastError;

  bool _micOn    = false;
  bool _micMuted = false;
  bool _sharing  = false;

  final Map<String, RemoteParticipant> _remoteParticipants = {};
  VideoTrack? _remoteScreenTrack;
  AudioTrack? _remoteScreenAudio;
  final Set<String> _speakingParticipants = {};

  // ── Getters ────────────────────────────────────────────────────────────
  bool get isConnected  => _connected;
  bool get isSharing    => _sharing;
  bool get isMicOn      => _micOn;
  bool get isMicMuted   => _micMuted;
  String? get lastError => _lastError;
  SimulRole get role    => _role;
  Room? get room        => _room;

  List<RemoteParticipant> get remoteParticipants =>
      List.unmodifiable(_remoteParticipants.values);
  VideoTrack? get remoteScreenTrack => _remoteScreenTrack;
  AudioTrack? get remoteScreenAudio => _remoteScreenAudio;
  bool get hasRemoteShare => _remoteScreenTrack != null;
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

    try {
      final token = await _fetchToken(
        roomId     : roomId,
        userId     : userId,
        displayName: displayName,
        canPublish : true, // everyone can publish mic; screen share is gated by role in UI
      );

      _room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast      : true,
          defaultVideoPublishOptions: const VideoPublishOptions(
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
        }
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
    notifyListeners();
  }

  /// Convenience: mic isn't started yet → start it. Started → toggle mute.
  Future<void> toggleMic() async {
    if (!_micOn) {
      await startMic();
    } else if (!_micMuted) {
      await muteMic();
    } else {
      await unmuteMic();
    }
  }

  // ── Screen / tab share ────────────────────────────────────────────────

  Future<bool> startScreenShare() async {
    if (_room?.localParticipant == null) return false;
    try {
      await _room!.localParticipant!.setScreenShareEnabled(true);
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
    _remoteScreenTrack = null;
    _remoteScreenAudio = null;
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
