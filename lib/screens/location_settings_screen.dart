// screens/location_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';

import 'package:myapp/providers/prayer_time_provider.dart';
import 'package:myapp/providers/user_profile_provider.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  bool _isCheckingLocation = false;
  String? _locationStatus;
  Position? _currentPosition;
  String? _selectedCountry;

  // Available countries list (same as in user profile setup)
  final List<String> _countries = [
    'Afghanistan', 'Albania', 'Algeria', 'Argentina', 'Australia', 'Austria',
    'Bahrain', 'Bangladesh', 'Belgium', 'Bosnia and Herzegovina', 'Brazil', 'Brunei',
    'Bulgaria', 'Canada', 'China', 'Croatia', 'Cyprus', 'Czech Republic',
    'Denmark', 'Egypt', 'Finland', 'France', 'Germany', 'Greece',
    'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Italy',
    'Japan', 'Jordan', 'Kazakhstan', 'Kuwait', 'Lebanon', 'Libya',
    'Malaysia', 'Maldives', 'Morocco', 'Netherlands', 'New Zealand', 'Norway',
    'Oman', 'Pakistan', 'Palestine', 'Philippines', 'Poland', 'Portugal',
    'Qatar', 'Romania', 'Russia', 'Saudi Arabia', 'Singapore', 'Somalia',
    'South Africa', 'Spain', 'Sri Lanka', 'Sudan', 'Sweden', 'Switzerland',
    'Syria', 'Tunisia', 'Turkey', 'UAE', 'United Kingdom', 'United States',
    'Uzbekistan', 'Yemen', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeLocationSettings();
  }

  void _initializeLocationSettings() {
    final prayerTimeProvider = Provider.of<PrayerTimeProvider>(context, listen: false);
    final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
    
    // Set initial selected country from user profile or prayer provider
    _selectedCountry = prayerTimeProvider.selectedCountry ?? 
                     userProfileProvider.country;
    
    if (_selectedCountry?.isEmpty == true) {
      _selectedCountry = null;
    }
    
    // Check current location if using GPS mode
    if (prayerTimeProvider.locationMode == LocationMode.currentLocation) {
      _checkCurrentLocation();
    }
  }

  Future<void> _checkCurrentLocation() async {
    setState(() {
      _isCheckingLocation = true;
      _locationStatus = 'Checking location...';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services are disabled';
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permissions are denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Location permissions are permanently denied';
        });
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _locationStatus = 'Location found successfully';
      });

    } catch (e) {
      setState(() {
        _locationStatus = 'Error getting location: $e';
      });
    } finally {
      setState(() {
        _isCheckingLocation = false;
      });
    }
  }

  Future<void> _enableCurrentLocation() async {
    final prayerTimeProvider = Provider.of<PrayerTimeProvider>(context, listen: false);
    
    setState(() {
      _isCheckingLocation = true;
    });

    try {
      await prayerTimeProvider.setLocationMode(LocationMode.currentLocation);
      await _checkCurrentLocation();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to current location mode'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to enable location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
        });
      }
    }
  }

  Future<void> _selectCountryMode(String country) async {
    final prayerTimeProvider = Provider.of<PrayerTimeProvider>(context, listen: false);
    
    try {
      await prayerTimeProvider.setSelectedCountry(country);
      await prayerTimeProvider.setLocationMode(LocationMode.selectedCountry);
      
      setState(() {
        _selectedCountry = country;
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location set to $country'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to set country: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: Consumer<PrayerTimeProvider>(
        builder: (context, prayerTimeProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header explanation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Prayer Time Location',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose how you want to determine your location for accurate prayer times. You can use your current GPS location or select a country.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Current location option
                _buildLocationOption(
                  title: 'Use Current Location (GPS)',
                  subtitle: 'Automatically detect your location using GPS',
                  icon: Icons.gps_fixed,
                  isSelected: prayerTimeProvider.locationMode == LocationMode.currentLocation,
                  onTap: _enableCurrentLocation,
                  trailing: _buildCurrentLocationStatus(prayerTimeProvider),
                ),
                const SizedBox(height: 16),

                // Country selection option
                _buildLocationOption(
                  title: 'Select Country',
                  subtitle: _selectedCountry != null 
                      ? 'Using: $_selectedCountry'
                      : 'Choose a specific country',
                  icon: Icons.public,
                  isSelected: prayerTimeProvider.locationMode == LocationMode.selectedCountry,
                  onTap: _showCountrySelection,
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Current settings summary
                _buildCurrentSettings(prayerTimeProvider),
                const SizedBox(height: 24),

                // Location permissions and troubleshooting
                _buildTroubleshootingSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLocationStatus(PrayerTimeProvider provider) {
    if (provider.locationMode != LocationMode.currentLocation) {
      return const SizedBox.shrink();
    }

    if (_isCheckingLocation) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_currentPosition != null) {
      return Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 20,
      );
    }

    if (_locationStatus != null && _locationStatus!.contains('Error')) {
      return Icon(
        Icons.error,
        color: Colors.red,
        size: 20,
      );
    }

    return Icon(
      Icons.location_searching,
      color: Colors.orange,
      size: 20,
    );
  }

  Widget _buildCurrentSettings(PrayerTimeProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            'Location Mode',
            provider.locationMode == LocationMode.currentLocation
                ? 'Current Location (GPS)'
                : 'Selected Country',
            Icons.location_on,
          ),
          _buildSettingRow(
            'Location',
            provider.locationDisplayText,
            Icons.place,
          ),
          if (_currentPosition != null)
            _buildSettingRow(
              'Coordinates',
              '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
              Icons.my_location,
            ),
          if (_locationStatus != null)
            _buildSettingRow(
              'Status',
              _locationStatus!,
              _locationStatus!.contains('Error') ? Icons.error : Icons.info,
            ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Troubleshooting',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_applications),
                  title: const Text('App Settings'),
                  subtitle: const Text('Open app settings to manage permissions'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _openAppSettings,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Location Settings'),
                  subtitle: const Text('Open device location settings'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _openLocationSettings,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Test Location'),
                  subtitle: const Text('Check current location access'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _checkCurrentLocation,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCountrySelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Country',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _countries.length,
                    itemBuilder: (context, index) {
                      final country = _countries[index];
                      final isSelected = country == _selectedCountry;
                      
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(
                          country,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _selectCountryMode(country);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Settings Help'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Location (GPS)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Uses your device\'s GPS to automatically determine your exact location. This provides the most accurate prayer times but requires location permission and GPS to be enabled.',
              ),
              SizedBox(height: 16),
              Text(
                'Select Country',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Uses a preset location for the selected country. This doesn\'t require GPS or location permissions and works offline, but may be less accurate than your exact location.',
              ),
              SizedBox(height: 16),
              Text(
                'Troubleshooting',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '• Make sure location services are enabled on your device\n'
                '• Grant location permission to this app\n'
                '• Try switching between location modes\n'
                '• Check your internet connection for initial setup',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}