import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer' as developer;

class PrayerTimeProvider with ChangeNotifier {
  PrayerTimes? _prayerTimes;
  Position? _currentLocation;
  String? _errorMessage;
  bool _isLoading = false;

  PrayerTimes? get prayerTimes => _prayerTimes;
  Position? get currentLocation => _currentLocation;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

      
Future<void> testPrayerTimesWithFixedLocation() async {
  _setLoadingState(true);
  _errorMessage = null;
  _prayerTimes = null;
  notifyListeners();

  try {
    developer.log('Testing with fixed location (Mecca)', name: 'PrayerTimeProvider');
    
    // Use Mecca coordinates for testing
    final coordinates = Coordinates(21.4225, 39.8262);
    
    final date = DateTime.now();
    final params = CalculationMethod.muslimWorldLeague();
    params.madhab = Madhab.shafi;

    _prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: params,
    );

    if (_prayerTimes != null) {
      developer.log('Test prayer times calculated successfully', name: 'PrayerTimeProvider');
      developer.log('Fajr: ${_prayerTimes?.fajr}', name: 'PrayerTimeProvider');
      developer.log('Dhuhr: ${_prayerTimes?.dhuhr}', name: 'PrayerTimeProvider');
    }
    
  } catch (e, stackTrace) {
    _errorMessage = 'Test failed: $e';
    developer.log('Test error: $e', name: 'PrayerTimeProvider', error: e, stackTrace: stackTrace);
  } finally {
    _setLoadingState(false);
    notifyListeners();
  }
}

  PrayerTimeProvider() {
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        onDidReceiveLocalNotification: (id, title, body, payload) {},
      );
      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );
      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      tz.initializeTimeZones();

      // Request notification permissions
      final status = await Permission.notification.request();
      if (status.isDenied) {
        developer.log('Notification permission denied', name: 'PrayerTimeProvider');
      } else if (status.isPermanentlyDenied) {
        developer.log('Notification permission permanently denied', name: 'PrayerTimeProvider');
      } else {
        developer.log('Notification permission granted.', name: 'PrayerTimeProvider');
      }
    } catch (e) {
      developer.log('Error initializing notifications: $e', name: 'PrayerTimeProvider');
    }
  }

  Future<void> fetchPrayerTimes() async {
    if (_isLoading) {
      developer.log('Already fetching prayer times, skipping...', name: 'PrayerTimeProvider');
      return;
    }

    _setLoadingState(true);
    _errorMessage = null;
    _prayerTimes = null;
    _currentLocation = null;
    notifyListeners();

    developer.log('Starting to fetch prayer times...', name: 'PrayerTimeProvider');

    try {
      // Step 1: Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }
      developer.log('Location services are enabled', name: 'PrayerTimeProvider');

      // Step 2: Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      developer.log('Current location permission: $permission', name: 'PrayerTimeProvider');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        developer.log('Requested location permission result: $permission', name: 'PrayerTimeProvider');
        
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location permission to get accurate prayer times.');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location permission in your device settings under Apps > [App Name] > Permissions.');
      }

      // Step 3: Get current position with timeout
      developer.log('Getting current position...', name: 'PrayerTimeProvider');
      
      try {
        _currentLocation = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15), // Add timeout
        );
      } catch (e) {
        developer.log('Failed to get high accuracy location, trying medium accuracy...', name: 'PrayerTimeProvider');
        // Fallback to medium accuracy if high accuracy fails
        _currentLocation = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      }
      
      developer.log('Current Location: ${_currentLocation?.latitude}, ${_currentLocation?.longitude}', name: 'PrayerTimeProvider');

      if (_currentLocation == null) {
        throw Exception('Unable to determine your location. Please check your GPS settings.');
      }

      // Step 4: Create coordinates
      final coordinates = Coordinates(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      // Step 5: Set calculation parameters
      final date = DateTime.now();
      final params = CalculationMethod.muslimWorldLeague();
      params.madhab = Madhab.shafi;

      developer.log('Calculating prayer times for date: $date', name: 'PrayerTimeProvider');
      developer.log('Using coordinates: ${coordinates.latitude}, ${coordinates.longitude}', name: 'PrayerTimeProvider');

      // Step 6: Calculate prayer times
      _prayerTimes = PrayerTimes(
        coordinates: coordinates,
        date: date,
        calculationParameters: params,
      );

      if (_prayerTimes == null) {
        throw Exception('Failed to calculate prayer times. Please try again.');
      }

      developer.log('Prayer Times calculated successfully:', name: 'PrayerTimeProvider');
      developer.log('Fajr: ${_prayerTimes?.fajr}', name: 'PrayerTimeProvider');
      developer.log('Sunrise: ${_prayerTimes?.sunrise}', name: 'PrayerTimeProvider');
      developer.log('Dhuhr: ${_prayerTimes?.dhuhr}', name: 'PrayerTimeProvider');
      developer.log('Asr: ${_prayerTimes?.asr}', name: 'PrayerTimeProvider');
      developer.log('Maghrib: ${_prayerTimes?.maghrib}', name: 'PrayerTimeProvider');
      developer.log('Isha: ${_prayerTimes?.isha}', name: 'PrayerTimeProvider');

      // Step 7: Schedule notifications
      await _schedulePrayerNotifications();

      developer.log('Prayer times fetched successfully', name: 'PrayerTimeProvider');

    } catch (e, stackTrace) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      developer.log(
        'Error in fetchPrayerTimes: $e',
        name: 'PrayerTimeProvider',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _setLoadingState(false);
      notifyListeners();
    }
  }

  void _setLoadingState(bool loading) {
    _isLoading = loading;
    developer.log('Loading state changed to: $loading', name: 'PrayerTimeProvider');
  }

  // Method to manually clear error and retry
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Method to check current status
  String getStatusMessage() {
    if (_isLoading) return 'Fetching prayer times...';
    if (_errorMessage != null) return 'Error: $_errorMessage';
    if (_prayerTimes != null) return 'Prayer times loaded';
    return 'Ready to fetch prayer times';
  }

  Future<void> _schedulePrayerNotifications() async {
    if (_prayerTimes == null) {
      developer.log('No prayer times to schedule notifications for.', name: 'PrayerTimeProvider');
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      developer.log('Cancelled all previous notifications.', name: 'PrayerTimeProvider');

      final prayers = {
        'Fajr': _prayerTimes!.fajr,
        'Sunrise': _prayerTimes!.sunrise,
        'Dhuhr': _prayerTimes!.dhuhr,
        'Asr': _prayerTimes!.asr,
        'Maghrib': _prayerTimes!.maghrib,
        'Isha': _prayerTimes!.isha,
      };

      int notificationId = 0;
      final String currentTimeZone = tz.local.name;
      developer.log('Current Time Zone for notifications: $currentTimeZone', name: 'PrayerTimeProvider');

      for (final entry in prayers.entries) {
        final prayerName = entry.key;
        final prayerTime = entry.value;

        if (prayerTime != null) {
          final tz.TZDateTime scheduledDate = tz.TZDateTime(
            tz.getLocation(currentTimeZone),
            prayerTime.year,
            prayerTime.month,
            prayerTime.day,
            prayerTime.hour,
            prayerTime.minute,
            prayerTime.second,
          );

          if (scheduledDate.isAfter(tz.TZDateTime.now(tz.getLocation(currentTimeZone)))) {
            developer.log('Scheduling notification for $prayerName at $scheduledDate', name: 'PrayerTimeProvider');
            await flutterLocalNotificationsPlugin.zonedSchedule(
              notificationId,
              'Prayer Time Alert',
              'It\'s almost $prayerName prayer time!',
              scheduledDate,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'prayer_channel_id',
                  'Prayer Reminders',
                  channelDescription: 'Notifications for daily prayer times',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.time,
            );
            notificationId++;
          } else {
            developer.log('Not scheduling $prayerName as time is in the past: $scheduledDate', name: 'PrayerTimeProvider');
          }
        }
      }
      developer.log('Notification scheduling completed', name: 'PrayerTimeProvider');
    } catch (e) {
      developer.log('Error scheduling notifications: $e', name: 'PrayerTimeProvider');
      // Don't throw here as notification scheduling failure shouldn't prevent prayer times from showing
    }
  }
}