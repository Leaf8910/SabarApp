import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

enum LocationMode {
  currentLocation,
  selectedCountry,
}

class CountryCoordinates {
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;

  CountryCoordinates({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });
}

class PrayerTimeProvider with ChangeNotifier {
  PrayerTimes? _prayerTimes;
  Position? _currentLocation;
  String? _errorMessage;
  bool _isLoading = false;
  LocationMode _locationMode = LocationMode.currentLocation;
  String? _selectedCountry;
  CountryCoordinates? _countryCoordinates;

  // Getters
  PrayerTimes? get prayerTimes => _prayerTimes;
  Position? get currentLocation => _currentLocation;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  LocationMode get locationMode => _locationMode;
  String? get selectedCountry => _selectedCountry;
  CountryCoordinates? get countryCoordinates => _countryCoordinates;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Country coordinates mapping (major cities as representatives)
  static final Map<String, CountryCoordinates> _countryCoordinatesMap = {
    'Afghanistan': CountryCoordinates(name: 'Kabul', latitude: 34.5553, longitude: 69.2075, timezone: 'Asia/Kabul'),
    'Albania': CountryCoordinates(name: 'Tirana', latitude: 41.3275, longitude: 19.8187, timezone: 'Europe/Tirane'),
    'Algeria': CountryCoordinates(name: 'Algiers', latitude: 36.7538, longitude: 3.0588, timezone: 'Africa/Algiers'),
    'Argentina': CountryCoordinates(name: 'Buenos Aires', latitude: -34.6118, longitude: -58.3960, timezone: 'America/Argentina/Buenos_Aires'),
    'Australia': CountryCoordinates(name: 'Sydney', latitude: -33.8688, longitude: 151.2093, timezone: 'Australia/Sydney'),
    'Austria': CountryCoordinates(name: 'Vienna', latitude: 48.2082, longitude: 16.3738, timezone: 'Europe/Vienna'),
    'Bahrain': CountryCoordinates(name: 'Manama', latitude: 26.2285, longitude: 50.5860, timezone: 'Asia/Bahrain'),
    'Bangladesh': CountryCoordinates(name: 'Dhaka', latitude: 23.8103, longitude: 90.4125, timezone: 'Asia/Dhaka'),
    'Belgium': CountryCoordinates(name: 'Brussels', latitude: 50.8503, longitude: 4.3517, timezone: 'Europe/Brussels'),
    'Bosnia and Herzegovina': CountryCoordinates(name: 'Sarajevo', latitude: 43.8563, longitude: 18.4131, timezone: 'Europe/Sarajevo'),
    'Brazil': CountryCoordinates(name: 'São Paulo', latitude: -23.5505, longitude: -46.6333, timezone: 'America/Sao_Paulo'),
    'Brunei': CountryCoordinates(name: 'Bandar Seri Begawan', latitude: 4.5353, longitude: 114.7277, timezone: 'Asia/Brunei'),
    'Bulgaria': CountryCoordinates(name: 'Sofia', latitude: 42.6977, longitude: 23.3219, timezone: 'Europe/Sofia'),
    'Canada': CountryCoordinates(name: 'Toronto', latitude: 43.6532, longitude: -79.3832, timezone: 'America/Toronto'),
    'China': CountryCoordinates(name: 'Beijing', latitude: 39.9042, longitude: 116.4074, timezone: 'Asia/Shanghai'),
    'Croatia': CountryCoordinates(name: 'Zagreb', latitude: 45.8150, longitude: 15.9819, timezone: 'Europe/Zagreb'),
    'Cyprus': CountryCoordinates(name: 'Nicosia', latitude: 35.1856, longitude: 33.3823, timezone: 'Asia/Nicosia'),
    'Czech Republic': CountryCoordinates(name: 'Prague', latitude: 50.0755, longitude: 14.4378, timezone: 'Europe/Prague'),
    'Denmark': CountryCoordinates(name: 'Copenhagen', latitude: 55.6761, longitude: 12.5683, timezone: 'Europe/Copenhagen'),
    'Egypt': CountryCoordinates(name: 'Cairo', latitude: 30.0444, longitude: 31.2357, timezone: 'Africa/Cairo'),
    'Finland': CountryCoordinates(name: 'Helsinki', latitude: 60.1699, longitude: 24.9384, timezone: 'Europe/Helsinki'),
    'France': CountryCoordinates(name: 'Paris', latitude: 48.8566, longitude: 2.3522, timezone: 'Europe/Paris'),
    'Germany': CountryCoordinates(name: 'Berlin', latitude: 52.5200, longitude: 13.4050, timezone: 'Europe/Berlin'),
    'Greece': CountryCoordinates(name: 'Athens', latitude: 37.9838, longitude: 23.7275, timezone: 'Europe/Athens'),
    'India': CountryCoordinates(name: 'New Delhi', latitude: 28.6139, longitude: 77.2090, timezone: 'Asia/Kolkata'),
    'Indonesia': CountryCoordinates(name: 'Jakarta', latitude: -6.2088, longitude: 106.8456, timezone: 'Asia/Jakarta'),
    'Iran': CountryCoordinates(name: 'Tehran', latitude: 35.6892, longitude: 51.3890, timezone: 'Asia/Tehran'),
    'Iraq': CountryCoordinates(name: 'Baghdad', latitude: 33.3152, longitude: 44.3661, timezone: 'Asia/Baghdad'),
    'Ireland': CountryCoordinates(name: 'Dublin', latitude: 53.3498, longitude: -6.2603, timezone: 'Europe/Dublin'),
    'Italy': CountryCoordinates(name: 'Rome', latitude: 41.9028, longitude: 12.4964, timezone: 'Europe/Rome'),
    'Japan': CountryCoordinates(name: 'Tokyo', latitude: 35.6762, longitude: 139.6503, timezone: 'Asia/Tokyo'),
    'Jordan': CountryCoordinates(name: 'Amman', latitude: 31.9539, longitude: 35.9106, timezone: 'Asia/Amman'),
    'Kazakhstan': CountryCoordinates(name: 'Nur-Sultan', latitude: 51.1694, longitude: 71.4491, timezone: 'Asia/Almaty'),
    'Kuwait': CountryCoordinates(name: 'Kuwait City', latitude: 29.3759, longitude: 47.9774, timezone: 'Asia/Kuwait'),
    'Lebanon': CountryCoordinates(name: 'Beirut', latitude: 33.8938, longitude: 35.5018, timezone: 'Asia/Beirut'),
    'Libya': CountryCoordinates(name: 'Tripoli', latitude: 32.8872, longitude: 13.1913, timezone: 'Africa/Tripoli'),
    'Malaysia': CountryCoordinates(name: 'Kuala Lumpur', latitude: 3.1390, longitude: 101.6869, timezone: 'Asia/Kuala_Lumpur'),
    'Maldives': CountryCoordinates(name: 'Malé', latitude: 4.1755, longitude: 73.5093, timezone: 'Indian/Maldives'),
    'Morocco': CountryCoordinates(name: 'Rabat', latitude: 34.0209, longitude: -6.8416, timezone: 'Africa/Casablanca'),
    'Netherlands': CountryCoordinates(name: 'Amsterdam', latitude: 52.3676, longitude: 4.9041, timezone: 'Europe/Amsterdam'),
    'New Zealand': CountryCoordinates(name: 'Auckland', latitude: -36.8485, longitude: 174.7633, timezone: 'Pacific/Auckland'),
    'Norway': CountryCoordinates(name: 'Oslo', latitude: 59.9139, longitude: 10.7522, timezone: 'Europe/Oslo'),
    'Oman': CountryCoordinates(name: 'Muscat', latitude: 23.5859, longitude: 58.4059, timezone: 'Asia/Muscat'),
    'Pakistan': CountryCoordinates(name: 'Islamabad', latitude: 33.6844, longitude: 73.0479, timezone: 'Asia/Karachi'),
    'Palestine': CountryCoordinates(name: 'Ramallah', latitude: 31.9073, longitude: 35.2044, timezone: 'Asia/Hebron'),
    'Philippines': CountryCoordinates(name: 'Manila', latitude: 14.5995, longitude: 120.9842, timezone: 'Asia/Manila'),
    'Poland': CountryCoordinates(name: 'Warsaw', latitude: 52.2297, longitude: 21.0122, timezone: 'Europe/Warsaw'),
    'Portugal': CountryCoordinates(name: 'Lisbon', latitude: 38.7223, longitude: -9.1393, timezone: 'Europe/Lisbon'),
    'Qatar': CountryCoordinates(name: 'Doha', latitude: 25.2760, longitude: 51.5200, timezone: 'Asia/Qatar'),
    'Romania': CountryCoordinates(name: 'Bucharest', latitude: 44.4268, longitude: 26.1025, timezone: 'Europe/Bucharest'),
    'Russia': CountryCoordinates(name: 'Moscow', latitude: 55.7558, longitude: 37.6176, timezone: 'Europe/Moscow'),
    'Saudi Arabia': CountryCoordinates(name: 'Riyadh', latitude: 24.7136, longitude: 46.6753, timezone: 'Asia/Riyadh'),
    'Singapore': CountryCoordinates(name: 'Singapore', latitude: 1.3521, longitude: 103.8198, timezone: 'Asia/Singapore'),
    'Somalia': CountryCoordinates(name: 'Mogadishu', latitude: 2.0469, longitude: 45.3182, timezone: 'Africa/Mogadishu'),
    'South Africa': CountryCoordinates(name: 'Cape Town', latitude: -33.9249, longitude: 18.4241, timezone: 'Africa/Johannesburg'),
    'Spain': CountryCoordinates(name: 'Madrid', latitude: 40.4168, longitude: -3.7038, timezone: 'Europe/Madrid'),
    'Sri Lanka': CountryCoordinates(name: 'Colombo', latitude: 6.9271, longitude: 79.8612, timezone: 'Asia/Colombo'),
    'Sudan': CountryCoordinates(name: 'Khartoum', latitude: 15.5007, longitude: 32.5599, timezone: 'Africa/Khartoum'),
    'Sweden': CountryCoordinates(name: 'Stockholm', latitude: 59.3293, longitude: 18.0686, timezone: 'Europe/Stockholm'),
    'Switzerland': CountryCoordinates(name: 'Bern', latitude: 46.9481, longitude: 7.4474, timezone: 'Europe/Zurich'),
    'Syria': CountryCoordinates(name: 'Damascus', latitude: 33.5138, longitude: 36.2765, timezone: 'Asia/Damascus'),
    'Tunisia': CountryCoordinates(name: 'Tunis', latitude: 36.8065, longitude: 10.1815, timezone: 'Africa/Tunis'),
    'Turkey': CountryCoordinates(name: 'Ankara', latitude: 39.9334, longitude: 32.8597, timezone: 'Europe/Istanbul'),
    'UAE': CountryCoordinates(name: 'Dubai', latitude: 25.2048, longitude: 55.2708, timezone: 'Asia/Dubai'),
    'United Kingdom': CountryCoordinates(name: 'London', latitude: 51.5074, longitude: -0.1278, timezone: 'Europe/London'),
    'United States': CountryCoordinates(name: 'New York', latitude: 40.7128, longitude: -74.0060, timezone: 'America/New_York'),
    'Uzbekistan': CountryCoordinates(name: 'Tashkent', latitude: 41.2995, longitude: 69.2401, timezone: 'Asia/Tashkent'),
    'Yemen': CountryCoordinates(name: 'Sana\'a', latitude: 15.3694, longitude: 44.1910, timezone: 'Asia/Aden'),
  };

  PrayerTimeProvider() {
    _initializeNotifications();
    _loadLocationPreferences();
  }

  Future<void> _loadLocationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationModeIndex = prefs.getInt('location_mode') ?? 0;
      _locationMode = LocationMode.values[locationModeIndex];
      _selectedCountry = prefs.getString('selected_country');
      
      if (_selectedCountry != null && _countryCoordinatesMap.containsKey(_selectedCountry)) {
        _countryCoordinates = _countryCoordinatesMap[_selectedCountry];
      }
      
      developer.log('Loaded location preferences: mode=$_locationMode, country=$_selectedCountry', name: 'PrayerTimeProvider');
      notifyListeners();
    } catch (e) {
      developer.log('Error loading location preferences: $e', name: 'PrayerTimeProvider');
    }
  }

  Future<void> setLocationMode(LocationMode mode) async {
    _locationMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('location_mode', mode.index);
    developer.log('Location mode changed to: $mode', name: 'PrayerTimeProvider');
    notifyListeners();
    
    // Refresh prayer times with new location mode
    await fetchPrayerTimes();
  }

  Future<void> setSelectedCountry(String country) async {
    _selectedCountry = country;
    _countryCoordinates = _countryCoordinatesMap[country];
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_country', country);
    
    developer.log('Selected country changed to: $country', name: 'PrayerTimeProvider');
    notifyListeners();
    
    // If using country mode, refresh prayer times
    if (_locationMode == LocationMode.selectedCountry) {
      await fetchPrayerTimes();
    }
  }

  String get locationDisplayText {
    if (_locationMode == LocationMode.currentLocation) {
      if (_currentLocation != null) {
        return 'Current Location (${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)})';
      } else {
        return 'Current Location (Not available)';
      }
    } else {
      if (_countryCoordinates != null) {
        return '${_countryCoordinates!.name}, $_selectedCountry';
      } else {
        return _selectedCountry ?? 'No country selected';
      }
    }
  }

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
    notifyListeners();

    developer.log('Starting to fetch prayer times with mode: $_locationMode', name: 'PrayerTimeProvider');

    try {
      Coordinates coordinates;

      if (_locationMode == LocationMode.currentLocation) {
        coordinates = await _getCurrentLocationCoordinates();
      } else {
        coordinates = await _getCountryCoordinates();
      }

      // Calculate prayer times
      final date = DateTime.now();
      final params = CalculationMethod.muslimWorldLeague();
      params.madhab = Madhab.shafi;

      developer.log('Calculating prayer times for date: $date', name: 'PrayerTimeProvider');
      developer.log('Using coordinates: ${coordinates.latitude}, ${coordinates.longitude}', name: 'PrayerTimeProvider');

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

      // Schedule notifications
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

  Future<Coordinates> _getCurrentLocationCoordinates() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services in your device settings or switch to country-based location in settings.');
    }
    developer.log('Location services are enabled', name: 'PrayerTimeProvider');

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    developer.log('Current location permission: $permission', name: 'PrayerTimeProvider');
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      developer.log('Requested location permission result: $permission', name: 'PrayerTimeProvider');
      
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied. Please grant location permission or switch to country-based location in settings.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable location permission in your device settings or switch to country-based location in settings.');
    }

    // Get current position with timeout
    developer.log('Getting current position...', name: 'PrayerTimeProvider');
    
    try {
      _currentLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
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
      throw Exception('Unable to determine your location. Please check your GPS settings or switch to country-based location in settings.');
    }

    return Coordinates(_currentLocation!.latitude, _currentLocation!.longitude);
  }

  Future<Coordinates> _getCountryCoordinates() async {
    if (_selectedCountry == null || _countryCoordinates == null) {
      throw Exception('No country selected. Please select a country in your profile or app settings.');
    }

    developer.log('Using country coordinates: ${_countryCoordinates!.name}, ${_selectedCountry}', name: 'PrayerTimeProvider');
    developer.log('Coordinates: ${_countryCoordinates!.latitude}, ${_countryCoordinates!.longitude}', name: 'PrayerTimeProvider');

    return Coordinates(_countryCoordinates!.latitude, _countryCoordinates!.longitude);
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