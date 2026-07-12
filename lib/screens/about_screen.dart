import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_controller.dart';
import '../utils/constants.dart';

/// About / profile screen.
///
/// Responsive: a centered single column on phones, and a two-column layout on
/// wide (desktop / web) screens — a sticky profile card on the left, content
/// on the right. Fully theme-aware via SimulColors.of(context).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── EDIT YOUR DETAILS HERE ─────────────────────────────────────────────
  static const String _name    = 'Arsalan Kaleem';
  static const String _field   = 'Computer Science';
  static const String _school  = 'The Shaikh Ayaz University';
  static const String _photo   = 'lib/assets/portfo-img.jpg';
  static const String _bio =
      'A short bio about yourself goes here. Tell people who you are, what '
      'you do, and what drives you.';
  static const String _appInfo =
      'SIMUL is a watch-together app that lets you and your friends sync '
      'YouTube videos in real time, chat, share screens, and play games — '
      'all in one room.';
  static const List<_Link> _links = [
    _Link(Icons.language_rounded, 'Website', 'yourwebsite.com'),
    _Link(Icons.alternate_email_rounded, 'GitHub', '@yourgithub'),
    _Link(Icons.mail_outline_rounded, 'Email', 'you@email.com'),
  ];
  // ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = SimulColors.of(context);
    final theme = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('About',
            style: TextStyle(
                color: c.text,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3)),
        actions: [
          _ThemeToggle(
            isDark: Theme.of(context).brightness == Brightness.dark,
            onTap: () =>
                theme.toggle(MediaQuery.platformBrightnessOf(context)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: wide ? 40 : 24, vertical: wide ? 48 : 28),
              child: wide ? _wide(context, c) : _narrow(context, c),
            ),
          ),
        );
      }),
    );
  }

  // ── Wide (desktop / web) ───────────────────────────────────────────────
  Widget _wide(BuildContext context, SimulPalette c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: profile card (sticky feel via top alignment)
        SizedBox(
          width: 320,
          child: _ProfileCard(c: c, centered: true),
        ),
        const SizedBox(width: 32),
        // Right: content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                c: c,
                icon: Icons.info_outline_rounded,
                label: 'About Me',
                content: _bio,
              ),
              const SizedBox(height: 20),
              _SectionCard(
                c: c,
                icon: Icons.play_circle_outline_rounded,
                label: 'About SIMUL',
                content: _appInfo,
              ),
              const SizedBox(height: 20),
              _LinksCard(c: c, links: _links),
              const SizedBox(height: 28),
              _Footer(c: c, alignEnd: false),
            ],
          ),
        ),
      ],
    );
  }

  // ── Narrow (phone) ─────────────────────────────────────────────────────
  Widget _narrow(BuildContext context, SimulPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProfileCard(c: c, centered: true),
        const SizedBox(height: 24),
        _SectionCard(
          c: c,
          icon: Icons.info_outline_rounded,
          label: 'About Me',
          content: _bio,
        ),
        const SizedBox(height: 16),
        _SectionCard(
          c: c,
          icon: Icons.play_circle_outline_rounded,
          label: 'About SIMUL',
          content: _appInfo,
        ),
        const SizedBox(height: 16),
        _LinksCard(c: c, links: _links),
        const SizedBox(height: 28),
        _Footer(c: c, alignEnd: false),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final SimulPalette c;
  final bool centered;
  const _ProfileCard({required this.c, this.centered = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.border, width: 2),
              color: c.card,
            ),
            child: ClipOval(
              child: Image.asset(
                AboutScreen._photo,
                width: 132,
                height: 132,
                fit: BoxFit.cover,
                // Shown only if the asset is missing / not yet added.
                errorBuilder: (_, __, ___) =>
                    _AvatarFallback(name: AboutScreen._name, c: c),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AboutScreen._name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.text,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(AboutScreen._field,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.faint, fontSize: 14, letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text(AboutScreen._school,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.subtle, fontSize: 13, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  final SimulPalette c;
  const _AvatarFallback({required this.name, required this.c});

  @override
  Widget build(BuildContext context) {
    // Rendered UNDER the image; only visible if the asset fails to load.
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(initial,
          style: TextStyle(
              color: c.subtle, fontSize: 44, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final SimulPalette c;
  final IconData icon;
  final String label;
  final String content;

  const _SectionCard({
    required this.c,
    required this.icon,
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: c.faint, size: 16),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1)),
          ]),
          const SizedBox(height: 14),
          Text(content,
              style: TextStyle(color: c.faint, fontSize: 14, height: 1.65)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _LinksCard extends StatelessWidget {
  final SimulPalette c;
  final List<_Link> links;
  const _LinksCard({required this.c, required this.links});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.card, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.link_rounded, color: c.faint, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Links',
                style: TextStyle(
                    color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          ...links.map((l) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(l.icon, color: c.subtle, size: 16),
                  const SizedBox(width: 12),
                  Text(l.label,
                      style: TextStyle(
                          color: c.faint,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Flexible(
                    child: Text(l.value,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: c.text, fontSize: 14)),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final SimulPalette c;
  final bool alignEnd;
  const _Footer({required this.c, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        Text('SIMUL · Version 1.1.0',
            style: TextStyle(color: c.subtle, fontSize: 12)),
        const SizedBox(height: 6),
        Text('Made with care',
            style: TextStyle(color: c.subtle, fontSize: 12)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _ThemeToggle({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SimulColors.of(context);
    return IconButton(
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(
        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: c.text,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}

class _Link {
  final IconData icon;
  final String label;
  final String value;
  const _Link(this.icon, this.label, this.value);
}
