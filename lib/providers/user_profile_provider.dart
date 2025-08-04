import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class UserProfile {
  final String uid;
  final String email;
  final String name;
  final int age;
  final String religiousLevel;
  final String country;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.age,
    required this.religiousLevel,
    required this.country,
    required this.profileCompleted,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      age: map['age']?.toInt() ?? 0,
      religiousLevel: map['religiousLevel'] ?? '',
      country: map['country'] ?? '',
      profileCompleted: map['profileCompleted'] ?? false,
      createdAt: map['createdAt']?.toDate(),
      updatedAt: map['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'age': age,
      'religiousLevel': religiousLevel,
      'country': country,
      'profileCompleted': profileCompleted,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? name,
    int? age,
    String? religiousLevel,
    String? country,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      religiousLevel: religiousLevel ?? this.religiousLevel,
      country: country ?? this.country,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(uid: $uid, name: $name, age: $age, religiousLevel: $religiousLevel, country: $country, profileCompleted: $profileCompleted)';
  }
}

class UserProfileProvider with ChangeNotifier {
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _userProfile != null && _userProfile!.profileCompleted;

  /// Fetch user profile from Firestore
  Future<void> fetchUserProfile(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      developer.log('Fetching user profile for UID: $uid', name: 'UserProfileProvider');
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        _userProfile = UserProfile.fromMap(doc.data()!);
        developer.log('User profile fetched successfully: $_userProfile', name: 'UserProfileProvider');
      } else {
        _userProfile = null;
        developer.log('No user profile found for UID: $uid', name: 'UserProfileProvider');
      }
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to fetch user profile: $e';
      developer.log(
        'Error fetching user profile',
        name: 'UserProfileProvider',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if user has completed their profile
  Future<bool> hasCompletedProfile(String uid) async {
    try {
      developer.log('Checking profile completion for UID: $uid', name: 'UserProfileProvider');
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final completed = data['profileCompleted'] == true;
        developer.log('Profile completion status: $completed', name: 'UserProfileProvider');
        return completed;
      }
      
      developer.log('No profile document found', name: 'UserProfileProvider');
      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Error checking profile completion',
        name: 'UserProfileProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Create or update user profile
  Future<bool> saveUserProfile({
    required String name,
    required int age,
    required String religiousLevel,
    required String country,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = 'No authenticated user found';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      developer.log('Saving user profile for UID: ${user.uid}', name: 'UserProfileProvider');

      final profileData = {
        'uid': user.uid,
        'email': user.email ?? '',
        'name': name.trim(),
        'age': age,
        'religiousLevel': religiousLevel,
        'country': country,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // If this is a new profile, add createdAt
      final existingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!existingDoc.exists) {
        profileData['createdAt'] = FieldValue.serverTimestamp();
        developer.log('Creating new user profile', name: 'UserProfileProvider');
      } else {
        developer.log('Updating existing user profile', name: 'UserProfileProvider');
      }

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      // Update local profile
      _userProfile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        name: name.trim(),
        age: age,
        religiousLevel: religiousLevel,
        country: country,
        profileCompleted: true,
        createdAt: _userProfile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      developer.log('User profile saved successfully', name: 'UserProfileProvider');
      return true;
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to save user profile: $e';
      developer.log(
        'Error saving user profile',
        name: 'UserProfileProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update specific profile fields
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _userProfile == null) {
      _errorMessage = 'No authenticated user or profile found';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      developer.log('Updating user profile fields: ${updates.keys}', name: 'UserProfileProvider');

      // Add timestamp
      updates['updatedAt'] = FieldValue.serverTimestamp();

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      // Update local profile
      String? name = updates['name'] ?? _userProfile!.name;
      int? age = updates['age'] ?? _userProfile!.age;
      String? religiousLevel = updates['religiousLevel'] ?? _userProfile!.religiousLevel;
      String? country = updates['country'] ?? _userProfile!.country;
      bool? profileCompleted = updates['profileCompleted'] ?? _userProfile!.profileCompleted;

      _userProfile = _userProfile!.copyWith(
        name: name,
        age: age,
        religiousLevel: religiousLevel,
        country: country,
        profileCompleted: profileCompleted,
        updatedAt: DateTime.now(),
      );

      developer.log('User profile updated successfully', name: 'UserProfileProvider');
      return true;
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to update user profile: $e';
      developer.log(
        'Error updating user profile',
        name: 'UserProfileProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete user profile
  Future<bool> deleteProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = 'No authenticated user found';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      developer.log('Deleting user profile for UID: ${user.uid}', name: 'UserProfileProvider');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      _userProfile = null;
      developer.log('User profile deleted successfully', name: 'UserProfileProvider');
      return true;
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to delete user profile: $e';
      developer.log(
        'Error deleting user profile',
        name: 'UserProfileProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Listen to real-time profile changes
  void listenToProfileChanges(String uid) {
    developer.log('Starting to listen to profile changes for UID: $uid', name: 'UserProfileProvider');
    
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (docSnapshot) {
        if (docSnapshot.exists && docSnapshot.data() != null) {
          _userProfile = UserProfile.fromMap(docSnapshot.data()!);
          developer.log('Profile updated from real-time listener', name: 'UserProfileProvider');
          notifyListeners();
        } else {
          _userProfile = null;
          notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = 'Error listening to profile changes: $error';
        developer.log('Error in profile listener', name: 'UserProfileProvider', error: error);
        notifyListeners();
      },
    );
  }

  /// Clear local profile data (useful for logout)
  void clearProfile() {
    developer.log('Clearing user profile data', name: 'UserProfileProvider');
    _userProfile = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear only error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get user's religious level for customization
  String get religiousLevel => _userProfile?.religiousLevel ?? '';

  /// Get user's country for prayer time calculations
  String get country => _userProfile?.country ?? '';

  /// Get user's display name
  String get displayName => _userProfile?.name ?? 'User';

  /// Check if user is a new convert for special guidance
  bool get isNewConvert => religiousLevel.toLowerCase().contains('newly convert');

  /// Check if user is a beginner for simplified instructions
  bool get isBeginner => religiousLevel.toLowerCase().contains('beginner') || isNewConvert;
}