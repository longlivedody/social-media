import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// A model class representing a user in the application.
/// This class wraps the Supabase User object and provides a clean interface
/// for accessing user data throughout the app.
class User {
  /// The unique identifier for the user
  final String uid;

  /// The user's display name
  final String? displayName;

  /// The user's email address
  final String? email;

  /// The URL to the user's profile photo
  final String? photoURL;

  /// Creates a new User instance
  const User({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
  });

  /// Creates a User instance from a Supabase User object
  factory User.fromSupabaseUser(supabase.User supabaseUser) {
    return User(
      uid: supabaseUser.id,
      displayName: supabaseUser.userMetadata?['display_name'] as String?,
      email: supabaseUser.email,
      photoURL: supabaseUser.userMetadata?['profile-image'] as String?,
    );
  }

  /// Creates a User instance from Supabase database data
  factory User.fromSupabase(Map<String, dynamic> data) {
    return User(
      uid: data['id'] as String,
      displayName: data['display_name'] as String?,
      email: data['email'] as String?,
      photoURL: data['profile-image'] as String?,
    );
  }

  /// Creates a copy of this User with the given fields replaced with new values
  User copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoURL,
  }) {
    return User(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
    );
  }

  /// Converts the User object to a Map for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'display_name': displayName,
      'email': email,
      'profile-image': photoURL,
    };
  }

  /// Creates a User instance from a Map (typically from database)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['id'] as String,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      photoURL: json['profile-image'] as String?,
    );
  }

  /// Getter for profile image (for compatibility)
  String? get profileImage => photoURL;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          displayName == other.displayName &&
          email == other.email &&
          photoURL == other.photoURL;

  @override
  int get hashCode =>
      uid.hashCode ^ displayName.hashCode ^ email.hashCode ^ photoURL.hashCode;

  @override
  String toString() {
    return 'User(uid: $uid, displayName: $displayName, email: $email, profile-image: $photoURL)';
  }
}
