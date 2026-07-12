import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/constants.dart';

/// Renders a [MediaStream] (local screen-share capture or remote peer stream)
/// inside a 16:9 aspect-ratio container styled to match SIMUL's dark theme.
///
/// Usage:
/// ```dart
/// ScreenShareViewer(
///   stream: shareService.stream,
///   isLocal: true,
///   onStop: () => shareService.stopSharing(),
/// )
/// ```
class ScreenShareViewer extends StatefulWidget {
  final MediaStream? stream;
  final bool isLocal;
  final VoidCallback? onStop;

  const ScreenShareViewer({
    super.key,
    required this.stream,
    this.isLocal = false,
    this.onStop,
  });

  @override
  State<ScreenShareViewer> createState() => _ScreenShareViewerState();
}

class _ScreenShareViewerState extends State<ScreenShareViewer> {
  RTCVideoRenderer? _renderer;
  bool _rendererReady = false;
  bool _rendererFailed = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    try {
      final r = RTCVideoRenderer();
      await r.initialize();
      _renderer = r;
      if (widget.stream != null) {
        r.srcObject = widget.stream;
      }
      _rendererReady = true;
    } catch (e) {
      // flutter_webrtc has no renderer on some desktop targets — fail soft
      // instead of taking the whole app down.
      debugPrint('RTCVideoRenderer init failed: $e');
      _rendererFailed = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ScreenShareViewer old) {
    super.didUpdateWidget(old);
    if (old.stream != widget.stream && _rendererReady) {
      _renderer?.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        children: [
          // Video surface
          Container(
            color: SimulColors.black,
            child: _rendererFailed
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Screen sharing isn\u2019t available on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: SimulColors.faint, fontSize: 13),
                      ),
                    ),
                  )
                : (_rendererReady && _renderer != null)
                    ? RTCVideoView(
                        _renderer!,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: SimulColors.white),
                      ),
          ),

          // Header badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SimulColors.shareActive.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.screen_share_rounded,
                    color: SimulColors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  widget.isLocal ? 'You are sharing' : 'Screen share',
                  style: const TextStyle(
                    color: SimulColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ),

          // Stop button (local only)
          if (widget.isLocal && widget.onStop != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onStop,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: SimulColors.error.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.stop_screen_share_rounded,
                        color: SimulColors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Stop sharing',
                        style: TextStyle(
                            color: SimulColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
