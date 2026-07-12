import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum UserStatus { online, offline, away }

class AppUser {
  final String id;
  final String name;
  final String? email;
  final String? roomId;
  final UserStatus status;
  final DateTime? lastSeen;
  final bool isInVoiceChat;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    this.email,
    this.roomId,
    this.status = UserStatus.offline,
    this.lastSeen,
    this.isInVoiceChat = false,
    required this.createdAt,
  });

  AppUser copyWith({
    String? id, String? name, String? email, String? roomId,
    UserStatus? status, DateTime? lastSeen, bool? isInVoiceChat,
    DateTime? createdAt,
  }) => AppUser(
    id: id ?? this.id, name: name ?? this.name, email: email ?? this.email,
    roomId: roomId ?? this.roomId, status: status ?? this.status,
    lastSeen: lastSeen ?? this.lastSeen,
    isInVoiceChat: isInVoiceChat ?? this.isInVoiceChat,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'email': email, 'roomId': roomId,
    'status': status.name,
    'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    'isInVoiceChat': isInVoiceChat,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory AppUser.fromMap(String id, Map<String, dynamic> map) => AppUser(
    id: id, name: map['name'] ?? 'Unknown',
    email: map['email'], roomId: map['roomId'],
    status: UserStatus.values.firstWhere(
        (s) => s.name == map['status'], orElse: () => UserStatus.offline),
    lastSeen: map['lastSeen'] != null
        ? (map['lastSeen'] as Timestamp).toDate() : null,
    isInVoiceChat: map['isInVoiceChat'] ?? false,
    createdAt: map['createdAt'] != null
        ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
  );

  bool get isActive => status == UserStatus.online;
}

// Legacy alias
typedef User = AppUser;

extension UserStatusExt on UserStatus {
  Color get color {
    switch (this) {
      case UserStatus.online: return const Color(0xFF22C55E);
      case UserStatus.away:   return const Color(0xFFF59E0B);
      case UserStatus.offline: return const Color(0xFF555555);
    }
  }
}
