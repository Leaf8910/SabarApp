// services/password_validator.dart
import 'package:flutter/material.dart';

enum PasswordStrength {
  weak,
  fair,
  good,
  strong,
  veryStrong,
}

class PasswordValidationResult {
  final bool isValid;
  final PasswordStrength strength;
  final List<String> errors;
  final List<String> suggestions;
  final double strengthScore; // 0.0 to 1.0

  PasswordValidationResult({
    required this.isValid,
    required this.strength,
    required this.errors,
    required this.suggestions,
    required this.strengthScore,
  });
}

class PasswordValidator {
  static const int minLength = 8;
  static const int maxLength = 128;

  /// Comprehensive password validation
  static PasswordValidationResult validatePassword(String password) {
    List<String> errors = [];
    List<String> suggestions = [];
    double score = 0.0;

    // Check minimum length
    if (password.length < minLength) {
      errors.add('Password must be at least $minLength characters long');
      suggestions.add('Add more characters to reach minimum length');
    } else {
      score += 0.2; // Base score for meeting minimum length
    }

    // Check maximum length
    if (password.length > maxLength) {
      errors.add('Password must not exceed $maxLength characters');
    }

    // Check for empty password
    if (password.isEmpty) {
      errors.add('Password cannot be empty');
      return PasswordValidationResult(
        isValid: false,
        strength: PasswordStrength.weak,
        errors: errors,
        suggestions: ['Please enter a password'],
        strengthScore: 0.0,
      );
    }

    // Character type checks
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChars = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    // Lowercase letters
    if (!hasLowercase) {
      errors.add('Password must contain at least one lowercase letter');
      suggestions.add('Add lowercase letters (a-z)');
    } else {
      score += 0.15;
    }

    // Uppercase letters
    if (!hasUppercase) {
      errors.add('Password must contain at least one uppercase letter');
      suggestions.add('Add uppercase letters (A-Z)');
    } else {
      score += 0.15;
    }

    // Numbers
    if (!hasDigits) {
      errors.add('Password must contain at least one number');
      suggestions.add('Add numbers (0-9)');
    } else {
      score += 0.15;
    }

    // Special characters
    if (!hasSpecialChars) {
      errors.add('Password must contain at least one special character');
      suggestions.add('Add special characters (!@#\$%^&*(),.?":{}|<>)');
    } else {
      score += 0.15;
    }

    // Length bonus
    if (password.length >= 12) {
      score += 0.1;
      if (password.length >= 16) {
        score += 0.1;
      }
    } else if (password.length >= 10) {
      score += 0.05;
    }

    // Common password patterns to avoid
    List<String> commonPatterns = [
      'password', '123456', 'qwerty', 'abc123', 'admin', 'letmein',
      'welcome', 'monkey', 'dragon', 'master', 'shadow', 'baseball',
      'football', 'basketball', 'superman', 'trustno1', 'iloveyou'
    ];

    for (String pattern in commonPatterns) {
      if (password.toLowerCase().contains(pattern)) {
        errors.add('Password contains common words or patterns');
        suggestions.add('Avoid common words like "$pattern"');
        score -= 0.2;
        break;
      }
    }

    // Sequential characters check
    if (_hasSequentialChars(password)) {
      errors.add('Password contains sequential characters');
      suggestions.add('Avoid sequences like "123" or "abc"');
      score -= 0.1;
    }

    // Repeated characters check
    if (_hasRepeatedChars(password)) {
      errors.add('Password has too many repeated characters');
      suggestions.add('Avoid repeating characters like "aaa" or "111"');
      score -= 0.1;
    }

    // Ensure score is between 0 and 1
    score = score.clamp(0.0, 1.0);

    // Determine password strength
    PasswordStrength strength;
    if (score < 0.3) {
      strength = PasswordStrength.weak;
    } else if (score < 0.5) {
      strength = PasswordStrength.fair;
    } else if (score < 0.7) {
      strength = PasswordStrength.good;
    } else if (score < 0.9) {
      strength = PasswordStrength.strong;
    } else {
      strength = PasswordStrength.veryStrong;
    }

    // Add positive suggestions for strong passwords
    if (errors.isEmpty) {
      if (strength == PasswordStrength.veryStrong) {
        suggestions.add('Excellent! Your password is very strong');
      } else if (strength == PasswordStrength.strong) {
        suggestions.add('Great! Your password is strong');
      } else if (strength == PasswordStrength.good) {
        suggestions.add('Good password strength');
      }
    }

    return PasswordValidationResult(
      isValid: errors.isEmpty,
      strength: strength,
      errors: errors,
      suggestions: suggestions,
      strengthScore: score,
    );
  }

  /// Check for sequential characters (abc, 123, etc.)
  static bool _hasSequentialChars(String password) {
    for (int i = 0; i < password.length - 2; i++) {
      String substr = password.substring(i, i + 3).toLowerCase();
      
      // Check for sequential letters
      if (substr == 'abc' || substr == 'bcd' || substr == 'cde' ||
          substr == 'def' || substr == 'efg' || substr == 'fgh' ||
          substr == 'ghi' || substr == 'hij' || substr == 'ijk' ||
          substr == 'jkl' || substr == 'klm' || substr == 'lmn' ||
          substr == 'mno' || substr == 'nop' || substr == 'opq' ||
          substr == 'pqr' || substr == 'qrs' || substr == 'rst' ||
          substr == 'stu' || substr == 'tuv' || substr == 'uvw' ||
          substr == 'vwx' || substr == 'wxy' || substr == 'xyz') {
        return true;
      }
      
      // Check for sequential numbers
      if (substr == '123' || substr == '234' || substr == '345' ||
          substr == '456' || substr == '567' || substr == '678' ||
          substr == '789' || substr == '890') {
        return true;
      }
    }
    return false;
  }

  /// Check for repeated characters
  static bool _hasRepeatedChars(String password) {
    int consecutiveCount = 1;
    for (int i = 1; i < password.length; i++) {
      if (password[i] == password[i - 1]) {
        consecutiveCount++;
        if (consecutiveCount >= 3) {
          return true;
        }
      } else {
        consecutiveCount = 1;
      }
    }
    return false;
  }

  /// Get color for password strength indicator
  static Color getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.good:
        return Colors.yellow;
      case PasswordStrength.strong:
        return Colors.lightGreen;
      case PasswordStrength.veryStrong:
        return Colors.green;
    }
  }

  /// Get strength description
  static String getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }

  /// Generate a strong password suggestion
  static String generateStrongPassword({int length = 12}) {
    const String lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const String uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String digits = '0123456789';
    const String specialChars = '!@#\$%^&*(),.?":{}|<>';
    
    final String allChars = lowercase + uppercase + digits + specialChars;
    final List<String> password = [];
    
    // Ensure at least one character from each category
    password.add(lowercase[(DateTime.now().millisecondsSinceEpoch % lowercase.length)]);
    password.add(uppercase[(DateTime.now().millisecondsSinceEpoch % uppercase.length)]);
    password.add(digits[(DateTime.now().millisecondsSinceEpoch % digits.length)]);
    password.add(specialChars[(DateTime.now().millisecondsSinceEpoch % specialChars.length)]);
    
    // Fill the rest randomly
    for (int i = password.length; i < length; i++) {
      password.add(allChars[(DateTime.now().millisecondsSinceEpoch + i) % allChars.length]);
    }
    
    // Shuffle the password
    password.shuffle();
    
    return password.join();
  }
}