import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String sender;
  final String senderId;
  final DateTime timestamp;
  final String? replyToId;
  final String? replyToText;
  final Map<String, List<String>> reactions; // emoji -> [userId]
  final bool deleted;

  Message({
    required this.id,
    required this.text,
    required this.sender,
    required this.senderId,
    required this.timestamp,
    this.replyToId,
    this.replyToText,
    this.reactions = const {},
    this.deleted = false,
  });

  factory Message.fromMap(String id, Map<String, dynamic> map) {
    final rawReactions = map['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((k, v) =>
        MapEntry(k, List<String>.from(v as List)));
    return Message(
      id: id,
      text: map['text'] ?? '',
      sender: map['sender'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      reactions: reactions,
      deleted: map['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'sender': sender,
    'senderId': senderId,
    'timestamp': Timestamp.fromDate(timestamp),
    'replyToId': replyToId,
    'replyToText': replyToText,
    'reactions': reactions,
    'deleted': deleted,
  };
}
