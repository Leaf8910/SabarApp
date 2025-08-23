// providers/sensor_provider.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../models/sensor_data.dart';
import '../services/sensor_service.dart';

class SensorProvider with ChangeNotifier {
  final SensorService _sensorService = SensorService();
  
  // Current state
  SensorData? _currentSensorData;
  List<SensorData> _sensorHistory = [];
  bool _isListening = false;
  bool _isConnected = false;
  String? _errorMessage;
  DateTime? _lastUpdateTime;
  
  // Stream subscription
  StreamSubscription<SensorData>? _sensorSubscription;
  Timer? _connectionCheckTimer;
  
  // Getters
  SensorData? get currentSensorData => _currentSensorData;
  List<SensorData> get sensorHistory => _sensorHistory;
  bool get isListening => _isListening;
  bool get isConnected => _isConnected;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  
  // Convenience getters
  bool get hasCurrentData => _currentSensorData != null;
  bool get hasMovement => _currentSensorData?.hasMovement ?? false;
  bool get hasSound => _currentSensorData?.hasSound ?? false;
  bool get hasPressure => _currentSensorData?.hasPressure ?? false;
  int get activityLevel => _currentSensorData?.activityLevel ?? 0;
  String get activitySummary => _currentSensorData?.summary ?? 'No data';
  
  // Additional helper method to get summary from SensorData
  String _getSummaryFromData(SensorData data) {
    List<String> activities = [];
    
    if (data.hasMovement) activities.add('Movement');
    if (data.hasSound) activities.add('Sound');
    if (data.hasPressure) activities.add('Pressure');
    
    if (activities.isEmpty) {
      return 'All quiet';
    } else {
      return activities.join(', ') + ' detected';
    }
  }
  
  // Initialize the provider
  Future<void> initialize() async {
    try {
      developer.log('Initializing SensorProvider', name: 'SensorProvider');
      
      await _sensorService.initialize();
      
      // Test connection
      _isConnected = await _sensorService.testConnection();
      
      // Load initial data
      await _loadInitialData();
      
      // Start periodic connection checks
      _startConnectionChecks();
      
      developer.log('SensorProvider initialized successfully', name: 'SensorProvider');
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to initialize sensor connection: $e';
      developer.log(
        'Error initializing SensorProvider',
        name: 'SensorProvider',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }
  
  // Load initial sensor data
  Future<void> _loadInitialData() async {
    try {
      developer.log('Loading initial sensor data', name: 'SensorProvider');
      
      // Get the latest sensor data
      final latestData = await _sensorService.getLatestSensorData();
      if (latestData != null) {
        _currentSensorData = latestData;
        _lastUpdateTime = DateTime.now();
      }
      
      // Load sensor history
      _sensorHistory = await _sensorService.getSensorHistory(limit: 100);
      
      developer.log('Loaded ${_sensorHistory.length} historical records', name: 'SensorProvider');
    } catch (e) {
      developer.log('Error loading initial data: $e', name: 'SensorProvider');
    }
  }
  
  // Start listening to real-time sensor updates
  Future<void> startListening() async {
    if (_isListening) {
      developer.log('Already listening to sensor data', name: 'SensorProvider');
      return;
    }
    
    try {
      developer.log('Starting real-time sensor listening', name: 'SensorProvider');
      
      await _sensorService.startListening();
      
      _sensorSubscription = _sensorService.sensorStream.listen(
        (SensorData data) {
          developer.log('Received new sensor data: $data', name: 'SensorProvider');
          
          _currentSensorData = data;
          _lastUpdateTime = DateTime.now();
          _errorMessage = null;
          
          // Add to history (keep last 200 records)
          _sensorHistory.insert(0, data);
          if (_sensorHistory.length > 200) {
            _sensorHistory.removeRange(200, _sensorHistory.length);
          }
          
          notifyListeners();
        },
        onError: (error) {
          developer.log('Error in sensor stream: $error', name: 'SensorProvider');
          _errorMessage = 'Sensor connection error: $error';
          _isListening = false;
          notifyListeners();
          
          // Try to reconnect after a delay
          Timer(const Duration(seconds: 5), () {
            if (!_isListening) {
              startListening();
            }
          });
        },
      );
      
      _isListening = true;
      _errorMessage = null;
      notifyListeners();
      
      developer.log('Successfully started listening to sensor data', name: 'SensorProvider');
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to start sensor listening: $e';
      _isListening = false;
      developer.log(
        'Error starting sensor listening',
        name: 'SensorProvider',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    }
  }
  
  // Stop listening to sensor updates
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    developer.log('Stopping sensor listening', name: 'SensorProvider');
    
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    await _sensorService.stopListening();
    
    _isListening = false;
    notifyListeners();
  }
  
  // Refresh sensor data manually
  Future<void> refreshData() async {
    try {
      developer.log('Manually refreshing sensor data', name: 'SensorProvider');
      
      final latestData = await _sensorService.getLatestSensorData();
      if (latestData != null) {
        _currentSensorData = latestData;
        _lastUpdateTime = DateTime.now();
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to refresh data: $e';
      developer.log('Error refreshing data: $e', name: 'SensorProvider');
      notifyListeners();
    }
  }
  
  // Check connection status
  Future<void> checkConnection() async {
    try {
      _isConnected = await _sensorService.testConnection();
      
      if (!_isConnected) {
        _errorMessage = 'Lost connection to sensor database';
      } else if (_errorMessage != null && _errorMessage!.contains('connection')) {
        _errorMessage = null; // Clear connection errors if reconnected
      }
      
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _errorMessage = 'Connection check failed: $e';
      notifyListeners();
    }
  }
  
  // Start periodic connection checks
  void _startConnectionChecks() {
    _connectionCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkConnection();
    });
  }
  
  // Get sensor data for a specific time range
  List<SensorData> getSensorDataInRange(DateTime start, DateTime end) {
    return _sensorHistory.where((data) {
      final dataTime = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
      return dataTime.isAfter(start) && dataTime.isBefore(end);
    }).toList();
  }
  
  // Get activity statistics for today
  Map<String, dynamic> getTodayActivityStats() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final todayData = getSensorDataInRange(startOfDay, today);
    
    if (todayData.isEmpty) {
      return {
        'totalReadings': 0,
        'movementDetections': 0,
        'soundDetections': 0,
        'pressureDetections': 0,
        'averageActivity': 0,
        'peakActivity': 0,
      };
    }
    
    int movementCount = 0;
    int soundCount = 0;
    int pressureCount = 0;
    int totalActivity = 0;
    int peakActivity = 0;
    
    for (final data in todayData) {
      if (data.hasMovement) movementCount++;
      if (data.hasSound) soundCount++;
      if (data.hasPressure) pressureCount++;
      
      totalActivity += data.activityLevel;
      if (data.activityLevel > peakActivity) {
        peakActivity = data.activityLevel;
      }
    }
    
    return {
      'totalReadings': todayData.length,
      'movementDetections': movementCount,
      'soundDetections': soundCount,
      'pressureDetections': pressureCount,
      'averageActivity': todayData.isNotEmpty ? (totalActivity / todayData.length).round() : 0,
      'peakActivity': peakActivity,
    };
  }
  
  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // Check if data is recent (within last 2 minutes)
  bool get isDataRecent {
    if (_currentSensorData == null) return false;
    
    final dataAge = DateTime.now().millisecondsSinceEpoch - _currentSensorData!.timestamp;
    return dataAge < 120000; // 2 minutes
  }
  
  // Get data age in human readable format
  String get dataAge {
    if (_currentSensorData == null) return 'No data';
    
    final age = DateTime.now().millisecondsSinceEpoch - _currentSensorData!.timestamp;
    final seconds = (age / 1000).round();
    
    if (seconds < 60) return '${seconds}s ago';
    if (seconds < 3600) return '${(seconds / 60).round()}m ago';
    if (seconds < 86400) return '${(seconds / 3600).round()}h ago';
    return '${(seconds / 86400).round()}d ago';
  }
  
  @override
  void dispose() {
    developer.log('Disposing SensorProvider', name: 'SensorProvider');
    stopListening();
    _connectionCheckTimer?.cancel();
    _sensorService.dispose();
    super.dispose();
  }
}