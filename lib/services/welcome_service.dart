import 'package:shared_preferences/shared_preferences.dart';

class WelcomeService {
  static const String _welcomeSeenKey = 'welcome_seen';
  
  /// Check if the user has seen the welcome screen
  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }
  
  /// Mark the welcome screen as seen
  static Future<void> markWelcomeAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }
  
  /// Reset welcome screen status (useful for testing or logout)
  static Future<void> resetWelcomeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_welcomeSeenKey);
  }
  
  /// Check if user should see welcome screen based on authentication state
  static Future<bool> shouldShowWelcome({
    required bool isNewLogin,
    required bool hasProfile,
  }) async {
    if (!hasProfile) {
      // User needs to complete profile first
      return false;
    }
    
    if (!isNewLogin) {
      // This is an existing session, don't show welcome
      return false;
    }
    
    // Check if welcome has been seen before
    final hasSeenWelcomeStatus = await hasSeenWelcome();
    return !hasSeenWelcomeStatus;
  }
}