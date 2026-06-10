📡 Dish Align Pro - Technical Architecture Document

1. System Overview
Dish Align Pro is a high-precision field utility application designed for satellite dish technicians. It calculates real-time orbital mechanics (Azimuth, Elevation, and LNB Skew) and guides users via 2D maps, 3D Augmented Reality (AR) overlays, and tactical HUDs.

Core Tech Stack:

Framework: Flutter (Dart)

State Management: Riverpod (flutter_riverpod)

Local Database: Hive (hive_flutter)

Hardware Interfacing: geolocator, sensors_plus, flutter_compass, camera

Mapping: flutter_map, latlong2

2. Boot Sequence & Routing Flow
The app is designed to load instantly and gracefully handle missing hardware permissions without trapping the user in "soft-locks."

main.dart: Initializes Hive (opens custom_satellites and app_settings boxes) and pre-warms the hardware cameras.

SplashScreen & BootManager: * Triggers the native OS Location Permission dialog on the first install.

Crucial Rule: It never blocks the user. Whether GPS is denied, off, or loading, it unconditionally routes the user to the HomeScreen after 500ms so they can access the database indoors.

HomeScreen: The central hub where users select their target satellite from the Hive database and navigate to specific alignment tools.

3. Core State Management (The Engine)
The app relies on a decoupled architecture where hardware streams are converted into global, reactive states via Riverpod.

A. Location Engine (LocationNotifier)
File: core/providers/location_provider.dart

Role: Manages GPS hardware and the Manual Override system.

Lifecycle Hook: Implements WidgetsBindingObserver. If the app drops to the background (e.g., user pulls down the notification drawer to turn on GPS) and resumes, it instantly re-fires _init() to catch the new hardware state.

Manual Override: Allows technicians to spoof their lat/lon to pre-plan jobs. Activating this pauses the hardware stream to save battery.

B. Inclinometer Engine (AccelerometerNotifier)
File: core/providers/accelerometer_provider.dart

Role: Calculates camera pitch and phone roll.

Math: Uses math.atan2 on raw x, y, z gravity vectors. Employs a Low-Pass Filter (_alpha = 0.15) to smooth out hand shakes and prevent UI jitter.

Pitch Stabilization: Uses math.sqrt on X and Y to ensure the Elevation calculation remains locked even if the phone is tilted sideways.

C. Azimuth Engine (CompassProvider)
Role: Streams device heading. Emits a needsCalibration flag if magnetic interference is detected, which triggers UI warnings.

4. UI/UX Architecture (The Tools)
All tracking screens are strictly layout-constrained (using SafeArea, Expanded, and Flexible widgets) to prevent scrolling or overflow.

The "Escape Hatch" Pattern
Every tool screen implements a localized GPS Lock Screen. If locationState.isLocked is false:

The UI is replaced by an "AWAITING SATELLITES" error screen.

It displays the exact error (e.g., "GPS Disabled").

It provides the Escape Hatch Button (ManualGpsDialog), allowing the technician to input coordinates and force the UI to unlock.

Tool Modules:
ActiveTrackingScreen: 2D Top-down orbital map. Combines flutter_map with a custom OrbitalGridPainter to show the true azimuth line against the physical compass heading.

ArViewScreen: 3D Camera overlay. Uses ArWorldPainter to map degrees to screen pixels (pixelsPerDegree). Displays directional arrows if the target is off-screen.

LnbSkewScreen: Visual protractor. Compares target polarization skew against the physical roll of the device.

LOSScannerScreen: Line-of-Sight tool. Uses the camera and elevation pitch to check for physical obstacles (trees, buildings) before installation.

5. Math & Calculation Services
File: core/utils/satellite_math.dart

Role: The brain of the app. Takes User Lat/Lon and Satellite Longitude and outputs the holy trinity of alignment:

True Azimuth: Uses spherical trigonometry.

Elevation: Accounts for the curvature of the Earth and the Clarke Belt distance (~35,786 km).

LNB Skew: Polarization offset angle.

Declination: Uses MagneticService to convert True North to Magnetic North based on localized magnetic drift.

6. Persistent Storage (Hive)
Setup: Hive is initialized in main.dart. Requires hive_generator and build_runner for TypeAdapters.

Models: * Satellite (Name, Position, Hemisphere, Bands).

Transponder (Frequency, Symbol Rate, Polarity).

Repository: SatelliteRepository acts as the interface between Riverpod providers and the Hive Box, handling CRUD (Create, Read, Update, Delete) operations for the Custom Satellite registry.

7. Future Development Notes & Best Practices
Adding New Tools: Any new tracking tool must import global_settings_menu.dart and implement the "Escape Hatch" lock screen at the top of its build method to prevent math crashes from 0.0 coordinates.

Audio Loops: The audioplayers package is set to ReleaseMode.loop. Always ensure _audioPlayer.stop() and _audioPlayer.dispose() are called in the dispose() method of stateful widgets to prevent memory leaks and ghost audio.

Asset Management: When adding new icons or tutorial images, they must be explicitly declared with trailing slashes or exact filenames in pubspec.yaml (e.g., assets/images/), otherwise they will fail to render in the Release APK.