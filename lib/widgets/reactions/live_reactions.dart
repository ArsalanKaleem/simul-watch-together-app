import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

const _emojis = ['👍', '❤️', '😂', '🔥', '😮'];

class LiveReactions extends StatefulWidget {
  final String roomId;
  const LiveReactions({super.key, required this.roomId});
  @override
  State<LiveReactions> createState() => _LiveReactionsState();
}

class _LiveReactionsState extends State<LiveReactions> {
  final List<_FloatingEmoji> _floating = [];
  StreamSubscription? _sub;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    final svc = context.read<FirebaseService>();
    _sub = svc.getReactionsStream(widget.roomId).listen((QuerySnapshot querySnapshot) {
      for (var change in querySnapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final documentData = change.doc.data() as Map<String, dynamic>?;
          final emoji = documentData?['emoji'] as String? ?? '👍';
          _addFloating(emoji);
        }
      }
    });
  }

  void _addFloating(String emoji) {
    if (!mounted) return;
    final id = DateTime.now().microsecondsSinceEpoch;
    final xOffset = _rand.nextDouble() * 0.6 + 0.2;
    setState(() => _floating.add(_FloatingEmoji(id: id, emoji: emoji, xRatio: xOffset)));
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _floating.removeWhere((e) => e.id == id));
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    return Stack(children: [
      // Floating emojis overlay — purely decorative, so it must never
      // intercept a tap meant for the video/controls underneath.
      IgnorePointer(
        child: Stack(children: [
          ...(_floating.map((e) => _AnimatedEmoji(data: e))),
        ]),
      ),

      // Reaction bar at bottom
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _emojis.map((emoji) =>
                GestureDetector(
                  // Guarded: an offline write here used to throw an
                  // unhandled async error straight out of the tap handler.
                  onTap: () => svc
                      .sendReaction(widget.roomId, emoji)
                      .catchError((_) {}),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SimulColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SimulColors.border),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                )).toList(),
          ),
        ),
      ),
    ]);
  }
}

class _FloatingEmoji {
  final int id;
  final String emoji;
  final double xRatio;
  _FloatingEmoji({required this.id, required this.emoji, required this.xRatio});
}

class _AnimatedEmoji extends StatefulWidget {
  final _FloatingEmoji data;
  const _AnimatedEmoji({required this.data});
  @override
  State<_AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<_AnimatedEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _y, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
    _y = Tween<double>(begin: 0, end: -180).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 0), weight: 90),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        bottom: 80 + _y.value,
        left: MediaQuery.of(context).size.width * widget.data.xRatio,
        child: Opacity(
          opacity: _opacity.value,
          child: Text(widget.data.emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}
