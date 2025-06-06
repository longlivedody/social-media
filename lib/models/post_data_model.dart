import 'package:cloud_firestore/cloud_firestore.dart';
// If you have a separate CommentsModel for structure, it's fine, but it won't be a direct field anymore.

class PostDataModel {
  final dynamic postId; // Can be int or String, ensure consistency
  final String username;
  final String profileImageUrl;
  final String postText;
  final String? postImageUrl;
  final String? videoUrl;
  final Timestamp postTime;

  final int sharesCount;
  final String userId;
  final String documentId;

  PostDataModel({
    required this.postId,
    required this.username,
    required this.profileImageUrl,
    required this.postText,
    this.postImageUrl,
    this.videoUrl,
    required this.postTime,
    required this.sharesCount,
    required this.userId,
    required this.documentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'postText': postText,
      'postImageUrl': postImageUrl,
      'videoUrl': videoUrl,
      'postTime': postTime,
      'sharesCount': sharesCount,
      'userId': userId,
      'documentId': documentId,
    };
  }

  factory PostDataModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PostDataModel(
      postId: map['postId'],
      username: map['username'] as String? ?? 'Anonymous',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      postText: map['postText'] as String? ?? '',
      postImageUrl: map['postImageUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      postTime: map['postTime'] as Timestamp? ?? Timestamp.now(),
      sharesCount: map['sharesCount'] as int? ?? 0,
      userId: map['userId'] as String? ?? '',
      documentId: documentId,
    );
  }
}
