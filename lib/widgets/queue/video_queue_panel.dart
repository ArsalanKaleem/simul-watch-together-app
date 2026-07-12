import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/video_queue_item.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

class VideoQueuePanel extends StatefulWidget {
  final String roomId;
  final Function(String videoId, String title) onVideoSelected;

  const VideoQueuePanel({super.key, required this.roomId, required this.onVideoSelected});

  @override
  State<VideoQueuePanel> createState() => _VideoQueuePanelState();
}

class _VideoQueuePanelState extends State<VideoQueuePanel> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  String? _extractVideoId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'^([a-zA-Z0-9_-]{11})$'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url.trim());
      if (m != null) return m.group(1);
    }
    return null;
  }

  void _addVideo() async {
    final url = _urlCtrl.text.trim();
    final title = _titleCtrl.text.trim().isEmpty ? 'Video' : _titleCtrl.text.trim();
    final videoId = _extractVideoId(url);
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Invalid YouTube URL'), backgroundColor: SimulColors.error));
      return;
    }
    await context.read<FirebaseService>().addToQueue(widget.roomId, videoId, title);
    _urlCtrl.clear(); _titleCtrl.clear();
    Navigator.pop(context);
  }

  void _showAdd() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: SimulColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add to Queue', style: TextStyle(
              color: SimulColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            style: const TextStyle(color: SimulColors.white),
            decoration: const InputDecoration(
                labelText: 'YouTube URL', prefixIcon: Icon(Icons.link, color: SimulColors.faint, size: 20)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: SimulColors.white),
            decoration: const InputDecoration(
                labelText: 'Title (optional)', prefixIcon: Icon(Icons.title, color: SimulColors.faint, size: 20)),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _addVideo, child: const Text('Add Video'))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FirebaseService>();
    final isHost = svc.isHost || svc.isModerator(svc.currentUser?.id ?? '');
    final myId = svc.currentUser?.id ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: SimulColors.surface,
        border: Border(top: BorderSide(color: SimulColors.border)),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Text('Queue', style: TextStyle(
                color: SimulColors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            GestureDetector(
              onTap: _showAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SimulColors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: SimulColors.black, size: 16),
                  SizedBox(width: 4),
                  Text('Add', style: TextStyle(color: SimulColors.black,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),

        // List
        Expanded(child: StreamBuilder<List<VideoQueueItem>>(
          stream: svc.getQueueStream(widget.roomId),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child:
                CircularProgressIndicator(strokeWidth: 2, color: SimulColors.white));
            final items = snap.data!;
            if (items.isEmpty) return const Center(child: Text('Queue is empty',
                style: TextStyle(color: SimulColors.subtle, fontSize: 13)));
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                final hasVoted = item.upvotedBy.contains(myId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: SimulColors.card, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SimulColors.border),
                  ),
                  child: Row(children: [
                    // Thumbnail placeholder
                    Container(width: 44, height: 32,
                      decoration: BoxDecoration(color: SimulColors.muted,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.play_circle_outline,
                          color: SimulColors.faint, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.title, style: const TextStyle(color: SimulColors.white,
                          fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('by ${item.addedByName}', style: const TextStyle(
                          color: SimulColors.faint, fontSize: 11)),
                    ])),

                    // Vote
                    GestureDetector(
                      onTap: () => svc.voteQueue(widget.roomId, item.id, true, myId),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(hasVoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                            size: 14, color: hasVoted ? SimulColors.white : SimulColors.faint),
                        const SizedBox(width: 3),
                        Text('${item.upvotes}', style: const TextStyle(
                            color: SimulColors.faint, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(width: 8),

                    // Play (host)
                    if (isHost)
                      GestureDetector(
                        onTap: () => widget.onVideoSelected(item.videoId, item.title),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: SimulColors.white, size: 20),
                      ),
                    if (isHost || item.addedBy == myId)
                      GestureDetector(
                        onTap: () => svc.removeFromQueue(widget.roomId, item.id),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.close_rounded, color: SimulColors.faint, size: 16),
                        ),
                      ),
                  ]),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  @override
  void dispose() { _urlCtrl.dispose(); _titleCtrl.dispose(); super.dispose(); }
}
