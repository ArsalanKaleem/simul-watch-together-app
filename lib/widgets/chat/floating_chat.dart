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
    await svc.sendMessage(widget.roomId, text, widget.userName,
        replyToId: _replyTo?.id, replyToText: _replyTo?.text);
    _msgCtrl.clear();
    setState(() => _replyTo = null);
    await svc.setTyping(widget.roomId, false);
    _typingTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 100), _scrollBottom);
  }

  void _onTyping(String val) {
    final svc = context.read<FirebaseService>();
    svc.setTyping(widget.roomId, val.isNotEmpty);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      svc.setTyping(widget.roomId, false);
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
    return Stack(
      children: [
        // Chat panel
        if (_open)
          Positioned(
            bottom: 80, right: 16,
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
                onNewMessage: (count) {
                  if (!_open) setState(() => _unread += count - _lastSeenCount);
                  _lastSeenCount = count;
                },
              ),
            ),
          ),

        // FAB
        Positioned(
          bottom: 16, right: 16,
          child: GestureDetector(
            onTap: _toggleChat,
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: SimulColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4),
                )],
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.chat_bubble_outline,
                      color: SimulColors.black, size: 24)),
                  if (_unread > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: SimulColors.error, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('$_unread',
                            style: const TextStyle(color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  const _ChatPanel({
    required this.roomId, required this.userName, required this.scrollCtrl,
    required this.msgCtrl, required this.replyTo, required this.onSend,
    required this.onTyping, required this.onClearReply, required this.onReply,
    required this.onNewMessage,
  });

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<FirebaseService>();
    final isHost = svc.isHost || svc.isModerator(svc.currentUser?.id ?? '');

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320, height: 440,
        decoration: BoxDecoration(
          color: SimulColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SimulColors.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.4),
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
                  onTap: () => svc.clearChat(roomId),
                  child: const Text('Clear', style: TextStyle(
                      color: SimulColors.faint, fontSize: 12)),
                ),
            ]),
          ),

          // Messages
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: svc.getMessagesStream(roomId),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: SimulColors.white));
                final msgs = snap.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onNewMessage(msgs.length);
                });
                if (msgs.isEmpty) return const Center(
                    child: Text('No messages yet', style: TextStyle(
                        color: SimulColors.subtle, fontSize: 13)));
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
