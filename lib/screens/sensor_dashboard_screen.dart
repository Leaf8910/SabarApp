// screens/sensor_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // Add this import
import 'package:intl/intl.dart';
import '../providers/sensor_provider.dart';
import '../models/sensor_data.dart';

class SensorDashboardScreen extends StatefulWidget {
  const SensorDashboardScreen({super.key});

  @override
  State<SensorDashboardScreen> createState() => _SensorDashboardScreenState();
}

class _SensorDashboardScreenState extends State<SensorDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize sensor provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SensorProvider>(context, listen: false);
      provider.initialize().then((_) {
        provider.startListening();
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle Android back button - go to home
        Navigator.of(context).pushReplacementNamed('/home');
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Prayer Sensor Dashboard'),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            tooltip: 'Back to Home',
          ),
          actions: [
          Consumer<SensorProvider>(
            builder: (context, provider, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Connection status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: provider.isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: provider.refreshData,
                    tooltip: 'Refresh Data',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'start':
                          provider.startListening();
                          break;
                        case 'stop':
                          provider.stopListening();
                          break;
                        case 'test':
                          provider.checkConnection();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'start',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, 
                                 color: provider.isListening ? Colors.grey : Colors.green),
                            const SizedBox(width: 8),
                            Text(provider.isListening ? 'Already Listening' : 'Start Listening'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'stop',
                        child: Row(
                          children: [
                            Icon(Icons.stop, 
                                 color: provider.isListening ? Colors.red : Colors.grey),
                            const SizedBox(width: 8),
                            Text(provider.isListening ? 'Stop Listening' : 'Not Listening'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'test',
                        child: Row(
                          children: [
                            Icon(Icons.wifi_find, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Test Connection'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<SensorProvider>(
        builder: (context, provider, child) {
          if (provider.errorMessage != null) {
            return _buildErrorView(provider);
          }
          
          if (!provider.hasCurrentData) {
            return _buildLoadingView(provider);
          }
          
          return _buildDashboardContent(provider);
        },
      ),
    ));
  }

  Widget _buildErrorView(SensorProvider provider) {
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
              'Sensor Connection Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    provider.clearError();
                    provider.initialize().then((_) => provider.startListening());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: provider.checkConnection,
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Test Connection'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(SensorProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            provider.isListening ? 'Waiting for sensor data...' : 'Initializing sensors...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your ESP32 device is connected and sending data',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(SensorProvider provider) {
    final data = provider.currentSensorData!;
    
    // Start pulse animation if there's high activity
    if (data.activityLevel > 50 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (data.activityLevel <= 50 && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    
    return RefreshIndicator(
      onRefresh: provider.refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            _buildStatusHeader(provider, data),
            const SizedBox(height: 20),
            
            // Current Activity Overview
            _buildActivityOverview(data),
            const SizedBox(height: 20),
            
            // Sensor Readings Grid
            _buildSensorGrid(data),
            const SizedBox(height: 20),
            
            // Today's Statistics
            _buildTodayStats(provider),
            const SizedBox(height: 20),
            
            // Recent Activity History
            _buildRecentActivity(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(SensorProvider provider, SensorData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.activityLevel > 50
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: data.activityLevel > 50 ? _pulseAnimation.value : 1.0,
                child: Icon(
                  data.activityLevel > 50 ? Icons.sensors : Icons.sensors_off,
                  size: 48,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            data.summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                provider.isListening ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                provider.isListening ? 'Live' : 'Offline',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                provider.dataAge,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityOverview(SensorData data) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Activity Level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: data.activityLevel / 100,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getActivityColor(data.activityLevel),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.activityLevel}% Active',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _getActivityColor(data.activityLevel),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getActivityDescription(data.activityLevel),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid(SensorData data) {
    return Column(
      children: [
        // First row: Motion and Sound
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                title: 'Motion',
                icon: Icons.directions_walk,
                value: data.pir.motion ? 'Detected' : 'None',
                isActive: data.pir.motion,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                title: 'Sound',
                icon: Icons.mic,
                value: data.microphone.status,
                isActive: data.microphone.soundDetected,
                color: Colors.blue,
                subtitle: 'Level: ${data.microphone.soundLevel}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row: All 3 FSR sensors
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                title: 'Left Hand',
                icon: Icons.touch_app,
                value: data.fsr1.status,
                isActive: data.fsr1.value > 10,
                color: Colors.green,
                subtitle: 'Value: ${data.fsr1.value}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorCard(
                title: 'Right Hand',
                icon: Icons.touch_app,
                value: data.fsr2.status,
                isActive: data.fsr2.value > 10,
                color: Colors.green,
                subtitle: 'Value: ${data.fsr2.value}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSensorCard(
                title: 'Knees',
                icon: Icons.touch_app,
                value: data.fsr3.status,
                isActive: data.fsr3.value > 10,
                color: Colors.green,
                subtitle: 'Value: ${data.fsr3.value}',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required String title,
    required IconData icon,
    required String value,
    required bool isActive,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: isActive ? color : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? color : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? color.withOpacity(0.8) : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayStats(SensorProvider provider) {
    final stats = provider.getTodayActivityStats();
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Activity Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Readings',
                  '${stats['totalReadings']}',
                  Icons.sensors,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Movement',
                  '${stats['movementDetections']}',
                  Icons.directions_walk,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Sound',
                  '${stats['soundDetections']}',
                  Icons.mic,
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Peak Activity',
                  '${stats['peakActivity']}%',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(SensorProvider provider) {
    final recentData = provider.sensorHistory.take(10).toList();
    
    if (recentData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: const Center(
          child: Text('No recent activity data'),
        ),
      );
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentData.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = recentData[index];
              final time = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _getActivityColor(data.activityLevel).withOpacity(0.2),
                  child: Icon(
                    data.activityLevel > 50 ? Icons.sensors : Icons.sensors_off,
                    color: _getActivityColor(data.activityLevel),
                    size: 20,
                  ),
                ),
                title: Text(
                  data.summary,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  DateFormat('HH:mm:ss').format(time),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '${data.activityLevel}%',
                  style: TextStyle(
                    color: _getActivityColor(data.activityLevel),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(int level) {
    if (level >= 70) return Colors.red;
    if (level >= 40) return Colors.orange;
    if (level >= 20) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getActivityDescription(int level) {
    if (level >= 70) return 'Very Active';
    if (level >= 40) return 'Active';
    if (level >= 20) return 'Moderate';
    return 'Quiet';
  }
    }