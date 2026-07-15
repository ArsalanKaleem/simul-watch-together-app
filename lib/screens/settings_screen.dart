// lib/screens/settings_screen.dart
//
// Where users paste their OWN LiveKit configuration. Values are saved to
// flutter_secure_storage (via AppSettingsService) and never leave the device.
//
// Recommended path: paste LiveKit URL + API Key + API Secret → the app mints
// join tokens on-device, no server required. Advanced users can instead point
// at their own token server URL.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_settings_service.dart';
import '../services/theme_controller.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _key;
  late final TextEditingController _secret;
  late final TextEditingController _tokenUrl;

  bool _obscureSecret = true;
  bool _showAdvanced = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppSettingsService>();
    _url = TextEditingController(text: s.liveKitUrlRaw);
    _key = TextEditingController(text: s.apiKey);
    _secret = TextEditingController(text: s.apiSecret);
    _tokenUrl = TextEditingController(text: s.tokenUrlRaw);
    _showAdvanced = s.tokenUrlRaw.isNotEmpty && s.apiKey.isEmpty;
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _secret.dispose();
    _tokenUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<AppSettingsService>().save(
      url: _url.text,
      apiKey: _key.text,
      apiSecret: _secret.text,
      tokenUrl: _tokenUrl.text,
    );
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LiveKit settings saved')),
    );
  }

  Future<void> _clear() async {
    await context.read<AppSettingsService>().clear();
    if (!mounted) return;
    _url.clear();
    _key.clear();
    _secret.clear();
    _tokenUrl.clear();
    setState(() => _saved = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LiveKit settings cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SimulColors.of(context);
    final settings = context.watch<AppSettingsService>();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => context.read<ThemeController>().toggle(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBanner(configured: settings.isConfigured, c: c),
                const SizedBox(height: 16),
                _SetupTutorial(c: c),
                const SizedBox(height: 24),
                Text('LiveKit connection',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Paste the details from your own LiveKit project '
                      '(cloud.livekit.io → Settings → Keys). They are stored '
                      'securely on this device only.',
                  style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),

                _Field(
                  label: 'LiveKit URL',
                  hint: 'wss://your-project.livekit.cloud',
                  controller: _url,
                  c: c,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                _Field(
                  label: 'API Key',
                  hint: 'APIxxxxxxxx',
                  controller: _key,
                  c: c,
                ),
                const SizedBox(height: 16),
                _Field(
                  label: 'API Secret',
                  hint: 'your api secret',
                  controller: _secret,
                  c: c,
                  obscure: _obscureSecret,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureSecret
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: c.muted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureSecret = !_obscureSecret),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'With a key + secret, the app generates join tokens on this '
                      'device — no server to run.',
                  style: TextStyle(color: c.faint, fontSize: 12, height: 1.4),
                ),

                const SizedBox(height: 16),
                // Advanced: token-server path instead of on-device minting.
                InkWell(
                  onTap: () =>
                      setState(() => _showAdvanced = !_showAdvanced),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(
                        _showAdvanced
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        color: c.muted,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text('Advanced: use a token server instead',
                          style: TextStyle(color: c.muted, fontSize: 13)),
                    ]),
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 8),
                  _Field(
                    label: 'Token Server URL',
                    hint: 'https://your-token-server/token',
                    controller: _tokenUrl,
                    c: c,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If set and no API secret is provided, the app fetches '
                        'tokens from here instead of minting them locally.',
                    style:
                    TextStyle(color: c.faint, fontSize: 12, height: 1.4),
                  ),
                ],

                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _clear,
                  child: Text('Clear saved settings',
                      style: TextStyle(color: c.error)),
                ),
                if (_saved) ...[
                  const SizedBox(height: 8),
                  Text('Saved. New room joins will use these settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.success, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool configured;
  final SimulPalette c;
  const _StatusBanner({required this.configured, required this.c});

  @override
  Widget build(BuildContext context) {
    final color = configured ? c.success : c.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(configured ? Icons.check_circle_outline : Icons.info_outline,
            color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            configured
                ? 'LiveKit is configured. Voice and screen sharing are ready.'
                : 'LiveKit is not configured yet. Add your details below to '
                'enable voice and screen sharing.',
            style: TextStyle(color: c.text, fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final SimulPalette c;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.c,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: c.text, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(color: c.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.faint, fontSize: 14),
            filled: true,
            fillColor: c.surface,
            suffixIcon: suffix,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Expandable "how do I set this up?" walkthrough shown at the top of
/// Settings. Written for both roles: the person hosting (who needs LiveKit
/// keys for voice/share) and the friend just joining (who needs nothing but
/// the room code).
class _SetupTutorial extends StatefulWidget {
  final SimulPalette c;
  const _SetupTutorial({required this.c});

  @override
  State<_SetupTutorial> createState() => _SetupTutorialState();
}

class _SetupTutorialState extends State<_SetupTutorial> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_outlined, color: c.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How to set up & start watching',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text('A 2-minute guide for you and your friend',
                        style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: c.muted,
              ),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: c.border, height: 1),
                const SizedBox(height: 14),

                _TutorialHeader(c: c, icon: Icons.videocam_outlined,
                    text: 'Just watching together? No setup needed.'),
                const SizedBox(height: 6),
                _TutorialStep(c: c, n: '1',
                    text: 'One of you creates a room on the home screen and '
                        'shares the 6-character code.'),
                _TutorialStep(c: c, n: '2',
                    text: 'The other enters the code under "Join Room".'),
                _TutorialStep(c: c, n: '3',
                    text: 'Paste any YouTube link in the room — play, pause '
                        'and seek stay in sync for everyone automatically.'),

                const SizedBox(height: 16),
                _TutorialHeader(c: c, icon: Icons.mic_none_rounded,
                    text: 'Want voice chat & screen sharing? '
                        'One-time setup (host only):'),
                const SizedBox(height: 6),
                _TutorialStep(c: c, n: '1',
                    text: 'Go to cloud.livekit.io and create a free account '
                        'and project (no credit card needed).'),
                _TutorialStep(c: c, n: '2',
                    text: 'In LiveKit: Settings → Keys → Create Key. Copy the '
                        'API Key and the Secret (shown once).'),
                _TutorialStep(c: c, n: '3',
                    text: 'Copy your project URL — it looks like '
                        'wss://your-project.livekit.cloud.'),
                _TutorialStep(c: c, n: '4',
                    text: 'Paste all three into the fields below and press '
                        'Save. The banner above turns green when it worked.'),
                _TutorialStep(c: c, n: '5',
                    text: 'Send that same URL, Key and Secret to your '
                        'friend privately, and have them paste those exact '
                        'same three values into their own Settings. '
                        'Important: both of you must use the SAME '
                        'LiveKit project — voice and screen share only '
                        'connect if you\'re pointed at the same one.'),

                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates_outlined,
                          color: c.warning, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tips: If you can see chat but not hear each '
                              'other, you\'re probably on two different LiveKit '
                              'projects — double check your URL/Key/Secret match '
                              'exactly. On desktop, share a browser TAB and tick '
                              '"Share tab audio" so sound comes through. If you '
                              "can't hear anyone, tap the \"Enable sound\" button "
                              '— browsers block audio until you interact once. '
                              'On phones, use "Share a Video Link" from the menu '
                              'instead of tab sharing.',
                          style: TextStyle(
                              color: c.faint, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ]),
    );
  }
}

class _TutorialHeader extends StatelessWidget {
  final SimulPalette c;
  final IconData icon;
  final String text;
  const _TutorialHeader({required this.c, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: c.accent, size: 16),
    const SizedBox(width: 8),
    Expanded(
      child: Text(text,
          style: TextStyle(
              color: c.text, fontSize: 13, fontWeight: FontWeight.w700)),
    ),
  ]);
}

class _TutorialStep extends StatelessWidget {
  final SimulPalette c;
  final String n;
  final String text;
  const _TutorialStep({required this.c, required this.n, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20, height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(n,
              style: TextStyle(
                  color: c.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: c.faint, fontSize: 13, height: 1.45)),
        ),
      ],
    ),
  );
}