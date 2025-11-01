// lib/screens/roboflow_prayer_pose_checker_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:sabar/screens/quran_verses_screen.dart';
import '../providers/roboflow_prayer_pose_provider.dart';
import '../models/prayer_pose.dart';

class RoboflowPrayerPoseCheckerScreen extends StatefulWidget {
  const RoboflowPrayerPoseCheckerScreen({Key? key}) : super(key: key);

  @override
  State<RoboflowPrayerPoseCheckerScreen> createState() => _RoboflowPrayerPoseCheckerScreenState();
}

class _RoboflowPrayerPoseCheckerScreenState extends State<RoboflowPrayerPoseCheckerScreen> 
    with WidgetsBindingObserver {
  bool _showInstructions = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<RoboflowPrayerPoseProvider>();
    
    switch (state) {
      case AppLifecycleState.paused:
        // App is in background
        provider.stopDetection();
        break;
      case AppLifecycleState.resumed:
        // App is back in foreground
        if (provider.isCameraInitialized && !provider.isDetecting) {
          // Optionally restart detection
          _reinitializeIfNeeded();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _reinitializeIfNeeded() async {
    final provider = context.read<RoboflowPrayerPoseProvider>();
    if (!provider.isCameraInitialized) {
      await _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return;
    
    setState(() {
      _isInitializing = true;
    });

    try {
      final provider = context.read<RoboflowPrayerPoseProvider>();
      await provider.initializeCamera();
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startDetection() async {
    setState(() {
      _showInstructions = false;
    });
    
    final provider = context.read<RoboflowPrayerPoseProvider>();
    
    if (!provider.isCameraInitialized) {
      await _initializeCamera();
    }
    
    if (provider.isCameraInitialized) {
      await provider.startDetection();
    }
  }

  Future<void> _stopDetection() async {
    final provider = context.read<RoboflowPrayerPoseProvider>();
    await provider.stopDetection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final provider = context.read<RoboflowPrayerPoseProvider>();
    provider.stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.self_improvement, size: 24),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prayer Pose Checker',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  kIsWeb ? 'Web Mode' : 'Mobile Mode',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeCamera,
            tooltip: 'Reinitialize Camera',
          ),
          IconButton(
            icon: Icon(Icons.book), // or Icons.menu_book for Quran
            tooltip: 'Quran Verses',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuranVersesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<RoboflowPrayerPoseProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              // Camera Preview
              _buildCameraPreview(provider),

              // Instructions Overlay
              if (_showInstructions && !provider.isDetecting)
                _buildInstructions(),

              // Pose Information Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildPoseInfoCard(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPreview(RoboflowPrayerPoseProvider provider) {
    if (_isInitializing || !provider.isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isInitializing) ...[
                const CircularProgressIndicator(
                  color: Colors.teal,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Initializing camera...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.videocam_off,
                  size: 64,
                  color: Colors.white54,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Camera not ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
              if (kIsWeb) ...[
                const SizedBox(height: 30),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '💡 Desktop/Web Camera Tips:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Allow camera access when prompted\n'
                        '• Close other apps using the camera\n'
                        '• Check browser camera permissions\n'
                        '• Try refreshing the page\n'
                        '• Ensure your camera is connected',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // TextButton.icon(
                      //   onPressed: () {
                      //     showDialog(
                      //       context: context,
                      //       builder: (context) => _buildTroubleshootingDialog(),
                      //     );
                      //   },
                      //   icon: const Icon(Icons.help_outline, color: Colors.teal),
                      //   label: const Text(
                      //     'Troubleshooting Guide',
                      //     style: TextStyle(color: Colors.teal),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview with proper aspect ratio
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: provider.cameraController!.value.aspectRatio,
              child: CameraPreview(provider.cameraController!),
            ),
          ),
        ),
        
        // Dark overlay gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        
        // Detection status indicator
        if (provider.isDetecting)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    kIsWeb ? 'Detecting (Web)' : 'Detecting (Live)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Processing indicator
        if (provider.isProcessing)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Analyzing pose...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Platform indicator
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  kIsWeb ? Icons.web : Icons.phone_android,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  kIsWeb ? 'Web Camera' : 'Mobile Camera',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.white.withOpacity(0.95),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.self_improvement,
                size: 64,
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
              const Text(
                'Prayer Pose Detection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                kIsWeb 
                    ? 'Position yourself in front of your webcam in a prayer pose. The AI will detect and guide you.'
                    : 'Position yourself in front of the camera in a prayer pose. The AI will detect and guide you in real-time.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startDetection,
                  icon: const Icon(Icons.play_arrow, size: 24),
                  label: const Text(
                    'Start Detection',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPoseInfoCard(RoboflowPrayerPoseProvider provider) {
    final pose = provider.currentPose;
    final detections = provider.detections;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isDetecting ? _stopDetection : _startDetection,
                    icon: Icon(
                      provider.isDetecting ? Icons.stop : Icons.play_arrow,
                      size: 24,
                    ),
                    label: Text(
                      provider.isDetecting ? 'Stop Detection' : 'Start Detection',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.isDetecting ? Colors.red : Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error message
            if (provider.error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Pose information
            if (pose != null) ...[
              _buildDetectedPoseInfo(pose),
              if (detections.isNotEmpty && detections.length > 1) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildDetectionsList(detections),
              ],
            ] else if (provider.isDetecting) ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.search, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'No pose detected',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Position yourself in a prayer pose',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Center(
                child: Text(
                  'Ready to detect prayer poses',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedPoseInfo(PrayerPose pose) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pose name with status
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pose.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pose.arabicName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: pose.isCorrect ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                pose.isCorrect ? 'Correct' : 'Needs Adjustment',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Confidence bar
        Text(
          'Confidence: ${(pose.confidence * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pose.confidence,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              pose.confidence > 0.7
                  ? Colors.green
                  : pose.confidence > 0.4
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          pose.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),

        // Correction guidance
        if (pose.correction != null && pose.correction!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pose.correction!,
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetectionsList(List<Map<String, dynamic>> detections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Detections (${detections.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: detections.length,
            itemBuilder: (context, index) {
              final detection = detections[index];
              final className = detection['class'] ?? 'Unknown';
              final confidence = (detection['confidence'] ?? 0.0).toDouble();
              
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      className,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(confidence * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: confidence,
                            minHeight: 4,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              confidence > 0.7
                                  ? Colors.green
                                  : confidence > 0.4
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}