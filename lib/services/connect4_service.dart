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

  void listenToGame(String roomId) {
    _gameSub?.cancel();
    _gameSub = _db.collection('rooms').doc(roomId)
        .collection('connect4').doc('game')
        .snapshots().listen((snap) {
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
    await _db.collection('rooms').doc(roomId).collection('connect4').doc('game').set({
      'board': flat, 'currentTurn': 1, 'winner': 0,
      'player1Id': myId, 'player1Name': myName,
      'player2Id': opponentId, 'player2Name': opponentName,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> dropPiece(String roomId, String myId, int col) async {
    final myTurn = (currentTurn == 1 && myId == player1Id) ||
        (currentTurn == 2 && myId == player2Id);
    if (!myTurn || winner != 0) return false;

    // Find lowest empty row in col
    int row = -1;
    for (int r = kRows - 1; r >= 0; r--) {
      if (board[r][col] == 0) { row = r; break; }
    }
    if (row == -1) return false; // column full

    final newBoard = board.map((r) => List<int>.from(r)).toList();
    newBoard[row][col] = currentTurn;
    final flat = [for (final r in newBoard) ...r];

    final newWinner = _checkWinner(newBoard, row, col, currentTurn);
    final isDraw = newWinner == 0 && flat.every((c) => c != 0);

    await _db.collection('rooms').doc(roomId).collection('connect4').doc('game').update({
      'board': flat,
      'currentTurn': currentTurn == 1 ? 2 : 1,
      'winner': isDraw ? -1 : newWinner,
    });
    return true;
  }

  int _checkWinner(List<List<int>> b, int row, int col, int player) {
    // Check all 4 directions
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
    await _db.collection('rooms').doc(roomId).collection('connect4').doc('game').update({
      'board': List.filled(kRows * kCols, 0), 'currentTurn': 1, 'winner': 0,
    });
  }

  Future<void> joinAsPlayer(String roomId, String myId, String myName) async {
    final ref = _db.collection('rooms').doc(roomId).collection('connect4').doc('game');
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) return;
      final data = doc.data()!;
      if (data['player2Id'] == null) {
        tx.update(ref, {'player2Id': myId, 'player2Name': myName});
      }
    });
  }

  void stopListening() { _gameSub?.cancel(); }

  @override
  void dispose() { _gameSub?.cancel(); super.dispose(); }
}
