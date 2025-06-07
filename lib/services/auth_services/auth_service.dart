// ignore_for_file: unnecessary_null_comparison

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../models/user_model.dart';

class AuthService {
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;
  static const String _storageBucket = 'profile-images';

  static const String _usersTable = 'users';
  static const String _postsTable = 'posts';

  Stream<User?> get authStateChanges => _supabase.auth.onAuthStateChange.map(
        (event) => event.session?.user == null
            ? null
            : User.fromSupabaseUser(event.session!.user),
      );

  Future<User?> get currentUser async {
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) return null;

    try {
      // Get user data from Supabase
      final userData = await _supabase
          .from(_usersTable)
          .select()
          .eq('id', supabaseUser.id)
          .single();

      if (userData == null) {
        return User.fromSupabaseUser(supabaseUser);
      }
      return User.fromSupabase(userData);
    } catch (error) {
      debugPrint('Error getting user data from Supabase: $error');
      return User.fromSupabaseUser(supabaseUser);
    }
  }

  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
    File? profileImage,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (response.user == null) {
          throw Exception('Failed to create user account');
        }

        // Wait for the session to be established
        await Future.delayed(const Duration(seconds: 1));

        // رفع الصورة وتخزين الرابط
        String? profileImageUrl;
        if (profileImage != null) {
          profileImageUrl = await _uploadProfileImage(
            profileImage,
            response.user!.id,
          );
        }

        // إنشاء حساب المستخدم مع رابط الصورة
        await _supabase.from(_usersTable).insert({
          'id': response.user!.id,
          'email': email,
          'display_name': displayName,
          'profile-image': profileImageUrl,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await _supabase.auth.updateUser(
          supabase.UserAttributes(
            data: {
              'display-name': displayName,
              'profile-image': profileImageUrl,
            },
          ),
        );

        return User.fromSupabaseUser(response.user!);
      } on supabase.AuthException catch (e) {
        if (e.message.contains('For security purposes') &&
            retryCount < maxRetries - 1) {
          retryCount++;
          await Future.delayed(retryDelay * retryCount);
          continue;
        }
        _handleAuthException(e, 'sign up');
        rethrow;
      } catch (e) {
        debugPrint('Unexpected error during sign up: $e');
        rethrow;
      }
    }
    throw Exception('Maximum retry attempts reached. Please try again later.');
  }

  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to sign in');
      }

      // Fetch complete user data from users table
      final userData = await _supabase
          .from(_usersTable)
          .select()
          .eq('id', response.user!.id)
          .single();

      // If user data exists in the table, return complete user object
      if (userData != null) {
        debugPrint('User profile image URL: ${userData['profile-image']}');
        debugPrint('Complete user data: $userData');
        return User.fromSupabase(userData);
      }

      // Fallback to basic user data if not found in users table
      return User.fromSupabaseUser(response.user!);
    } on supabase.AuthException catch (e) {
      _handleAuthException(e, 'sign in');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  Future<void> updatePassword({
    required String newPassword,
    required String oldPassword,
  }) async {
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) {
      throw Exception('User not logged in. Cannot update password.');
    }

    try {
      await _supabase.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (e) {
      _handleAuthException(e, 'update password');
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
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser == null) {
      throw Exception('User not logged in. Cannot update profile.');
    }

    try {
      String? profileImageUrl;
      if (profileImage != null) {
        profileImageUrl = await _uploadProfileImage(
          profileImage,
          supabaseUser.id,
        );
      }

      if (displayName != null || profileImageUrl != null) {
        await _supabase.auth.updateUser(
          supabase.UserAttributes(
            data: {
              if (displayName != null) 'display_name': displayName,
              if (profileImageUrl != null) 'profile_image': profileImageUrl,
            },
          ),
        );
        await _updateUserProfile(
          uid: supabaseUser.id,
          displayName: displayName,
          profileImageUrl: profileImageUrl,
        );
      }

      // Fetch updated user data from the database
      final userData = await _supabase
          .from(_usersTable)
          .select()
          .eq('id', supabaseUser.id)
          .single();

      // Return complete user data including profile image
      return User.fromSupabase(userData);
    } on supabase.AuthException catch (e) {
      _handleAuthException(e, 'update profile');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error updating profile: $e');
      rethrow;
    }
  }

  Future<String> _uploadProfileImage(File imageFile, String userId) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = 'profile_$userId.$fileExt';
      final filePath = '$userId/$fileName';

      debugPrint('Uploading profile image to path: $filePath');

      // اقرأ الصورة كـ bytes
      final bytes = await imageFile.readAsBytes();

      // ارفع الصورة إلى Supabase Storage
      await _supabase.storage.from(_storageBucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: supabase.FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Get the public URL
      final imageUrl =
          _supabase.storage.from(_storageBucket).getPublicUrl(filePath);

      debugPrint('Profile image uploaded successfully. URL: $imageUrl');
      return imageUrl;
    } on supabase.StorageException catch (e) {
      debugPrint('Storage error uploading profile image: ${e.message}');
      if (e.message.contains('row-level security policy')) {
        throw Exception(
            'Unable to upload profile image. Please make sure you have the correct permissions and the storage bucket is properly configured.');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }

  Future<void> _updateUserProfile({
    required String uid,
    String? displayName,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) {
        updates['display_name'] = displayName;
        await _updateDisplayNameAcrossCollections(uid, displayName);
      }
      if (profileImageUrl != null) {
        updates['profile_image'] = profileImageUrl;
        await _updateProfileImageAcrossCollections(uid, profileImageUrl);
      }

      await _supabase.from(_usersTable).update(updates).eq('id', uid);
    } catch (e) {
      throw Exception('Unexpected error while updating user profile: $e');
    }
  }

  Future<void> _updateDisplayNameAcrossCollections(
      String userId, String displayName) async {
    try {
      // Update posts
      await _supabase
          .from(_postsTable)
          .update({'username': displayName}).eq('user_id', userId);

      // Update comments
      await _supabase
          .from('comments')
          .update({'username': displayName}).eq('user_id', userId);

      // Update likes with better error handling
      await _supabase
          .from('likes')
          .update({'username': displayName}).eq('user_id', userId);
    } catch (e) {
      debugPrint('Error updating display name in database: $e');
      rethrow;
    }
  }

  Future<void> _updateProfileImageAcrossCollections(
      String userId, String profileImageUrl) async {
    try {
      // Update posts
      await _supabase
          .from(_postsTable)
          .update({'profile_image_url': profileImageUrl}).eq('user_id', userId);

      // Update comments
      await _supabase
          .from('comments')
          .update({'profile_image_url': profileImageUrl}).eq('user_id', userId);
    } catch (e) {
      debugPrint('Error updating profile image in database: $e');
      rethrow;
    }
  }

  void _handleAuthException(supabase.AuthException e, String operation) {
    debugPrint('Auth Exception during $operation: ${e.message}');

    switch (e.message) {
      case 'Invalid login credentials':
        throw Exception('Invalid email or password.');
      case 'Email not confirmed':
        throw Exception('Please confirm your email address.');
      case 'Email already registered':
        throw Exception('This email is already registered.');
      case 'Password should be at least 6 characters':
        throw Exception('The password is too weak.');
      case 'Invalid email':
        throw Exception('The email address is invalid.');
      case 'User not found':
        throw Exception('No user found with this email.');
      case 'Too many requests':
        throw Exception(
            'Too many attempts. Please wait a moment and try again.');
      case String message when message.contains('For security purposes'):
        final seconds = int.tryParse(message
                .split(' ')
                .lastWhere((word) => word.contains('seconds'))
                .replaceAll('seconds', '')
                .trim()) ??
            48;
        throw Exception('Please wait $seconds seconds before trying again.');
      default:
        throw Exception('Authentication error: ${e.message}');
    }
  }
}
