import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'package:myapp/providers/prayer_time_provider.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
    // Fetch prayer times when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PrayerTimeProvider>(context, listen: false).fetchPrayerTimes();
    });

    
    // In your PrayerTimesScreen, add this button for testing
ElevatedButton(
  onPressed: () {
    Provider.of<PrayerTimeProvider>(context, listen: false)
        .testPrayerTimesWithFixedLocation();
  },
  child: const Text('Test with Fixed Location'),
);
  }

  Future<void> _checkSystemStatus() async {
    String debug = 'System Status:\n';
    
    // Check location services
    bool locationEnabled = await Geolocator.isLocationServiceEnabled();
    debug += '• Location Services: ${locationEnabled ? "Enabled" : "DISABLED"}\n';
    
    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    debug += '• Location Permission: $permission\n';
    
    setState(() {
      _debugInfo = debug;
    });
  }

  String _getCurrentPrayer() {
    final prayerTimeProvider = Provider.of<PrayerTimeProvider>(context, listen: false);
    if (prayerTimeProvider.prayerTimes == null) return '';
    
    final now = DateTime.now();
    final prayerTimes = prayerTimeProvider.prayerTimes!;
    
    if (now.isBefore(prayerTimes.fajr!)) {
      return 'Fajr';
    } else if (now.isBefore(prayerTimes.sunrise!)) {
      return 'Sunrise';
    } else if (now.isBefore(prayerTimes.dhuhr!)) {
      return 'Dhuhr';
    } else if (now.isBefore(prayerTimes.asr!)) {
      return 'Asr';
    } else if (now.isBefore(prayerTimes.maghrib!)) {
      return 'Maghrib';
    } else if (now.isBefore(prayerTimes.isha!)) {
      return 'Isha';
    } else {
      return 'Fajr (Next Day)';
    }
  }

  DateTime? _getNextPrayerTime() {
    final prayerTimeProvider = Provider.of<PrayerTimeProvider>(context, listen: false);
    if (prayerTimeProvider.prayerTimes == null) return null;
    
    final now = DateTime.now();
    final prayerTimes = prayerTimeProvider.prayerTimes!;
    
    if (now.isBefore(prayerTimes.fajr!)) {
      return prayerTimes.fajr;
    } else if (now.isBefore(prayerTimes.sunrise!)) {
      return prayerTimes.sunrise;
    } else if (now.isBefore(prayerTimes.dhuhr!)) {
      return prayerTimes.dhuhr;
    } else if (now.isBefore(prayerTimes.asr!)) {
      return prayerTimes.asr;
    } else if (now.isBefore(prayerTimes.maghrib!)) {
      return prayerTimes.maghrib;
    } else if (now.isBefore(prayerTimes.isha!)) {
      return prayerTimes.isha;
    } else {
      return prayerTimes.fajr!.add(const Duration(days: 1));
    }
  }

  String _getTimeRemaining() {
    final nextPrayerTime = _getNextPrayerTime();
    if (nextPrayerTime == null) return '';
    
    final now = DateTime.now();
    final difference = nextPrayerTime.difference(now);
    
    if (difference.isNegative) return '';
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else {
      return '${minutes}m remaining';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<PrayerTimeProvider>(context, listen: false).fetchPrayerTimes();
            },
            tooltip: 'Refresh Prayer Times',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              _showDebugDialog();
            },
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: Consumer<PrayerTimeProvider>(
        builder: (context, prayerTimeProvider, child) {
          if (prayerTimeProvider.errorMessage != null && prayerTimeProvider.errorMessage!.isNotEmpty) {
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
                      'Error Loading Prayer Times',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prayerTimeProvider.errorMessage!,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            prayerTimeProvider.clearError();
                            prayerTimeProvider.fetchPrayerTimes();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showDebugDialog,
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Show Debug Info'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Open App Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else if (prayerTimeProvider.isLoading || prayerTimeProvider.prayerTimes == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    prayerTimeProvider.getStatusMessage(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _showDebugDialog,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Show Debug Info'),
                  ),
                ],
              ),
            );
          } else {
            final prayerTimes = prayerTimeProvider.prayerTimes!;
            final currentLocation = prayerTimeProvider.currentLocation;
            final currentPrayer = _getCurrentPrayer();
            final timeRemaining = _getTimeRemaining();
            
            return RefreshIndicator(
              onRefresh: () async {
                await prayerTimeProvider.fetchPrayerTimes();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Current date
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (timeRemaining.isNotEmpty)
                                  Text(
                                    'Next: $currentPrayer - $timeRemaining',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Text(
                      'Today\'s Prayer Times',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Prayer times list
                    _buildPrayerTimeRow('Fajr', prayerTimes.fajr, context, 
                        isNext: currentPrayer == 'Fajr'),
                    _buildPrayerTimeRow('Sunrise', prayerTimes.sunrise, context, 
                        isNext: currentPrayer == 'Sunrise'),
                    _buildPrayerTimeRow('Dhuhr', prayerTimes.dhuhr, context, 
                        isNext: currentPrayer == 'Dhuhr'),
                    _buildPrayerTimeRow('Asr', prayerTimes.asr, context, 
                        isNext: currentPrayer == 'Asr'),
                    _buildPrayerTimeRow('Maghrib', prayerTimes.maghrib, context, 
                        isNext: currentPrayer == 'Maghrib'),
                    _buildPrayerTimeRow('Isha', prayerTimes.isha, context, 
                        isNext: currentPrayer == 'Isha'),
                    
                    const SizedBox(height: 24),
                    
                    // Location info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  if (currentLocation != null)
                                    Text(
                                      'Lat: ${currentLocation.latitude.toStringAsFixed(4)}, '
                                      'Lng: ${currentLocation.longitude.toStringAsFixed(4)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    )
                                  else
                                    Text(
                                      'Location data not available',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Calculation method info
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calculate,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Calculation Method',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Text(
                                    'Muslim World League (Shafi Madhab)',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Debug Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_debugInfo),
                const SizedBox(height: 16),
                Consumer<PrayerTimeProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Provider Status:'),
                        Text('• Loading: ${provider.isLoading}'),
                        Text('• Has Prayer Times: ${provider.prayerTimes != null}'),
                        Text('• Has Location: ${provider.currentLocation != null}'),
                        Text('• Error: ${provider.errorMessage ?? "None"}'),
                        if (provider.currentLocation != null) ...[
                          const SizedBox(height: 8),
                          Text('Location Details:'),
                          Text('• Lat: ${provider.currentLocation!.latitude}'),
                          Text('• Lng: ${provider.currentLocation!.longitude}'),
                          Text('• Accuracy: ${provider.currentLocation!.accuracy}m'),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Location Settings'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrayerTimeRow(String name, DateTime? time, BuildContext context, {bool isNext = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      elevation: isNext ? 4 : 2,
      color: isNext ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Prayer icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isNext 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _getPrayerIcon(name),
                color: isNext 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            
            // Prayer name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                      color: isNext ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                  if (isNext)
                    Text(
                      'Next Prayer',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
            
            // Prayer time
            Text(
              time != null ? DateFormat.jm().format(time) : 'N/A',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isNext ? Theme.of(context).colorScheme.onPrimaryContainer : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPrayerIcon(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'sunrise':
        return Icons.wb_sunny;
      case 'dhuhr':
        return Icons.wb_sunny_outlined;
      case 'asr':
        return Icons.wb_cloudy;
      case 'maghrib':
        return Icons.brightness_3;
      case 'isha':
        return Icons.nights_stay;
      default:
        return Icons.schedule;
    }
  }
}