// lib/widgets/live_share_viewer.dart
//
// Renders whichever screen-share track is relevant — the local host's own
// preview, or the remote track being broadcast by whoever is sharing.
//
// When viewing a REMOTE share, a speaker button lets THIS viewer mute the
// shared audio in their own window only (does not affect the sharer or other
// viewers). See LiveKitService.toggleRemoteScreenAudioMute.

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import '../services/livekit_service.dart';
import '../utils/constants.dart';

class LiveShareViewer extends StatelessWidget {
  /// True to render the local host's own share preview.
  /// False to render whichever remote participant is currently sharing.
  final bool isLocal;

  /// Host-only: called when the user taps "Stop".
  final VoidCallback? onStop;

  const LiveShareViewer({
    super.key,
    required this.isLocal,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final lk = context.watch<LiveKitService>();
    final VideoTrack? track =
        isLocal ? lk.localScreenTrack : lk.remoteScreenTrack;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          Container(
            color: SimulColors.black,
            child: track != null
                ? VideoTrackRenderer(track)
                : _placeholder(lk),
          ),
          Positioned(
            top: 8, left: 8,
            child: _Badge(
              icon : Icons.cast_rounded,
              label: isLocal ? 'You are sharing' : 'Live screen share',
            ),
          ),

          // Viewer's own audio control (remote share only, and only when the
          // share actually carries audio).
          if (!isLocal && lk.hasRemoteScreenAudio)
            Positioned(
              bottom: 8, right: 8,
              child: _AudioButton(
                muted: lk.isRemoteScreenAudioMuted,
                onTap: lk.toggleRemoteScreenAudioMute,
              ),
            ),

          // If the browser is blocking audio, offer a one-tap unblock.
          if (!isLocal && lk.isAudioBlocked)
            Positioned(
              bottom: 8, left: 8,
              child: _EnableSoundButton(onTap: lk.enableAudioPlayback),
            ),

          if (isLocal && onStop != null)
            Positioned(
              top: 8, right: 8,
              child: _StopButton(onTap: onStop!),
            ),
        ],
      ),
    );
  }

  Widget _placeholder(LiveKitService lk) {
    if (!lk.isConnected) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: SimulColors.shareActive),
      );
    }
    if (isLocal) {
      return const Center(
        child: Text('Starting screen share…',
            style: TextStyle(color: SimulColors.faint, fontSize: 13)),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              strokeWidth: 2, color: SimulColors.shareActive),
          SizedBox(height: 16),
          Text('Waiting for host to share…',
              style: TextStyle(color: SimulColors.faint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _AudioButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;
  const _AudioButton({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: muted ? SimulColors.faint : SimulColors.white,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              muted ? 'Share muted' : 'Share sound on',
              style: TextStyle(
                color: muted ? SimulColors.faint : SimulColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      );
}

class _EnableSoundButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EnableSoundButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SimulColors.info.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.volume_up_rounded, color: Colors.white, size: 15),
            SizedBox(width: 6),
            Text('Enable sound',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: SimulColors.shareActive.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: SimulColors.white, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: SimulColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: SimulColors.error.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.stop_screen_share_rounded,
                color: SimulColors.white, size: 14),
            SizedBox(width: 6),
            Text('Stop',
                style: TextStyle(
                    color: SimulColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
