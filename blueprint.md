# Islamic Prayer App Blueprint

## Project Overview

This application aims to provide a comprehensive Islamic prayer experience for users, assisting them with their daily prayers through various features. The app will be available on mobile and web platforms, built using Flutter and leveraging Firebase for backend services.

### Core Features:
- **User Authentication:** Secure sign-up and login functionality powered by Firebase Authentication.
- **Daily Prayer Guidance:** Instructions and guidance for performing daily prayers.
- **Prayer Time Schedules:** Accurate prayer times calculated based on the user's geographical location and timezone.
- **Prayer Time Notifications:** Timely notifications to alert users when prayer times are near.
- **Qibla Compass:** A feature to help users determine the direction of the Kaabah (Qibla) for prayer.

### Technology Stack:
- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Authentication, potentially Firestore for user data/preferences, though not explicitly requested yet)
- **State Management:** Provider
- **Navigation:** go_router
- **Location & Sensors:** geolocator, flutter_compass (or similar for Qibla)
- **Notifications:** flutter_local_notifications
- **Prayer Time Calculation:** adhan_dart
- **Theming:** Material Design 3, google_fonts

## Detailed Outline of Implemented Features

### Initial Version (Current State after this plan's execution):

#### 1. Project Setup and Dependencies:
- **`pubspec.yaml`:** Configured with core Flutter packages, Firebase SDKs (`firebase_core`, `firebase_auth`), state management (`provider`), navigation (`go_router`), location (`geolocator`), notifications (`flutter_local_notifications`), prayer time calculation (`adhan_dart`), and UI enhancements (`google_fonts`, `flutter_compass`).
- **`main.dart`:** Initialized Firebase.

#### 2. Theming and Visual Design:
- **Material Design 3:** Application theme implemented using `ThemeData` with `ColorScheme.fromSeed` for consistent light and dark modes.
- **Typography:** `google_fonts` integrated for custom font usage in the `TextTheme`.
- **`ThemeProvider`:** A `ChangeNotifierProvider` to manage and toggle between light and dark themes.
- **Aesthetics:** Emphasis on modern components, clean spacing, and clear typography.

#### 3. Routing and Navigation:
- **`go_router`:** Configured for declarative navigation, handling different app routes (e.g., `/`, `/login`, `/register`, `/home`, `/qibla`).
- **Authentication Redirects:** `go_router` will manage redirects for authenticated and unauthenticated users.

#### 4. User Authentication (Firebase Auth):
- **Sign-up Screen:** UI and logic for new user registration with email and password.
- **Login Screen:** UI and logic for existing user login with email and password.
- **Firebase Integration:** Uses `firebase_auth` for all authentication operations.
- **Error Handling:** Basic error handling for authentication failures.

#### 5. Prayer Time Features:
- **Location Services:** Utilizes `geolocator` to get the user's current location (latitude and longitude).
- **Prayer Time Calculation:** `adhan_dart` calculates daily prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha) based on the fetched location and detected timezone.
- **Display:** A dedicated section on the home screen to display the calculated prayer times.

#### 6. Notifications:
- **Local Notifications:** `flutter_local_notifications` is used to schedule notifications for each prayer time, reminding the user when it's near.
- **Permissions:** Handles requesting necessary notification permissions from the user.

#### 7. Qibla Compass:
- **Compass Integration:** Integrates `flutter_compass` (or a similar solution) to read device orientation.
- **Direction Calculation:** Calculates the Qibla direction based on the user's current location and the Kaabah's coordinates.
- **UI:** A visual compass component that points towards the Qibla.

#### 8. Daily Prayer Guidance:
- **Basic Content:** A dedicated screen or section providing simple text-based guidance or steps for performing daily prayers (e.g., steps for Wudu, basic Rakat count).

## Current Requested Change Plan (Developing the Islamic Prayer App)

This section outlines the steps to be taken to implement the features described in the "Detailed Outline of Implemented Features" section.

### Step-by-Step Implementation:

1.  **Create `blueprint.md` (Completed in this step).**
2.  **Update `.idx/mcp.json` with Firebase server configuration.**
3.  **Modify `pubspec.yaml` to add all required dependencies:**
    *   `firebase_core`: For Firebase initialization.
    *   `firebase_auth`: For user authentication.
    *   `provider`: For state management.
    *   `go_router`: For declarative routing and navigation.
    *   `geolocator`: For location services (prayer times, Qibla).
    *   `flutter_local_notifications`: For prayer time notifications.
    *   `adhan_dart`: For accurate prayer time calculations.
    *   `google_fonts`: For custom font integration.
    *   `flutter_compass`: For the Qibla compass functionality.
    *   `permission_handler`: For handling runtime permissions (location, notifications).
4.  **Run `flutter pub get`** to fetch the new dependencies.
5.  **Configure Firebase in `lib/main.dart`:**
    *   Add `WidgetsFlutterBinding.ensureInitialized();` and `await Firebase.initializeApp(...)` with `DefaultFirebaseOptions.currentPlatform`. (Note: `firebase_options.dart` needs to be generated by the user using `flutterfire configure`). I will add a comment for this.
6.  **Implement `ThemeProvider` and basic theming:**
    *   Create `lib/theme/app_theme.dart` to define light and dark `ThemeData` objects using `ColorScheme.fromSeed` and `google_fonts`.
    *   Create `lib/providers/theme_provider.dart` for `ChangeNotifier` to manage `ThemeMode`.
    *   Integrate `ThemeProvider` into `main.dart` using `ChangeNotifierProvider` and `Consumer`.
7.  **Set up `go_router`:**
    *   Define routes for `/`, `/login`, `/register`, `/home`, `/qibla`, `/prayer_guidance`.
    *   Implement `MaterialApp.router` in `main.dart`.
    *   Add initial redirect logic for authentication state.
8.  **Develop Authentication Screens (`lib/screens/auth_screen.dart`):**
    *   Create a single screen with toggles/tabs for "Login" and "Sign Up".
    *   Implement `TextFormField`s for email and password.
    *   Add `ElevatedButton`s for actions (Login, Sign Up).
    *   Integrate `firebase_auth` methods (`createUserWithEmailAndPassword`, `signInWithEmailAndPassword`).
    *   Show loading indicators and error messages.
    *   Navigate on successful authentication using `context.go('/home')`.
9.  **Develop Home Screen (`lib/screens/home_screen.dart`):**
    *   Basic `Scaffold` with `AppBar` and `BottomNavigationBar` for navigation to Prayer Times, Qibla, Guidance.
    *   Display a welcome message.
    *   Add a Logout button.
10. **Implement Prayer Times Functionality:**
    *   Create `lib/providers/prayer_time_provider.dart` using `ChangeNotifier`.
    *   In `prayer_time_provider.dart`:
        *   Request location permission using `permission_handler`.
        *   Get current location using `geolocator`.
        *   Calculate prayer times for the current day using `adhan_dart`.
        *   Expose prayer times to the UI.
    *   Display prayer times on `home_screen.dart` or a dedicated `lib/screens/prayer_times_screen.dart`.
11. **Implement Notifications:**
    *   Initialize `flutter_local_notifications` in `main.dart` or a dedicated notification service.
    *   Request notification permission.
    *   In `prayer_time_provider.dart` (or a separate service), schedule notifications for each prayer time.
12. **Implement Qibla Compass (`lib/screens/qibla_screen.dart`):**
    *   Request location permission.
    *   Use `flutter_compass` to get device heading.
    *   Calculate Qibla direction based on current location and Kaabah coordinates.
    *   Draw a compass needle or indicator pointing towards the Qibla.
13. **Implement Prayer Guidance Screen (`lib/screens/prayer_guidance_screen.dart`):**
    *   Simple `Scaffold` with `AppBar` and text content for prayer instructions.
14. **Ensure UI/UX and Accessibility:**
    *   Review all screens for mobile responsiveness.
    *   Apply consistent padding, margins, and typography.
    *   Consider semantic labels for accessibility widgets.
15. **Continuous Error Checking:**
    *   After each major file modification:
        *   Run `flutter pub get`.
        *   Run `flutter analyze`.
        *   Run `flutter format .`.
    *   Monitor terminal for compilation errors and preview for runtime issues.

---
