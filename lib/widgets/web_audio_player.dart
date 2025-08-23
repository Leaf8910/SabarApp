// widgets/web_audio_player.dart
// Simplified version that works on all platforms
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final Function(bool) onPlayStateChanged;
  final Function(Duration) onPositionChanged;
  final Function(Duration) onDurationChanged;

  const WebAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.onPlayStateChanged,
    required this.onPositionChanged,
    required this.onDurationChanged,
  });

  @override
  State<WebAudioPlayer> createState() => _WebAudioPlayerState();
}

class _WebAudioPlayerState extends State<WebAudioPlayer> {
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Only initialize on web
    if (kIsWeb) {
      _initializeWebAudio();
    }
  }

  void _initializeWebAudio() {
    // For now, just show a placeholder
    // Web audio functionality can be added later when needed
    setState(() {
      _duration = const Duration(minutes: 3); // Mock duration
    });
  }

  Future<void> playPause() async {
    if (!kIsWeb) return;

    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    widget.onPlayStateChanged(_isPlaying);
    
    // Show message that this is a placeholder
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPlaying 
            ? 'Web audio playback started (placeholder)' 
            : 'Web audio playback paused (placeholder)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void seekTo(Duration position) {
    if (kIsWeb) {
      setState(() {
        _position = position;
      });
      widget.onPositionChanged(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show the player on web
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: playPause,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 28,
                ),
                color: Theme.of(context).colorScheme.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3,
                      ),
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble().clamp(1.0, double.infinity),
                        onChanged: (value) {
                          seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Web Audio Player (Placeholder) - Use mobile app for full audio experience',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
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
    // No cleanup needed for placeholder
    super.dispose();
  }
}