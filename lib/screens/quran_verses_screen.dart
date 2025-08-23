// screens/quran_verses_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:go_router/go_router.dart';

// Import the models and services we created
import 'package:myapp/models/quran_verse.dart';
import 'package:myapp/services/pronunciation_service.dart';
import 'package:myapp/widgets/web_audio_player.dart';

class QuranVersesScreen extends StatefulWidget {
  const QuranVersesScreen({super.key});

  @override
  State<QuranVersesScreen> createState() => _QuranVersesScreenState();
}

class _QuranVersesScreenState extends State<QuranVersesScreen> {
  List<QuranVerse> _verses = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentSurah = 1; // Default to Al-Fatihah
  AudioPlayer? _audioPlayer;
  PronunciationService? _pronunciationService;
  int? _currentlyPlayingIndex;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Surah mapping for first few surahs as mentioned in documentation
  final Map<int, String> _surahNames = {
    1: 'Al-Fatihah',
    2: 'Al-Baqarah',
    3: 'Aal-E-Imran',
    4: 'An-Nisa',
    5: 'Al-Maidah',
    6: 'Al-Anam',
    7: 'Al-Araf',
    8: 'Al-Anfal',
    9: 'At-Tawbah',
    10: 'Yunus',
  };

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadSurahVerses(_currentSurah);
  }

  

  Future<void> _initializeServices() async {
    if (!kIsWeb) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onPositionChanged.listen((position) {
        setState(() => _currentPosition = position);
      });
      _audioPlayer!.onDurationChanged.listen((duration) {
        setState(() => _totalDuration = duration);
      });
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        setState(() => _isPlaying = state == PlayerState.playing);
      });
    }

    _pronunciationService = PronunciationService();
    await _pronunciationService!.initialize();
  }

  Future<void> _loadSurahVerses(int surahNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _verses.clear();
    });

    try {
      // First, try with just Arabic text to test API
      print('Loading Surah $surahNumber...');
      
      final response = await http.get(
        Uri.parse('https://api.alquran.cloud/v1/surah/$surahNumber'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body.substring(0, 200)}...'); // First 200 chars for debugging

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data['code'] == 200 && data['data'] != null) {
          await _parseSimpleApiResponse(data['data']);
        } else {
          throw Exception('Invalid API response: ${data['status'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to load Quran verses');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load verses: $e';
      });
      print('Error loading Surah verses: $e'); // Debug print
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  

  Future<void> _parseSimpleApiResponse(dynamic surahData) async {
    try {
      print('Parsing API response...');
      print('Surah data type: ${surahData.runtimeType}');
      
      // Convert to proper Map type
      final surahMap = Map<String, dynamic>.from(surahData as Map);
      
      final ayahs = surahMap['ayahs'];
      print('Ayahs type: ${ayahs.runtimeType}');
      print('Number of ayahs: ${(ayahs as List).length}');
      
      final ayahsList = List<Map<String, dynamic>>.from(
        (ayahs as List).map((ayah) => Map<String, dynamic>.from(ayah as Map))
      );
      
      List<QuranVerse> verses = [];

      for (int i = 0; i < ayahsList.length; i++) {
        final ayahData = ayahsList[i];
        
        // Create verse with basic data
        final verse = QuranVerse(
          number: _safeParseInt(ayahData['number']),
          numberInSurah: _safeParseInt(ayahData['numberInSurah']),
          arabicText: ayahData['text']?.toString() ?? '',
          englishTranslation: 'Translation will be loaded separately', // Placeholder
          audioUrl: _generateAudioUrl(surahMap['number'], ayahData['numberInSurah']),
          surahName: surahMap['englishName']?.toString() ?? 'Unknown',
          surahNameArabic: surahMap['name']?.toString() ?? '',
          surahNumber: _safeParseInt(surahMap['number']),
        );
        
        verses.add(verse);
      }

      print('Successfully parsed ${verses.length} verses');

      setState(() {
        _verses = verses;
      });
    } catch (e, stackTrace) {
      print('Error parsing API response: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to parse API response: $e');
    }
  }

  String _generateAudioUrl(dynamic surahNum, dynamic ayahNum) {
    final surahStr = _safeParseInt(surahNum).toString().padLeft(3, '0');
    final ayahStr = _safeParseInt(ayahNum).toString().padLeft(3, '0');
    return 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/$surahStr$ayahStr.mp3';
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _playAudio(int index) async {
    if (index >= _verses.length) return;

    final verse = _verses[index];
    
    try {
      if (kIsWeb) {
        setState(() {
          _currentlyPlayingIndex = index;
        });
      } else {
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
          
          setState(() {
            _currentlyPlayingIndex = index;
          });
          
          await _audioPlayer!.play(UrlSource(verse.audioUrl));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopAudio() async {
    if (kIsWeb) {
      setState(() {
        _currentlyPlayingIndex = null;
      });
    } else {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        setState(() {
          _currentlyPlayingIndex = null;
          _currentPosition = Duration.zero;
        });
      }
    }
  }

  void _debugPronunciationService() {
    print('=== Pronunciation Service Debug ===');
    print('Service exists: ${_pronunciationService != null}');
    if (_pronunciationService != null) {
      print('Is initialized: ${_pronunciationService!.isInitialized}');
      print('Is listening: ${_pronunciationService!.isListening}');
    }
    print('==================================');
  }

  void _startPronunciationPractice(int index) {
    _debugPronunciationService(); // Debug output
    
    if (index >= _verses.length || _pronunciationService == null) {
      print('ERROR: Invalid index or null pronunciation service');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPronunciationPracticeSheet(index),
    );
  }

  Widget _buildPronunciationPracticeSheet(int index) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.mic,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pronunciation Practice',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Arabic text being practiced
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_verses[index].surahName} - Verse ${_verses[index].numberInSurah}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _verses[index].arabicText,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 2.0,
                        fontFamily: 'Arabic',
                      ),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              
              // Practice interface
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: _buildSimplePracticeInterface(index),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimplePracticeInterface(int index) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isListening = _pronunciationService?.isListening ?? false;
        bool isInitialized = _pronunciationService?.isInitialized ?? false;
        
        // State variables for this practice session
        List<String> sessionAttempts = [];
        String? lastRecognizedText;
        double? lastAccuracy;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isListening
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isListening ? Colors.green : Colors.blue,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isListening ? Colors.green : Colors.blue).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Status indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isListening ? Colors.green : Colors.blue,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: isListening ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ] : null,
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                isListening 
                    ? 'Listening... Speak the verse clearly'
                    : isInitialized 
                        ? 'Ready to practice pronunciation'
                        : 'Initializing microphone...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isListening ? Colors.green.shade800 : Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              if (!isInitialized)
                Text(
                  'Please grant microphone permission when prompted',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              
              // Show last recognition result
              if (lastRecognizedText != null && lastAccuracy != null)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getAccuracyColor(lastAccuracy!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getAccuracyColor(lastAccuracy!)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getAccuracyIcon(lastAccuracy!),
                            color: _getAccuracyColor(lastAccuracy!),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Accuracy: ${(lastAccuracy! * 100).toInt()}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getAccuracyColor(lastAccuracy!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You said: "$lastRecognizedText"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFeedbackMessage(lastAccuracy!),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: _getAccuracyColor(lastAccuracy!),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Practice tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, 
                             color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Practice Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipRow('Speak clearly and at moderate pace'),
                    _buildTipRow('Hold device 6-8 inches from mouth'),
                    _buildTipRow('Practice in quiet environment'),
                    _buildTipRow('Focus on one word at a time'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Control buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isInitialized ? () async {
                        if (isListening) {
                          await _pronunciationService!.stopListening();
                          setState(() {});
                        } else {
                          try {
                            await _pronunciationService!.startListening(
                              onResult: (result) {
                                // Stop listening immediately after getting result
                                _pronunciationService!.stopListening();
                                
                                // Calculate accuracy
                                final accuracy = _pronunciationService!.calculateAccuracy(
                                  _verses[index].arabicText, 
                                  result
                                );
                                
                                // Update UI with results
                                setState(() {
                                  lastRecognizedText = result;
                                  lastAccuracy = accuracy;
                                  sessionAttempts.add(result);
                                });
                                
                                // Show single notification
                                _showPronunciationResult(result, accuracy);
                              },
                              onError: (error) {
                                // Stop listening on error
                                _pronunciationService!.stopListening();
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.warning, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('Error: $error')),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'Retry',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        _pronunciationService!.initialize();
                                      },
                                    ),
                                  ),
                                );
                                setState(() {});
                              },
                            );
                            setState(() {});
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to start listening: $e'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } : () async {
                        // Try to initialize
                        final initialized = await _pronunciationService!.initialize();
                        if (!initialized) {
                          _showInitializationError();
                        }
                        setState(() {});
                      },
                      icon: Icon(isListening ? Icons.stop : Icons.play_arrow),
                      label: Text(isListening ? 'Stop Practice' : 
                                 isInitialized ? 'Start Practice' : 'Initialize'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isListening ? Colors.red : 
                                       isInitialized ? Colors.green : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      try {
                        _pronunciationService!.speakArabicText(_verses[index].arabicText);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('TTS not available: $e'),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Hear Pronunciation',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Status information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildStatusRow('Microphone', isInitialized ? 'Ready' : 'Not Ready', 
                                   isInitialized ? Colors.green : Colors.red),
                    _buildStatusRow('Speech Recognition', isListening ? 'Active' : 'Inactive', 
                                   isListening ? Colors.green : Colors.grey),
                    _buildStatusRow('TTS', 'Available', Colors.blue),
                    if (sessionAttempts.isNotEmpty)
                      _buildStatusRow('Attempts', '${sessionAttempts.length}', Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPronunciationResult(String recognizedText, double accuracy) {
    // Remove any existing snackbars
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    
    final isGood = accuracy > 0.7;
    final color = isGood ? Colors.green : Colors.orange;
    final icon = isGood ? Icons.check_circle : Icons.info;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(accuracy * 100).toInt()}% Accuracy',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _getFeedbackMessage(accuracy),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Try Again',
          textColor: Colors.white,
          onPressed: () {
            // Ready for another attempt
          },
        ),
      ),
    );
  }

  String _getFeedbackMessage(double accuracy) {
    if (accuracy >= 0.9) return 'Excellent pronunciation! 🌟';
    if (accuracy >= 0.8) return 'Very good! Keep it up! 👍';
    if (accuracy >= 0.7) return 'Good pronunciation! 😊';
    if (accuracy >= 0.5) return 'Not bad, try speaking more clearly 🔄';
    if (accuracy >= 0.3) return 'Keep practicing, you\'re improving! 💪';
    return 'Try speaking slower and clearer 🎯';
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    if (accuracy >= 0.4) return Colors.amber;
    return Colors.red;
  }

  IconData _getAccuracyIcon(double accuracy) {
    if (accuracy >= 0.8) return Icons.star;
    if (accuracy >= 0.6) return Icons.thumb_up;
    if (accuracy >= 0.4) return Icons.trending_up;
    return Icons.trending_down;
  }

  Widget _buildTipRow(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.amber.shade700, fontSize: 16)),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 14,
                color: Colors.amber.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInitializationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Microphone Access Required'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To practice pronunciation, please:'),
            SizedBox(height: 12),
            Text('• Grant microphone permission'),
            Text('• Ensure microphone is working'),
            Text('• Check device settings'),
            Text('• Try restarting the app'),
            SizedBox(height: 12),
            Text(
              'Note: Speech recognition requires an active internet connection.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
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
              _pronunciationService!.initialize();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      ),
      title: Text('Quran Verses - ${_surahNames[_currentSurah] ?? 'Surah $_currentSurah'}'),
      actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Select Surah',
            onSelected: (surahNumber) {
              setState(() {
                _currentSurah = surahNumber;
              });
              _loadSurahVerses(surahNumber);
            },
            
            itemBuilder: (context) {
              return _surahNames.entries.map((entry) {
                return PopupMenuItem<int>(
                  value: entry.key,
                  child: Text('${entry.key}. ${entry.value}'),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSurahVerses(_currentSurah),
            tooltip: 'Refresh',
          ),
          
        ],
      ),
      body: _buildBody(),
    );
  }

  

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Quran verses...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Verses',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _loadSurahVerses(_currentSurah),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_verses.isEmpty) {
      return const Center(
        child: Text('No verses found.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _verses.length,
      itemBuilder: (context, index) {
        return _buildVerseCard(index);
      },
    );
  }

  Widget _buildVerseCard(int index) {
    final verse = _verses[index];
    final isCurrentlyPlaying = _currentlyPlayingIndex == index;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${verse.numberInSurah}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (isCurrentlyPlaying)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.volume_up,
                          size: 16,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Playing',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Arabic text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                verse.arabicText,
                style: const TextStyle(
                  fontSize: 24,
                  height: 2.0,
                  fontFamily: 'Arabic',
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),

            // English translation
            if (verse.englishTranslation.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  verse.englishTranslation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            const SizedBox(height: 16),

            // Audio player for web
            if (kIsWeb && isCurrentlyPlaying && verse.audioUrl.isNotEmpty)
              WebAudioPlayer(
                audioUrl: verse.audioUrl,
                onPlayStateChanged: (playing) {
                  setState(() => _isPlaying = playing);
                },
                onPositionChanged: (position) {
                  setState(() => _currentPosition = position);
                },
                onDurationChanged: (duration) {
                  setState(() => _totalDuration = duration);
                },
              ),

            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isCurrentlyPlaying
                      ? _stopAudio
                      : () => _playAudio(index),
                  icon: Icon(isCurrentlyPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(isCurrentlyPlaying ? 'Stop' : 'Play'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _startPronunciationPractice(index),
                  icon: const Icon(Icons.mic),
                  label: const Text('Practice'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    _shareVerse(verse);
                  },
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareVerse(QuranVerse verse) {
    final text = '''
${verse.surahName} (${verse.surahNameArabic}) - Verse ${verse.numberInSurah}

${verse.arabicText}

${verse.englishTranslation}

Shared from Islamic Prayer App
''';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Verse'),
        content: SingleChildScrollView(
          child: Text(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    _pronunciationService?.dispose();
    super.dispose();
  }
}
