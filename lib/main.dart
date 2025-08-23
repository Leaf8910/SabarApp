import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/screens/user_profile_setup_screen.dart';
import 'package:myapp/screens/welcome_screen.dart';
import 'package:myapp/screens/location_settings_screen.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/screens/auth_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/qibla_screen.dart';
import 'package:myapp/screens/prayer_guidance_screen.dart';
import 'package:myapp/screens/prayer_times_screen.dart';
import 'package:myapp/screens/quran_verses_screen.dart';
import 'package:myapp/providers/prayer_time_provider.dart';
// Add these imports for sensor functionality
import 'package:myapp/providers/sensor_provider.dart';
import 'package:myapp/screens/sensor_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => PrayerTimeProvider()),
        ChangeNotifierProvider(create: (context) => UserProfileProvider()),
        ChangeNotifierProvider(create: (context) => SensorProvider()), // Add this line
        StreamProvider<User?>(
          create: (context) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Islamic Prayer App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
        );
      },
    );
  }
}

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const AuthScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const AuthScreen();
      },
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) {
        return const AuthScreen();
      },
    ),
    GoRoute(
      path: '/welcome',
      builder: (BuildContext context, GoRouterState state) {
        return const WelcomeScreen();
      },
    ),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
    GoRoute(
      path: '/qibla',
      builder: (BuildContext context, GoRouterState state) {
        return const QiblaScreen();
      },
    ),
    GoRoute(
      path: '/prayer_guidance',
      builder: (BuildContext context, GoRouterState state) {
        return const PrayerGuidanceScreen();
      },
    ),
    GoRoute(
      path: '/prayer_times',
      builder: (BuildContext context, GoRouterState state) {
        return const PrayerTimesScreen();
      },
    ),
    GoRoute(
      path: '/profile_setup',
      builder: (BuildContext context, GoRouterState state) {
        return const UserProfileSetupScreen();
      },
    ),
    GoRoute(
      path: '/quran_verses',
      builder: (BuildContext context, GoRouterState state) {
        return const QuranVersesScreen();
      },
    ),
    GoRoute(
      path: '/location_settings',
      builder: (BuildContext context, GoRouterState state) {
        return const LocationSettingsScreen();
      },
    ),
    // Add this route for the sensor dashboard
    GoRoute(
      path: '/sensors',
      builder: (BuildContext context, GoRouterState state) {
        return const SensorDashboardScreen();
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Page not found: ${state.uri.path}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);