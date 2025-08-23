// widgets/pronunciation_practice_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:myapp/models/quran_verse.dart';
import 'package:myapp/services/pronunciation_service.dart';

/// Advanced pronunciation practice widget with detailed analytics
class PronunciationPracticeWidget extends StatefulWidget {
  final QuranVerse verse;
  final int verseIndex;
  final Function(PronunciationSession) onSessionComplete;
  final PronunciationService pronunciationService;

  const PronunciationPracticeWidget({
    Key? key,
    required this.verse,
    required this.verseIndex,
    required this.onSessionComplete,
    required this.pronunciationService,
  }) : super(key: key);

  @override
  State<PronunciationPracticeWidget> createState() => _PronunciationPracticeWidgetState();
}

class _PronunciationPracticeWidgetState extends State<PronunciationPracticeWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;
  
  PronunciationSession? _currentSession;
  Timer? _practiceTimer;
  Timer? _listeningTimeoutTimer;
  
  bool _isSessionActive = false;
  bool _showDetailedFeedback = false;
  double _currentSoundLevel = 0.0;
  List<String> _practiceHistory = [];
  bool _isInitialized = false;
  String? _initializationError;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializePracticeSession();
    _initializePronunciationService();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticInOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializePracticeSession() {
    _currentSession = PronunciationSession(
      verseIndex: widget.verseIndex,
      arabicText: widget.verse.arabicText,
      startTime: DateTime.now(),
    );
  }

  Future<void> _initializePronunciationService() async {
    try {
      final initialized = await widget.pronunciationService.initialize();
      setState(() {
        _isInitialized = initialized;
        if (!initialized) {
          _initializationError = 'Failed to initialize speech recognition. Please check microphone permissions.';
        }
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _initializationError = 'Error initializing pronunciation service: $e';
      });
    }
  }

  Future<void> _startPracticeSession() async {
    if (!_isInitialized) {
      await _initializePronunciationService();
      if (!_isInitialized) {
        _showInitializationError();
        return;
      }
    }

    setState(() {
      _isSessionActive = true;
      _showDetailedFeedback = false;
    });
    
    _pulseController.repeat(reverse: true);
    _progressController.forward();
    
    // Start listening with enhanced configuration
    await widget.pronunciationService.startListening(
      onResult: _handlePronunciationResult,
      onError: _handlePronunciationError,
      onSoundLevelChange: (level) {
        setState(() {
          _currentSoundLevel = level;
        });
      },
    );
    
    // Set practice timer (auto-stop after 2 minutes)
    _practiceTimer = Timer(const Duration(minutes: 2), () {
      _stopPracticeSession();
    });
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handlePronunciationResult(String recognizedText) {
    if (_currentSession == null || !_isSessionActive) return;
    
    setState(() {
      _practiceHistory.add(recognizedText);
      _currentSession!.addAttempt(recognizedText);
    });
    
    // Provide immediate audio feedback
    _playFeedbackSound(_currentSession!.getCurrentAccuracy() > 0.7);
    
    // Visual feedback animation
    _triggerFeedbackAnimation(_currentSession!.getCurrentAccuracy());
  }

  void _handlePronunciationError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('Recognition error: $error')),
          ],
        ),
        backgroundColor: Colors.orange.shade100,
        action: SnackBarAction(
          label: 'Retry',
          onPressed: _startPracticeSession,
        ),
      ),
    );
  }

  void _playFeedbackSound(bool isCorrect) {
    // Use the pronunciation service's feedback method
    widget.pronunciationService.playFeedbackSound(isCorrect);
  }

  void _triggerFeedbackAnimation(double accuracy) {
    if (accuracy > 0.8) {
      // Excellent - green pulse
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    } else if (accuracy > 0.6) {
      // Good - yellow flash
      _progressController.forward().then((_) {
        _progressController.reverse();
      });
    } else {
      // Needs improvement - gentle shake
      _pulseController.forward().then((_) {
        _pulseController.reverse();
      });
    }
  }

  void _stopPracticeSession() {
    setState(() {
      _isSessionActive = false;
      _showDetailedFeedback = true;
    });
    
    _pulseController.stop();
    _progressController.stop();
    _practiceTimer?.cancel();
    _listeningTimeoutTimer?.cancel();
    
    widget.pronunciationService.stopListening();
    
    if (_currentSession != null) {
      _currentSession!.endSession();
      widget.onSessionComplete(_currentSession!);
    }
    
    HapticFeedback.mediumImpact();
  }

  void _showInitializationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Access Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_initializationError ?? 'Unable to access microphone'),
            const SizedBox(height: 16),
            const Text('To practice pronunciation, please:'),
            const SizedBox(height: 8),
            const Text('• Grant microphone permission'),
            const Text('• Ensure microphone is working'),
            const Text('• Try restarting the app'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initializePronunciationService();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isSessionActive
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSessionActive ? Colors.green : Colors.blue,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isSessionActive ? Colors.green : Colors.blue).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPracticeHeader(),
          if (_isSessionActive) _buildActivePracticeContent(),
          if (_showDetailedFeedback) _buildDetailedFeedback(),
          _buildPracticeControls(),
        ],
      ),
    );
  }

  Widget _buildPracticeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isSessionActive ? _pulseAnimation.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSessionActive ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isSessionActive ? Icons.mic : Icons.school,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSessionActive ? 'Practice Active' : 'Pronunciation Practice',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isSessionActive ? Colors.green.shade800 : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isSessionActive 
                      ? 'Listening for your pronunciation...'
                      : _isInitialized 
                          ? 'Tap to start practicing this verse'
                          : 'Initializing...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (_currentSession != null && _isSessionActive)
            _buildAccuracyIndicator(),
        ],
      ),
    );
  }

  Widget _buildAccuracyIndicator() {
    final accuracy = _currentSession!.getCurrentAccuracy();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getAccuracyColor(accuracy).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getAccuracyColor(accuracy),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getAccuracyIcon(accuracy),
            size: 16,
            color: _getAccuracyColor(accuracy),
          ),
          const SizedBox(width: 4),
          Text(
            '${(accuracy * 100).toInt()}%',
            style: TextStyle(
              color: _getAccuracyColor(accuracy),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePracticeContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Sound level visualizer
          _buildSoundLevelVisualizer(),
          const SizedBox(height: 16),
          
          // Real-time pronunciation feedback
          if (_currentSession != null && _currentSession!.attempts.isNotEmpty)
            _buildRealTimeFeedback(),
          
          // Practice tips
          _buildPracticeTips(),
        ],
      ),
    );
  }

  Widget _buildSoundLevelVisualizer() {
    return Container(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(20, (index) {
          final isActive = index < (_currentSoundLevel * 20).toInt();
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 4,
            height: isActive ? 40 + (index * 1.0) : 10,
            decoration: BoxDecoration(
              color: isActive
                  ? _getSoundLevelColor(index / 20)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Color _getSoundLevelColor(double level) {
    if (level < 0.3) return Colors.green;
    if (level < 0.7) return Colors.orange;
    return Colors.red;
  }

  Widget _buildRealTimeFeedback() {
    final latestAttempt = _currentSession!.attempts.last;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                latestAttempt.accuracy > 0.7 ? Icons.check_circle : Icons.error,
                color: latestAttempt.accuracy > 0.7 ? Colors.green : Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Latest attempt: ${(latestAttempt.accuracy * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recognized: ${latestAttempt.recognizedText}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeTips() {
    final tips = [
      'Speak clearly and at moderate pace',
      'Position microphone 6-8 inches from mouth',
      'Practice in a quiet environment',
      'Focus on one word at a time',
    ];
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Text(
                'Practice Tips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: Colors.blue.shade700)),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildDetailedFeedback() {
    if (_currentSession == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Results',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Overall stats
          _buildSessionStats(),
          const SizedBox(height: 16),
          
          // Attempt history
          _buildAttemptHistory(),
          const SizedBox(height: 16),
          
          // Improvement suggestions
          _buildImprovementSuggestions(),
        ],
      ),
    );
  }

  Widget _buildSessionStats() {
    final session = _currentSession!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.indigo.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Attempts',
                '${session.attempts.length}',
                Icons.repeat,
                Colors.blue,
              ),
              _buildStatItem(
                'Duration',
                '${session.getDuration().inSeconds}s',
                Icons.timer,
                Colors.green,
              ),
              _buildStatItem(
                'Best Score',
                '${(session.getBestAccuracy() * 100).toInt()}%',
                Icons.star,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: session.getCurrentAccuracy(),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getAccuracyColor(session.getCurrentAccuracy()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall Accuracy: ${(session.getCurrentAccuracy() * 100).toInt()}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAttemptHistory() {
    final attempts = _currentSession!.attempts;
    if (attempts.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attempt History',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: attempts.length,
            itemBuilder: (context, index) {
              final attempt = attempts[index];
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _getAccuracyColor(attempt.accuracy).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getAccuracyColor(attempt.accuracy),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(attempt.accuracy * 100).toInt()}%',
                      style: TextStyle(
                        color: _getAccuracyColor(attempt.accuracy),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      _getAccuracyIcon(attempt.accuracy),
                      color: _getAccuracyColor(attempt.accuracy),
                      size: 16,
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

  Widget _buildImprovementSuggestions() {
    final accuracy = _currentSession!.getCurrentAccuracy();
    List<String> suggestions = [];
    
    if (accuracy < 0.5) {
      suggestions.addAll([
        'Try speaking more slowly and clearly',
        'Practice individual words first',
        'Ensure you\'re in a quiet environment',
        'Check microphone positioning',
      ]);
    } else if (accuracy < 0.7) {
      suggestions.addAll([
        'Focus on correct pronunciation of difficult words',
        'Practice connecting words smoothly',
        'Work on consistent speech pace',
      ]);
    } else if (accuracy < 0.9) {
      suggestions.addAll([
        'Fine-tune pronunciation of specific sounds',
        'Practice with longer phrases',
        'Focus on intonation and rhythm',
      ]);
    } else {
      suggestions.addAll([
        'Excellent pronunciation! Keep practicing',
        'Try more challenging verses',
        'Help others with their pronunciation',
      ]);
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: Colors.amber.shade700, size: 16),
              const SizedBox(width: 8),
              Text(
                'Improvement Suggestions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...suggestions.take(3).map((suggestion) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡 ', style: TextStyle(color: Colors.amber.shade700)),
                Expanded(
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade600,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildPracticeControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isInitialized 
                  ? (_isSessionActive ? _stopPracticeSession : _startPracticeSession)
                  : null,
              icon: Icon(_isSessionActive ? Icons.stop : Icons.play_arrow),
              label: Text(_isSessionActive ? 'Stop Practice' : 'Start Practice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSessionActive ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => widget.pronunciationService.speakArabicText(widget.verse.arabicText),
            icon: const Icon(Icons.volume_up),
            tooltip: 'Hear Pronunciation',
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue.shade100,
              foregroundColor: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _showPracticeSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Practice Settings',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _showPracticeSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PracticeSettingsSheet(),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.9) return Colors.green;
    if (accuracy >= 0.7) return Colors.orange;
    if (accuracy >= 0.5) return Colors.amber;
    return Colors.red;
  }

  IconData _getAccuracyIcon(double accuracy) {
    if (accuracy >= 0.9) return Icons.star;
    if (accuracy >= 0.7) return Icons.thumb_up;
    if (accuracy >= 0.5) return Icons.trending_up;
    return Icons.trending_down;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _practiceTimer?.cancel();
    _listeningTimeoutTimer?.cancel();
    super.dispose();
  }
}

/// Practice settings bottom sheet
class PracticeSettingsSheet extends StatefulWidget {
  @override
  State<PracticeSettingsSheet> createState() => _PracticeSettingsSheetState();
}

class _PracticeSettingsSheetState extends State<PracticeSettingsSheet> {
  double _sensitivityLevel = 0.7;
  bool _enableHapticFeedback = true;
  bool _enableSoundFeedback = true;
  double _speechRate = 0.5;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practice Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Sensitivity slider
          Text('Recognition Sensitivity', style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: _sensitivityLevel,
            onChanged: (value) => setState(() => _sensitivityLevel = value),
            min: 0.3,
            max: 1.0,
            divisions: 7,
            label: '${(_sensitivityLevel * 100).toInt()}%',
          ),
          
          // Speech rate slider
          Text('TTS Speech Rate', style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: _speechRate,
            onChanged: (value) => setState(() => _speechRate = value),
            min: 0.3,
            max: 1.0,
            divisions: 7,
            label: '${(_speechRate * 100).toInt()}%',
          ),
          
          // Toggle switches
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibrate on correct pronunciation'),
            value: _enableHapticFeedback,
            onChanged: (value) => setState(() => _enableHapticFeedback = value),
          ),
          
          SwitchListTile(
            title: const Text('Sound Feedback'),
            subtitle: const Text('Play sounds for pronunciation feedback'),
            value: _enableSoundFeedback,
            onChanged: (value) => setState(() => _enableSoundFeedback = value),
          ),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Save settings (you could use SharedPreferences here)
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}