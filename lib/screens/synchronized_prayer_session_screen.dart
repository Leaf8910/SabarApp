
// lib/screens/synchronized_prayer_session_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/synchronized_prayer_session_provider.dart';
import '../providers/roboflow_prayer_pose_provider.dart';
// import '../widgets/pose_camera_widget.dart';
import '../widgets/quran_verse_display_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import 'package:camera/camera.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../services/posture_monitoring_service.dart'; 
import '../services/sensor_manager.dart';
import '../widgets/speech_recognition_fallback_dialog.dart';
import '../screens/synchronized_prayer_session_screen.dart' show PostureDetectionResult;
import 'package:google_fonts/google_fonts.dart';

// Posture detection models
enum PrayerPosture {
  qiyam,    // Standing
  ruku,     // Bowing
  sujud,    // Prostration
  tahiyat,  // Sitting
  unknown
}

class PostureDetectionResult {
  final PrayerPosture posture;
  final bool isCorrect;
  final double confidence;
  final Map<String, double> sensorReadings;
  final List<String> corrections;
  final Map<String, double> balanceIssues;
  final DateTime timestamp;

  PostureDetectionResult({
    required this.posture,
    required this.isCorrect,
    required this.confidence,
    required this.sensorReadings,
    required this.corrections,
    required this.balanceIssues,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'posture': posture.name,
      'isCorrect': isCorrect,
      'confidence': confidence,
      'sensorReadings': sensorReadings,
      'corrections': corrections,
      'balanceIssues': balanceIssues,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class SynchronizedPrayerSessionScreen extends StatefulWidget {
  final String? prayerName;
  final String? sessionId;

  const SynchronizedPrayerSessionScreen({
    super.key,
    this.prayerName,
    this.sessionId,
  });

  @override
  State<SynchronizedPrayerSessionScreen> createState() =>
      _SynchronizedPrayerSessionScreenState();
}

class _SynchronizedPrayerSessionScreenState
    extends State<SynchronizedPrayerSessionScreen> {
  SynchronizedPrayerSessionProvider? _sessionProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
 

  bool _isInitialized = false;
  bool _showPrayerSelection = true;
  bool _showSurahSelection = false;
  String? _selectedPrayerName;
  String? _selectedSessionId;
  String? _rakaat1Surah;
  String? _rakaat2Surah;
  int? _lastAutoStartedVerseIndex;
  bool _isAutoStarting = false; 
    Timer? _autoStartDebounce;

    late PostureMonitoringService _postureMonitor;
  PostureAlert? _currentAlert;
  bool _isMonitoring = false;
  bool _useWidgetRecording = true; 


  // bool _isMonitoring = false;
  Timer? _postureCheckTimer;
  PostureDetectionResult? _currentPosture;
  DateTime? _lastAlertTime;
  static const Duration alertCooldown = Duration(seconds: 5);
  static const double activeThreshold = 15.0;
  static const double balanceTolerance = 0.30; // 30%

  // Cooldown to prevent alert spam
  // DateTime? _lastAlertTime;
  // static const Duration alertCooldown = Duration(seconds: 5);

   Map<String, double> _sensorValues = {
    'head': 0.0,
    'left_hand': 0.0,
    'right_hand': 0.0,
    'left_knee': 0.0,
    'right_knee': 0.0,
    'left_foot': 0.0,
    'right_foot': 0.0,
  };

  // Posture history for analysis
  List<PostureDetectionResult> _postureHistory = [];

  

  int _failedRecordingAttempts = 0;
  static const int MAX_FAILED_ATTEMPTS = 2;

  int _rakaat1FatihahEndIndex = 0;  // Index where Al-Fatihah ends in Rakaat 1
  int _rakaat2FatihahEndIndex = 0;  // Index where Al-Fatihah ends in Rakaat 2


  // Stream subscriptions for sensor data (if using streams)
  StreamSubscription<double>? _leftKneeSub;
  StreamSubscription<double>? _rightKneeSub;
  StreamSubscription<double>? _leftFootSub;
  StreamSubscription<double>? _rightFootSub;
  StreamSubscription<double>? _leftHandSub;
  StreamSubscription<double>? _rightHandSub;
  StreamSubscription<double>? _headSub;

  // Prayer times data
  final List<Map<String, dynamic>> _prayerTimes = [
    {
      'name': 'Fajr',
      'arabicName': 'الفجر',
      'icon': Icons.wb_twilight,
      'color': const Color(0xFF6366F1),
      'description': 'Dawn Prayer',
      'estimatedDuration': const Duration(minutes: 15),
    },
    {
      'name': 'Dhuhr',
      'arabicName': 'الظهر',
      'icon': Icons.wb_sunny,
      'color': const Color(0xFFF59E0B),
      'description': 'Midday Prayer',
      'estimatedDuration': const Duration(minutes: 20),
    },
    {
      'name': 'Asr',
      'arabicName': 'العصر',
      'icon': Icons.wb_sunny_outlined,
      'color': const Color(0xFFEF4444),
      'description': 'Afternoon Prayer',
      'estimatedDuration': const Duration(minutes: 18),
    },
    {
      'name': 'Maghrib',
      'arabicName': 'المغرب',
      'icon': Icons.wb_twilight,
      'color': const Color(0xFFEC4899),
      'description': 'Sunset Prayer',
      'estimatedDuration': const Duration(minutes: 12),
    },
    {
      'name': 'Isha',
      'arabicName': 'العشاء',
      'icon': Icons.brightness_2,
      'color': const Color(0xFF8B5CF6),
      'description': 'Night Prayer',
      'estimatedDuration': const Duration(minutes: 22),
    },
  ];

  @override
void initState() {
  super.initState();

  _initializePostureMonitor();
  
  // Initialize the session provider FIRST
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _sessionProvider = context.read<SynchronizedPrayerSessionProvider>();
      
      // Check if prayer was already selected
      if (widget.prayerName != null && widget.sessionId != null) {
        _selectedPrayerName = widget.prayerName;
        _selectedSessionId = widget.sessionId;
        _showPrayerSelection = false;
        
        // Initialize session (which will also init camera)
        _initializeSession();
      } else {
        _showPrayerSelection = true;
      }
    }
  });
}

Future<void> _initializeSession() async {
    if (_selectedPrayerName == null) {
    debugPrint('❌ Cannot initialize: No prayer selected');
    return;
  }
    
    try {
      _selectedSessionId = widget.sessionId ??
          '${_selectedPrayerName}_${DateTime.now().millisecondsSinceEpoch}';
      
      int rakaat1SurahNum = int.tryParse(_rakaat1Surah!) ?? 112;
      int rakaat2SurahNum = int.tryParse(_rakaat2Surah ?? '112') ?? 112;
      
      final poseProvider = context.read<RoboflowPrayerPoseProvider>();
      if (!poseProvider.isCameraInitialized) {
        await poseProvider.initializeCamera();
      }
      
      await _sessionProvider!.initializeSession(
        prayerName: _selectedPrayerName!,
        sessionId: _selectedSessionId!,
        rakaat1Surah: rakaat1SurahNum,
        rakaat2Surah: rakaat2SurahNum,
      );
      
      _setupPoseListener();
      await _startPostureMonitoring();
      
      setState(() {
        _isInitialized = true;
      });
      
      debugPrint('✅ Session initialization complete');
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      if (mounted) {
        _showNotification('Initialization failed: $e', Colors.red);
      }
    }
  }

  void _setupPoseListener() {
    final poseProvider = context.read<RoboflowPrayerPoseProvider>();
    
    if (_sessionProvider == null) return;
    
    poseProvider.addListener(() {
      if (mounted && poseProvider.currentPose != null) {
        _sessionProvider!.updatePoseWithCorrection(poseProvider.currentPose!);
      }
    });
  }

  void _initializePostureMonitor() {
    _postureMonitor = PostureMonitoringService(
      onPostureAlert: _handlePostureAlert,
      checkInterval: const Duration(milliseconds: 500),
    );
  }

  void _handlePostureAlert(PostureAlert alert) {
    final now = DateTime.now();
    
    // Check cooldown to prevent alert spam
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < alertCooldown) {
      return;
    }
    
    setState(() {
      _currentAlert = alert;
      _lastAlertTime = now;
    });

    Future.delayed(_getAlertDuration(alert.severity), () {
      if (mounted && _currentAlert == alert) {
        setState(() {
          _currentAlert = null;
        });
      }
    });
  }

   Duration _getAlertDuration(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return const Duration(seconds: 3);
      case AlertSeverity.medium:
        return const Duration(seconds: 5);
      case AlertSeverity.high:
        return const Duration(seconds: 7);
    }
  }

  void _initializePostureMonitoring() {
    debugPrint('🎯 Initializing posture monitoring system');
  }

  Future<void> _startPostureMonitoring() async {
    if (_isMonitoring) return;
    
    debugPrint('🚀 Starting FSR posture monitoring...');
    
    try {
      final sensorManager = SensorManager.instance;
      await sensorManager.startMonitoring();
      
      setState(() {
        _isMonitoring = true;
      });
      
      // Subscribe to all sensor streams
      _subscribeToSensorStreams();
      
      // Start periodic posture checking (every 500ms)
      _postureCheckTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _checkPosture(),
      );
      
      _showNotification(
        '✅ Posture monitoring activated',
        Colors.green,
      );
      
      debugPrint('✅ Posture monitoring started');
    } catch (e) {
      debugPrint('❌ Error starting posture monitoring: $e');
      _showNotification(
        'Failed to start posture monitoring',
        Colors.red,
      );
    }
  }




  void _stopPostureMonitoring() {
    if (!_isMonitoring) return;
    
    debugPrint('🛑 Stopping posture monitoring...');
    
    _postureCheckTimer?.cancel();
    _cancelSensorSubscriptions();
    
    setState(() {
      _isMonitoring = false;
      _currentPosture = null;
    });
    
    debugPrint('✅ Posture monitoring stopped');
  }

  void _subscribeToSensorStreams() {
    final sensorManager = SensorManager.instance;
    
    _headSub = sensorManager.headPressureStream.listen((p) {
      _sensorValues['head'] = p;
    });
    
    _leftHandSub = sensorManager.leftHandPressureStream.listen((p) {
      _sensorValues['left_hand'] = p;
    });
    
    _rightHandSub = sensorManager.rightHandPressureStream.listen((p) {
      _sensorValues['right_hand'] = p;
    });
    
    _leftKneeSub = sensorManager.leftKneePressureStream.listen((p) {
      _sensorValues['left_knee'] = p;
    });
    
    _rightKneeSub = sensorManager.rightKneePressureStream.listen((p) {
      _sensorValues['right_knee'] = p;
    });
    
    _leftFootSub = sensorManager.leftFootPressureStream.listen((p) {
      _sensorValues['left_foot'] = p;
    });
    
    _rightFootSub = sensorManager.rightFootPressureStream.listen((p) {
      _sensorValues['right_foot'] = p;
    });
  }

  void _cancelSensorSubscriptions() {
    _headSub?.cancel();
    _leftHandSub?.cancel();
    _rightHandSub?.cancel();
    _leftKneeSub?.cancel();
    _rightKneeSub?.cancel();
    _leftFootSub?.cancel();
    _rightFootSub?.cancel();
  }

   void _checkPosture() {
    final result = _detectPosture();
    
    if (result == null) return;
    
    // Check cooldown
    final now = DateTime.now();
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < alertCooldown) {
      return;
    }
    
    setState(() {
      _currentPosture = result;
    });
    
    // Add to history
    _postureHistory.add(result);
    
    // Save to provider
    // _sessionProvider?.recordPostureDetection(result);
    
    // Show notification
    _showPostureNotification(result);
    
    _lastAlertTime = now;
  }

   PostureDetectionResult? _detectPosture() {
    // Check which sensors are active
    final head = _sensorValues['head']! > activeThreshold;
    final leftHand = _sensorValues['left_hand']! > activeThreshold;
    final rightHand = _sensorValues['right_hand']! > activeThreshold;
    final leftKnee = _sensorValues['left_knee']! > activeThreshold;
    final rightKnee = _sensorValues['right_knee']! > activeThreshold;
    final leftFoot = _sensorValues['left_foot']! > activeThreshold;
    final rightFoot = _sensorValues['right_foot']! > activeThreshold;
    
    final hands = leftHand && rightHand;
    final knees = leftKnee && rightKnee;
    final feet = leftFoot && rightFoot;
    
    PrayerPosture posture = PrayerPosture.unknown;
    
    // Detect posture based on sensor combinations
    if (hands && knees && feet && head) {
      posture = PrayerPosture.sujud; // Prostration
    } else if (knees && feet && !hands && !head) {
      posture = PrayerPosture.tahiyat; // Sitting
    } else if (feet && !hands && !knees && !head) {
      posture = PrayerPosture.qiyam; // Standing
    } else if (hands && feet && !head) {
      posture = PrayerPosture.ruku; // Bowing
    }
    
    if (posture == PrayerPosture.unknown) return null;
    
    // Check balance
    final balanceIssues = _checkBalance();
    final corrections = _generateCorrections(posture, balanceIssues);
    
    // Determine if posture is correct
    final isCorrect = balanceIssues.isEmpty && corrections.isEmpty;
    
    // Calculate confidence based on sensor readings
    final confidence = _calculateConfidence(posture);
    
    return PostureDetectionResult(
      posture: posture,
      isCorrect: isCorrect,
      confidence: confidence,
      sensorReadings: Map.from(_sensorValues),
      corrections: corrections,
      balanceIssues: balanceIssues,
      timestamp: DateTime.now(),
    );
  }

   Map<String, double> _checkBalance() {
    final balanceIssues = <String, double>{};
    
    // Check hand balance
    final handImbalance = _calculateImbalance(
      _sensorValues['left_hand']!,
      _sensorValues['right_hand']!,
    );
    if (handImbalance > balanceTolerance) {
      balanceIssues['hands'] = handImbalance;
    }
    
    // Check knee balance
    final kneeImbalance = _calculateImbalance(
      _sensorValues['left_knee']!,
      _sensorValues['right_knee']!,
    );
    if (kneeImbalance > balanceTolerance) {
      balanceIssues['knees'] = kneeImbalance;
    }
    
    // Check foot balance
    final footImbalance = _calculateImbalance(
      _sensorValues['left_foot']!,
      _sensorValues['right_foot']!,
    );
    if (footImbalance > balanceTolerance) {
      balanceIssues['feet'] = footImbalance;
    }
    
    return balanceIssues;
  }

  double _calculateImbalance(double left, double right) {
    if (left < activeThreshold && right < activeThreshold) return 0.0;
    
    final diff = (left - right).abs();
    final avg = (left + right) / 2;
    
    return avg > 0 ? diff / avg : 0.0;
  }

  List<String> _generateCorrections(
    PrayerPosture posture,
    Map<String, double> balanceIssues,
  ) {
    final corrections = <String>[];
    
    balanceIssues.forEach((bodyPart, imbalance) {
      final percentage = (imbalance * 100).toInt();
      final leftValue = _sensorValues['left_$bodyPart'] ?? 0.0;
      final rightValue = _sensorValues['right_$bodyPart'] ?? 0.0;
      
      final weaker = leftValue < rightValue ? 'left' : 'right';
      corrections.add(
        'Shift weight to $weaker $bodyPart ($percentage% imbalance)',
      );
    });
    
    // Check for low pressure on expected sensors
    switch (posture) {
      case PrayerPosture.sujud:
        if (_sensorValues['head']! < activeThreshold) {
          corrections.add('Lower forehead to mat');
        }
        break;
      case PrayerPosture.ruku:
        if (_sensorValues['left_hand']! < activeThreshold ||
            _sensorValues['right_hand']! < activeThreshold) {
          corrections.add('Place hands firmly on knees');
        }
        break;
      default:
        break;
    }
    
    return corrections;
  }


  double _calculateConfidence(PrayerPosture posture) {
    int activeCount = 0;
    int expectedCount = 0;
    
    switch (posture) {
      case PrayerPosture.sujud:
        expectedCount = 7; // All sensors
        break;
      case PrayerPosture.tahiyat:
        expectedCount = 4; // Knees + feet
        break;
      case PrayerPosture.qiyam:
        expectedCount = 2; // Feet only
        break;
      case PrayerPosture.ruku:
        expectedCount = 4; // Hands + feet
        break;
      case PrayerPosture.unknown:
        return 0.0;
    }
    
    _sensorValues.forEach((key, value) {
      if (value > activeThreshold) activeCount++;
    });
    
    return (activeCount / expectedCount).clamp(0.0, 1.0);
  }

  void _showPostureNotification(PostureDetectionResult result) {
    Color color;
    IconData icon;
    String title;
    
    if (result.isCorrect) {
      color = Colors.green;
      icon = Icons.check_circle;
      title = '✅ ${_getPostureName(result.posture)} - Correct';
    } else {
      color = Colors.orange;
      icon = Icons.warning;
      title = '⚠️ ${_getPostureName(result.posture)} - Needs correction';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (result.corrections.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...result.corrections.map((c) => Text('• $c')),
            ],
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getPostureName(PrayerPosture posture) {
    switch (posture) {
      case PrayerPosture.qiyam:
        return 'Qiyam (Standing)';
      case PrayerPosture.ruku:
        return 'Ruku (Bowing)';
      case PrayerPosture.sujud:
        return 'Sujud (Prostration)';
      case PrayerPosture.tahiyat:
        return 'Tahiyat (Sitting)';
      case PrayerPosture.unknown:
        return 'Unknown Posture';
    }
  }


  Widget _buildPostureNotificationBanner() {
  if (_currentPosture == null) return const SizedBox.shrink();
  
  final result = _currentPosture!;
  
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: result.isCorrect 
          ? Colors.green.shade700 
          : Colors.orange.shade700,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: (result.isCorrect ? Colors.green : Colors.orange)
              .withOpacity(0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 2,
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                result.isCorrect ? Icons.check_circle : Icons.warning,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPostureName(result.posture),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Confidence: ${(result.confidence * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                result.isCorrect ? 'CORRECT' : 'ADJUST',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        
        // Balance issues
        if (result.balanceIssues.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.balance, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Balance Issues:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...result.balanceIssues.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.arrow_right,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_formatBodyPart(entry.key)}: ${(entry.value * 100).toInt()}% imbalance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
        
        // Corrections
        if (result.corrections.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Corrections:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...result.corrections.map((correction) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.arrow_right,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            correction,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

String _formatBodyPart(String bodyPart) {
  return bodyPart.split('_').map((word) => 
    word[0].toUpperCase() + word.substring(1)
  ).join(' ');
}




  void _subscribeToSensorData() {
  debugPrint('📡 Subscribing to sensor data streams...');
  
  final sensorManager = SensorManager.instance;
  
  // Subscribe to left knee pressure
  _leftKneeSub = sensorManager.leftKneePressureStream.listen((pressure) {
    _postureMonitor.updateSensorReading('left_knee', pressure);
    debugPrint('Left Knee: $pressure');
  });
  
  // Subscribe to right knee pressure
  _rightKneeSub = sensorManager.rightKneePressureStream.listen((pressure) {
    _postureMonitor.updateSensorReading('right_knee', pressure);
    debugPrint('Right Knee: $pressure');
  });
  
  // Subscribe to left foot pressure
  _leftFootSub = sensorManager.leftFootPressureStream.listen((pressure) {
    _postureMonitor.updateSensorReading('left_foot', pressure);
    debugPrint('Left Foot: $pressure');
  });
  
  // Subscribe to right foot pressure
  _rightFootSub = sensorManager.rightFootPressureStream.listen((pressure) {
    _postureMonitor.updateSensorReading('right_foot', pressure);
    debugPrint('Right Foot: $pressure');
  });
  
  // Subscribe to left hand pressure
  _leftHandSub = sensorManager.leftHandPressureStream.listen((pressure) {
    _postureMonitor.updateSensorReading('left_hand', pressure);
    debugPrint('Left Hand: $pressure');
  });
  
  // Subscribe to right hand pressure
  _rightHandSub = sensorManager.rightHandPressureStream.listen((pressure) {
    _postureMonitor.updateSensorReading('right_hand', pressure);
    debugPrint('Right Hand: $pressure');
  });
  
  // Subscribe to head pressure (optional, if you're using this sensor)
  _headSub = sensorManager.headPressureStream.listen((pressure) {
    // You can use this for Sujood (prostration) detection
    debugPrint('Head: $pressure');
  });
  
  debugPrint('✅ Successfully subscribed to all sensor data streams');
}

// void _cancelSensorSubscriptions() {
//   debugPrint('🛑 Cancelling sensor subscriptions...');
  
//   _leftKneeSub?.cancel();
//   _rightKneeSub?.cancel();
//   _leftFootSub?.cancel();
//   _rightFootSub?.cancel();
//   _leftHandSub?.cancel();
//   _rightHandSub?.cancel();
//   _headSub?.cancel();
  
//   _leftKneeSub = null;
//   _rightKneeSub = null;
//   _leftFootSub = null;
//   _rightFootSub = null;
//   _leftHandSub = null;
//   _rightHandSub = null;
//   _headSub = null;
  
//   debugPrint('✅ All sensor subscriptions cancelled');
// }

void _subscribeSensorData() {
    // This is where you connect to your sensor streams from sensor_screen.dart
    // Example assuming you have a SensorManager or similar:
    
    
    // Subscribe to each sensor's pressure stream
    SensorManager.instance.leftKneePressureStream.listen((pressure) {
      _postureMonitor.updateSensorReading('left_knee', pressure);
    });
    
    SensorManager.instance.rightKneePressureStream.listen((pressure) {
      _postureMonitor.updateSensorReading('right_knee', pressure);
    });
    
    SensorManager.instance.leftFootPressureStream.listen((pressure) {
      _postureMonitor.updateSensorReading('left_foot', pressure);
    });
    
    SensorManager.instance.rightFootPressureStream.listen((pressure) {
      _postureMonitor.updateSensorReading('right_foot', pressure);
    });
    
    SensorManager.instance.leftHandPressureStream.listen((pressure) {
      _postureMonitor.updateSensorReading('left_hand', pressure);
    });
    
    SensorManager.instance.rightHandPressureStream.listen((pressure) {
      _postureMonitor.updateSensorReading('right_hand', pressure);
    });
    
  }

  Future<void> _checkSensorConnectivity() async {
  final sensorManager = SensorManager.instance;
  
  if (!sensorManager.isInitialized || !sensorManager.isMonitoring) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sensors Not Connected'),
        content: const Text(
          'Please ensure your sensors are connected to Firebase.\n\n'
          'Check that:\n'
          '• Arduino is powered on\n'
          '• WiFi connection is active\n'
          '• Firebase database is accessible'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await sensorManager.startMonitoring();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attempting to reconnect to sensors...'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to connect: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showSessionSummaryDialog(
  SynchronizedPrayerSessionProvider provider,
  Map<String, dynamic> recitationStats,
) async {
  // Calculate scores
  final overallRecitationScore = (recitationStats['averageAccuracy'] as double) * 100;
  final hasRecitationData = (recitationStats['totalAttempts'] as int) > 0;
  
  // Calculate pose score (if pose data exists)
  final totalPoseDetections = provider.poseRecords.length;
  final correctPoses = provider.poseRecords.where((r) => r.isCorrect).length;
  final poseScore = totalPoseDetections > 0 
      ? (correctPoses / totalPoseDetections * 100) 
      : 0.0;
  
  // Calculate overall score (50% recitation + 50% pose)
  final overallScore = hasRecitationData
      ? (overallRecitationScore * 0.5) + (poseScore * 0.5)
      : poseScore;
  
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Prayer Session Complete!',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade900],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Overall Performance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${overallScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getScoreLabel(overallScore),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Recitation Section (if data exists)
            if (hasRecitationData) ...[
              _buildScoreSection(
                title: 'Quranic Recitation',
                icon: Icons.menu_book,
                color: Colors.blue,
                score: overallRecitationScore,
                details: [
                  _buildStatRow(
                    'Verses Attempted',
                    '${recitationStats['totalVersesAttempted']}/${recitationStats['totalVersesAvailable']}',
                  ),
                  _buildStatRow(
                    'Success Rate',
                    '${recitationStats['successRate'].toStringAsFixed(1)}%',
                  ),
                  _buildStatRow(
                    'Total Attempts',
                    '${recitationStats['totalAttempts']}',
                  ),
                  _buildStatRow(
                    'Successful',
                    '${recitationStats['successfulRecitations']}',
                  ),
                  if (recitationStats['improvementCount'] > 0)
                    _buildStatRow(
                      'Verses Improved',
                      '${recitationStats['improvementCount']}',
                      icon: Icons.trending_up,
                      iconColor: Colors.green,
                    ),
                ],
              ),
              
              // Best/Worst Verses
              if (recitationStats['bestVerse'] != null) ...[
                const SizedBox(height: 12),
                _buildVerseHighlight(
                  'Best Performance',
                  recitationStats['bestVerse']['accuracy'] * 100,
                  'Verse ${recitationStats['bestVerse']['index'] + 1}',
                  Colors.green,
                ),
              ],
              
              if (recitationStats['worstVerse'] != null &&
                  recitationStats['worstVerse']['accuracy'] < 0.7) ...[
                const SizedBox(height: 8),
                _buildVerseHighlight(
                  'Needs Practice',
                  recitationStats['worstVerse']['accuracy'] * 100,
                  'Verse ${recitationStats['worstVerse']['index'] + 1}',
                  Colors.orange,
                ),
              ],
              
              const SizedBox(height: 20),
            ],
            
            // Pose Section (if data exists)
            if (totalPoseDetections > 0) ...[
              _buildScoreSection(
                title: 'Prayer Posture',
                icon: Icons.accessibility_new,
                color: Colors.purple,
                score: poseScore,
                details: [
                  _buildStatRow('Total Detections', '$totalPoseDetections'),
                  _buildStatRow('Correct Poses', '$correctPoses'),
                  _buildStatRow(
                    'Accuracy',
                    '${poseScore.toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            // Session Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    'Duration',
                    provider.formattedElapsedTime,
                    icon: Icons.timer,
                  ),
                  _buildStatRow(
                    'Prayer',
                    _selectedPrayerName ?? 'Unknown',
                    icon: Icons.mosque,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.go('/prayer_history');
          },
          icon: const Icon(Icons.history),
          label: const Text('View History'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.go('/home');
          },
          icon: const Icon(Icons.check),
          label: const Text('Done'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    ),
  );
}


String _getScoreLabel(double score) {
  if (score >= 90) return 'Excellent! ⭐⭐⭐⭐⭐';
  if (score >= 80) return 'Very Good! ⭐⭐⭐⭐';
  if (score >= 70) return 'Good ⭐⭐⭐';
  if (score >= 60) return 'Fair ⭐⭐';
  return 'Keep Practicing! ⭐';
}

Widget _buildScoreSection({
  required String title,
  required IconData icon,
  required Color color,
  required double score,
  required List<Widget> details,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${score.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        ...details,
      ],
    ),
  );
}

Widget _buildStatRow(
  String label,
  String value, {
  IconData? icon,
  Color? iconColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: iconColor ?? Colors.grey),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildVerseHighlight(
  String title,
  double score,
  String verse,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(
          score >= 70 ? Icons.star : Icons.flag,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                verse,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Text(
          '${score.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}






// =============================================================================
// FIX for synchronized_prayer_session_screen.dart
// =============================================================================

// STEP 1: CHANGE the _sessionProvider declaration from 'late' to nullable
// FIND this line (around line 50-60):
// late SynchronizedPrayerSessionProvider _sessionProvider;

// REPLACE WITH:
// SynchronizedPrayerSessionProvider? _sessionProvider;


// STEP 2: UPDATE initState method
// FIND the initState method and REPLACE it with:
// @override
// void initState() {
//   super.initState();

//   _initializePostureMonitor();
  
//   // Initialize the session provider FIRST
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     if (mounted) {
//       _sessionProvider = context.read<SynchronizedPrayerSessionProvider>();
      
//       // Check if prayer was already selected
//       if (widget.prayerName != null && widget.sessionId != null) {
//         _selectedPrayerName = widget.prayerName;
//         _selectedSessionId = widget.sessionId;
//         _showPrayerSelection = false;
        
//         // Initialize session (which will also init camera)
//         _initializeSession();
//       } else {
//         _showPrayerSelection = true;
//       }
//     }
//   });
// }





// STEP 4: UPDATE all places where _sessionProvider is used
// Add null checks where _sessionProvider is accessed

// EXAMPLE - Update _setupPoseListener:
// void _setupPoseListener() {
//   if (_sessionProvider == null) {
//     debugPrint('⚠️ Session provider not initialized yet');
//     return;
//   }
  
//   final poseProvider = context.read<RoboflowPrayerPoseProvider>();
  
//   // Add listener to update session provider when pose changes
//   poseProvider.addListener(() {
//     if (mounted && poseProvider.currentPose != null && _sessionProvider != null) {
//       _sessionProvider!.updatePoseWithCorrection(poseProvider.currentPose!);
//     }
//   });
// }


// STEP 5: UPDATE _buildPrayerSessionScreen method
// Add a safety check at the beginning:
// 



// STEP 6: UPDATE the _onStartPrayerSession method in Surah selection
// FIND this method and UPDATE it:
void _onStartPrayerSession() async {
  if (_rakaat1Surah == null || _rakaat2Surah == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select Surahs for both Rakaats'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  setState(() {
    _showSurahSelection = false;
    _showPrayerSelection = false;
  });
  
  // Initialize provider if not already done
  if (_sessionProvider == null) {
    _sessionProvider = context.read<SynchronizedPrayerSessionProvider>();
  }
  
  // Now initialize the session
  await _initializeSession();
}





  // int? _lastAutoStartedVerseIndex;

// bool _isAutoStarting = false; // Add this flag at class level

// Timer? _autoStartDebounce;



void _onVerseChanged(int newVerseIndex) async {
  if (_lastAutoStartedVerseIndex == newVerseIndex) {
    debugPrint('⏭️ Already handled verse $newVerseIndex');
    return; // Already handled this verse
  }
  
  _lastAutoStartedVerseIndex = newVerseIndex;
  
  debugPrint('📖 Verse changed to ${newVerseIndex + 1}');
  
  final provider = context.read<SynchronizedPrayerSessionProvider>();
  
  // Force reset recording state first
  debugPrint('🔄 Force resetting before auto-start...');
  await provider.forceResetRecording();
  
  // Wait for UI to settle
  await Future.delayed(const Duration(milliseconds: 2000));
  
  if (!mounted) {
    debugPrint('❌ Widget unmounted, aborting auto-start');
    return;
  }
  
  // Double-check conditions
  if (!provider.isRecording && 
      !provider.isListeningToSpeech &&
      provider.currentVerse != null) {
    
    debugPrint('🎤 Auto-starting recording for verse ${newVerseIndex + 1}');
    await provider.startRecording();
  } else {
    debugPrint('❌ Cannot auto-start:');
    debugPrint('   - isRecording: ${provider.isRecording}');
    debugPrint('   - isListening: ${provider.isListeningToSpeech}');
    debugPrint('   - hasVerse: ${provider.currentVerse != null}');
  }
}

 @override
Widget build(BuildContext context) {
  // Show prayer selection screen if no prayer selected
  if (_showPrayerSelection) {
    return _buildPrayerSelectionScreen(); // ✅ FIXED
  }

  // Show Surah selection screen after prayer selection
  if (_showSurahSelection) {
    return _buildSurahSelectionScreen();
  }

  // Show loading while initializing
  if (!_isInitialized) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // Show main prayer session with posture overlay
  return Stack(
    children: [
      _buildPrayerSessionScreen(),
      // Posture notification overlay
      // if (_currentPosture != null)
      //   Positioned(
      //     top: 0,
      //     left: 0,
      //     right: 0,
      //     child: SafeArea(
      //       child: _buildPostureNotificationBanner(),
      //     ),
      //   ),
    ],
  );
}

    // ============ SURAH SELECTION SCREEN ============
  Widget _buildSurahSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade900, Colors.teal.shade700],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showSurahSelection = false;
                            _showPrayerSelection = true;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Surahs for $_selectedPrayerName',
                              style: GoogleFonts.lato(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Choose Surahs to recite after Al-Fatiha',
                              style: GoogleFonts.lato(
                                color: Colors.white70,
                                fontSize:14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Surah selection widget
            Expanded(
              child: _buildSurahSelectionWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahSelectionWidget() {
    // Popular Surahs for prayer
    final List<Map<String, dynamic>> popularSurahs = [
      {
        'name': 'Al-Ikhlas',
        'arabicName': 'الإخلاص',
        'number': 112,
        'verses': 4,
        'meaning': 'The Sincerity',
        'color': const Color(0xFF6366F1),
      },
      {
        'name': 'Al-Falaq',
        'arabicName': 'الفلق',
        'number': 113,
        'verses': 5,
        'meaning': 'The Daybreak',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'name': 'An-Nas',
        'arabicName': 'الناس',
        'number': 114,
        'verses': 6,
        'meaning': 'Mankind',
        'color': const Color(0xFFEC4899),
      },
      {
        'name': 'Al-Kafirun',
        'arabicName': 'الكافرون',
        'number': 109,
        'verses': 6,
        'meaning': 'The Disbelievers',
        'color': const Color(0xFFF59E0B),
      },
      {
        'name': 'Al-Kawthar',
        'arabicName': 'الكوثر',
        'number': 108,
        'verses': 3,
        'meaning': 'The Abundance',
        'color': const Color(0xFF10B981),
      },
      {
        'name': 'Al-Asr',
        'arabicName': 'العصر',
        'number': 103,
        'verses': 3,
        'meaning': 'The Time',
        'color': const Color(0xFF3B82F6),
      },
      {
        'name': 'An-Nasr',
        'arabicName': 'النصر',
        'number': 110,
        'verses': 3,
        'meaning': 'The Help',
        'color': const Color(0xFF06B6D4),
      },
    ];

    return Column(
      children: [
        // Rakaat 1 Selection
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade700, Colors.teal.shade600],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.looks_one, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'First Rakaat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_rakaat1Surah != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _rakaat1Surah!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: popularSurahs.map((surah) {
                      return _buildSurahCard(
                        surah: surah,
                        isSelected: _rakaat1Surah == surah['name'],
                        onTap: () {
                          setState(() {
                            _rakaat1Surah = surah['name'];
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Rakaat 2 Selection
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade600],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.looks_two, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Second Rakaat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_rakaat2Surah != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _rakaat2Surah!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: popularSurahs.map((surah) {
                      return _buildSurahCard(
                        surah: surah,
                        isSelected: _rakaat2Surah == surah['name'],
                        onTap: () {
                          setState(() {
                            _rakaat2Surah = surah['name'];
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Start Prayer Button
        Container(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _rakaat1Surah != null && _rakaat2Surah != null
                ? () async {
                    await _startPrayerWithSurahs();
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Prayer Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              minimumSize: const Size(double.infinity, 50),
              disabledBackgroundColor: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
  

  

 Widget _buildSurahCard({
    required Map<String, dynamic> surah,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? surah['color'] : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [
                      surah['color'].withOpacity(0.3),
                      surah['color'].withOpacity(0.1),
                    ]
                  : [
                      Colors.grey.shade800,
                      Colors.grey.shade900,
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Surah number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surah['color'].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${surah['number']}',
                    style: TextStyle(
                      color: surah['color'],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Surah info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          surah['arabicName'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          ' • ${surah['verses']} verses',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: surah['color'],
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

   Future<void> _startPrayerWithSurahs() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Starting prayer session...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Update session document with selected Surahs
      await _firestore.collection('prayer_sessions').doc(_selectedSessionId).update({
        'rakaat1Surah': _rakaat1Surah,
        'rakaat2Surah': _rakaat2Surah,
        'surahsSelected': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        
        // Update state to show session
        setState(() {
          _showSurahSelection = false;
        });
        
        // Initialize session
        await _initializeSession();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prayer started: Rakaat 1 - $_rakaat1Surah, Rakaat 2 - $_rakaat2Surah'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting prayer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
   }

  // ============ PRAYER SELECTION SCREEN ============
  Widget _buildPrayerSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade900, Colors.indigo.shade700],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => context.go('/home'),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Prayer Time',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Choose which prayer you want to perform',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Prayer time cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _prayerTimes.length,
                itemBuilder: (context, index) {
                  final prayer = _prayerTimes[index];
                  return _buildPrayerTimeCard(prayer);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimeCard(Map<String, dynamic> prayer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _selectPrayerTime(prayer),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                prayer['color'].withOpacity(0.7),
                prayer['color'].withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  prayer['icon'],
                  color: Colors.white,
                  size: 32,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Prayer info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      prayer['arabicName'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prayer['description'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPrayerTime(Map<String, dynamic> prayer) async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Preparing ${prayer['name']} prayer...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Generate session ID
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Save prayer selection to Firebase
      final prayerSelectionData = {
        'userId': _auth.currentUser!.uid,
        'userEmail': _auth.currentUser!.email,
        'prayerName': prayer['name'],
        'prayerArabicName': prayer['arabicName'],
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'sessionId': sessionId,
        'status': 'selected',
      };

      await _firestore
          .collection('prayer_selections')
          .add(prayerSelectionData);

      // Create initial session document
      await _firestore.collection('prayer_sessions').doc(sessionId).set({
        'userId': _auth.currentUser!.uid,
        'userEmail': _auth.currentUser!.email,
        'prayerName': prayer['name'],
        'sessionId': sessionId,
        'startTime': FieldValue.serverTimestamp(),
        'status': 'active',
        'sensorConfig': {
          'enableCamera': true,
          'enableAudio': true,
          'enableSensors': true,
          'realTimeAnalysis': true,
        },
      });

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Update state to show Surah selection
        setState(() {
          _selectedPrayerName = prayer['name'];
          _selectedSessionId = sessionId;
          _showPrayerSelection = false;
          _showSurahSelection = true; // Show Surah selection next
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${prayer['name']} prayer selected. Now choose Surahs for each Rakaat.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting prayer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  

  Widget _buildSensorStatusIndicator() {
  final sensorManager = SensorManager.instance;
  
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: sensorManager.isMonitoring 
          ? Colors.green.withOpacity(0.2) 
          : Colors.grey.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: sensorManager.isMonitoring ? Colors.green : Colors.grey,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          sensorManager.isMonitoring 
              ? Icons.sensors 
              : Icons.sensors_off,
          size: 16,
          color: sensorManager.isMonitoring ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          sensorManager.isMonitoring ? 'Sensors Active' : 'Sensors Inactive',
          style: TextStyle(
            fontSize: 12,
            color: sensorManager.isMonitoring ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

  // ============ MAIN PRAYER SESSION SCREEN ============
  Widget _buildPrayerSessionScreen() {

    if (_sessionProvider == null) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

    return WillPopScope(
      onWillPop: () async {
        final shouldEnd = await _showEndSessionDialog();
        return shouldEnd ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<SynchronizedPrayerSessionProvider>(
          builder: (context, provider, child) {
            return Stack(
              children: [
                // Main content area
                Column(
                  children: [
                    // Top bar with session info
                    _buildTopBar(provider),
                    
                    // Main split view
                    Expanded(
                      child: Row(
                        children: [
                          // Left side: Camera pose detection
                          Expanded(
                            flex: 3,
                            child: _buildCameraSection(provider),
                          ),
                          
                          // Right side: Quran verses and audio
                          Expanded(
                            flex: 2,
                            child: _buildQuranSection(provider),
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom controls
                    _buildBottomControls(provider),
                  ],
                ),
                
                // Overlay indicators
                if (provider.isRecording)
                  Positioned(
                    top: 100,
                    right: 20,
                    child: _buildRecordingIndicator(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(SynchronizedPrayerSessionProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Prayer name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedPrayerName ?? 'Prayer Session',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    ),
                ),
                Row(
                  children: [
                    Text(
                      'Session ID: ${_selectedSessionId?.substring(0, 8) ?? 'N/A'}...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ADD SENSOR STATUS HERE
                    _buildSensorStatusIndicator(),
                  ],
                ),
              ],
            ),
          ),
            
            // Session timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    provider.formattedElapsedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Close button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () async {
                final shouldEnd = await _showEndSessionDialog();
                if (shouldEnd == true && mounted) {
                  await _endSession();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

Widget _buildCameraSection(SynchronizedPrayerSessionProvider provider) {
  return Consumer<RoboflowPrayerPoseProvider>(
    builder: (context, poseProvider, child) {
      // debugPrint('📸 Camera section rebuild:');
      // debugPrint('  - Initialized: ${poseProvider.isCameraInitialized}');
      // debugPrint('  - Controller: ${poseProvider.cameraController != null}');
      // debugPrint('  - Error: ${poseProvider.error}');
      
      // Error state
      if (poseProvider.error != null) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Camera Error',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    poseProvider.error!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    debugPrint('🔄 Retrying camera initialization...');
                    await poseProvider.initializeCamera();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      // Loading state
      if (!poseProvider.isCameraInitialized) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Initializing camera...',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    debugPrint('🔄 Manual camera initialization...');
                    await poseProvider.initializeCamera();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Retry Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      // Success - show camera preview
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            if (kIsWeb)
              Center(child: poseProvider.buildCameraPreview())
            else if (poseProvider.cameraController != null && 
                     poseProvider.cameraController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CameraPreview(poseProvider.cameraController!),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Camera not ready',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            
            // Pose detection indicator
            if (poseProvider.currentPose != null)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pose: ${poseProvider.currentPose?.label ?? "Unknown"}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Confidence: ${((poseProvider.currentPose?.confidence ?? 0) * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _buildPostureAlertCard(PostureAlert alert) {
  Color alertColor;
  IconData alertIcon;
  String message;
  
  switch (alert.severity) {
    case AlertSeverity.low:
      alertColor = Colors.blue;
      alertIcon = Icons.info_outline;
      message = 'Minor posture adjustment suggested';
      break;
    case AlertSeverity.medium:
      alertColor = Colors.orange;
      alertIcon = Icons.warning_amber;
      message = 'Please correct your posture';
      break;
    case AlertSeverity.high:
      alertColor = Colors.red;
      alertIcon = Icons.error_outline;
      message = 'Significant posture imbalance detected!';
      break;
  }
  
  return Card(
    color: alertColor.withOpacity(0.95),
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(alertIcon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper method to format sensor names nicely
String _formatSensorName(String sensor) {
  return sensor
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}


  Widget _buildEnhancedCameraHeader(SynchronizedPrayerSessionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade900.withOpacity(0.7),
            Colors.blue.shade800.withOpacity(0.5),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt, 
              color: Colors.white, 
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Posture Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  provider.currentPose != null 
                      ? 'Analyzing pose...' 
                      : 'Position yourself in view',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          if (provider.currentPose != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: provider.isPoseCorrect ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (provider.isPoseCorrect ? Colors.green : Colors.orange)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.isPoseCorrect ? Icons.check_circle : Icons.warning_amber,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.currentPose?.label ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoboflowCameraView(SynchronizedPrayerSessionProvider provider) {
    return Consumer<RoboflowPrayerPoseProvider>(
      builder: (context, poseProvider, _) {
        // Only show debug output when there's an error or initialization issue
        if (poseProvider.error != null || !poseProvider.isCameraInitialized) {
          debugPrint('🎥 Camera State:');
          debugPrint('  - Initialized: ${poseProvider.isCameraInitialized}');
          debugPrint('  - Has controller: ${poseProvider.cameraController != null}');
          debugPrint('  - Controller initialized: ${poseProvider.cameraController?.value.isInitialized ?? false}');
          debugPrint('  - Error: ${poseProvider.error}');
        }
        
        if (poseProvider.error != null) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Error',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      poseProvider.error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      debugPrint('🔄 Retrying camera initialization...');
                      await poseProvider.initializeCamera();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!poseProvider.isCameraInitialized) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
                  const SizedBox(height: 16),
                  const Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      debugPrint('🔄 Manual camera initialization...');
                      await poseProvider.initializeCamera();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Initialize Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (kIsWeb)
                Center(
                  child: poseProvider.buildCameraPreview(),
                )
              else if (poseProvider.cameraController != null && 
                       poseProvider.cameraController!.value.isInitialized)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CameraPreview(poseProvider.cameraController!),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera not ready',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          debugPrint('🔄 Reinitializing camera...');
                          await poseProvider.initializeCamera();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (poseProvider.isProcessing)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Analyzing...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              if (!poseProvider.isDetecting)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Detection paused - Tap Play to start',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedPoseFeedback(SynchronizedPrayerSessionProvider provider) {
    if (provider.currentPose == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withOpacity(0.5),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              color: Colors.white.withOpacity(0.5),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Waiting for pose detection...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: provider.isPoseCorrect
              ? [Colors.green.shade700, Colors.green.shade900]
              : [Colors.orange.shade700, Colors.orange.shade900],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: (provider.isPoseCorrect ? Colors.green : Colors.orange)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  provider.isPoseCorrect 
                      ? Icons.check_circle 
                      : Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.isPoseCorrect 
                          ? 'Perfect Posture!' 
                          : 'Needs Adjustment',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.poseFeedback,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              Column(
                children: [
                  Text(
                    '${(provider.poseConfidence * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    'Confidence',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: provider.poseConfidence,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          
          if (!provider.isPoseCorrect && provider.primaryCorrection != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.primaryCorrection!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (provider.correctionSteps.isNotEmpty)
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.7),
                      size: 14,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectionOverlay(SynchronizedPrayerSessionProvider provider) {
    return Positioned(
      top: 70,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.orange.withOpacity(0.95),
        elevation: 12,
        shadowColor: Colors.orange.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_fix_high,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Correction Guide',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => provider.toggleVisualGuide(),
                    tooltip: 'Hide guide',
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(color: Colors.white54, thickness: 1),
              const SizedBox(height: 12),
              
              if (provider.primaryCorrection != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    provider.primaryCorrection!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              
              if (provider.correctionSteps.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Steps to correct:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...provider.correctionSteps.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuranSection(SynchronizedPrayerSessionProvider provider) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Quran header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade900.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.book, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Quranic Recitation',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  'Verse ${provider.currentVerseIndex + 1}/${provider.totalVerses}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Verse display - FIXED
          Expanded(
            child: provider.verses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.teal),
                        SizedBox(height: 16),
                        Text(
                          'Loading verses...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : QuranVerseDisplayWidget(
                    currentVerseIndex: provider.currentVerseIndex,
                    verses: provider.verses,
                    isHighlighted: provider.isRecitationActive,
                    showNavigation: true,
                    onPrevious: provider.canGoPrevious 
                        ? () => provider.previousVerse()
                        : null,
                    onNext: provider.canGoNext
                        ? () => provider.nextVerse()
                        : null,
                  ),
          ),
          
          // Audio section with auto-advance
          Container(
            padding: const EdgeInsets.all(16),
            child: AudioRecorderWidget(
              sessionId: _selectedSessionId ?? '',
              currentVerse: provider.currentVerse,
              isRecording: provider.isRecording,
              pronunciationService: provider.pronunciationService!,
              onRecordingStateChanged: (isRecording) {
                debugPrint('📱 Screen: Recording state changed to $isRecording');
                provider.setRecording(isRecording);
              },
              onAccuracyCalculated: (accuracy, recognizedText) {
                debugPrint('📱 Screen: Accuracy callback received: ${(accuracy * 100).toInt()}%');
                provider.updateRecitationAccuracy(accuracy, recognizedText);
              },
              onHighAccuracyAchieved: () {
                debugPrint('📱 Screen: onHighAccuracyAchieved callback triggered!');
                
                if (provider.canGoNext) {
                  debugPrint('🎉 Auto-advancing to next verse');
                  
                  final nextIndex = provider.currentVerseIndex + 1;
                  provider.nextVerse();
                  
                  // Auto-start recording for new verse
                  _onVerseChanged(nextIndex);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Excellent! Verse ${provider.currentVerseIndex + 1}/${provider.totalVerses}'),
                        backgroundColor: Colors.green,
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          
          // Recitation feedback with immediate auto-advance indicator
          if (provider.lastRecitationAccuracy != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: provider.lastRecitationAccuracy! >= 0.50
                      ? [Colors.green.shade700, Colors.green.shade900]
                      : provider.lastRecitationAccuracy! >= 0.30
                          ? [Colors.teal.shade700, Colors.teal.shade900]
                          : [Colors.orange.shade700, Colors.orange.shade900],
                ),
                boxShadow: provider.lastRecitationAccuracy! >= 0.50
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    provider.lastRecitationAccuracy! >= 0.50
                        ? Icons.auto_awesome
                        : provider.lastRecitationAccuracy! >= 0.30
                            ? Icons.check_circle
                            : Icons.info,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Accuracy: ${(provider.lastRecitationAccuracy! * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (provider.lastRecitationAccuracy! >= 0.50) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'EXCELLENT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.lastRecitationAccuracy! >= 0.50
                              ? '✨ Moving to next verse...'
                              : provider.lastRecitationAccuracy! >= 0.30
                                  ? 'Good job! Tap Next to continue'
                                  : 'Try again to improve accuracy',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (provider.lastRecitationAccuracy! >= 0.50)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(SynchronizedPrayerSessionProvider provider) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade900,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Start/Stop Detection
            _buildControlButton(
              icon: context.watch<RoboflowPrayerPoseProvider>().isDetecting 
                  ? Icons.stop 
                  : Icons.play_arrow,
              label: context.watch<RoboflowPrayerPoseProvider>().isDetecting 
                  ? 'Stop' 
                  : 'Start',
              onPressed: () async {
                final poseProvider = context.read<RoboflowPrayerPoseProvider>();
                if (poseProvider.isDetecting) {
                  await poseProvider.stopDetection();
                } else {
                  await poseProvider.startDetection();
                }
              },
              color: context.watch<RoboflowPrayerPoseProvider>().isDetecting 
                  ? Colors.red 
                  : Colors.green,
            ),
            
            const SizedBox(width: 8),
            
            // Previous verse
            _buildControlButton(
              icon: Icons.skip_previous,
              label: 'Previous',
              onPressed: provider.canGoPrevious
                  ? () {
                      provider.previousVerse();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Verse ${provider.currentVerseIndex + 1}/${provider.totalVerses}'
                          ),
                          duration: const Duration(seconds: 1),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  : null,
            ),
            
            const SizedBox(width: 8),
            
            // Play/Pause audio
            _buildControlButton(
              icon: provider.isAudioPlaying ? Icons.pause : Icons.play_arrow,
              label: provider.isAudioPlaying ? 'Pause' : 'Play',
              onPressed: () {
                provider.toggleAudioPlayback();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.isAudioPlaying ? 'Playing audio...' : 'Audio paused'
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              color: Colors.blue,
            ),
            
            const SizedBox(width: 8),
            
            // Record button
            _buildRecordButton(provider),
            
            const SizedBox(width: 8),
            
            // Next verse
            _buildControlButton(
              icon: Icons.skip_next,
              label: 'Next',
              onPressed: provider.canGoNext
                  ? () {
                      provider.nextVerse();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Verse ${provider.currentVerseIndex + 1}/${provider.totalVerses}'
                          ),
                          duration: const Duration(seconds: 1),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  : null,
            ),
            
            const SizedBox(width: 8),
            
            // End session
            _buildControlButton(
              icon: Icons.stop_circle,
              label: 'End',
              onPressed: () async {
                final shouldEnd = await _showEndSessionDialog();
                if (shouldEnd == true) {
                  await _endSession();
                }
              },
              color: Colors.red.shade700,
            ),

            const SizedBox(width: 8),

            // ✅ SENSOR TOGGLE BUTTON - ADD HERE!
            _buildControlButton(
              icon: _isMonitoring ? Icons.sensors : Icons.sensors_off,
              label: _isMonitoring ? 'Sensors On' : 'Sensors Off',
              onPressed: () {
                if (_isMonitoring) {
                  _stopPostureMonitoring();
                } else {
                  _startPostureMonitoring();
                }
              },
              color: _isMonitoring ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildControlButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.grey.shade700,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            disabledBackgroundColor: Colors.grey.shade800,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: onPressed == null ? Colors.grey : Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }


  // UPDATED: Record button with fallback handling
  Widget _buildRecordButton(SynchronizedPrayerSessionProvider provider) {
    // If in fallback mode, show different buttons
    if (provider.fallbackMode == 'manual') {
      return _buildControlButton(
        icon: Icons.keyboard,
        label: 'Manual',
        onPressed: () => _showManualEntryDialog(provider),
        color: Colors.blue,
      );
    } else if (provider.fallbackMode == 'skip') {
      return _buildControlButton(
        icon: Icons.skip_next,
        label: 'Skip',
        onPressed: () async {
          provider.skipCurrentVerse();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Skipped to verse ${provider.currentVerseIndex + 1}/${provider.totalVerses}'
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        color: Colors.orange,
      );
    }

    // Normal record button
    return _buildControlButton(
      icon: provider.isRecording ? Icons.stop : Icons.mic,
      label: provider.isRecording ? 'Stop' : 'Record',
      onPressed: _isAutoStarting
          ? null
          : () async {
              if (provider.isRecording) {
                // Stop recording
                debugPrint('🛑 Manual stop requested');
                await provider.stopRecording();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recording stopped'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                // Check if verse is available
                if (provider.currentVerse == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please wait for verse to load'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                // Start recording manually
                debugPrint('🎤 Manual start requested (Attempt ${_failedRecordingAttempts + 1})');
                await provider.startRecording();
                
                // Wait a moment to check if recording actually started
                await Future.delayed(const Duration(milliseconds: 500));
                
                // Check if recording failed
                if (!provider.isRecording && !provider.isListeningToSpeech) {
                  _failedRecordingAttempts++;
                  debugPrint('❌ Recording failed (Attempt $_failedRecordingAttempts/$MAX_FAILED_ATTEMPTS)');
                  
                  if (_failedRecordingAttempts >= MAX_FAILED_ATTEMPTS) {
                    // Show fallback dialog after multiple failures
                    debugPrint('⚠️ Max attempts reached, showing fallback options');
                    _failedRecordingAttempts = 0; // Reset counter
                    
                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => SpeechRecognitionFallbackDialog(
                          onRetry: () async {
                            debugPrint('🔄 Retrying speech recognition...');
                            provider.resetToSpeechMode();
                            await Future.delayed(const Duration(milliseconds: 500));
                            await provider.startRecording();
                          },
                        ),
                      );
                    }
                  } else {
                    // Show retry message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to start recording. Attempt $_failedRecordingAttempts/$MAX_FAILED_ATTEMPTS',
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Retry',
                            textColor: Colors.white,
                            onPressed: () async {
                              await provider.startRecording();
                            },
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  // Recording started successfully
                  _failedRecordingAttempts = 0; // Reset counter
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Recording started... Recite the verse'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
      color: provider.isRecording ? Colors.red : Colors.green,
    );
  }

  // NEW: Manual entry dialog
  void _showManualEntryDialog(SynchronizedPrayerSessionProvider provider) {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: Colors.blue),
            SizedBox(width: 8),
            Text('Manual Entry'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Verse:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.currentVerse?.arabicText ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontFamily: 'Arabic',
                ),
                // textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Type what you recited:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'Enter Arabic text...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.edit),
              ),
              // textDirection: TextDirection.rtl,
              maxLines: 3,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final enteredText = textController.text.trim();
              if (enteredText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some text'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              await provider.processManualEntry(enteredText);
              Navigator.pop(dialogContext);
              
              // Show accuracy result
              final accuracy = provider.lastRecitationAccuracy ?? 0.0;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${provider.getPronunciationFeedback(accuracy)}\nAccuracy: ${(accuracy * 100).toInt()}%',
                    ),
                    backgroundColor: provider.getAccuracyColor(accuracy),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              
              // Auto-advance if meets threshold
              if (provider.meetsAccuracyThreshold(accuracy)) {
                await Future.delayed(const Duration(milliseconds: 500));
                if (provider.canGoNext) {
                  provider.nextVerse();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Excellent! Moving to verse ${provider.currentVerseIndex + 1}/${provider.totalVerses}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Check Accuracy'),
          ),
        ],
      ),
    );
  }

  



  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'RECORDING',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showEndSessionDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Prayer Session?'),
        content: const Text(
          'Are you sure you want to end this prayer session? '
          'All data will be saved to Firebase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }

 
Future<void> _endSession() async {
  if (_sessionProvider == null) {
    debugPrint('⚠️ Session provider is null');
    return;
  }
  
  final provider = _sessionProvider!;
  
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Saving session data...'),
            ],
          ),
        ),
      ),
    ),
  );
  
  try {
    // End the session and save all data
    await provider.endSession();
    
    if (!mounted) return;
    
    // Close loading dialog
    Navigator.pop(context);
    
    // Get session statistics before showing summary
    final recitationStats = provider.getRecitationStatistics();
    final hasRecitationData = (recitationStats['totalAttempts'] as int) > 0;
    
    // Show session summary dialog
    await _showSessionSummaryDialog(provider, recitationStats);
    
  } catch (e) {
    debugPrint('❌ Error ending session: $e');
    
    if (mounted) {
      Navigator.pop(context); // Close loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving session: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}




  @override
void dispose() {
  // Reset auto-start flags
  _lastAutoStartedVerseIndex = null;
  _isAutoStarting = false;
  _autoStartDebounce?.cancel();
  
  // Stop posture monitoring
  _postureMonitor.stopMonitoring();
  if (_isMonitoring) {
    _stopPostureMonitoring();
  }
  
  // Cancel timers and subscriptions
  _postureCheckTimer?.cancel();
  _cancelSensorSubscriptions();
  
  // Call super last
  super.dispose();
}
}
