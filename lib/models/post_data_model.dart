import 'package:cloud_firestore/cloud_firestore.dart';
// If you have a separate CommentsModel for structure, it's fine, but it won't be a direct field anymore.

class PostDataModel {
  final dynamic postId; // Can be int or String, ensure consistency
  final String username;
  final String profileImageUrl;
  final String postText;
  final String? postImageUrl;
  final Timestamp postTime;

  // final int likesCount; // REMOVED - Handled by subcollection
  final int sharesCount; // Keep if you manage it directly on the post
  // final List<CommentModel> comments; // REMOVED - Handled by subcollection
  final String userId; // Author's UID
  final String documentId; // Firestore document ID - VERY IMPORTANT

  PostDataModel({
    required this.postId,
    required this.username,
    required this.profileImageUrl,
    required this.postText,
    this.postImageUrl,
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
      'postTime': postTime,
      'sharesCount': sharesCount,
      'userId': userId,
      'documentId': documentId,
      // Make sure this is saved if you need it later
      // though often the Firestore doc.id is the source of truth
    };
  }

  factory PostDataModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PostDataModel(
      postId: map['postId'],
      // Adjust type casting if needed (e.g., as int? ?? 0)
      username: map['username'] as String? ?? 'Anonymous',
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
      postText: map['postText'] as String? ?? '',
      postImageUrl: map['postImageUrl'] as String?,
      postTime: map['postTime'] as Timestamp? ?? Timestamp.now(),
      sharesCount: map['sharesCount'] as int? ?? 0,
      userId: map['userId'] as String? ?? '',
      documentId: documentId, // Assign the passed document ID
    );
  }
}