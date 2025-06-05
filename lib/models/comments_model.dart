import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId; // Firestore document ID for the comment
  final String userId;
  final String username;
  final String profileImageUrl;
  final String commentText;
  final Timestamp timestamp;

  CommentModel({
    required this.commentId,
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.commentText,
    required this.timestamp,
  });

  // Not sending commentId to Firestore as it's the document's ID
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'commentText': commentText,
      'timestamp': timestamp,
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map, String commentId) {
    return CommentModel(
      commentId: commentId,
      userId: map['userId'] as String? ?? '',
      username: map['username'] as String? ?? 'Anonymous',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      commentText: map['commentText'] as String? ?? '',
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}