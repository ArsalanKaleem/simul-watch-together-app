import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/message.dart';
import '../../services/firebase_service.dart';
import '../../utils/constants.dart';

class FloatingChat extends StatefulWidget {
  final String roomId;
  final String userName;

  const FloatingChat({super.key, required this.roomId, required this.userName});

  @override
  State<FloatingChat> createState() => _FloatingChatState();
}

class _FloatingChatState extends State<FloatingChat>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  int _unread = 0;
  late AnimationController _anim;
  late Animation<double> _scale;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Message? _replyTo;
  Timer? _typingTimer;
  int _lastSeenCount = 0;
  // Until the first snapshot lands we don't know the baseline, so the old
  // code counted the entire chat history as "unread" the moment you entered
  // a room. Seed the baseline instead of counting it.
  bool _seenFirstSnapshot = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _anim.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _open = !_open;
      if (_open) { _anim.forward(); _unread = 0; }
      else { _anim.reverse(); }
    });
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final svc = context.read<FirebaseService>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Capture the reply target BEFORE clearing it, or the reply metadata is
    // lost by the time the write runs.
    final replyTo = _replyTo;

    // Optimistically clear the field so typing feels instant, but keep the
    // text so we can restore it if the send fails.
    _msgCtrl.clear();
    setState(() => _replyTo = null);
    _typingTimer?.cancel();

    try {
      await svc.sendMessage(widget.roomId, text, widget.userName,
          replyToId: replyTo?.id, replyToText: replyTo?.text);
      // Firestore writes were unguarded here: when the client is offline this
      // throws straight out of the send button's callback as an unhandled
      // async error. Now it degrades to a toast and the text is given back.
      await svc.setTyping(widget.roomId, false);
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 100), _scrollBottom);
    } catch (e) {
      debugPrint('[Chat] send failed: $e');
      if (!mounted) return;
      _msgCtrl.text = text; // don't lose what they typed
      setState(() => _replyTo = replyTo); // and don't lose the reply context
      messenger?.showSnackBar(SnackBar(
        content: const Text("Message not sent — you appear to be offline."),
        backgroundColor: SimulColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _onTyping(String val) {
    final svc = context.read<FirebaseService>();
    // Fire-and-forget presence write — must never surface as an unhandled
    // async error while someone is simply typing.
    svc.setTyping(widget.roomId, val.isNotEmpty).catchError((_) {});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      svc.setTyping(widget.roomId, false).catchError((_) {});
    });
  }

  void _scrollBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    // The panel used to be a hardcoded 320×440, which could clip past the
    // left edge on narrow phones (~320-360px wide) and get hidden behind the
    // keyboard while typing (nothing accounted for viewInsets.bottom). Clamp
    // it to the available space instead, and lift it above the keyboard.
    final panelWidth = (screen.width - 32).clamp(240.0, 320.0);
    final panelHeight = (screen.height - 180 - keyboard).clamp(280.0, 440.0);

    // IMPORTANT: this whole widget is passed to Scaffold as
    // `floatingActionButton`. Scaffold measures the FAB's own layout size to
    // position both the FAB itself and any floating SnackBar. A raw `Stack`
    // with only `Positioned` children (as this used to be) has an ambiguous,
    // sometimes very large reported size once the chat panel's Positioned
    // child is in the mix — which corrupts Scaffold's SnackBar geometry math
    // and throws "A floating SnackBar presented off screen", cascading into
    // render/hit-test assertions that can make the whole page stop
    // responding to clicks.
    //
    // Fix: pin the FAB's reported layout size to the actual 56×56 button via
    // SizedBox, and let the chat panel render OUTSIDE that box purely via
    // paint (clipBehavior: Clip.none) — it stays fully visible and
    // interactive, but no longer affects what Scaffold thinks the FAB's size
    // is.
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // FAB — fills the SizedBox exactly (this box IS the button's size,
          // already placed at the screen's bottom-right by Scaffold's
          // `floatingActionButtonLocation: endFloat`), so no Positioned offset
          // needed here anymore.
          GestureDetector(
            onTap: _toggleChat,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: SimulColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4),
                )],
              ),
              child: const Center(child: Icon(Icons.chat_bubble_outline,
                  color: SimulColors.black, size: 24)),
            ),
          ),

          // Unread badge — sits proud of the button's top-right corner. The
          // outer Stack uses Clip.none, so it can overhang the 56x56 box
          // without changing the size Scaffold measures for the FAB.
          if (_unread > 0 && !_open)
            Positioned(
              top: -4,
              right: -4,
              child: IgnorePointer(
                child: _UnreadBadge(count: _unread),
              ),
            ),

          // Chat panel — anchored to the same box's top-right corner (right: 0
          // matches the button's right edge; bottom: 64 clears the 56px button
          // plus an 8px gap). clipBehavior: Clip.none on the Stack above lets
          // this paint outside the tiny 56×56 box without being clipped, and
          // without changing what Scaffold thinks the FAB's size is.
          if (_open)
            Positioned(
              bottom: 64 + keyboard,
              right: 0,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.bottomRight,
                child: _ChatPanel(
                  roomId: widget.roomId,
                  userName: widget.userName,
                  scrollCtrl: _scrollCtrl,
                  msgCtrl: _msgCtrl,
                  replyTo: _replyTo,
                  onSend: _sendMessage,
                  onTyping: _onTyping,
                  onClearReply: () => setState(() => _replyTo = null),
                  onReply: (msg) => setState(() => _replyTo = msg),
                  onClose: _toggleChat,
                  width: panelWidth,
                  height: panelHeight,
                  onNewMessage: (count) {
                    if (!_open) setState(() => _unread += count - _lastSeenCount);
                    _lastSeenCount = count;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final String roomId, userName;
  final ScrollController scrollCtrl;
  final TextEditingController msgCtrl;
  final Message? replyTo;
  final VoidCallback onSend;
  final Function(String) onTyping;
  final VoidCallback onClearReply;
  final Function(Message) onReply;
  final Function(int) onNewMessage;
  final VoidCallback onClose;
  final double width;
  final double height;

  const _ChatPanel({
    required this.roomId, required this.userName, required this.scrollCtrl,
    required this.msgCtrl, required this.replyTo, required this.onSend,
    required this.onTyping, required this.onClearReply, required this.onReply,
    required this.onNewMessage, required this.onClose,
    required this.width, required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FirebaseService>();
    final isHost = svc.isHost || svc.isModerator(svc.currentUser?.id ?? '');

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: SimulColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SimulColors.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20, offset: const Offset(0, 8),
          )],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SimulColors.border)),
            ),
            child: Row(children: [
              const Text('Chat', style: TextStyle(
                  color: SimulColors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              if (isHost)
                GestureDetector(
                  onTap: () => svc.clearChat(roomId).catchError((_) {}),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text('Clear', style: TextStyle(
                        color: SimulColors.faint, fontSize: 12)),
                  ),
                ),
              const SizedBox(width: 4),
              // Close the panel without having to hunt for the bubble again.
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      color: SimulColors.faint, size: 18),
                ),
              ),
            ]),
          ),

          // Messages
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: svc.getMessagesStream(roomId),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2,
                          color: SimulColors.white));
                }
                final msgs = snap.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onNewMessage(msgs.length);
                });
                if (msgs.isEmpty) {
                  return const Center(
                      child: Text('No messages yet', style: TextStyle(
                          color: SimulColors.subtle, fontSize: 13)));
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => _MsgBubble(
                    msg: msgs[i], isMe: msgs[i].sender == userName,
                    onReply: () => onReply(msgs[i]),
                    canDelete: isHost || msgs[i].sender == userName,
                    onDelete: () => svc.deleteMessage(roomId, msgs[i].id),
                    onReact: (emoji) => svc.addReactionToMessage(
                        roomId, msgs[i].id, emoji, svc.currentUser?.id ?? ''),
                  ),
                );
              },
            ),
          ),

          // Typing indicator
          StreamBuilder<List<String>>(
            stream: svc.getTypingStream(roomId),
            builder: (_, snap) {
              final names = snap.data ?? [];
              if (names.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text('${names.join(', ')} typing…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SimulColors.faint, fontSize: 11)),
              );
            },
          ),

          // Reply preview
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SimulColors.muted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Expanded(child: Text('↩ ${replyTo!.text}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: SimulColors.faint, fontSize: 12))),
                GestureDetector(onTap: onClearReply,
                    child: const Icon(Icons.close, size: 14, color: SimulColors.faint)),
              ]),
            ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: SimulColors.border)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: msgCtrl,
                  onChanged: onTyping,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(color: SimulColors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: const TextStyle(color: SimulColors.subtle, fontSize: 13),
                    filled: true, fillColor: SimulColors.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: SimulColors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.send_rounded, color: SimulColors.black, size: 18),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  final Message msg;
  final bool isMe;
  final VoidCallback onReply;
  final bool canDelete;
  final VoidCallback onDelete;
  final Function(String) onReact;

  const _MsgBubble({
    required this.msg, required this.isMe, required this.onReply,
    required this.canDelete, required this.onDelete, required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    if (msg.deleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: const Text('Message deleted', style: TextStyle(
              color: SimulColors.subtle, fontSize: 11, fontStyle: FontStyle.italic)),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.replyToText != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SimulColors.muted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('↩ ${msg.replyToText}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: SimulColors.faint, fontSize: 10)),
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? SimulColors.white : SimulColors.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isMe ? 14 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(msg.sender, style: const TextStyle(
                          color: SimulColors.faint, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                    Text(msg.text, style: TextStyle(
                        color: isMe ? SimulColors.black : SimulColors.white, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(DateFormat('HH:mm').format(msg.timestamp),
                        style: TextStyle(
                            color: isMe ? SimulColors.subtle : SimulColors.faint,
                            fontSize: 9)),
                  ],
                ),
              ),
              if (msg.reactions.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: msg.reactions.entries.map((e) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: SimulColors.muted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${e.key} ${e.value.length}',
                            style: const TextStyle(fontSize: 10)),
                      )).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SimulColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Emoji reactions
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍','❤️','😂','🔥','😮'].map((e) =>
                  GestureDetector(
                    onTap: () { Navigator.pop(context); onReact(e); },
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  )).toList()),
          const SizedBox(height: 12),
          ListTile(leading: const Icon(Icons.reply, color: SimulColors.white),
              title: const Text('Reply', style: TextStyle(color: SimulColors.white)),
              onTap: () { Navigator.pop(context); onReply(); }),
          if (canDelete)
            ListTile(leading: const Icon(Icons.delete_outline, color: SimulColors.error),
                title: const Text('Delete', style: TextStyle(color: SimulColors.error)),
                onTap: () { Navigator.pop(context); onDelete(); }),
        ]),
      ),
    );
  }
}


/// Small unread pill on the chat bubble. Pulses briefly whenever the count
/// changes so a newly-arrived message is noticeable without being loud.
class _UnreadBadge extends StatefulWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void initState() {
    super.initState();
    _pulse.forward(from: 0);
  }

  @override
  void didUpdateWidget(_UnreadBadge old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.count > 9 ? '9+' : '${widget.count}';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        // One soft ring that expands and fades out, then settles.
        final t = Curves.easeOut.transform(_pulse.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_pulse.value < 1)
              Container(
                width: 20 + 16 * t,
                height: 20 + 16 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SimulColors.error.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
            child!,
          ],
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        decoration: BoxDecoration(
          color: SimulColors.error,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: SimulColors.black, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}