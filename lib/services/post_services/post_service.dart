import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:facebook_clone/models/post_data_model.dart';
import 'package:facebook_clone/models/comments_model.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';

/// Service class for managing post-related operations in Firestore
class PostService {
  // Constants
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const String _collection = 'posts';
  static const String _commentsSubCollection = 'comments';
  static const String _likesSubCollection = 'likes';

  // Firestore instance
  final FirebaseFirestore _firestore;

  /// Creates a new instance of [PostService]
  PostService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Executes a Firestore operation with retry logic
  Future<T> _executeWithRetry<T>(Future<T> Function() operation) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        retryCount++;
        if (retryCount == _maxRetries) {
          debugPrint('Operation failed after $_maxRetries attempts: $e');
          rethrow;
        }
        await Future.delayed(_retryDelay * retryCount);
      }
    }
    throw Exception('Operation failed after $_maxRetries attempts');
  }

  Future<void> createPost({
    required String postText,
    String? postImageUrl,
    required User user,
  }) async {
    if (postText.trim().isEmpty) {
      throw ArgumentError('Post text cannot be empty');
    }
    if (user.uid.isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    await _executeWithRetry(() async {
      final docRef = _firestore.collection(_collection).doc();

      final post = PostDataModel(
        postId: DateTime.now()
            .millisecondsSinceEpoch, // Or use docRef.id if you prefer
        username: user.displayName ?? 'Anonymous',
        profileImageUrl: user.photoURL ?? '',
        postText: postText.trim(),
        postImageUrl: postImageUrl ?? '',
        postTime: Timestamp.now(),
        sharesCount: 0,
        userId: user.uid,
        documentId: docRef.id,
      );

      await docRef.set(post.toMap());
    });
  }

  Stream<List<PostDataModel>> getPosts() {
    try {
      return _firestore
          .collection(_collection)
          .orderBy('postTime', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_mapDocumentToPost).toList());
    } catch (e) {
      debugPrint('Error getting posts: $e');
      rethrow;
    }
  }

  Future<void> addCommentToPost({
    required String postId, // This is the documentId of the post
    required String commentText,
    // Change these parameters to accept the data directly
    required String commentingUserId,
    String?
        commentingUserName, // Can be nullable if display name might be missing
    String? commentingUserProfileImageUrl, // Can be nullable
  }) async {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (commentText.trim().isEmpty) {
      throw ArgumentError('Comment text cannot be empty');
    }
    if (commentingUserId.isEmpty) {
      throw ArgumentError('Commenting user ID cannot be empty');
    }

    await _executeWithRetry(() async {
      final postRef = _firestore.collection(_collection).doc(postId);
      final commentRef =
          postRef.collection(_commentsSubCollection).doc(); // New comment doc

      // Use the passed-in parameters directly
      final newComment = CommentModel(
        commentId: commentRef.id,
        userId: commentingUserId,
        username:
            commentingUserName ?? 'Anonymous', // Use provided name or default
        profileImageUrl:
            commentingUserProfileImageUrl ?? '', // Use provided URL or default
        commentText: commentText.trim(),
        timestamp: Timestamp.now(),
      );

      await commentRef.set(newComment.toMap());
    });
  }

  /// Toggles like status for a post
  Future<void> toggleLike({
    required String postId,
    required String userId,
    required String username,
  }) async {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (userId.isEmpty) throw ArgumentError('User ID cannot be empty');

    await _executeWithRetry(() async {
      final likeRef = _firestore
          .collection(_collection)
          .doc(postId)
          .collection(_likesSubCollection)
          .doc(userId);

      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // Unlike: Remove the like document
        await likeRef.delete();
      } else {
        // Like: Create a new like document
        await likeRef.set({
          'userId': userId,
          'username': username,
          'timestamp': Timestamp.now(),
        });
      }
    });
  }

  /// Returns a stream of like status for a post and user
  Stream<bool> hasUserLikedPost(String postId, String userId) {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (userId.isEmpty) throw ArgumentError('User ID cannot be empty');

    return _firestore
        .collection(_collection)
        .doc(postId)
        .collection(_likesSubCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  /// Gets a stream of users who liked a post
  Stream<List<Map<String, dynamic>>> getLikesForPost(String postId) {
    return _firestore
        .collection(_collection)
        .doc(postId)
        .collection(_likesSubCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': data['userId'],
          'username': data['username'],
          'timestamp': data['timestamp'],
        };
      }).toList();
    });
  }

  Stream<int> getLikesCountForPost(String postId) {
    return _firestore
        .collection(_collection)
        .doc(postId)
        .collection(_likesSubCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<CommentModel>> getCommentsForPost(String postId) {
    return _firestore
        .collection(_collection)
        .doc(postId)
        .collection(_commentsSubCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  PostDataModel _mapDocumentToPost(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return PostDataModel.fromMap(data, doc.id);
  }

  /// Deletes a post and its associated data
  Future<void> deletePost({
    required String postId,
    required String userId,
  }) async {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (userId.isEmpty) throw ArgumentError('User ID cannot be empty');

    await _executeWithRetry(() async {
      final postRef = _firestore.collection(_collection).doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      if (postData['userId'] != userId) {
        throw Exception('Not authorized to delete this post');
      }

      // Delete all comments
      final commentsRef = postRef.collection(_commentsSubCollection);
      final commentsSnapshot = await commentsRef.get();
      for (var doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all likes
      final likesRef = postRef.collection(_likesSubCollection);
      final likesSnapshot = await likesRef.get();
      for (var doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the post document
      await postRef.delete();
    });
  }

  /// Updates an existing post
  Future<void> updatePost({
    required String postId,
    required String userId,
    required String postText,
    String? postImageUrl,
  }) async {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (userId.isEmpty) throw ArgumentError('User ID cannot be empty');
    if (postText.trim().isEmpty) {
      throw ArgumentError('Post text cannot be empty');
    }

    await _executeWithRetry(() async {
      final postRef = _firestore.collection(_collection).doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final postData = postDoc.data() as Map<String, dynamic>;
      if (postData['userId'] != userId) {
        throw Exception('Not authorized to update this post');
      }

      await postRef.update({
        'postText': postText.trim(),
        if (postImageUrl != null) 'postImageUrl': postImageUrl,
      });
    });
  }

  /// Updates an existing comment
  Future<void> updateComment({
    required String postId,
    required String commentId,
    required String newCommentText,
    required String userId, // To verify ownership
  }) async {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (commentId.isEmpty) throw ArgumentError('Comment ID cannot be empty');
    if (newCommentText.trim().isEmpty) {
      throw ArgumentError('Comment text cannot be empty');
    }
    if (userId.isEmpty) throw ArgumentError('User ID cannot be empty');

    await _executeWithRetry(() async {
      final commentRef = _firestore
          .collection(_collection)
          .doc(postId)
          .collection(_commentsSubCollection)
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data();
      if (commentData?['userId'] != userId) {
        throw Exception('Not authorized to update this comment');
      }

      await commentRef.update({
        'commentText': newCommentText.trim(),
        'updatedAt': Timestamp.now(),
      });
    });
  }

  /// Deletes a comment
  Future<void> deleteComment({
    required String postId,
    required String commentId,
    required String userId, // To verify ownership
  }) async {
    if (postId.isEmpty) throw ArgumentError('Post ID cannot be empty');
    if (commentId.isEmpty) throw ArgumentError('Comment ID cannot be empty');
    if (userId.isEmpty) throw ArgumentError('User ID cannot be empty');

    await _executeWithRetry(() async {
      final commentRef = _firestore
          .collection(_collection)
          .doc(postId)
          .collection(_commentsSubCollection)
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentData = commentDoc.data();
      if (commentData?['userId'] != userId) {
        throw Exception('Not authorized to delete this comment');
      }

      await commentRef.delete();
    });
  }
}
