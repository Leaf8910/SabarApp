// services/pronunciation_service.dart
// Alternative version without SystemSound dependency

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;

class PronunciationService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isInitialized = false;
  String _localeId = 'ar-SA'; // Arabic (Saudi Arabia)
  
  // Getters
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  // Constructor
  PronunciationService() {
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage('ar-SA');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        throw Exception('Microphone permission denied');
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
        },
        onError: (error) {
          print('Speech recognition error: $error');
        },
      );

      if (_isInitialized) {
        // Get available locales and find Arabic
        final locales = await _speech.locales();
        final arabicLocales = locales.where((locale) => 
          locale.localeId.startsWith('ar')).toList();
        
        if (arabicLocales.isNotEmpty) {
          _localeId = arabicLocales.first.localeId;
          print('Using Arabic locale: $_localeId');
        }
      }

      return _isInitialized;
    } catch (e) {
      print('Error initializing pronunciation service: $e');
      return false;
    }
  }

  /// Start listening for pronunciation practice
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    Function(double)? onSoundLevelChange,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError('Failed to initialize speech recognition');
        return;
      }
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: _localeId,
        onSoundLevelChange: onSoundLevelChange,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      _isListening = false;
      onError('Failed to start listening: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Speak Arabic text using TTS
  Future<void> speakArabicText(String arabicText) async {
    try {
      await _flutterTts.setLanguage('ar-SA');
      await _flutterTts.speak(arabicText);
    } catch (e) {
      print('Error speaking Arabic text: $e');
      // Fallback: use haptic feedback instead of system sound
      await _playFallbackFeedback();
    }
  }

  /// Play fallback feedback when audio fails
  Future<void> _playFallbackFeedback() async {
    try {
      // Use haptic feedback as fallback
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Fallback feedback failed: $e');
      // Silent failure - no audio/haptic available
    }
  }

  /// Play feedback sound for pronunciation accuracy
  Future<void> playFeedbackSound(bool isCorrect) async {
    try {
      if (isCorrect) {
        await HapticFeedback.lightImpact();
        // Could also use TTS to say "Good" or similar
        await _flutterTts.speak('Good');
      } else {
        await HapticFeedback.heavyImpact();
        // Could also use TTS to say "Try again" or similar
        await _flutterTts.speak('Try again');
      }
    } catch (e) {
      print('Error playing feedback sound: $e');
    }
  }

  /// Calculate pronunciation accuracy (simplified)
  double calculateAccuracy(String original, String recognized) {
    if (original.isEmpty || recognized.isEmpty) return 0.0;
    
    // Remove diacritics and normalize text for comparison
    final normalizedOriginal = _normalizeArabicText(original);
    final normalizedRecognized = _normalizeArabicText(recognized);
    
    // Calculate similarity using Levenshtein distance
    final distance = _levenshteinDistance(normalizedOriginal, normalizedRecognized);
    final maxLength = math.max(normalizedOriginal.length, normalizedRecognized.length);
    
    if (maxLength == 0) return 1.0;
    
    final accuracy = 1.0 - (distance / maxLength);
    return math.max(0.0, accuracy);
  }

  /// Normalize Arabic text for comparison
  String _normalizeArabicText(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u0652]'), '') // Remove diacritics
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim()
        .toLowerCase();
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    
    final matrix = List.generate(
      len1 + 1,
      (i) => List.generate(len2 + 1, (j) => 0),
    );
    
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }
    
    return matrix[len1][len2];
  }

  /// Get available languages for speech recognition
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      final locales = await _speech.locales();
      return locales.map((locale) => locale.localeId).toList();
    } catch (e) {
      print('Error getting available languages: $e');
      return [];
    }
  }

  /// Set speech recognition language
  Future<void> setLanguage(String localeId) async {
    _localeId = localeId;
    await _flutterTts.setLanguage(localeId);
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _flutterTts.stop();
  }
}

// Data models for pronunciation practice
class PronunciationSession {
  final int verseIndex;
  final String arabicText;
  final DateTime startTime;
  DateTime? endTime;
  final List<PronunciationAttempt> attempts = [];

  PronunciationSession({
    required this.verseIndex,
    required this.arabicText,
    required this.startTime,
  });

  void addAttempt(String recognizedText) {
    final pronunciationService = PronunciationService();
    final accuracy = pronunciationService.calculateAccuracy(arabicText, recognizedText);
    
    attempts.add(PronunciationAttempt(
      recognizedText: recognizedText,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    ));
  }

  void endSession() {
    endTime = DateTime.now();
  }

  Duration getDuration() {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  double getCurrentAccuracy() {
    if (attempts.isEmpty) return 0.0;
    return attempts.map((a) => a.accuracy).reduce((a, b) => a + b) / attempts.length;
  }

  double getBestAccuracy() {
    if (attempts.isEmpty) return 0.0;
    return attempts.map((a) => a.accuracy).reduce(math.max);
  }
}

class PronunciationAttempt {
  final String recognizedText;
  final double accuracy;
  final DateTime timestamp;

  PronunciationAttempt({
    required this.recognizedText,
    required this.accuracy,
    required this.timestamp,
  });
}