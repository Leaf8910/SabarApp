// services/email_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class EmailService {
  static const String _emailCollectionPath = 'email_notifications';

  /// Send welcome email notification to new user
  static Future<void> sendWelcomeEmail({
    required String userEmail,
    required String userName,
    required String userId,
  }) async {
    try {
      developer.log('Sending welcome email to: $userEmail', name: 'EmailService');

      // Create email document for Cloud Function to process
      final emailData = {
        'to': userEmail,
        'template': 'welcome',
        'data': {
          'userName': userName,
          'userEmail': userEmail,
          'userId': userId,
          'appName': 'Islamic Prayer App',
          'signupDate': FieldValue.serverTimestamp(),
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'welcome_signup',
      };

      // Add to Firestore collection (Cloud Function will process this)
      await FirebaseFirestore.instance
          .collection(_emailCollectionPath)
          .add(emailData);

      developer.log('Welcome email queued successfully for: $userEmail', name: 'EmailService');

    } catch (e, stackTrace) {
      developer.log(
        'Error sending welcome email to $userEmail',
        name: 'EmailService',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't throw error - email failure shouldn't prevent signup
    }
  }

  /// Send email verification reminder
  static Future<void> sendEmailVerificationReminder(User user) async {
    try {
      if (user.email == null || user.emailVerified) return;

      developer.log('Sending email verification reminder to: ${user.email}', name: 'EmailService');

      final emailData = {
        'to': user.email!,
        'template': 'email_verification',
        'data': {
          'userName': user.displayName ?? 'User',
          'userEmail': user.email!,
          'userId': user.uid,
          'appName': 'Islamic Prayer App',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'email_verification',
      };

      await FirebaseFirestore.instance
          .collection(_emailCollectionPath)
          .add(emailData);

      // Also send Firebase's built-in email verification
      await user.sendEmailVerification();

      developer.log('Email verification reminder sent successfully', name: 'EmailService');

    } catch (e, stackTrace) {
      developer.log(
        'Error sending email verification reminder',
        name: 'EmailService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send password reset confirmation email
  static Future<void> sendPasswordResetConfirmation({
    required String userEmail,
    required String userName,
  }) async {
    try {
      developer.log('Sending password reset confirmation to: $userEmail', name: 'EmailService');

      final emailData = {
        'to': userEmail,
        'template': 'password_reset_confirmation',
        'data': {
          'userName': userName,
          'userEmail': userEmail,
          'appName': 'Islamic Prayer App',
          'resetDate': FieldValue.serverTimestamp(),
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'password_reset',
      };

      await FirebaseFirestore.instance
          .collection(_emailCollectionPath)
          .add(emailData);

      developer.log('Password reset confirmation email queued successfully', name: 'EmailService');

    } catch (e, stackTrace) {
      developer.log(
        'Error sending password reset confirmation',
        name: 'EmailService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send profile completion reminder
  static Future<void> sendProfileCompletionReminder({
    required String userEmail,
    required String userName,
    required String userId,
  }) async {
    try {
      developer.log('Sending profile completion reminder to: $userEmail', name: 'EmailService');

      final emailData = {
        'to': userEmail,
        'template': 'profile_completion',
        'data': {
          'userName': userName,
          'userEmail': userEmail,
          'userId': userId,
          'appName': 'Islamic Prayer App',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'profile_reminder',
      };

      await FirebaseFirestore.instance
          .collection(_emailCollectionPath)
          .add(emailData);

      developer.log('Profile completion reminder queued successfully', name: 'EmailService');

    } catch (e, stackTrace) {
      developer.log(
        'Error sending profile completion reminder',
        name: 'EmailService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get email notification status
  static Future<List<Map<String, dynamic>>> getEmailHistory(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(_emailCollectionPath)
          .where('data.userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

    } catch (e, stackTrace) {
      developer.log(
        'Error getting email history for user: $userId',
        name: 'EmailService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
}