// lib/screens/about_screen.dart
//
// 2026-standard About screen:
//  • Gradient hero with a glowing avatar ring and staggered entrance
//  • Glassy cards, gradient accents, pill skill chips
//  • Tappable link buttons (url_launcher) with hover/press feedback
//  • Fully theme-aware (SimulColors.of) and responsive (two-column ≥ 880px)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_controller.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ── Edit these ──────────────────────────────────────────────────────────
  static const String _name   = 'Arsalan Kaleem';
  static const String _field  = 'Computer Science';
  static const String _school = 'The Shaikh Ayaz University';
  static const String _photo  = 'lib/assets/me.png';

  static const String _bio =
      'Computer Science student and Flutter developer who enjoys building '
      'real-time, cross-platform experiences. SIMUL grew out of wanting to '
      'watch videos with friends without juggling three different apps — '
      'so I built one room that does it all.';

  static const List<String> _skills = [
    'Flutter', 'Dart', 'Firebase', 'LiveKit', 'WebRTC', 'UI/UX',
  ];

  static const String _appInfo =
      'SIMUL is a watch-together app: synced YouTube, voice chat, screen '
      'sharing with audio, live reactions, chat, and Connect 4 — in one '
      'room, on every platform.';

  static const List<_Link> _links = [
    _Link(Icons.language_rounded, 'Portfolio',
        'https://arsalankaleem.github.io/portfolio/'),
    _Link(Icons.code_rounded, 'GitHub', 'https://github.com/ArsalanKaleem'),
    _Link(Icons.business_center_outlined, 'LinkedIn',
        'https://www.linkedin.com/in/arsalankaleem'),
  ];
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = SimulColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        actions: const [_ThemeToggle(), SizedBox(width: 8)],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        // Ambient gradient glows behind everything.
        const _AmbientGlow(),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 880;
          final content = wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(width: 340, child: _HeroColumn()),
                  const SizedBox(width: 28),
                  Expanded(child: _DetailColumn(c: c)),
                ])
              : Column(children: [
                  const _HeroColumn(),
                  const SizedBox(height: 24),
                  _DetailColumn(c: c),
                ]);
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 72, 20, 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: _Entrance(child: content),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Hero (avatar + identity + links) ──────────────────────────────────────

class _HeroColumn extends StatelessWidget {
  const _HeroColumn();

  @override
  Widget build(BuildContext context) {
    final c = SimulColors.of(context);
    return _Glass(
      c: c,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(children: [
        const _GlowAvatar(),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFF7C8CFF), Color(0xFF4ADE80)],
          ).createShader(r),
          child: const Text(
            AboutScreen._name,
            textAlign: TextAlign.center,
            style: TextStyle(
              // Painted by the shader; kept white for the mask.
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(AboutScreen._field,
            style: TextStyle(
                color: c.text, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(AboutScreen._school,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.faint, fontSize: 12.5)),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: AboutScreen._skills
              .map((sk) => _Chip(label: sk, c: c))
              .toList(),
        ),
        const SizedBox(height: 22),
        Divider(color: c.border, height: 1),
        const SizedBox(height: 14),
        ...AboutScreen._links.map((l) => _LinkButton(link: l, c: c)),
      ]),
    );
  }
}

class _GlowAvatar extends StatelessWidget {
  const _GlowAvatar();

  @override
  Widget build(BuildContext context) {
    final c = SimulColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C8CFF), Color(0xFF4ADE80)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C8CFF).withValues(alpha: 0.35),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
        child: ClipOval(
          child: SizedBox(
            width: 108,
            height: 108,
            child: Image.asset(
              AboutScreen._photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: c.card,
                alignment: Alignment.center,
                child: Text(
                  AboutScreen._name.isNotEmpty ? AboutScreen._name[0] : '?',
                  style: TextStyle(
                      color: c.text,
                      fontSize: 40,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right column: bio, app, footer ────────────────────────────────────────

class _DetailColumn extends StatelessWidget {
  final SimulPalette c;
  const _DetailColumn({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Glass(
        c: c,
        child: _Section(
          c: c,
          icon: Icons.person_outline_rounded,
          title: 'About me',
          body: AboutScreen._bio,
        ),
      ),
      const SizedBox(height: 16),
      _Glass(
        c: c,
        child: _Section(
          c: c,
          icon: Icons.play_circle_outline_rounded,
          title: 'About SIMUL',
          body: AboutScreen._appInfo,
        ),
      ),
      const SizedBox(height: 16),
      _Glass(
        c: c,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          Icon(Icons.favorite_rounded,
              color: const Color(0xFFF472B6), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Built with Flutter, Firebase & LiveKit · Open source (MIT)',
              style: TextStyle(color: c.faint, fontSize: 12.5),
            ),
          ),
          Text('© 2026', style: TextStyle(color: c.subtle, fontSize: 12)),
        ]),
      ),
    ]);
  }
}

class _Section extends StatelessWidget {
  final SimulPalette c;
  final IconData icon;
  final String title;
  final String body;
  const _Section({
    required this.c,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF7C8CFF).withValues(alpha: 0.18),
              const Color(0xFF4ADE80).withValues(alpha: 0.18),
            ]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c.text, size: 16),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                color: c.text, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Text(body,
          style: TextStyle(color: c.faint, fontSize: 13.5, height: 1.65)),
    ]);
  }
}

// ── Reusable pieces ───────────────────────────────────────────────────────

/// Soft glassy card. (True backdrop blur is intentionally avoided — it's
/// expensive on low-end devices/web; a translucent fill + hairline border
/// reads the same at a fraction of the cost.)
class _Glass extends StatelessWidget {
  final SimulPalette c;
  final Widget child;
  final EdgeInsets padding;
  const _Glass({
    required this.c,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final SimulPalette c;
  const _Chip({required this.label, required this.c});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: c.faint, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

class _LinkButton extends StatefulWidget {
  final _Link link;
  final SimulPalette c;
  const _LinkButton({required this.link, required this.c});

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _hover ? c.card : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? c.accent : c.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => launchUrl(Uri.parse(widget.link.url),
                  mode: LaunchMode.externalApplication),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(widget.link.icon, color: c.accent, size: 17),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.link.label,
                        style: TextStyle(
                            color: c.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.arrow_outward_rounded, color: c.subtle, size: 15),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient background glows.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(children: [
        Positioned(
          top: -140,
          left: -100,
          child: _blob(const Color(0xFF7C8CFF), 380),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: _blob(const Color(0xFF4ADE80), 420),
        ),
      ]),
    );
  }

  Widget _blob(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.0),
          ]),
        ),
      );
}

/// Simple fade + rise entrance for the whole page.
class _Entrance extends StatelessWidget {
  final Widget child;
  const _Entrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => context.read<ThemeController>().toggle(),
    );
  }
}

class _Link {
  final IconData icon;
  final String label;
  final String url;
  const _Link(this.icon, this.label, this.url);
}
