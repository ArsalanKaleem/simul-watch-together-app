import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  DocumentReference<Map<String, dynamic>> _ref(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('connect4').doc('game');

  void listenToGame(String roomId) {
    _gameSub?.cancel();
    _gameSub = _ref(roomId).snapshots().listen((snap) {
      if (!snap.exists) { isActive = false; notifyListeners(); return; }
      final data = snap.data()!;
      isActive = true;
      currentTurn = data['currentTurn'] ?? 1;
      player1Id = data['player1Id'];
      player2Id = data['player2Id'];
      player1Name = data['player1Name'];
      player2Name = data['player2Name'];
      winner = data['winner'] ?? 0;
      final flat = List<int>.from(data['board'] ?? List.filled(kRows * kCols, 0));
      board = List.generate(kRows, (r) => flat.sublist(r * kCols, r * kCols + kCols));
      notifyListeners();
    });
  }

  Future<void> startGame(String roomId, String myId, String myName,
      {String? opponentId, String? opponentName}) async {
    final flat = List<int>.filled(kRows * kCols, 0);
    await _ref(roomId).set({
      'board': flat, 'currentTurn': 1, 'winner': 0,
      'player1Id': myId, 'player1Name': myName,
      'player2Id': opponentId, 'player2Name': opponentName,
      'startedAt': FieldValue.serverTimestamp(),
    });
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

  Future<void> restartGame(String roomId) async {
    await _ref(roomId).update({
      'board': List.filled(kRows * kCols, 0), 'currentTurn': 1, 'winner': 0,
    });
  }

  Future<void> joinAsPlayer(String roomId, String myId, String myName) async {
    final ref = _ref(roomId);
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
  }

  void stopListening() { _gameSub?.cancel(); }

  @override
  void dispose() { _gameSub?.cancel(); super.dispose(); }
}
