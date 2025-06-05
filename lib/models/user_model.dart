import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

/// A model class representing a user in the application.
/// This class wraps the Firebase User object and provides a clean interface
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

  /// Whether the user's email has been verified

  /// Creates a new User instance
  const User({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
  });

  /// Creates a User instance from a Firebase User object
  factory User.fromFirebaseUser(fb_auth.User firebaseUser) {
    return User(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName,
      email: firebaseUser.email,
      photoURL: firebaseUser.photoURL,
    );
  }

  /// Creates a User instance from Firestore document data
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      uid: doc.id,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      photoURL:
          data['profileImage'] as String?, // Get profileImage from Firestore
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
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'profileImage': photoURL, // Store as profileImage in Firestore
    };
  }

  /// Creates a User instance from a Map (typically from database)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      photoURL: json['profileImage'] as String?, // Get profileImage from JSON
    );
  }

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
    return 'User(uid: $uid, displayName: $displayName, email: $email, photoURL: $photoURL)';
  }
}
