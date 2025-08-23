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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          // Welcome section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'Assalamu Alaikum!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your daily companion for Islamic worship',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Quick actions grid
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildActionCard(
                context,
                icon: Icons.schedule,
                title: 'Prayer Times',
                subtitle: 'View today\'s prayers',
                onTap: () => context.go('/prayer_times'),
                color: Colors.blue,
              ),
              _buildActionCard(
                context,
                icon: Icons.explore,
                title: 'Qibla Finder',
                subtitle: 'Find direction to Kaaba',
                onTap: () => context.go('/qibla'),
                color: Colors.green,
              ),
              _buildActionCard(
                context,
                icon: Icons.menu_book,
                title: 'Quran Verses',
                subtitle: 'Read & listen to Quran',
                onTap: () => context.go('/quran_verses'),
                color: Colors.purple,
              ),
              _buildActionCard(
                context,
                icon: Icons.book,
                title: 'Prayer Guide',
                subtitle: 'Learn prayer methods',
                onTap: () => context.go('/prayer_guidance'),
                color: Colors.orange,
              ),
              _buildActionCard(
                context,
                icon: Icons.sensors,
                title: 'Prayer Sensors',
                subtitle: 'Monitor prayer activity',
                onTap: () => context.go('/sensors'),
                color: Colors.teal,
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Today's reminder section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
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
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Daily Reminder',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '"And it is He who created the heavens and earth in truth. And the day He says, \'Be,\' and it is, His word is the truth." - Quran 6:73',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
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