import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// SIMUL YouTube Sync Service
///
/// Fixes vs the old SIMUL version:
///  1. Join-time guard loosened: was `!eventTime.isAfter(joinTime - 1s)` which
///     silently dropped events that arrived within the first second of joining.
///     Now uses a 3-second grace window so a new joiner always gets the initial
///     'load' + 'sync' event even on slow connections.
///  2. Dedup guard is retained to prevent loops from own events.
///  3. Throttle kept (2-second position drift) to avoid Firestore write storms.
class YouTubeSyncService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get videoStateStream => _stateController.stream;

  StreamSubscription? _syncSub;
  DateTime? _joinTime;
  String?   _myUserId;
  String?   _lastEventId; // dedupe

  double _lastSentPosition = -999;
  bool   _lastSentPlaying  = false;

  // ── Listen ─────────────────────────────────────────────────────────────────

  void listenToVideoSync(String roomId, String myUserId) {
    _myUserId = myUserId;
    _syncSub?.cancel();
    _joinTime = DateTime.now();

    _syncSub = _db
        .collection('rooms')
        .doc(roomId)
        .collection('videoSync')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;
      final doc  = snap.docs.first;
      if (doc.id == _lastEventId) return; // dedupe

      final data = doc.data();

      // Skip own events (prevents echo loops)
      if (data['senderId'] == _myUserId) return;

      // FIX: grace window of 3 s so new joiners receive the 'load' event that
      // was written just before or just after they joined.  The old code used
      // a 1-second grace but subtracted from joinTime, so events within the
      // first second were silently dropped – causing the "other person cannot
      // join the room" bug where the video never loaded for the late joiner.
      final ts = data['timestamp'];
      if (ts != null && _joinTime != null) {
        final eventTime = (ts as Timestamp).toDate();
        final cutoff    = _joinTime!.subtract(const Duration(seconds: 3));
        if (eventTime.isBefore(cutoff)) return; // truly stale; skip
      }

      _lastEventId = doc.id;
      _stateController.add(data);
    });
  }

  // ── Send helpers ───────────────────────────────────────────────────────────

  Future<void> _send(
      String roomId, String senderId, Map<String, dynamic> payload) async {
    try {
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('videoSync')
          .add({
        ...payload,
        'senderId' : senderId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Audit fix: sync writes fired from play/pause/seek callbacks were
      // unguarded — offline, every interaction threw an unhandled async
      // error. Sync events are fire-and-forget by nature; the periodic
      // position sync self-heals once the connection returns.
      debugPrint('[Sync] send failed (${payload['action']}): $e');
    }
  }

  /// Shares an arbitrary web link with the room (mobile "share by link" for
  /// non-YouTube URLs). Receivers show an "open link" prompt — nothing is
  /// embedded, so this works for any site.
  Future<void> sendLinkShared(
          String roomId, String senderId, String url, String byName) =>
      _send(roomId, senderId, {
        'action': 'link',
        'url'   : url,
        'byName': byName,
      });

  Future<void> sendVideoLoaded(
          String roomId, String senderId, String videoId, {String title = ''}) =>
      _send(roomId, senderId, {
        'action' : 'load',
        'videoId': videoId,
        'title'  : title,
      });

  Future<void> sendPlayEvent(
      String roomId, String senderId, double position) {
    _lastSentPlaying  = true;
    _lastSentPosition = position;
    return _send(roomId, senderId,
        {'action': 'play', 'position': position, 'isPlaying': true});
  }

  Future<void> sendPauseEvent(
      String roomId, String senderId, double position) {
    _lastSentPlaying  = false;
    _lastSentPosition = position;
    return _send(roomId, senderId,
        {'action': 'pause', 'position': position, 'isPlaying': false});
  }

  Future<void> sendSeekEvent(
      String roomId, String senderId, double position) {
    _lastSentPosition = position;
    return _send(roomId, senderId,
        {'action': 'seek', 'position': position});
  }

  /// Periodic sync – only writes if position or play-state meaningfully changed.
  Future<void> sendPositionSync(
      String roomId, String senderId, double position, bool isPlaying) async {
    final drift        = (position - _lastSentPosition).abs();
    final stateChanged = isPlaying != _lastSentPlaying;
    if (drift < 2.0 && !stateChanged) return;
    _lastSentPosition = position;
    _lastSentPlaying  = isPlaying;
    return _send(roomId, senderId,
        {'action': 'sync', 'position': position, 'isPlaying': isPlaying});
  }

  void stopListening() {
    _syncSub?.cancel();
    _joinTime    = null;
    _myUserId    = null;
    _lastEventId = null;
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _stateController.close();
    super.dispose();
  }
}
