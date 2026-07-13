import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../models/activity_log.dart';
import '../models/video_queue_item.dart';

/// Result enum for joinRoom – gives callers precise error information
/// so they can show the right message instead of a generic "Room not found".
enum JoinResult { success, notFound, roomFull, networkError }

class FirebaseService extends ChangeNotifier {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  AppUser? _currentUser;
  AppUser? _partner;
  String?  _currentRoomId;
  bool _isConnected  = false;
  bool _isHost       = false;
  String?  _hostId;
  List<String> _moderatorIds    = [];
  List<String> _participantIds  = [];
  List<String> _participantNames = [];

  StreamSubscription? _roomSub;
  StreamSubscription? _partnerSub;

  AppUser? get currentUser      => _currentUser;
  AppUser? get partner          => _partner;
  String?  get partnerName      => _partner?.name;
  bool     get isConnected      => _isConnected;
  bool     get isHost           => _isHost;
  String?  get hostId           => _hostId;
  String?  get currentRoomId    => _currentRoomId;
  bool     isModerator(String uid) => _moderatorIds.contains(uid);
  bool     get isMeHost         => _isHost;
  List<String> get participantIds   => _participantIds;
  List<String> get participantNames => _participantNames;

  @override
  void dispose() {
    _roomSub?.cancel();
    _partnerSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  // ── Create room ────────────────────────────────────────────────────────────

  Future<String?> createRoom(String userName) async {
    try {
      await _ensureAuth();
      final uid = _auth.currentUser!.uid;

      String roomCode;
      bool exists = true;
      do {
        roomCode = _generateRoomCode();
        final doc = await _db.collection('rooms').doc(roomCode).get();
        exists = doc.exists;
      } while (exists);

      final user = AppUser(
        id: uid, name: userName, status: UserStatus.online,
        lastSeen: DateTime.now(), roomId: roomCode, createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toMap());

      await _db.collection('rooms').doc(roomCode).set({
        'createdAt'    : FieldValue.serverTimestamp(),
        'userIds'      : [uid],
        'userNames'    : [userName],
        'maxUsers'     : 20,
        'isActive'     : true,
        'createdBy'    : uid,
        'hostId'       : uid,
        'moderatorIds' : [],
        'queueLocked'  : false,
      });

      await _logActivity(roomCode, ActivityType.userJoined, '$userName created the room');

      _currentRoomId   = roomCode;
      _currentUser     = user;
      _isHost          = true;
      _hostId          = uid;
      _participantIds  = [uid];
      _participantNames = [userName];
      _listenToRoom(roomCode);
      notifyListeners();
      return roomCode;
    } catch (e) {
      debugPrint('createRoom error: $e');
      return null;
    }
  }

  // ── Join room ──────────────────────────────────────────────────────────────
  // FIX: returns JoinResult enum so callers know exactly what went wrong.
  // FIX: checks isActive flag so deleted/empty rooms are rejected.
  // FIX: normalizes room code before Firestore lookup.

  Future<JoinResult> joinRoom(String roomCode, String userName) async {
    try {
      await _ensureAuth();
      final uid        = _auth.currentUser!.uid;
      final normalized = roomCode.trim().toUpperCase();
      final roomRef    = _db.collection('rooms').doc(normalized);
      final roomDoc    = await roomRef.get();

      // Room must exist and still be active
      if (!roomDoc.exists) return JoinResult.notFound;
      final data = roomDoc.data()!;
      if (data['isActive'] == false) return JoinResult.notFound;

      final userIds   = List<String>.from(data['userIds']   ?? []);
      final userNames = List<String>.from(data['userNames'] ?? []);
      final maxUsers  = (data['maxUsers'] as int?) ?? 20;
      final hostId    = data['hostId'] as String? ?? '';

      // Capacity check (skip if user already in room)
      if (!userIds.contains(uid) && userIds.length >= maxUsers) {
        return JoinResult.roomFull;
      }

      final user = AppUser(
        id: uid, name: userName, status: UserStatus.online,
        lastSeen: DateTime.now(), roomId: normalized, createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toMap());

      if (!userIds.contains(uid)) {
        userIds.add(uid);
        userNames.add(userName);
        await roomRef.update({
          'userIds'  : userIds,
          'userNames': userNames,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _logActivity(normalized, ActivityType.userJoined, '$userName joined the room');
      }

      _currentRoomId   = normalized;
      _currentUser     = user;
      _isHost          = uid == hostId;
      _hostId          = hostId;
      _participantIds  = userIds;
      _participantNames = userNames;

      _listenToRoom(normalized);
      notifyListeners();
      return JoinResult.success;
    } catch (e) {
      debugPrint('joinRoom error: $e');
      return JoinResult.networkError;
    }
  }

  // ── Initialize (called after navigating to RoomScreen) ────────────────────

  Future<void> initializeRoom(String roomId, String userName) async {
    _currentRoomId = roomId;
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) _currentUser = AppUser.fromMap(uid, doc.data()!);
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      if (roomDoc.exists) {
        final data = roomDoc.data()!;
        _isHost          = data['hostId'] == uid;
        _hostId          = data['hostId'] as String?;
        _moderatorIds    = List<String>.from(data['moderatorIds'] ?? []);
        _participantIds  = List<String>.from(data['userIds']      ?? []);
        _participantNames = List<String>.from(data['userNames']   ?? []);
      }
    }
    _listenToRoom(roomId);
  }

  void _listenToRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = _db.collection('rooms').doc(roomId).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final uid  = _auth.currentUser?.uid ?? '';
      _participantIds   = List<String>.from(data['userIds']      ?? []);
      _participantNames = List<String>.from(data['userNames']    ?? []);
      _isConnected      = _participantIds.length >= 2;
      _isHost           = data['hostId'] == uid;
      _hostId           = data['hostId'] as String?;
      _moderatorIds     = List<String>.from(data['moderatorIds'] ?? []);

      if (_currentUser != null && _participantIds.length >= 2) {
        final pid = _participantIds.firstWhere(
                (id) => id != uid, orElse: () => '');
        if (pid.isNotEmpty) _loadPartner(pid);
      } else {
        _partner = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadPartner(String partnerId) async {
    _partnerSub?.cancel();
    _partnerSub = _db.collection('users').doc(partnerId).snapshots().listen((snap) {
      if (snap.exists) {
        _partner = AppUser.fromMap(snap.id, snap.data()!);
        notifyListeners();
      }
    });
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  Future<void> sendMessage(String roomId, String text, String sender,
      {String? replyToId, String? replyToText}) async {
    try {
      await _db.collection('rooms').doc(roomId).collection('messages').add({
        'text': text, 'sender': sender,
        'senderId' : _currentUser?.id,
        'timestamp': FieldValue.serverTimestamp(),
        'replyToId': replyToId, 'replyToText': replyToText,
        'reactions': {}, 'deleted': false,
      });
    } catch (e) { debugPrint('sendMessage error: $e'); }
  }

  Future<void> deleteMessage(String roomId, String messageId) async {
    await _db.collection('rooms').doc(roomId)
        .collection('messages').doc(messageId)
        .update({'deleted': true, 'text': ''});
  }

  Future<void> addReactionToMessage(String roomId, String messageId,
      String emoji, String userId) async {
    final ref = _db.collection('rooms').doc(roomId)
        .collection('messages').doc(messageId);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final data      = doc.data()!;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      final users     = List<String>.from(reactions[emoji] ?? []);
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      reactions[emoji] = users;
      tx.update(ref, {'reactions': reactions});
    });
  }

  Stream<List<Message>> getMessagesStream(String roomId) {
    return _db.collection('rooms').doc(roomId).collection('messages')
        .orderBy('timestamp').snapshots()
        .map((s) => s.docs.map((d) => Message.fromMap(d.id, d.data())).toList());
  }

  // ── Queue ──────────────────────────────────────────────────────────────────

  Future<void> addToQueue(String roomId, String videoId, String title) async {
    final ref   = _db.collection('rooms').doc(roomId).collection('queue');
    final count = (await ref.get()).docs.length;
    await ref.add({
      'videoId'    : videoId,
      'title'      : title,
      'addedBy'    : _currentUser?.id   ?? '',
      'addedByName': _currentUser?.name ?? '',
      'addedAt'    : FieldValue.serverTimestamp(),
      'upvotes': 0, 'downvotes': 0, 'upvotedBy': [],
      'approved': true, 'order': count,
    });
  }

  Future<void> removeFromQueue(String roomId, String itemId) async {
    await _db.collection('rooms').doc(roomId).collection('queue').doc(itemId).delete();
  }

  Future<void> voteQueue(String roomId, String itemId, bool up, String userId) async {
    final ref = _db.collection('rooms').doc(roomId).collection('queue').doc(itemId);
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final data      = doc.data()!;
      final upvotedBy = List<String>.from(data['upvotedBy'] ?? []);
      int upvotes     = data['upvotes']   ?? 0;
      int downvotes   = data['downvotes'] ?? 0;
      if (upvotedBy.contains(userId)) {
        upvotedBy.remove(userId);
        if (up) {
          upvotes--;
        } else {
          downvotes--;
        }
      } else {
        upvotedBy.add(userId);
        if (up) {
          upvotes++;
        } else {
          downvotes++;
        }
      }
      tx.update(ref, {'upvotes': upvotes, 'downvotes': downvotes, 'upvotedBy': upvotedBy});
    });
  }

  Stream<List<VideoQueueItem>> getQueueStream(String roomId) {
    return _db.collection('rooms').doc(roomId).collection('queue')
        .orderBy('order').snapshots()
        .map((s) => s.docs.map((d) => VideoQueueItem.fromMap(d.id, d.data())).toList());
  }

  // ── Reactions ──────────────────────────────────────────────────────────────

  Future<void> sendReaction(String roomId, String emoji) async {
    await _db.collection('rooms').doc(roomId).collection('reactions').add({
      'emoji'    : emoji,
      'userId'   : _currentUser?.id   ?? '',
      'userName' : _currentUser?.name ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getReactionsStream(String roomId) {
    final since = DateTime.now().subtract(const Duration(seconds: 5));
    return _db.collection('rooms').doc(roomId).collection('reactions')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .snapshots();
  }

  // ── Activity log ───────────────────────────────────────────────────────────

  Future<void> _logActivity(String roomId, ActivityType type, String message) async {
    await _db.collection('rooms').doc(roomId).collection('activityLog').add({
      'type'     : type.name,
      'message'  : message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ActivityLog>> getActivityStream(String roomId) {
    return _db.collection('rooms').doc(roomId).collection('activityLog')
        .orderBy('timestamp', descending: true).limit(50).snapshots()
        .map((s) => s.docs.map((d) => ActivityLog.fromMap(d.id, d.data())).toList());
  }

  // ── Moderators ─────────────────────────────────────────────────────────────

  Future<void> promoteModerator(String roomId, String userId, String userName) async {
    await _db.collection('rooms').doc(roomId).update({
      'moderatorIds': FieldValue.arrayUnion([userId]),
    });
    await _logActivity(roomId, ActivityType.moderatorAdded, '$userName was promoted to moderator');
  }

  Future<void> demoteModerator(String roomId, String userId, String userName) async {
    await _db.collection('rooms').doc(roomId).update({
      'moderatorIds': FieldValue.arrayRemove([userId]),
    });
    await _logActivity(roomId, ActivityType.moderatorRemoved, '$userName was removed as moderator');
  }

  Future<void> removeParticipant(String roomId, String userId, String userName) async {
    await _db.collection('rooms').doc(roomId).update({
      'userIds'  : FieldValue.arrayRemove([userId]),
      'userNames': FieldValue.arrayRemove([userName]),
      'bannedIds': FieldValue.arrayUnion([userId]),
    });
    await _logActivity(roomId, ActivityType.userRemoved, '$userName was removed');
  }

  Future<void> clearChat(String roomId) async {
    final batch = _db.batch();
    final msgs = await _db.collection('rooms').doc(roomId).collection('messages').get();
    for (final doc in msgs.docs) {
      batch.update(doc.reference, {'deleted': true, 'text': ''});
    }
    await batch.commit();
    await _logActivity(roomId, ActivityType.chatCleared, 'Chat was cleared');
  }

  // ── Invite ─────────────────────────────────────────────────────────────────

  String generateInviteLink(String roomId) => 'https://simul.app/join/$roomId';

  // ── Leave ──────────────────────────────────────────────────────────────────

  Future<void> leaveRoom() async {
    if (_currentRoomId == null || _currentUser == null) return;
    try {
      final roomRef = _db.collection('rooms').doc(_currentRoomId);
      await _db.runTransaction((tx) async {
        final doc = await tx.get(roomRef);
        if (!doc.exists) return;
        final data  = doc.data()!;
        final ids   = List<String>.from(data['userIds']   ?? []);
        final names = List<String>.from(data['userNames'] ?? []);
        ids.remove(_currentUser!.id);
        names.remove(_currentUser!.name);
        String? newHost;
        if (data['hostId'] == _currentUser!.id && ids.isNotEmpty) {
          newHost = ids.first;
        }
        final update = <String, dynamic>{
          'userIds'  : ids,
          'userNames': names,
          'isActive' : ids.isNotEmpty,
        };
        if (newHost != null) update['hostId'] = newHost;
        tx.update(roomRef, update);
      });

      await _logActivity(_currentRoomId!, ActivityType.userLeft,
          '${_currentUser!.name} left the room');

      await _db.collection('users').doc(_currentUser!.id).update({
        'roomId': null, 'status': 'offline', 'lastSeen': Timestamp.now(),
      });

      _roomSub?.cancel();
      _partnerSub?.cancel();
      _currentRoomId    = null;
      _partner          = null;
      _isConnected      = false;
      _isHost           = false;
      _participantIds   = [];
      _participantNames = [];
      notifyListeners();
    } catch (e) { debugPrint('leaveRoom error: $e'); }
  }

  // ── Typing indicator ───────────────────────────────────────────────────────

  Future<void> setTyping(String roomId, bool isTyping) async {
    final uid = _currentUser?.id ?? '';
    if (uid.isEmpty) return;
    await _db.collection('rooms').doc(roomId).collection('typing').doc(uid).set({
      'name'    : _currentUser?.name ?? '',
      'isTyping': isTyping,
      'ts'      : FieldValue.serverTimestamp(),
    });
  }

  Stream<List<String>> getTypingStream(String roomId) {
    return _db.collection('rooms').doc(roomId).collection('typing')
        .snapshots()
        .map((s) => s.docs
        .where((d) => d.data()['isTyping'] == true && d.id != (_currentUser?.id ?? ''))
        .map((d) => d.data()['name'] as String)
        .toList());
  }
}
