import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/providers/prayer_time_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Make _widgetOptions a getter so it's created within the build context
  List<Widget> get _widgetOptions => <Widget>[
    const HomeContent(),
    const PrayerTimesScreenContent(),
    const QiblaScreenContent(),
    const PrayerGuidanceScreenContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/prayer_times');
        break;
      case 2:
        context.go('/qibla');
        break;
      case 3:
        context.go('/prayer_guidance');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Islamic Prayer App'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) {
                return;
              } // Check mounted after async operation
              context.go('/'); // Redirect to login/auth screen
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Prayer Times',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Qibla',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Guidance',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Assalamu Alaikum!',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 20),
          Text(
            'Your daily companion for prayer.',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => context.go('/prayer_times'),
            icon: const Icon(Icons.schedule),
            label: const Text('View Prayer Times'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.go('/qibla'),
            icon: const Icon(Icons.explore),
            label: const Text('Find Qibla Direction'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder for PrayerTimesScreenContent
class PrayerTimesScreenContent extends StatelessWidget {
  const PrayerTimesScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerTimeProvider>(
      builder: (context, prayerTimeProvider, child) {
        // No FutureBuilder here, as fetchPrayerTimes is called in initState of PrayerTimesScreen
        if (prayerTimeProvider.errorMessage != null && prayerTimeProvider.errorMessage!.isNotEmpty) {
          return Center(child: Text('Error: ${prayerTimeProvider.errorMessage}'));
        } else if (prayerTimeProvider.prayerTimes == null) {
          return Center(child: Text(prayerTimeProvider.errorMessage ?? 'Fetching prayer times...'));
        } else {
          final prayerTimes = prayerTimeProvider.prayerTimes!;
          final currentLocation = prayerTimeProvider.currentLocation;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: <Widget>[
                Text(
                  'Todays Prayer Times',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildPrayerTimeRow('Fajr', prayerTimes.fajr, context),
                _buildPrayerTimeRow('Sunrise', prayerTimes.sunrise, context),
                _buildPrayerTimeRow('Dhuhr', prayerTimes.dhuhr, context),
                _buildPrayerTimeRow('Asr', prayerTimes.asr, context),
                _buildPrayerTimeRow('Maghrib', prayerTimes.maghrib, context),
                _buildPrayerTimeRow('Isha', prayerTimes.isha, context),
                const SizedBox(height: 20),
                if (currentLocation != null) // Only show location if available
                  Text(
                    'Location: ${currentLocation.latitude.toStringAsFixed(2)}, ${currentLocation.longitude.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ) else Text('Location data not available.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildPrayerTimeRow(String name, DateTime? time, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            Text(time != null ? DateFormat.jm().format(time) : 'N/A',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Placeholder for QiblaScreenContent
class QiblaScreenContent extends StatelessWidget {
  const QiblaScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    // This will eventually contain the Qibla compass logic
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Qibla Compass',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          const Icon(Icons.explore, size: 100, color: Colors.teal),
          const SizedBox(height: 20),
          Text(
            'Orient your device towards the Kaabah.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Placeholder for PrayerGuidanceScreenContent
class PrayerGuidanceScreenContent extends StatelessWidget {
  const PrayerGuidanceScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Daily Prayer Guidance',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Text(
            'Fajr Prayer (2 Rakat)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Fajr prayer is performed before sunrise. It consists of 2 units (rakats).',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Dhuhr Prayer (4 Rakat)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Dhuhr prayer is performed after true noon until Asr. It consists of 4 units (rakats).',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Asr Prayer (4 Rakat)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Asr prayer is performed after Dhuhr until sunset. It consists of 4 units (rakats).',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Maghrib Prayer (3 Rakat)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Maghrib prayer is performed after sunset until Isha. It consists of 3 units (rakats).',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Isha Prayer (4 Rakat)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Isha prayer is performed after Maghrib until Fajr. It consists of 4 units (rakats).',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 30),
          Text(
            '*Note: This is a simplified guide. Please refer to comprehensive Islamic resources for detailed prayer methods.*',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
