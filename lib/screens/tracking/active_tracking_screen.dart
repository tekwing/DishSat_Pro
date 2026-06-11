import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:ui' as ui;

import '../../models/satellite_model.dart';
import '../../core/providers/compass_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/active_satellite_provider.dart';
import '../../core/utils/satellite_math.dart';
import '../../core/providers/settings_provider.dart';
import '../setting/settings_menu.dart'; // Ensure correct path for ManualGpsDialog
import '../tutorial/tutorial_dialog.dart';

// ==========================================
// PREMIUM COLORS
// ==========================================
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class ActiveTrackingScreen extends ConsumerStatefulWidget {
  const ActiveTrackingScreen({super.key});

  @override
  ConsumerState<ActiveTrackingScreen> createState() =>
      _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends ConsumerState<ActiveTrackingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isPinging = true;
  late AudioPlayer _audioPlayer;
  bool _isAppInForeground = true;

  // Track the previous states to know exactly when to swap audio tracks
  bool _wasLocked = false;
  bool _wasSoundEnabled = false;

  final MapController _mapController = MapController();
  final double _currentZoom = 3.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();

    // Set the audio player to infinitely loop whatever track is currently loaded!
    _audioPlayer.setReleaseMode(ReleaseMode.loop);

    _startProximityLoop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;

      // --- FORCE THE LOOP TO RE-EVALUATE AUDIO ---
      // By toggling these, the next loop iteration will see a "change"
      // and trigger the audio logic block automatically.
      _wasLocked = !_wasLocked;
      _wasSoundEnabled = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppInForeground = false;
      _audioPlayer.stop();
    }
  }

  Future<void> _startProximityLoop() async {
    while (_isPinging && mounted) {
      // --- NEW FIX: PAUSE EVERYTHING IF APP IS IN BACKGROUND ---
      if (!_isAppInForeground) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }

      if (_audioPlayer.state == PlayerState.disposed) {
        _audioPlayer = AudioPlayer();
        _audioPlayer.setReleaseMode(ReleaseMode.loop);
      }
      final locationState = ref.read(locationProvider);
      final settings = ref.read(settingsProvider);

      // --- NEW FIX: SILENCE AUDIO & PAUSE MATH IF NO GPS LOCK ---
      if (!locationState.isLocked ||
          locationState.lat == null ||
          locationState.lon == null) {
        await _audioPlayer.stop();
        _wasSoundEnabled = false;
        _wasLocked = false;
        await Future.delayed(const Duration(milliseconds: 1000));
        continue; // Skip the rest of the loop until GPS returns!
      }

      final targetSatellite = ref.read(activeSatelliteProvider);
      final compassState = ref.read(compassProvider);

      final currentAzimuth = compassState.azimuth;
      final userLat = locationState.lat!;
      final userLon = locationState.lon!;

      final double currentLocalDeclination = MagneticService.getDeclination(
        userLat,
        userLon,
      );
      final trueAzimuth = SatelliteMath.getAzimuth(
        userLat: userLat,
        userLon: userLon,
        satLon: targetSatellite.position,
        useTrueNorth: settings.useTrueNorth,
        magneticDeclination: currentLocalDeclination,
      );

      double azDiff = (trueAzimuth - currentAzimuth).abs();
      if (azDiff > 180) azDiff = 360 - azDiff;

      final bool isLocked = azDiff < 2.0;

      // --- 1. CONTINUOUS AUDIO LOGIC (WITH STOP BUGFIX) ---
      if (settings.enableSound) {
        if (isLocked != _wasLocked || !_wasSoundEnabled) {
          await _audioPlayer.stop(); // Clear buffer before swapping tracks
          if (isLocked) {
            await _audioPlayer.play(AssetSource('audio/lock.mp3'));
          } else {
            await _audioPlayer.play(AssetSource('audio/beep.mp3'));
          }
        }
      } else {
        if (_wasSoundEnabled) {
          await _audioPlayer.stop();
        }
      }

      // --- 2. HAPTIC FEEDBACK LOGIC ---
      if (isLocked && settings.enableVibration) {
        HapticFeedback.heavyImpact();
      }

      _wasLocked = isLocked;
      _wasSoundEnabled = settings.enableSound;

      await Future.delayed(
        isLocked
            ? const Duration(milliseconds: 1000)
            : const Duration(milliseconds: 500),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isPinging = false;
    _audioPlayer.dispose();
    super.dispose();
    _mapController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetSatellite = ref.watch(activeSatelliteProvider);
    final locationState = ref.watch(locationProvider);
    final settings = ref.watch(settingsProvider);

    // ==========================================
    // UPGRADED GPS LOCK SCREEN w/ ESCAPE HATCH
    // ==========================================
    if (!locationState.isLocked ||
        locationState.lat == null ||
        locationState.lon == null ||
        (locationState.lat == 0.0 && locationState.lon == 0.0)) {
      final bool hasError = locationState.error != null;

      return Scaffold(
        backgroundColor: _bgDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hasError
                      ? Icons.location_disabled_rounded
                      : Icons.satellite_alt,
                  color: hasError ? Colors.redAccent : _alertOrange,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  hasError ? "GPS UNAVAILABLE" : "AWAITING SATELLITES",
                  style: TextStyle(
                    color: hasError ? Colors.redAccent : _alertOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // --- UPDATED CLEAR INSTRUCTIONAL TEXT ---
                Text(
                  hasError
                      ? "${locationState.error!.toUpperCase()}\n\nPlease enable your device's hardware GPS, or enter your coordinates manually to bypass."
                      : "Searching for hardware GPS lock...\n\nPlease wait, or enter your coordinates manually to bypass.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 32),

                if (!hasError)
                  const CircularProgressIndicator(color: _alertOrange)
                else
                  const SizedBox(height: 20),

                const SizedBox(height: 40),

                // --- THE ESCAPE HATCH BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.edit_location_alt,
                      color: _accentCyan,
                    ),
                    label: const Text(
                      "ENTER MANUAL OVERRIDE",
                      style: TextStyle(
                        color: _accentCyan,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _accentCyan.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      backgroundColor: _accentCyan.withValues(alpha: 0.05),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const ManualGpsDialog(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userLat = locationState.lat!;
    final userLon = locationState.lon!;

    final double currentLocalDeclination = MagneticService.getDeclination(
      userLat,
      userLon,
    );

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "TRACKING: ${targetSatellite.name}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
            Text(
              "${targetSatellite.formattedPosition} • ${targetSatellite.bands.join("/")}-Band",
              style: TextStyle(
                color: _accentCyan.withValues(alpha: 0.8),
                fontSize: 11,
                fontFamily: 'Courier',
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: _accentCyan),
            onPressed: () {
              ImageTutorialDialog.show(
                context,
                title: "Map Azimuth Guide",
                description:
                    "Align the dish to the target satellite using the map view.",
                instructions: [
                  "Stand 0.5–1 meter (2–3 feet) away from the dish for best compass accuracy.",
                  "Use the map view to identify the target satellite direction.",
                  "Keep the device facing the same direction as the dish.",
                  "Rotate the dish left or right while monitoring the live azimuth indicator.",
                  "Continue until the current azimuth matches the target azimuth.",
                  "When aligned, the indicator will turn green and the position is locked.",
                ],
                imagePath: 'assets/images/tutorial_tracking.jpg',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderLight, width: 2),
                  color: const Color(0xFF0B192C),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(userLat, userLon),
                              initialZoom: _currentZoom,
                              interactionOptions: const InteractionOptions(
                                flags:
                                    InteractiveFlag.pinchZoom |
                                    InteractiveFlag.doubleTapZoom,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                                userAgentPackageName:
                                    'com.example.dish_align_pro',
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: _accentCyan,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      final currentLiveZoom =
                                          _mapController.camera.zoom;
                                      final newZoom = (currentLiveZoom + 1.0)
                                          .clamp(1.0, 18.0);

                                      _mapController.move(
                                        LatLng(userLat, userLon),
                                        newZoom,
                                      );
                                    },
                                  ),
                                  const SizedBox(
                                    height: 1,
                                    width: 30,
                                    child: ColoredBox(color: Colors.white10),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove,
                                      color: _accentCyan,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      final currentLiveZoom =
                                          _mapController.camera.zoom;
                                      final newZoom = (currentLiveZoom - 1.0)
                                          .clamp(1.0, 18.0);

                                      _mapController.move(
                                        LatLng(userLat, userLon),
                                        newZoom,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Consumer(
                            builder: (context, ref, child) {
                              final compassState = ref.watch(compassProvider);
                              final currentAzimuth = compassState.azimuth;

                              final trueAzimuth = SatelliteMath.getAzimuth(
                                userLat: userLat,
                                userLon: userLon,
                                satLon: targetSatellite.position,
                                useTrueNorth: settings.useTrueNorth,
                                magneticDeclination: currentLocalDeclination,
                              );

                              double azDiff = (trueAzimuth - currentAzimuth)
                                  .abs();
                              if (azDiff > 180) azDiff = 360 - azDiff;
                              final bool isLocked = azDiff < 2.0;

                              return Stack(
                                children: [
                                  IgnorePointer(
                                    child: CustomPaint(
                                      size: Size.infinite,
                                      painter: OrbitalGridPainter(
                                        currentAzimuth: currentAzimuth,
                                        trueAzimuth: trueAzimuth,
                                        isLocked: isLocked,
                                      ),
                                    ),
                                  ),
                                  IgnorePointer(
                                    child: Center(
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(
                                            alpha: 0.2,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white38,
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2.0,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  OverflowBox(
                                    maxWidth: constraints.maxWidth,
                                    maxHeight: constraints.maxHeight,
                                    child: Stack(
                                      children: [
                                        _buildSafeMapBadge(
                                          satellite: targetSatellite,
                                          trueAzimuth: trueAzimuth,
                                          isLocked: isLocked,
                                          radiusFactor: 0.35,
                                          mapConstraints: constraints,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Consumer(
              builder: (context, ref, child) {
                final compassState = ref.watch(compassProvider);
                final currentAzimuth = compassState.azimuth;

                final trueAzimuth = SatelliteMath.getAzimuth(
                  userLat: userLat,
                  userLon: userLon,
                  satLon: targetSatellite.position,
                  useTrueNorth: settings.useTrueNorth,
                  magneticDeclination: currentLocalDeclination,
                );

                double azDiff = (trueAzimuth - currentAzimuth).abs();
                if (azDiff > 180) azDiff = 360 - azDiff;
                final bool isLocked = azDiff < 2.0;

                return _buildTelemetryPanel(
                  isLocked,
                  currentAzimuth,
                  trueAzimuth,
                  settings.useTrueNorth,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryPanel(
    bool isLocked,
    double currentAzimuth,
    double trueAzimuth,
    bool useTrueNorth,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TELEMETRY DATA",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: useTrueNorth
                          ? _accentCyan.withValues(alpha: 0.1)
                          : Colors.purpleAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: useTrueNorth
                            ? _accentCyan.withValues(alpha: 0.5)
                            : Colors.purpleAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      useTrueNorth
                          ? "🧭 TRUE NORTH MODE (GPS)"
                          : "🧲 MAGNETIC MODE (COMPASS)",
                      style: TextStyle(
                        color: useTrueNorth ? _accentCyan : Colors.purpleAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isLocked ? _successGreen : _alertOrange)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (isLocked ? _successGreen : _alertOrange)
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      isLocked ? "LOCKED" : "SEARCHING",
                      style: TextStyle(
                        color: isLocked ? _successGreen : _alertOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.6, end: 1),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTelemetryData("AZIMUTH", currentAzimuth, trueAzimuth, "°"),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: 0.2).fade();
  }

  Widget _buildSafeMapBadge({
    required Satellite satellite,
    required double trueAzimuth,
    required double radiusFactor,
    required BoxConstraints mapConstraints,
    bool isLocked = false,
  }) {
    final center = Offset(
      mapConstraints.maxWidth / 2,
      mapConstraints.maxHeight / 2,
    );
    final radius = mapConstraints.maxWidth * radiusFactor;

    final double azRad = (trueAzimuth - 90) * (math.pi / 180);
    final double x = center.dx + radius * math.cos(azRad);
    final double y = center.dy + radius * math.sin(azRad);

    final double safeX = (x - 45).clamp(12.0, mapConstraints.maxWidth - 110.0);
    final double safeY = (y - 14).clamp(12.0, mapConstraints.maxHeight - 40.0);

    return Positioned(
      left: safeX,
      top: safeY,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2124),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isLocked ? _successGreen : Colors.black26,
            width: isLocked ? 1.0 : 0.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Icon(
                Icons.satellite_alt,
                color: isLocked ? _successGreen : Colors.white,
                size: 11,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        satellite.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        satellite.formattedPosition,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isLocked ? "TARGET LOCKED" : "ALIGNING...",
                    style: TextStyle(
                      color: isLocked ? _successGreen : _alertOrange,
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isLocked ? 1 : 0).shimmer(color: Colors.white24);
  }

  Widget _buildTelemetryData(
    String label,
    double current,
    double target,
    String unit,
  ) {
    Color valueColor = (current - target).abs() < 2
        ? _successGreen
        : Colors.white;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${current.toStringAsFixed(1)}$unit",
          style: TextStyle(
            color: valueColor,
            fontFamily: 'Courier',
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "TGT: ${target.toStringAsFixed(1)}$unit",
          style: const TextStyle(
            color: Colors.white38,
            fontFamily: 'Courier',
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// ORBITAL GRID PAINTER
// ==========================================
class OrbitalGridPainter extends CustomPainter {
  final double currentAzimuth;
  final double trueAzimuth;
  final bool isLocked;

  OrbitalGridPainter({
    required this.currentAzimuth,
    required this.trueAzimuth,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double ringSpacing = 22.0;
    final double maxRadius = ringSpacing * 4;

    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(center, maxRadius, [
        const Color(0xFF00E5FF).withValues(alpha: 0.12),
        Colors.transparent,
      ]);
    canvas.drawCircle(center, maxRadius, glowPaint);

    final innerGridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final outerGridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, ringSpacing * 1, innerGridPaint);
    canvas.drawCircle(center, ringSpacing * 2, innerGridPaint);
    canvas.drawCircle(center, ringSpacing * 3, innerGridPaint);
    canvas.drawCircle(center, maxRadius, outerGridPaint);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 10) {
      final double angleRad = i * (math.pi / 180);
      final bool isMajor = i % 90 == 0;
      final bool isMid = i % 30 == 0;

      final double tickLength = isMajor ? 8.0 : (isMid ? 5.0 : 2.5);

      tickPaint.strokeWidth = isMajor ? 2.0 : 1.0;
      tickPaint.color = isMajor
          ? const Color(0xFF00E5FF)
          : Colors.white.withValues(alpha: 0.3);

      final double startX =
          center.dx + (maxRadius - tickLength) * math.cos(angleRad);
      final double startY =
          center.dy + (maxRadius - tickLength) * math.sin(angleRad);
      final double endX = center.dx + maxRadius * math.cos(angleRad);
      final double endY = center.dy + maxRadius * math.sin(angleRad);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double gap = ringSpacing * 0.8;
    final double ext = ringSpacing * 4.5;

    canvas.drawLine(
      Offset(center.dx, center.dy - gap),
      Offset(center.dx, center.dy - ext),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + gap),
      Offset(center.dx, center.dy + ext),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx - gap, center.dy),
      Offset(center.dx - ext, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx + gap, center.dy),
      Offset(center.dx + ext, center.dy),
      crosshairPaint,
    );

    final targetPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double pixelRadius = size.width * 0.35;
    _drawDashedLine(canvas, center, trueAzimuth, pixelRadius, targetPaint);

    final headingColor = isLocked ? const Color(0xFF00E676) : Colors.white;

    final headingPaint = Paint()
      ..color = headingColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double phoneAzRad = (currentAzimuth - 90) * (math.pi / 180);

    final double lineEndX = center.dx + (maxRadius - 10) * math.cos(phoneAzRad);
    final double lineEndY = center.dy + (maxRadius - 10) * math.sin(phoneAzRad);

    final double lineStartX = center.dx + gap * math.cos(phoneAzRad);
    final double lineStartY = center.dy + gap * math.sin(phoneAzRad);
    canvas.drawLine(
      Offset(lineStartX, lineStartY),
      Offset(lineEndX, lineEndY),
      headingPaint,
    );

    final double dishX = center.dx + maxRadius * math.cos(phoneAzRad);
    final double dishY = center.dy + maxRadius * math.sin(phoneAzRad);

    canvas.save();
    canvas.translate(dishX, dishY);
    canvas.rotate(phoneAzRad);

    final dishBodyPaint = Paint()
      ..color = headingColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Rect arcRect = Rect.fromCircle(
      center: const Offset(-4, 0),
      radius: 8,
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2.5,
      math.pi / 1.25,
      false,
      dishBodyPaint,
    );
    canvas.drawLine(const Offset(-4, 0), const Offset(6, 0), dishBodyPaint);

    final lnbPaint = Paint()
      ..color = headingColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(6, 0), 2.0, lnbPaint);

    canvas.restore();
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset center,
    double absoluteAzimuth,
    double radius,
    Paint paint,
  ) {
    final double azRad = (absoluteAzimuth - 90) * (math.pi / 180);

    final double endX = center.dx + radius * math.cos(azRad);
    final double endY = center.dy + radius * math.sin(azRad);

    const double dashWidth = 4;
    const double dashSpace = 4;

    double startX = center.dx;
    double startY = center.dy;

    final distance = math.sqrt(
      math.pow(endX - startX, 2) + math.pow(endY - startY, 2),
    );
    final double dx = (endX - startX) / distance;
    final double dy = (endY - startY) / distance;

    double currentDistance = 24.0;

    while (currentDistance < distance - 10) {
      canvas.drawLine(
        Offset(startX + dx * currentDistance, startY + dy * currentDistance),
        Offset(
          startX + dx * (currentDistance + dashWidth),
          startY + dy * (currentDistance + dashWidth),
        ),
        paint,
      );
      currentDistance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant OrbitalGridPainter oldDelegate) {
    return oldDelegate.currentAzimuth != currentAzimuth ||
        oldDelegate.trueAzimuth != trueAzimuth ||
        oldDelegate.isLocked != isLocked;
  }
}
