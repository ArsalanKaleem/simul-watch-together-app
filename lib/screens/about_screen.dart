import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SimulColors.black,
      appBar: AppBar(
        backgroundColor: SimulColors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: SimulColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About',
          style: TextStyle(
            color: SimulColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: SimulColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Profile photo ──
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SimulColors.border, width: 2),
                color: SimulColors.surface,
              ),
              child: const CircleAvatar(
                radius: 60,
                backgroundColor: SimulColors.surface,
                // TODO: replace with your actual photo
                backgroundImage: AssetImage('lib/assets/portfo-img.jpg'),
              ),
            ),
            const SizedBox(height: 20),

            // ── Name ──
            const Text(
              'Arsalan Kaleem', // TODO: replace with your name
              style: TextStyle(
                color: SimulColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            // ── Field of study ──
            Column(
              children: [
                const Text(
                  'Computer Science ', // TODO: replace with your details
                  style: TextStyle(
                    color: SimulColors.faint,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                const Text(
                  'The Shaikh Ayaz University', // TODO: replace with your details
                  style: TextStyle(
                    color: SimulColors.faint,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Divider ──
            const Divider(color: SimulColors.border),
            const SizedBox(height: 24),

            // ── Bio section ──
            _SectionCard(
              icon: Icons.info_outline_rounded,
              label: 'About Me',
              content:
                  'A short bio about yourself goes here. Tell people who you are, '
                  'what you do, and what drives you.', // TODO: replace
            ),
            const SizedBox(height: 16),

            // ── App info section ──
            _SectionCard(
              icon: Icons.play_circle_outline_rounded,
              label: 'About SIMUL',
              content:
                  'SIMUL is a watch-together app that lets you and your friends '
                  'sync YouTube videos in real time, chat, and play games — all '
                  'in one room.', // TODO: update if needed
            ),
            const SizedBox(height: 16),

            // ── Contact / links section ──
            _LinksCard(),
            const SizedBox(height: 32),

            // ── App version ──
            Text(
              'Version 1.0.0', // TODO: pull from package_info_plus if desired
              style: const TextStyle(color: SimulColors.subtle, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Made with ❤️', // TODO: replace
              style: TextStyle(color: SimulColors.subtle, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable section card
// ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SimulColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SimulColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: SimulColors.faint, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: SimulColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: SimulColors.faint,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Links / contact card
// ─────────────────────────────────────────────────────────────
class _LinksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: replace href values and labels with your actual links
    final links = [
      _LinkItem(icon: Icons.language_rounded, label: 'Website', value: 'yourwebsite.com'),
      _LinkItem(icon: Icons.alternate_email_rounded, label: 'GitHub', value: '@yourgithub'),
      _LinkItem(icon: Icons.mail_outline_rounded, label: 'Email', value: 'you@email.com'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SimulColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SimulColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.link_rounded, color: SimulColors.faint, size: 16),
            SizedBox(width: 8),
            Text(
              'Links',
              style: TextStyle(
                color: SimulColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ...links.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Icon(l.icon, color: SimulColors.subtle, size: 15),
                  const SizedBox(width: 10),
                  Text(
                    l.label,
                    style: const TextStyle(
                      color: SimulColors.faint,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l.value,
                    style: const TextStyle(
                      color: SimulColors.white,
                      fontSize: 13,
                    ),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}

class _LinkItem {
  final IconData icon;
  final String label;
  final String value;
  const _LinkItem({required this.icon, required this.label, required this.value});
}
