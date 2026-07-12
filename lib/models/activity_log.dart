import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType {
  userJoined,
  userLeft,
  hostChanged,
  videoChanged,
  queueChanged,
  moderatorAdded,
  moderatorRemoved,
  chatCleared,
  userRemoved,
}

class ActivityLog {
  final String id;
  final ActivityType type;
  final String message;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  factory ActivityLog.fromMap(String id, Map<String, dynamic> map) =>
      ActivityLog(
        id: id,
        type: ActivityType.values.firstWhere((t) => t.name == map['type'],
            orElse: () => ActivityType.userJoined),
        message: map['message'] ?? '',
        timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'message': message,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
