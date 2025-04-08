import 'user.dart';

enum FriendStatus {
  pending,
  accepted,
  rejected,
}

class Friend {
  final int id;
  final User requester;
  final User recipient;
  final FriendStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Friend({
    required this.id,
    required this.requester,
    required this.recipient,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      requester: User.fromJson(json['requester']),
      recipient: User.fromJson(json['recipient']),
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester': requester.toJson(),
      'recipient': recipient.toJson(),
      'status': _statusToString(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  static FriendStatus _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'pending':
        return FriendStatus.pending;
      case 'accepted':
        return FriendStatus.accepted;
      case 'rejected':
        return FriendStatus.rejected;
      default:
        return FriendStatus.pending;
    }
  }

  static String _statusToString(FriendStatus status) {
    switch (status) {
      case FriendStatus.pending:
        return 'pending';
      case FriendStatus.accepted:
        return 'accepted';
      case FriendStatus.rejected:
        return 'rejected';
    }
  }

  // Get the other user in the friendship
  User getOtherUser(int currentUserId) {
    if (requester.id == currentUserId) {
      return recipient;
    } else {
      return requester;
    }
  }

  // Check if this is an outgoing friend request from the current user
  bool isOutgoingRequest(int currentUserId) {
    return requester.id == currentUserId && status == FriendStatus.pending;
  }

  // Check if this is an incoming friend request to the current user
  bool isIncomingRequest(int currentUserId) {
    return recipient.id == currentUserId && status == FriendStatus.pending;
  }

  // Check if the friendship is confirmed
  bool get isAccepted => status == FriendStatus.accepted;
  
  // Get time since the friend request was created
  String getTimeSinceCreated() {
    final difference = DateTime.now().difference(createdAt);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
} 