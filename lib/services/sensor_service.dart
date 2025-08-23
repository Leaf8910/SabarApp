// services/sensor_service.dart
// HTTP-based implementation - no Firebase SDK required
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/sensor_data.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // Your Firebase Realtime Database URL from Arduino code
  static const String _databaseUrl = 'https://sabarapp-9c850-default-rtdb.asia-southeast1.firebasedatabase.app';
  
  Timer? _pollingTimer;
  final StreamController<SensorData> _sensorController = StreamController<SensorData>.broadcast();
  
  // Getters
  Stream<SensorData> get sensorStream => _sensorController.stream;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool _isPolling = false;
  bool get isPolling => _isPolling;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      developer.log('Initializing HTTP-based Sensor Service', name: 'SensorService');
      _isInitialized = true;
      developer.log('Sensor Service initialized successfully', name: 'SensorService');
    } catch (e, stackTrace) {
      developer.log(
        'Error initializing Sensor Service',
        name: 'SensorService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to initialize sensor service: $e');
    }
  }

  /// Start polling for sensor data
  Future<void> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isPolling) {
      developer.log('Already polling for sensor data', name: 'SensorService');
      return;
    }

    try {
      developer.log('Starting to poll for sensor data', name: 'SensorService');
      
      _isPolling = true;
      
      // Poll every 2 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        try {
          final sensorData = await getLatestSensorData();
          if (sensorData != null) {
            _sensorController.add(sensorData);
          }
        } catch (e) {
          developer.log('Error during polling: $e', name: 'SensorService');
          // Continue polling even if one request fails
        }
      });
      
      developer.log('Successfully started polling sensor data', name: 'SensorService');
    } catch (e, stackTrace) {
      _isPolling = false;
      developer.log(
        'Error starting sensor polling',
        name: 'SensorService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to start listening to sensor data: $e');
    }
  }

  /// Stop polling for sensor data
  Future<void> stopListening() async {
    developer.log('Stopping sensor data polling', name: 'SensorService');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }

  /// Get the latest sensor data from Firebase via HTTP
  Future<SensorData?> getLatestSensorData() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      developer.log('Fetching latest sensor data via HTTP', name: 'SensorService');
      
      // Construct the URL to get latest sensor data
      final url = Uri.parse('$_databaseUrl/sensors/latest.json');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timeout', const Duration(seconds: 10));
        },
      );
      
      if (response.statusCode == 200) {
        final jsonString = response.body;
        
        // Check if we got valid data
        if (jsonString == 'null' || jsonString.isEmpty) {
          developer.log('No sensor data found in database', name: 'SensorService');
          return null;
        }
        
        final Map<String, dynamic> sensorData = json.decode(jsonString);
        
        final parsedData = SensorData.fromJson(sensorData);
        developer.log('Retrieved latest sensor data: $parsedData', name: 'SensorService');
        
        return parsedData;
      } else {
        developer.log('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}', name: 'SensorService');
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching latest sensor data',
        name: 'SensorService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get sensor history via HTTP
  Future<List<SensorData>> getSensorHistory({int limit = 50}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      developer.log('Fetching sensor history via HTTP (limit: $limit)', name: 'SensorService');
      
      // Try to get history data (you might need to modify your Arduino code to store history)
      final url = Uri.parse('$_databaseUrl/sensors/history.json?orderBy="\$key"&limitToLast=$limit');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Request timeout', const Duration(seconds: 15));
        },
      );
      
      if (response.statusCode == 200) {
        final jsonString = response.body;
        
        if (jsonString == 'null' || jsonString.isEmpty) {
          developer.log('No sensor history found in database', name: 'SensorService');
          return [];
        }
        
        final Map<String, dynamic> data = json.decode(jsonString);
        final List<SensorData> history = [];
        
        data.forEach((key, value) {
          if (value != null && value is Map<String, dynamic>) {
            try {
              history.add(SensorData.fromJson(value));
            } catch (e) {
              developer.log('Error parsing history entry: $e', name: 'SensorService');
            }
          }
        });
        
        // Sort by timestamp (newest first)
        history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        developer.log('Retrieved ${history.length} sensor history records', name: 'SensorService');
        return history;
      } else {
        developer.log('HTTP Error for history: ${response.statusCode}', name: 'SensorService');
        return [];
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching sensor history',
        name: 'SensorService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Check if sensors are currently active
  Future<bool> areSensorsActive() async {
    try {
      final latestData = await getLatestSensorData();
      if (latestData == null) return false;
      
      // Consider sensors active if data is less than 1 minute old
      final dataAge = DateTime.now().millisecondsSinceEpoch - latestData.timestamp;
      final isActive = dataAge < 60000; // 1 minute in milliseconds
      
      developer.log('Sensors active: $isActive (data age: ${dataAge}ms)', name: 'SensorService');
      return isActive;
    } catch (e) {
      developer.log('Error checking sensor activity: $e', name: 'SensorService');
      return false;
    }
  }

  /// Test connection to Firebase
  Future<bool> testConnection() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Try to make a simple request to test connectivity
      final url = Uri.parse('$_databaseUrl/.json?shallow=true');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timeout', const Duration(seconds: 5));
        },
      );
      
      final isConnected = response.statusCode == 200;
      developer.log('Firebase HTTP connection test: $isConnected (${response.statusCode})', name: 'SensorService');
      
      return isConnected;
    } catch (e) {
      developer.log('Connection test failed: $e', name: 'SensorService');
      return false;
    }
  }

  /// Send a test command to ESP32 (optional feature)
  Future<bool> sendCommand(String command, dynamic value) async {
    try {
      developer.log('Sending command to ESP32: $command = $value', name: 'SensorService');
      
      final url = Uri.parse('$_databaseUrl/commands/$command.json');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'value': value,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
      ).timeout(const Duration(seconds: 10));
      
      final success = response.statusCode == 200;
      developer.log('Command sent: $success (${response.statusCode})', name: 'SensorService');
      
      return success;
    } catch (e) {
      developer.log('Error sending command: $e', name: 'SensorService');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    developer.log('Disposing SensorService', name: 'SensorService');
    stopListening();
    _sensorController.close();
    _isInitialized = false;
  }
}

/// Exception for sensor service errors
class SensorServiceException implements Exception {
  final String message;
  final int? statusCode;
  
  SensorServiceException(this.message, [this.statusCode]);
  
  @override
  String toString() {
    if (statusCode != null) {
      return 'SensorServiceException (HTTP $statusCode): $message';
    }
    return 'SensorServiceException: $message';
  }
}