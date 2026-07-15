import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const int kRows = 6;
const int kCols = 7;

class Connect4Service extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription? _gameSub;

  List<List<int>> board = List.generate(kRows, (_) => List.filled(kCols, 0));
  int currentTurn = 1; // 1 = player1, 2 = player2
  String? player1Id;
  String? player2Id;
  String? player1Name;
  String? player2Name;
  int winner = 0; // 0=none, 1=p1, 2=p2, -1=draw
  String? gameDocId;
  bool isActive = false;

  bool _disposed = false;

  /// The last error the service hit, if any (surfaced in the UI).
  String? lastError;

  DocumentReference<Map<String, dynamic>> _ref(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('connect4').doc('game');

  /// notifyListeners() that is safe to call from a Firestore snapshot.
  ///
  /// Two real crashes came from calling notifyListeners() naively here:
  ///   1. Firestore can deliver a CACHED snapshot synchronously, while the
  ///      widget that created this service is still building. Notifying then
  ///      marks listeners dirty during build → framework assertion.
  ///   2. A snapshot can land after the provider disposed this service →
  ///      "used after being disposed" throw.
  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  /// Rebuilds a 6x7 board from Firestore's flat array, tolerating a missing,
  /// short, over-long or wrongly-typed array instead of throwing a RangeError
  /// inside the stream (which surfaced as an unhandled crash).
  List<List<int>> _parseBoard(dynamic raw) {
    final flat = List<int>.filled(kRows * kCols, 0);
    if (raw is List) {
      for (var i = 0; i < kRows * kCols && i < raw.length; i++) {
        final v = raw[i];
        flat[i] = v is num ? v.toInt() : 0;
      }
    }
    return List.generate(
        kRows, (r) => flat.sublist(r * kCols, r * kCols + kCols));
  }

  void listenToGame(String roomId) {
    _gameSub?.cancel();
    _gameSub = _ref(roomId).snapshots().listen((snap) {
      if (_disposed) return;
      try {
        if (!snap.exists) {
          isActive = false;
          _safeNotify();
          return;
        }
        final data = snap.data() ?? const <String, dynamic>{};
        isActive    = true;
        currentTurn = (data['currentTurn'] as num?)?.toInt() ?? 1;
        player1Id   = data['player1Id'] as String?;
        player2Id   = data['player2Id'] as String?;
        player1Name = data['player1Name'] as String?;
        player2Name = data['player2Name'] as String?;
        winner      = (data['winner'] as num?)?.toInt() ?? 0;
        board       = _parseBoard(data['board']);
        lastError   = null;
        _safeNotify();
      } catch (e) {
        debugPrint('[Connect4] snapshot parse failed: $e');
        lastError = 'Could not read the game state.';
        _safeNotify();
      }
    }, onError: (e) {
      debugPrint('[Connect4] stream error: $e');
      lastError = 'Lost connection to the game.';
      _safeNotify();
    });
  }

  /// Returns true on success. Never throws — a Firestore write can fail
  /// (offline, rules), and an unguarded throw here surfaced as an unhandled
  /// async error straight out of the button's onPressed, crashing the tab.
  Future<bool> startGame(String roomId, String myId, String myName,
      {String? opponentId, String? opponentName}) async {
    try {
      final flat = List<int>.filled(kRows * kCols, 0);
      await _ref(roomId).set({
        'board': flat, 'currentTurn': 1, 'winner': 0,
        'player1Id': myId, 'player1Name': myName,
        'player2Id': opponentId, 'player2Name': opponentName,
        'startedAt': FieldValue.serverTimestamp(),
      });
      lastError = null;
      return true;
    } catch (e) {
      debugPrint('[Connect4] startGame failed: $e');
      lastError = "Couldn't start the game — check your connection.";
      _safeNotify();
      return false;
    }
  }

  /// Drops a piece for [myId] in [col].
  ///
  /// FIX for "only one player can click": the whole move now runs inside a
  /// transaction that reads the LATEST board and, crucially, AUTO-JOINS the
  /// caller as player 2 if the seat is still open. Previously the second
  /// person had to notice and tap a small "Join as Player 2" link before any
  /// tap did anything — miss it, and only player 1 could ever play. Now the
  /// second person simply taps a column and is seated automatically.
  Future<bool> dropPiece(String roomId, String myId, String myName, int col) async {
    if (col < 0 || col >= kCols) return false;
    final ref = _ref(roomId);
    try {
      return await _db.runTransaction<bool>((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists) return false;
        final data = doc.data()!;

        String? p1 = data['player1Id'] as String?;
        String? p2 = data['player2Id'] as String?;
        final int turn   = (data['currentTurn'] as num?)?.toInt() ?? 1;
        final int win    = (data['winner'] as num?)?.toInt() ?? 0;
        if (win != 0) return false;

        // Seat the caller if they aren't a player yet and a seat is open.
        final Map<String, dynamic> seatUpdate = {};
        if (myId != p1 && myId != p2) {
          if (p1 == null) {
            p1 = myId;
            seatUpdate['player1Id'] = myId;
            seatUpdate['player1Name'] = myName;
          } else if (p2 == null) {
            p2 = myId;
            seatUpdate['player2Id'] = myId;
            seatUpdate['player2Name'] = myName;
          } else {
            return false; // both seats taken → spectator
          }
        }

        final myPiece = (myId == p1) ? 1 : 2;
        if (turn != myPiece) {
          // Not their turn — but still persist a seat grab if we made one, so
          // the button/label updates for everyone.
          if (seatUpdate.isNotEmpty) tx.update(ref, seatUpdate);
          return false;
        }

        // Rebuild the board from the transaction snapshot (authoritative).
        final flat = List<int>.from(
            data['board'] ?? List.filled(kRows * kCols, 0));
        final b = List.generate(
            kRows, (r) => flat.sublist(r * kCols, r * kCols + kCols));

        // Lowest empty row in the column.
        int row = -1;
        for (int r = kRows - 1; r >= 0; r--) {
          if (b[r][col] == 0) { row = r; break; }
        }
        if (row == -1) {
          if (seatUpdate.isNotEmpty) tx.update(ref, seatUpdate);
          return false; // column full
        }

        b[row][col] = myPiece;
        final newFlat = [for (final r in b) ...r];
        final newWinner = _checkWinner(b, row, col, myPiece);
        final isDraw = newWinner == 0 && newFlat.every((c) => c != 0);

        tx.update(ref, {
          ...seatUpdate,
          'board': newFlat,
          'currentTurn': myPiece == 1 ? 2 : 1,
          'winner': isDraw ? -1 : newWinner,
        });
        return true;
      });
    } catch (e) {
      debugPrint('[Connect4] dropPiece failed: $e');
      lastError = "Couldn't make that move — check your connection.";
      _safeNotify();
      return false;
    }
  }

  int _checkWinner(List<List<int>> b, int row, int col, int player) {
    final dirs = [[0,1],[1,0],[1,1],[1,-1]];
    for (final d in dirs) {
      int count = 1;
      for (int dir = -1; dir <= 1; dir += 2) {
        int r = row + dir * d[0];
        int c = col + dir * d[1];
        while (r >= 0 && r < kRows && c >= 0 && c < kCols && b[r][c] == player) {
          count++; r += dir * d[0]; c += dir * d[1];
        }
      }
      if (count >= 4) return player;
    }
    return 0;
  }

  Future<bool> restartGame(String roomId) async {
    try {
      await _ref(roomId).update({
        'board': List.filled(kRows * kCols, 0), 'currentTurn': 1, 'winner': 0,
      });
      lastError = null;
      return true;
    } catch (e) {
      debugPrint('[Connect4] restartGame failed: $e');
      lastError = "Couldn't restart the game — check your connection.";
      _safeNotify();
      return false;
    }
  }

  Future<void> joinAsPlayer(String roomId, String myId, String myName) async {
    final ref = _ref(roomId);
    try {
      await _db.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists) return;
        final data = doc.data()!;
        if (data['player1Id'] != myId &&
            data['player2Id'] == null &&
            data['player1Id'] != null) {
          tx.update(ref, {'player2Id': myId, 'player2Name': myName});
        }
      });
    } catch (e) {
      debugPrint('[Connect4] joinAsPlayer failed: $e');
      lastError = "Couldn't join the game — check your connection.";
      _safeNotify();
    }
  }

  void stopListening() { _gameSub?.cancel(); }

  @override
  void dispose() {
    _disposed = true;
    _gameSub?.cancel();
    super.dispose();
  }
}