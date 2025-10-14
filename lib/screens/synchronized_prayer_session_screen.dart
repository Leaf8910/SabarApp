
                // lib/screens/synchronized_prayer_session_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/synchronized_prayer_session_provider.dart';
import '../providers/roboflow_prayer_pose_provider.dart';
import '../widgets/pose_camera_widget.dart';
import '../widgets/quran_verse_display_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import 'package:camera/camera.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb;

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
  late SynchronizedPrayerSessionProvider _sessionProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isInitialized = false;
  bool _showPrayerSelection = true;
  bool _showSurahSelection = false;
  String? _selectedPrayerName;
  String? _selectedSessionId;
  String? _rakaat1Surah;
  String? _rakaat2Surah;

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
    
    // Check if prayer was already selected
    if (widget.prayerName != null && widget.sessionId != null) {
      _selectedPrayerName = widget.prayerName;
      _selectedSessionId = widget.sessionId;
      _showPrayerSelection = false;
      
      // Initialize session (which will also init camera)
      _initializeSession();
    } else {
      // Show prayer selection first - no camera initialization needed yet
      _showPrayerSelection = true;
    }
  }

  Future<void> _initializeSession() async {
    _sessionProvider = context.read<SynchronizedPrayerSessionProvider>();
    
    // Initialize camera FIRST
    final poseProvider = context.read<RoboflowPrayerPoseProvider>();
    if (!poseProvider.isCameraInitialized) {
      await poseProvider.initializeCamera();
    }
    
    // Then initialize session
    await _sessionProvider.initializeSession(
      sessionId: _selectedSessionId!,
      prayerName: _selectedPrayerName!,
    );

    // Setup pose listener after both are ready
    _setupPoseListener();

    setState(() => _isInitialized = true);
  }

  void _setupPoseListener() {
    final sessionProvider = context.read<SynchronizedPrayerSessionProvider>();
    final poseProvider = context.read<RoboflowPrayerPoseProvider>();
    
    // Add listener to update session provider when pose changes
    poseProvider.addListener(() {
      if (mounted && poseProvider.currentPose != null) {
        sessionProvider.updatePoseWithCorrection(poseProvider.currentPose!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show prayer selection screen if no prayer selected
    if (_showPrayerSelection) {
      return _buildPrayerSelectionScreen();
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

    // Show main prayer session
    return _buildPrayerSessionScreen();
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Choose Surahs to recite after Al-Fatiha',
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
                      Colors.grey.shade800,
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
                        onPressed: () => context.go('/sensors'),
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

  // ============ MAIN PRAYER SESSION SCREEN ============
  Widget _buildPrayerSessionScreen() {
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
                  Text(
                    'Session ID: ${_selectedSessionId?.substring(0, 8) ?? 'N/A'}...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
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
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _buildEnhancedCameraHeader(provider),
              Expanded(
                child: _buildRoboflowCameraView(provider),
              ),
              _buildEnhancedPoseFeedback(provider),
            ],
          ),
          
          if (provider.showVisualGuide && 
              provider.primaryCorrection != null && 
              !provider.isPoseCorrect)
            _buildCorrectionOverlay(provider),
        ],
      ),
    );
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
                    provider.currentPose ?? 'Unknown',
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
                
                // Auto-advance to next verse when high accuracy achieved
                if (provider.canGoNext) {
                  debugPrint('🎉 Auto-advancing to next verse immediately');
                  debugPrint('📊 Current verse: ${provider.currentVerseIndex + 1}/${provider.totalVerses}');
                  
                  // Move to next verse immediately
                  provider.nextVerse();
                  
                  debugPrint('✅ Moved to verse: ${provider.currentVerseIndex + 1}/${provider.totalVerses}');
                  
                  // Show brief success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Excellent! Verse ${provider.currentVerseIndex}/${provider.totalVerses}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(milliseconds: 1500),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                } else {
                  // Completed all verses
                  debugPrint('🎊 All verses completed!');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.celebration, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'All Verses Completed!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Excellent recitation!',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                  colors: provider.lastRecitationAccuracy! >= 0.85
                      ? [Colors.green.shade700, Colors.green.shade900]
                      : provider.lastRecitationAccuracy! >= 0.7
                          ? [Colors.teal.shade700, Colors.teal.shade900]
                          : [Colors.orange.shade700, Colors.orange.shade900],
                ),
                boxShadow: provider.lastRecitationAccuracy! >= 0.85
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
                    provider.lastRecitationAccuracy! >= 0.85
                        ? Icons.auto_awesome
                        : provider.lastRecitationAccuracy! >= 0.7
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
                            if (provider.lastRecitationAccuracy! >= 0.85) ...[
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
                          provider.lastRecitationAccuracy! >= 0.85
                              ? '✨ Moving to next verse...'
                              : provider.lastRecitationAccuracy! >= 0.7
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
                  if (provider.lastRecitationAccuracy! >= 0.85)
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
              
              // Record toggle - FIXED to prevent double starts
              _buildControlButton(
                icon: provider.isRecording ? Icons.stop : Icons.mic,
                label: provider.isRecording ? 'Stop' : 'Record',
                onPressed: provider.isListeningToSpeech 
                    ? null // Disable button while speech recognition is active
                    : () async {
                        if (provider.isRecording) {
                          // Stop recording
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
                          
                          // Start recording
                          await provider.startRecording();
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
                      },
                color: provider.isRecording ? Colors.red : Colors.green,
              ),
              
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
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
    final provider = context.read<SynchronizedPrayerSessionProvider>();
    
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
                Text('Saving session data...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      await provider.endSession();
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        // Show success and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prayer session saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        context.go('/sensors');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sessionProvider.dispose();
    super.dispose();
  }
}