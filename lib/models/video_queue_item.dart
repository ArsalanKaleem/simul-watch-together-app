import 'package:cloud_firestore/cloud_firestore.dart';

class VideoQueueItem {
  final String id;
  final String videoId;
  final String title;
  final String addedBy;
  final String addedByName;
  final DateTime addedAt;
  final int upvotes;
  final int downvotes;
  final List<String> upvotedBy;
  final bool approved;
  int order;

  VideoQueueItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.addedBy,
    required this.addedByName,
    required this.addedAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.upvotedBy = const [],
    this.approved = true,
    this.order = 0,
  });

  int get score => upvotes - downvotes;

  factory VideoQueueItem.fromMap(String id, Map<String, dynamic> map) =>
      VideoQueueItem(
        id: id,
        videoId: map['videoId'] ?? '',
        title: map['title'] ?? 'Untitled',
        addedBy: map['addedBy'] ?? '',
        addedByName: map['addedByName'] ?? '',
        addedAt: (map['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        upvotes: map['upvotes'] ?? 0,
        downvotes: map['downvotes'] ?? 0,
        upvotedBy: List<String>.from(map['upvotedBy'] ?? []),
        approved: map['approved'] ?? true,
        order: map['order'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
    'videoId': videoId, 'title': title, 'addedBy': addedBy,
    'addedByName': addedByName,
    'addedAt': Timestamp.fromDate(addedAt),
    'upvotes': upvotes, 'downvotes': downvotes,
    'upvotedBy': upvotedBy, 'approved': approved, 'order': order,
  };
}
