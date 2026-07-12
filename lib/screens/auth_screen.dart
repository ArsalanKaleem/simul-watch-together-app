import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/firebase_service.dart';
import '../screens/room_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _isCreating = true;
  bool _isLoading  = false;
  bool _copied     = false;
  late AnimationController _tabAnim;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() { _nameCtrl.dispose(); _roomCtrl.dispose(); _tabAnim.dispose(); super.dispose(); }

  void _switchTab(bool creating) {
    setState(() => _isCreating = creating);
    if (creating) _tabAnim.reverse(); else _tabAnim.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SimulColors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
            const SizedBox(height: 48),

            // Logo
            Center(child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: SimulColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SimulColors.border),
                ),
                child: const Center(child: Text('S', style: TextStyle(
                  color: SimulColors.white, fontSize: 28, fontWeight: FontWeight.w700,
                ))),
              ),
              const SizedBox(height: 16),
              const Text('SIMUL', style: TextStyle(
                color: SimulColors.white, fontSize: 28,
                fontWeight: FontWeight.w700, letterSpacing: 2,
              )),
              const SizedBox(height: 4),
              const Text('Watch together, in sync.', style: TextStyle(
                color: SimulColors.faint, fontSize: 14,
              )),
            ])),

            const SizedBox(height: 48),

            // Tab switcher
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: SimulColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SimulColors.border),
              ),
              child: Row(children: [
                _TabBtn('Create Room', _isCreating, () => _switchTab(true)),
                _TabBtn('Join Room', !_isCreating, () => _switchTab(false)),
              ]),
            ),

            const SizedBox(height: 28),

            // Name field
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
                  ? const Center(child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: SimulColors.white)))
                  : ElevatedButton(
                      onPressed: _isCreating ? _createRoom : _joinRoom,
                      child: Text(_isCreating ? 'Create Room' : 'Join Room'),
                    ),
            ),

            const SizedBox(height: 16),
            const Center(child: Text(
              'Anonymous. No account needed.',
              style: TextStyle(color: SimulColors.subtle, fontSize: 11),
              textAlign: TextAlign.center,
            )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _createRoom() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _err('Enter your name'); return; }
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
    if (name.isEmpty) { _err('Enter your name'); return; }
    if (code.isEmpty) { _err('Enter room code'); return; }
    if (code.length != 6) { _err('Room code must be 6 characters'); return; }
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

  void _showCreated(String roomId, String name) {
    setState(() => _copied = false);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: SimulColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: SimulColors.border)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: SimulColors.success.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: SimulColors.success, size: 24)),
              const SizedBox(height: 16),
              const Text('Room Created', style: TextStyle(
                  color: SimulColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Share this code to invite others',
                  style: TextStyle(color: SimulColors.faint, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),

              // Code box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: SimulColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SimulColors.border),
                ),
                child: Column(children: [
                  const Text('ROOM CODE', style: TextStyle(
                      color: SimulColors.faint, fontSize: 10,
                      fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(roomId, style: const TextStyle(
                      color: SimulColors.white, fontSize: 30,
                      fontWeight: FontWeight.w800, letterSpacing: 4)),
                ]),
              ),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: roomId));
                    setS(() => _copied = true);
                  },
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16, color: _copied ? SimulColors.success : SimulColors.faint),
                  label: Text(_copied ? 'Copied!' : 'Copy',
                      style: TextStyle(color: _copied ? SimulColors.success : SimulColors.faint)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _copied ? SimulColors.success : SimulColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, _route(RoomScreen(roomId: roomId, userName: name)));
                  },
                  child: const Text('Enter Room'),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: SimulColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  PageRoute _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

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
        child: Center(child: Text(label, style: TextStyle(
          color: active ? SimulColors.black : SimulColors.faint,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          fontSize: 14,
        ))),
      ),
    ),
  );
}

class _SimulField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextCapitalization caps;
  const _SimulField({required this.controller, required this.label,
      required this.icon, this.caps = TextCapitalization.words});

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
