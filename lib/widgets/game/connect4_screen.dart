import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connect4_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

class Connect4Screen extends StatelessWidget {
  final String roomId;
  const Connect4Screen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Connect4Service()..listenToGame(roomId),
      child: _Connect4View(roomId: roomId),
    );
  }
}

class _Connect4View extends StatefulWidget {
  final String roomId;
  const _Connect4View({required this.roomId});
  @override
  State<_Connect4View> createState() => _Connect4ViewState();
}

class _Connect4ViewState extends State<_Connect4View> {
  String? _shownError;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: SimulColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<Connect4Service>();

    // Surface backend failures (offline, permissions) instead of the tap
    // silently doing nothing. Deferred so we never show a SnackBar mid-build.
    if (game.lastError != null && game.lastError != _shownError) {
      _shownError = game.lastError;
      final msg = game.lastError!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _toast(msg));
    } else if (game.lastError == null) {
      _shownError = null;
    }

    final fb = context.read<FirebaseService>();
    final myId = fb.currentUser?.id ?? '';
    final myName = fb.currentUser?.name ?? '';

    final amPlayer1 = game.player1Id == myId;
    final amPlayer2 = game.player2Id == myId;
    final amPlayer = amPlayer1 || amPlayer2;
    final myPiece = amPlayer1 ? 1 : 2;
    final isMyTurn = (game.currentTurn == 1 && amPlayer1) ||
        (game.currentTurn == 2 && amPlayer2);

    return Scaffold(
      backgroundColor: SimulColors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Connect 4'),
        actions: [
          if (fb.isHost || fb.isModerator(myId))
            TextButton(
              onPressed: () => game.restartGame(widget.roomId),
              child: const Text('Restart',
                  style: TextStyle(color: SimulColors.white)),
            ),
        ],
      ),
      body: game.isActive
          ? _buildGame(context, game, fb, myId, myName, amPlayer, myPiece, isMyTurn)
          : _buildLobby(context, game, fb, myId, myName),
    );
  }

  Widget _buildLobby(BuildContext ctx, Connect4Service game,
      FirebaseService fb, String myId, String myName) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Connect 4',
            style: TextStyle(
                color: SimulColors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => game.startGame(widget.roomId, myId, myName),
          child: const Text('Start Game'),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text('Start the game and share the room code to play!',
              style: TextStyle(color: SimulColors.faint),
              textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _buildGame(
      BuildContext ctx,
      Connect4Service game,
      FirebaseService fb,
      String myId,
      String myName,
      bool amPlayer,
      int myPiece,
      bool isMyTurn,
      ) {
    return Column(
      children: [
        // ── Status bar ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (game.winner == 0) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _PlayerChip(
                    name: game.player1Name ?? 'Player 1',
                    piece: 1,
                    active: game.currentTurn == 1),
                const SizedBox(width: 16),
                const Text('vs',
                    style: TextStyle(color: SimulColors.faint)),
                const SizedBox(width: 16),
                _PlayerChip(
                    name: game.player2Name ?? 'Player 2',
                    piece: 2,
                    active: game.currentTurn == 2),
              ]),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final canJoin = !amPlayer && game.player2Id == null;
                final label = canJoin
                    ? 'Tap any column to join as Player 2'
                    : (amPlayer
                        ? (isMyTurn ? 'Your turn!' : 'Waiting…')
                        : 'Spectating');
                final color = (canJoin || isMyTurn)
                    ? SimulColors.success
                    : SimulColors.faint;
                return Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600));
              }),
            ] else ...[
              Text(
                game.winner == -1
                    ? 'Draw! 🤝'
                    : '${game.winner == 1 ? game.player1Name : game.player2Name} wins! 🎉',
                style: const TextStyle(
                    color: SimulColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => game.restartGame(widget.roomId),
                child: const Text('Play Again'),
              ),
            ],
          ]),
        ),

        // ── Board ─────────────────────────────────────────────────────────
        // Expanded (a direct child of this Column) gives the board bounded
        // height; LayoutBuilder then sizes the grid to fit without overflow.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The cell size must satisfy BOTH axes. The old code derived it
              // from width only and then clamped the container's height, so
              // whenever the tab was shorter than the board's natural height
              // (e.g. docked under the video on web) the six rows overflowed
              // — "A RenderFlex overflowed by 123 pixels on the bottom".
              const pad = 4.0;      // board padding
              const gap = 3.0;      // padding around each cell
              final availW = constraints.maxWidth - 32 - pad * 2;
              final availH = constraints.maxHeight - 8 - pad * 2;
              final cell = math.min(availW / kCols, availH / kRows);

              // Nothing sensible to draw in a degenerate box.
              if (cell <= 1 || !cell.isFinite) return const SizedBox.shrink();

              return Center(
                child: Container(
                  width: cell * kCols + pad * 2,
                  height: cell * kRows + pad * 2,
                  padding: const EdgeInsets.all(pad),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A5C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(kRows, (row) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(kCols, (col) {
                        final cell0 = game.board[row][col];
                        return SizedBox(
                          width: cell,
                          height: cell,
                          child: Padding(
                            padding: const EdgeInsets.all(gap),
                            child: GestureDetector(
                                // Anyone who could still take a seat (or is a
                                // player whose turn it is) can tap. The service
                                // auto-seats player 2 and enforces turns, so a
                                // second person just taps a column to start
                                // playing — no separate "join" step required.
                                onTap: game.winner == 0 &&
                                        ((amPlayer && isMyTurn) ||
                                            (!amPlayer &&
                                                game.player2Id == null))
                                    ? () => game.dropPiece(
                                        widget.roomId, myId, myName, col)
                                    : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _cellColor(cell0),
                                  shape: BoxShape.circle,
                                  boxShadow: cell0 != 0
                                      ? [
                                          BoxShadow(
                                            color: _cellColor(cell0)
                                                .withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    )),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Color _cellColor(int cell) {
    switch (cell) {
      case 1:
        return const Color(0xFFF43F5E); // Red
      case 2:
        return const Color(0xFFF59E0B); // Yellow
      default:
        return const Color(0xFF0A1628); // Empty
    }
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final int piece;
  final bool active;
  const _PlayerChip(
      {required this.name, required this.piece, required this.active});

  @override
  Widget build(BuildContext context) {
    final color =
    piece == 1 ? const Color(0xFFF43F5E) : const Color(0xFFF59E0B);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : SimulColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                color: active ? SimulColors.white : SimulColors.faint,
                fontSize: 13,
                fontWeight:
                active ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}
