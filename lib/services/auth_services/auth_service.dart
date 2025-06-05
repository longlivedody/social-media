import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../utils/image_picker_utils.dart';

class AuthService {
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'users';
  static const String _postsCollection = 'posts';

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges().map(
        (firebaseUser) =>
            firebaseUser == null ? null : User.fromFirebaseUser(firebaseUser),
      );

  Future<User?> get currentUser async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;

    try {
      // Get user data from Firestore
      final userDoc =
          await _firestore.collection(_usersCollection).doc(fbUser.uid).get();
      if (!userDoc.exists) {
        return User.fromFirebaseUser(fbUser);
      }
      return User.fromFirestore(userDoc);
    } catch (error) {
      debugPrint('Error getting user data from Firestore: $error');
      return User.fromFirebaseUser(fbUser);
    }
  }

  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
    File? profileImage,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }

      String? profileImageBase64;
      if (profileImage != null) {
        final processedImage =
            await ImagePickerUtils.resizeImageIfNeeded(profileImage);
        profileImageBase64 = ImagePickerUtils.getBase64Image(processedImage);
      }

      await _createUserProfile(
        uid: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        profileImageBase64: profileImageBase64,
      );

      if (displayName != null && displayName.isNotEmpty) {
        await userCredential.user!.updateDisplayName(displayName);
      }

      await userCredential.user!.reload();

      return User.fromFirebaseUser(userCredential.user!);
    } on fb_auth.FirebaseAuthException catch (e) {
      _handleFirebaseAuthException(e, 'sign up');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during sign up: $e');
      rethrow;
    }
  }

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Failed to sign in');
      }

      return User.fromFirebaseUser(userCredential.user!);
    } on fb_auth.FirebaseAuthException catch (e) {
      _handleFirebaseAuthException(e, 'sign in');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String newPassword,
    required String oldPassword,
  }) async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) {
      throw Exception('User not logged in. Cannot update password.');
    }

    try {
      await signInWithEmailAndPassword(
        email: fbUser.email!,
        password: oldPassword,
      );
      await fbUser.updatePassword(newPassword);
    } on fb_auth.FirebaseAuthException catch (e) {
      _handleFirebaseAuthException(e, 'update password');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating password: $e');
      rethrow;
    }
  }

  Future<User> updateUserProfile({
    String? displayName,
    File? profileImage,
  }) async {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) {
      throw Exception('User not logged in. Cannot update profile.');
    }

    try {
      if (displayName != null) {
        await fbUser.updateDisplayName(displayName);
        await _updateUserProfile(
          uid: fbUser.uid,
          displayName: displayName,
        );
      }

      if (profileImage != null) {
        final processedImage =
            await ImagePickerUtils.resizeImageIfNeeded(profileImage);
        final profileImageBase64 =
            ImagePickerUtils.getBase64Image(processedImage);

        // await fbUser.updatePhotoURL(profileImageBase64);
        await _updateUserProfile(
          uid: fbUser.uid,
          profileImageBase64: profileImageBase64,
        );
      }

      await fbUser.reload();
      return User.fromFirebaseUser(_firebaseAuth.currentUser!);
    } on fb_auth.FirebaseAuthException catch (e) {
      _handleFirebaseAuthException(e, 'update profile');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating profile: $e');
      rethrow;
    }
  }

  Future<void> _createUserProfile({
    required String uid,
    required String email,
    String? displayName,
    String? profileImageBase64,
  }) async {
    try {
      final userData = {
        'email': email,
        'displayName': displayName,
        'profileImage': profileImageBase64,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_usersCollection).doc(uid).set(userData);
    } on FirebaseException catch (e) {
      throw Exception('Failed to create user profile: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while creating user profile: $e');
    }
  }

  /// Updates an existing user profile in Firestore.
  Future<void> _updateUserProfile({
    required String uid,
    String? displayName,
    String? profileImageBase64,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        updates['displayName'] = displayName;
        // Update display name across all user-related data
        await _updateDisplayNameAcrossCollections(uid, displayName);
      }
      if (profileImageBase64 != null) {
        updates['profileImage'] = profileImageBase64;
        // Update profile image across all user-related data
        await _updateProfileImageAcrossCollections(uid, profileImageBase64);
      }

      await _firestore.collection(_usersCollection).doc(uid).update(updates);
    } on FirebaseException catch (e) {
      throw Exception('Failed to update user profile: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error while updating user profile: $e');
    }
  }

  /// Updates the user's display name across all relevant collections in Firestore.
  Future<void> _updateDisplayNameAcrossCollections(
      String userId, String displayName) async {
    try {
      final batch = _firestore.batch();

      // Update posts
      final postsSnapshot = await _firestore
          .collection(_postsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in postsSnapshot.docs) {
        batch.update(doc.reference, {'username': displayName});

        // Update comments in subcollection
        final commentsSnapshot = await doc.reference
            .collection('comments')
            .where('userId', isEqualTo: userId)
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          batch.update(commentDoc.reference, {'username': displayName});
        }

        // Update likes in subcollection
        final likesSnapshot = await doc.reference
            .collection('likes')
            .where('userId', isEqualTo: userId)
            .get();

        for (var likeDoc in likesSnapshot.docs) {
          batch.update(likeDoc.reference, {'username': displayName});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error updating display name in database: $e');
      rethrow;
    }
  }

  /// Updates the user's profile image across all relevant collections in Firestore.
  Future<void> _updateProfileImageAcrossCollections(
      String userId, String profileImageBase64) async {
    try {
      final batch = _firestore.batch();

      // Update posts
      final postsSnapshot = await _firestore
          .collection(_postsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in postsSnapshot.docs) {
        batch.update(doc.reference, {'profileImageUrl': profileImageBase64});

        // Update comments in subcollection
        final commentsSnapshot = await doc.reference
            .collection('comments')
            .where('userId', isEqualTo: userId)
            .get();

        for (var commentDoc in commentsSnapshot.docs) {
          batch.update(
              commentDoc.reference, {'profileImageUrl': profileImageBase64});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error updating profile image in database: $e');
      rethrow;
    }
  }

  // --- Helper Methods ---
  /// Handles Firebase Auth exceptions with appropriate error messages.
  void _handleFirebaseAuthException(
      fb_auth.FirebaseAuthException e, String operation) {
    debugPrint(
        'Firebase Auth Exception during $operation: ${e.message} (Code: ${e.code})');

    switch (e.code) {
      case 'user-not-found':
        throw Exception('No user found with this email.');
      case 'wrong-password':
        throw Exception('Incorrect password.');
      case 'email-already-in-use':
        throw Exception('This email is already registered.');
      case 'weak-password':
        throw Exception('The password is too weak.');
      case 'invalid-email':
        throw Exception('The email address is invalid.');
      case 'requires-recent-login':
        throw Exception('Please sign in again to perform this action.');
      case 'user-disabled':
        throw Exception('This account has been disabled.');
      case 'too-many-requests':
        throw Exception('Too many attempts. Please try again later.');
      case 'operation-not-allowed':
        throw Exception('This operation is not allowed.');
      case 'network-request-failed':
        throw Exception('Network error. Please check your connection.');
      default:
        throw Exception('Authentication error: ${e.message}');
    }
  }
}
