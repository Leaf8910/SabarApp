import 'package:flutter/material.dart';

class PrayerGuidanceScreen extends StatelessWidget {
  const PrayerGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Guidance'),
      ),
      body: SingleChildScrollView(
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
      ),
    );
  }
}
