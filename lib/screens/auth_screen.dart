// lib/screens/auth_screen.dart
//
// RESPONSIVE REWRITE.
//
// What was wrong before:
//  • Fixed maxWidth(440) + fixed horizontal padding(28) meant very narrow
//    phones (≤360px) had cramped fields, and very wide desktop windows just
//    left the form floating with no visual anchor.
//  • No keyboard-safe handling: on short screens, opening the keyboard could
//    push the button off-screen (only a bare SingleChildScrollView, no
//    minHeight so the button could sit awkwardly high on tall screens).
//  • The "Room Created" dialog used a fixed Dialog with no width constraint,
//    fixed insetPadding, a 30px letter-spaced room code with NO overflow
//    protection (would clip/overflow on narrow phones), and no distinction
//    between mobile/desktop presentation.
//
// What's fixed:
//  • LayoutBuilder-driven breakpoints: compact (<600), medium (600-900),
//    wide (>900) — padding and max width scale accordingly.
//  • A true responsive dialog: bottom sheet on compact screens (matches the
//    pattern already used elsewhere in the app for the invite sheet),
//    centered constrained dialog on wide screens.
//  • Room code uses FittedBox so it always fits, however narrow.
//  • Buttons switch from a Row to a stacked Column if the available width
//    ever gets too tight to hold both comfortably.
//  • SafeArea + scroll view sized to the viewport so content is never
//    unreachable behind the keyboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/firebase_service.dart';
import '../screens/room_screen.dart';
import '../screens/settings_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _isCreating = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  void _switchTab(bool creating) => setState(() => _isCreating = creating);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SimulColors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: SimulColors.faint),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final compact = w < 600;
            final maxFormWidth = w >= 900 ? 460.0 : (w >= 600 ? 420.0 : 440.0);
            final hPad = compact ? 20.0 : 32.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: compact ? 24 : 40,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxFormWidth,
                    minHeight: constraints.maxHeight - (compact ? 48 : 80),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Logo(compact: compact),
                      SizedBox(height: compact ? 32 : 48),

                      // Tab switcher
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: SimulColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SimulColors.border),
                        ),
                        child: Row(children: [
                          _TabBtn('Create Room', _isCreating,
                              () => _switchTab(true)),
                          _TabBtn('Join Room', !_isCreating,
                              () => _switchTab(false)),
                        ]),
                      ),

                      const SizedBox(height: 28),

                      _SimulField(
                        controller: _nameCtrl,
                        label: 'Your name',
                        icon: Icons.person_outline,
                      ),

                      if (!_isCreating) ...[
                        const SizedBox(height: 12),
                        _SimulField(
                          controller: _roomCtrl,
                          label: 'Room code',
                          icon: Icons.tag_rounded,
                          caps: TextCapitalization.characters,
                        ),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        height: 50,
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: SimulColors.white,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _isCreating ? _createRoom : _joinRoom,
                                child: Text(
                                    _isCreating ? 'Create Room' : 'Join Room'),
                              ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Anonymous. No account needed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SimulColors.subtle, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _createRoom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _err('Enter your name');
      return;
    }
    setState(() => _isLoading = true);
    final svc = context.read<FirebaseService>();
    final roomId = await svc.createRoom(name);
    setState(() => _isLoading = false);
    if (roomId != null && mounted) {
      _showCreated(roomId, name);
    } else if (mounted) {
      _err('Could not create room. Check connection.');
    }
  }

  void _joinRoom() async {
    final name = _nameCtrl.text.trim();
    final code = _roomCtrl.text.trim().toUpperCase();
    if (name.isEmpty) {
      _err('Enter your name');
      return;
    }
    if (code.isEmpty) {
      _err('Enter room code');
      return;
    }
    if (code.length != 6) {
      _err('Room code must be 6 characters');
      return;
    }
    setState(() => _isLoading = true);
    final svc = context.read<FirebaseService>();
    final result = await svc.joinRoom(code, name);
    setState(() => _isLoading = false);
    if (!mounted) return;
    switch (result) {
      case JoinResult.success:
        Navigator.push(context, _route(RoomScreen(roomId: code, userName: name)));
      case JoinResult.notFound:
        _err('Room not found. Check the code and try again.');
      case JoinResult.roomFull:
        _err('Room is full (max 20 participants).');
      case JoinResult.networkError:
        _err('Connection error. Check your network and retry.');
    }
  }

  // Responsive "room created" presentation: bottom sheet on compact screens
  // (thumb-reachable, matches the invite sheet elsewhere in the app), a
  // centered constrained dialog on wide screens. Either way the content is
  // the same _RoomCreatedContent, which is itself overflow-safe.
  void _showCreated(String roomId, String name) {
    final compact = MediaQuery.of(context).size.width < 600;

    if (compact) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: SimulColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: _RoomCreatedContent(
                roomId: roomId,
                onEnter: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context, _route(RoomScreen(roomId: roomId, userName: name)));
                },
              ),
            ),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: SimulColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SimulColors.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: _RoomCreatedContent(
              roomId: roomId,
              onEnter: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context, _route(RoomScreen(roomId: roomId, userName: name)));
              },
            ),
          ),
        ),
      ),
    );
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: SimulColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  PageRoute _route(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      );
}

// ── Sub-widgets ──────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final bool compact;
  const _Logo({required this.compact});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: SimulColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SimulColors.border),
          ),
          child: const Center(
            child: Text('S',
                style: TextStyle(
                    color: SimulColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 16),
        Text('SIMUL',
            style: TextStyle(
                color: SimulColors.white,
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('Watch together, in sync.',
            style: TextStyle(color: SimulColors.faint, fontSize: 14)),
      ]);
}

class _RoomCreatedContent extends StatefulWidget {
  final String roomId;
  final VoidCallback onEnter;
  const _RoomCreatedContent({required this.roomId, required this.onEnter});

  @override
  State<_RoomCreatedContent> createState() => _RoomCreatedContentState();
}

class _RoomCreatedContentState extends State<_RoomCreatedContent> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.roomId));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: SimulColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: SimulColors.success, size: 24),
      ),
      const SizedBox(height: 16),
      const Text('Room Created',
          style: TextStyle(
              color: SimulColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Share this code to invite others',
          textAlign: TextAlign.center,
          style: TextStyle(color: SimulColors.faint, fontSize: 13)),
      const SizedBox(height: 24),

      // Code box — FittedBox guarantees the code never overflows or clips,
      // regardless of how narrow the sheet/dialog ends up being.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: SimulColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SimulColors.border),
        ),
        child: Column(children: [
          const Text('ROOM CODE',
              style: TextStyle(
                  color: SimulColors.faint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.roomId,
                style: const TextStyle(
                    color: SimulColors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4)),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // LayoutBuilder + fallback: on a genuinely tiny width the two actions
      // stack instead of squeezing into an unreadable sliver. On normal
      // widths they sit side by side as before.
      LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 300;
        final copyBtn = OutlinedButton.icon(
          onPressed: _copy,
          icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16, color: _copied ? SimulColors.success : SimulColors.faint),
          label: Text(_copied ? 'Copied!' : 'Copy',
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: _copied ? SimulColors.success : SimulColors.faint)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _copied ? SimulColors.success : SimulColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        final enterBtn = ElevatedButton(
          onPressed: widget.onEnter,
          child: const Text('Enter Room', overflow: TextOverflow.ellipsis),
        );

        if (stacked) {
          return Column(children: [
            SizedBox(width: double.infinity, child: enterBtn),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: copyBtn),
          ]);
        }
        return Row(children: [
          Expanded(child: copyBtn),
          const SizedBox(width: 10),
          Expanded(child: enterBtn),
        ]);
      }),
    ]);
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? SimulColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: active ? SimulColors.black : SimulColors.faint,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
}

class _SimulField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextCapitalization caps;
  const _SimulField({
    required this.controller,
    required this.label,
    required this.icon,
    this.caps = TextCapitalization.words,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        textCapitalization: caps,
        style: const TextStyle(color: SimulColors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: SimulColors.faint, size: 20),
        ),
      );
}
