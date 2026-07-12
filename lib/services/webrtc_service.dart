import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// SIMUL WebRTC mesh service.
///
/// Provides live peer-to-peer media (voice + screen/tab share) between every
/// member of a room. Signalling (SDP offers/answers + ICE candidates) is
/// relayed through Firestore at `rooms/{roomId}/signaling`.
///
/// Connection model: a full mesh — one RTCPeerConnection per remote peer.
/// Glare/renegotiation is handled with the "perfect negotiation" pattern, so
/// either side can start a share at any time without colliding.
///
/// Whatever you share (a tab, a window, or your whole screen) is added as an
/// outgoing video track and shows up live in every other member's
/// ScreenShareViewer via [remoteShareStreams].
class WebRTCService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _roomId;
  String? _myUid;

  // Local media
  MediaStream? _voiceStream;       // local mic
  MediaStream? _shareStream;       // local screen/tab capture
  bool _voiceActive = false;
  bool _sharing = false;

  // Per-remote-peer connections
  final Map<String, _Peer> _peers = {};

  // Remote streams received from peers, keyed by remote uid.
  final Map<String, MediaStream> _remoteShareStreams = {};

  StreamSubscription? _signalSub;

  // ── Public getters ──────────────────────────────────────────────────────────
  bool get isVoiceActive => _voiceActive;
  bool get isSharing     => _sharing;

  /// Remote screen/tab shares currently being received (uid -> stream).
  Map<String, MediaStream> get remoteShareStreams =>
      Map.unmodifiable(_remoteShareStreams);

  /// The most relevant remote share to display (first available), or null.
  MediaStream? get primaryRemoteShare =>
      _remoteShareStreams.isEmpty ? null : _remoteShareStreams.values.first;

  bool get hasRemoteShare => _remoteShareStreams.isNotEmpty;

  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // For users on different networks/NATs you will likely need a TURN
      // relay here, e.g.:
      // {'urls':'turn:YOUR_HOST:3478','username':'user','credential':'pass'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Call once after joining a room. Starts listening for signalling messages.
  Future<void> connect(String roomId, String myUid) async {
    if (_roomId == roomId && _myUid == myUid && _signalSub != null) return;
    _roomId = roomId;
    _myUid = myUid;

    _signalSub?.cancel();
    _signalSub = _db
        .collection('rooms')
        .doc(roomId)
        .collection('signaling')
        .where('to', isEqualTo: myUid)
        .snapshots()
        .listen(_onSignals);
  }

  /// Reconcile the mesh with the current room membership. Call whenever the
  /// participant list changes. Creates connections to new peers and drops
  /// connections to peers who left.
  Future<void> syncPeers(List<String> memberUids) async {
    final myUid = _myUid;
    if (myUid == null) return;
    final others = memberUids.where((u) => u != myUid).toSet();

    // Remove stale peers
    for (final uid in _peers.keys.toList()) {
      if (!others.contains(uid)) await _removePeer(uid);
    }

    // Add new peers
    for (final uid in others) {
      if (!_peers.containsKey(uid)) {
        await _createPeer(uid, initiator: myUid.compareTo(uid) < 0);
      }
    }
  }

  // ── Peer management ─────────────────────────────────────────────────────────

  Future<_Peer> _createPeer(String remoteUid, {required bool initiator}) async {
    final pc = await createPeerConnection(_rtcConfig);
    // "Polite" peer yields on glare. Make the non-initiator polite.
    final peer = _Peer(remoteUid: remoteUid, pc: pc, polite: !initiator);
    _peers[remoteUid] = peer;

    pc.onIceCandidate = (RTCIceCandidate c) {
      _sendSignal(remoteUid, {
        'kind': 'candidate',
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    pc.onTrack = (RTCTrackEvent e) {
      if (e.track.kind == 'video' && e.streams.isNotEmpty) {
        _remoteShareStreams[remoteUid] = e.streams.first;
        notifyListeners();
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _remoteShareStreams.remove(remoteUid);
        notifyListeners();
      }
    };

    pc.onRenegotiationNeeded = () => _makeOffer(peer);

    // Re-attach any media we are already sending to this new peer.
    await _attachLocalTracks(peer);

    // The initiator kicks off the first offer.
    if (initiator) await _makeOffer(peer);

    return peer;
  }

  Future<void> _attachLocalTracks(_Peer peer) async {
    try {
      if (_voiceStream != null) {
        for (final t in _voiceStream!.getAudioTracks()) {
          await peer.pc.addTrack(t, _voiceStream!);
        }
      }
      if (_shareStream != null) {
        for (final t in _shareStream!.getVideoTracks()) {
          peer.shareSender = await peer.pc.addTrack(t, _shareStream!);
        }
      }
    } catch (e) {
      debugPrint('attachLocalTracks($peer) error: $e');
    }
  }

  Future<void> _makeOffer(_Peer peer) async {
    try {
      peer.makingOffer = true;
      final offer = await peer.pc.createOffer();
      await peer.pc.setLocalDescription(offer);
      _sendSignal(peer.remoteUid, {
        'kind': 'description',
        'type': offer.type,
        'sdp': offer.sdp,
      });
    } catch (e) {
      debugPrint('makeOffer error: $e');
    } finally {
      peer.makingOffer = false;
    }
  }

  Future<void> _removePeer(String uid) async {
    final peer = _peers.remove(uid);
    if (peer == null) return;
    _remoteShareStreams.remove(uid);
    try {
      await peer.pc.close();
    } catch (_) {}
    notifyListeners();
  }

  // ── Signalling I/O ──────────────────────────────────────────────────────────

  void _sendSignal(String toUid, Map<String, dynamic> data) {
    final roomId = _roomId, myUid = _myUid;
    if (roomId == null || myUid == null) return;
    _db.collection('rooms').doc(roomId).collection('signaling').add({
      ...data,
      'from': myUid,
      'to': toUid,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _onSignals(QuerySnapshot snap) async {
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final doc = change.doc;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      await _handleSignal(data);
      // Consume the message so it isn't reprocessed.
      doc.reference.delete().catchError((_) {});
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> data) async {
    final from = data['from'] as String?;
    if (from == null) return;

    var peer = _peers[from];
    // A peer we don't know yet is offering — create as the polite side.
    peer ??= await _createPeer(from, initiator: false);

    final kind = data['kind'] as String?;
    try {
      if (kind == 'description') {
        final type = data['type'] as String?;
        final sdp = data['sdp'] as String?;
        if (type == null || sdp == null) return;

        final offerCollision = type == 'offer' &&
            (peer.makingOffer ||
                (await peer.pc.getSignalingState()) !=
                    RTCSignalingState.RTCSignalingStateStable);

        peer.ignoreOffer = !peer.polite && offerCollision;
        if (peer.ignoreOffer) return;

        await peer.pc
            .setRemoteDescription(RTCSessionDescription(sdp, type));

        if (type == 'offer') {
          final answer = await peer.pc.createAnswer();
          await peer.pc.setLocalDescription(answer);
          _sendSignal(from, {
            'kind': 'description',
            'type': answer.type,
            'sdp': answer.sdp,
          });
        }
      } else if (kind == 'candidate') {
        final cand = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          (data['sdpMLineIndex'] as num?)?.toInt(),
        );
        try {
          await peer.pc.addCandidate(cand);
        } catch (e) {
          if (!peer.ignoreOffer) debugPrint('addCandidate error: $e');
        }
      }
    } catch (e) {
      debugPrint('handleSignal error: $e');
    }
  }

  // ── Voice ───────────────────────────────────────────────────────────────────

  Future<void> startVoiceChat([String? _]) async {
    if (_voiceActive) return;
    try {
      _voiceStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false});
      _voiceActive = true;
      for (final t in _voiceStream!.getAudioTracks()) {
        for (final peer in _peers.values) {
          await peer.pc.addTrack(t, _voiceStream!); // triggers renegotiation
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('startVoiceChat error: $e');
      _voiceActive = false;
      notifyListeners();
    }
  }

  Future<void> stopVoiceChat() async {
    _voiceStream?.getTracks().forEach((t) => t.stop());
    _voiceStream = null;
    _voiceActive = false;
    notifyListeners();
  }

  // ── Screen / tab share ──────────────────────────────────────────────────────

  /// Begin broadcasting [displayStream] (from getDisplayMedia) to every peer.
  Future<void> startScreenShareBroadcast(MediaStream displayStream) async {
    _shareStream = displayStream;
    _sharing = true;
    final videoTracks = displayStream.getVideoTracks();
    if (videoTracks.isEmpty) return;
    final track = videoTracks.first;
    for (final peer in _peers.values) {
      try {
        peer.shareSender = await peer.pc.addTrack(track, displayStream);
      } catch (e) {
        debugPrint('share addTrack error: $e');
      }
    }
    notifyListeners();
  }

  /// Stop broadcasting the screen/tab share to all peers.
  Future<void> stopScreenShareBroadcast() async {
    for (final peer in _peers.values) {
      final sender = peer.shareSender;
      if (sender != null) {
        try {
          await peer.pc.removeTrack(sender);
        } catch (e) {
          debugPrint('removeTrack error: $e');
        }
        peer.shareSender = null;
      }
    }
    _shareStream = null;
    _sharing = false;
    notifyListeners();
  }

  // Back-compat shims for older call sites.
  Future<void> addScreenShareTrack(MediaStream s) => startScreenShareBroadcast(s);
  Future<void> removeScreenShareTrack() => stopScreenShareBroadcast();

  // ── Teardown ────────────────────────────────────────────────────────────────

  Future<void> leave() async {
    _signalSub?.cancel();
    _signalSub = null;
    for (final uid in _peers.keys.toList()) {
      await _removePeer(uid);
    }
    _voiceStream?.getTracks().forEach((t) => t.stop());
    _voiceStream = null;
    _shareStream = null;
    _voiceActive = false;
    _sharing = false;
    _remoteShareStreams.clear();
    _roomId = null;
    _myUid = null;
    notifyListeners();
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }
}

class _Peer {
  final String remoteUid;
  final RTCPeerConnection pc;
  final bool polite;
  bool makingOffer = false;
  bool ignoreOffer = false;
  RTCRtpSender? shareSender;

  _Peer({required this.remoteUid, required this.pc, required this.polite});

  @override
  String toString() => 'Peer($remoteUid, polite:$polite)';
}