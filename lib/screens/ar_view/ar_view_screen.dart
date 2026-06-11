import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../models/satellite_model.dart';
import '../../core/providers/camera_provider.dart';
import '../../core/providers/compass_provider.dart';
import '../../core/providers/accelerometer_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/utils/satellite_math.dart';
import '../../core/providers/active_satellite_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../tutorial/tutorial_dialog.dart';
import '../setting/settings_menu.dart';

const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class ArViewScreen extends ConsumerStatefulWidget {
  const ArViewScreen({super.key});

  @override
  ConsumerState<ArViewScreen> createState() => _ArViewScreenState();
}

class _ArViewScreenState extends ConsumerState<ArViewScreen>
    with WidgetsBindingObserver {
  bool _isPinging = true;
  bool _isAppInForeground = true;
  late AudioPlayer _audioPlayer;

  bool _wasLocked = false;
  bool _wasSoundEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _startProximityLoop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;

      // --- FORCE THE LOOP TO RE-EVALUATE AUDIO ---
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
      // --- BACKGROUND GUARD ---
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

      // --- GPS LOCK GUARD ---
      if (!locationState.isLocked ||
          locationState.lat == null ||
          locationState.lon == null) {
        await _audioPlayer.stop();
        _wasSoundEnabled = false;
        _wasLocked = false;
        await Future.delayed(const Duration(milliseconds: 1000));
        continue;
      }

      final targetSatellite = ref.read(activeSatelliteProvider);
      final compassState = ref.read(compassProvider);

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

      final currentAzimuth = compassState.azimuth;

      double azDiff = (trueAzimuth - currentAzimuth).abs();
      if (azDiff > 180) azDiff = 360 - azDiff;

      // --- THE FIX: AZIMUTH ONLY LOCK ---
      final bool isLocked = azDiff < 3.0;

      // --- AUDIO LOGIC ---
      if (settings.enableSound) {
        if (isLocked != _wasLocked || !_wasSoundEnabled) {
          await _audioPlayer.stop();
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
  }

  String _getLiveApparentSlot(
    double currentAzimuth,
    double userLat,
    double userLon,
    double trueAzimuth,
    Satellite targetSatellite,
  ) {
    final double baseAzimuth = userLat >= 0 ? 180.0 : 0.0;

    if ((trueAzimuth - baseAzimuth).abs() < 0.5) {
      return targetSatellite.position.toStringAsFixed(1);
    }

    final double degreesPerAzimuth =
        (targetSatellite.position - userLon) / (trueAzimuth - baseAzimuth);

    final double estimatedSlot =
        userLon + degreesPerAzimuth * (currentAzimuth - baseAzimuth);

    return estimatedSlot.toStringAsFixed(1);
  }

  Widget _buildMetricTile(
    String label,
    String current,
    String target,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          current,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontFamily: 'Courier',
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          target,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white38,
            fontFamily: 'Courier',
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraAsync = ref.watch(cameraProvider);
    final locationState = ref.watch(locationProvider);
    final targetSatellite = ref.watch(activeSatelliteProvider);
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

    final trueAzimuth = SatelliteMath.getAzimuth(
      userLat: userLat,
      userLon: userLon,
      satLon: targetSatellite.position,
      useTrueNorth: settings.useTrueNorth,
      magneticDeclination: currentLocalDeclination,
    );

    final trueElevation = SatelliteMath.getElevation(
      userLat,
      userLon,
      targetSatellite.position,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. CAMERA BACKGROUND
          Positioned.fill(
            child: cameraAsync.when(
              data: (controller) {
                return FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 1080,
                    height: controller.value.previewSize?.width ?? 1920,
                    child: CameraPreview(controller),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: _accentCyan),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Camera Error',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          // 2. AR PAINTER (Crosshairs & Targets)
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, child) {
                final compass = ref.watch(compassProvider);
                final accel = ref.watch(accelerometerProvider);

                return CustomPaint(
                  painter: ArWorldPainter(
                    currentAzimuth: compass.azimuth,
                    currentRoll: accel.roll,
                    targetAzimuth: trueAzimuth,
                    targetName: targetSatellite.name,
                    orbitSlot: targetSatellite.formattedPosition,
                    // --- THE FIX: AZIMUTH ONLY LOCK ---
                    isAligned:
                        ((trueAzimuth - compass.azimuth).abs() < 3.0 ||
                        (trueAzimuth - compass.azimuth).abs() > 357.0),
                  ),
                );
              },
            ),
          ),

          // 3. UI OVERLAYS
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- TOP CLUSTER (Bar + Badges) ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _accentCyan.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  "TARGET: ${targetSatellite.name} [ ${targetSatellite.formattedPosition} ]",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _accentCyan,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline,
                              color: Color(0xFF00E5FF),
                            ),
                            onPressed: () {
                              ImageTutorialDialog.show(
                                context,
                                title: "AR Azimuth Compass",
                                description:
                                    "Rotate the dish left or right until it faces the target satellite position.",
                                instructions: [
                                  "Stand 1–2 meters (3–6 feet) behind the dish for the best view.",
                                  "Keep the dish and LNB visible in the camera frame.",
                                  "Place the dish LNB inside the on-screen circle.",
                                  "Rotate the dish left or right while keeping the phone aligned with the dish.",
                                  "Continue rotating until the target locks in the center.",
                                  "When locked, the app will beep, vibrate (if enabled), and the azimuth value will turn green.",
                                ],
                                imagePath: 'assets/images/tutorial_ar.jpeg',
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // North Indicator Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: settings.useTrueNorth
                                ? _accentCyan
                                : Colors.purpleAccent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          settings.useTrueNorth
                              ? "🧭 TRUE NORTH MODE (GPS)"
                              : "🧲 MAGNETIC MODE (COMPASS)",
                          style: TextStyle(
                            color: settings.useTrueNorth
                                ? _accentCyan
                                : Colors.purpleAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Magnetic Calibration Warning
                    Consumer(
                      builder: (context, ref, child) {
                        final compassState = ref.watch(compassProvider);
                        if (!compassState.needsCalibration) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _alertOrange,
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: _alertOrange,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Magnetic interference! Move device in ∞ pattern.",
                                  style: TextStyle(
                                    color: _alertOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // --- BOTTOM CLUSTER (Telemetry) ---
                Consumer(
                  builder: (context, ref, child) {
                    final compass = ref.watch(compassProvider);

                    final currentAzimuth = compass.azimuth;

                    final bool isAzimuthLocked =
                        (trueAzimuth - currentAzimuth).abs() < 3 ||
                        (trueAzimuth - currentAzimuth).abs() > 357;

                    // Kept strictly for the UI text color, doesn't affect main lock

                    final String liveSlot = _getLiveApparentSlot(
                      currentAzimuth,
                      userLat,
                      userLon,
                      trueAzimuth,
                      targetSatellite,
                    );

                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _panelColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              "ORBIT SLOT",
                              targetSatellite.formattedPosition,
                              "EQUATOR",
                              Colors.white,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white10,
                          ),
                          Expanded(
                            flex: 2,
                            child: _buildMetricTile(
                              "LIVE SLOT | AZIMUTH",
                              "$liveSlot | ${currentAzimuth.toStringAsFixed(1)}",
                              "REQ: ${targetSatellite.position} ➔ ${trueAzimuth.toStringAsFixed(1)}°",
                              isAzimuthLocked ? _successGreen : _alertOrange,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30,
                            color: Colors.white10,
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              "ELEVATION",
                              "${trueElevation.toStringAsFixed(1)}°",
                              "SET ON DISH",
                              _accentCyan,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArWorldPainter extends CustomPainter {
  final double currentAzimuth;
  final double currentRoll;
  final double targetAzimuth;
  final String targetName;
  final String? orbitSlot;
  final bool isAligned;

  ArWorldPainter({
    required this.currentAzimuth,
    required this.currentRoll,
    required this.targetAzimuth,
    required this.targetName,
    required this.orbitSlot,
    this.isAligned = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const double horizontalFov = 60.0;
    final double pixelsPerDegreeX = size.width / horizontalFov;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    canvas.rotate(-currentRoll * math.pi / 180);

    // ==========================================
    // 1. DRAW CENTER CROSSHAIRS & LNB BRACKETS
    // ==========================================
    const double aimOffsetY = -130.0;
    const double circleRadius = 75.0;
    const double bracketGapX = 55.0;

    final crosshairPaint = Paint()
      ..color = _accentCyan.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      const Offset(0, aimOffsetY),
      circleRadius,
      crosshairPaint,
    );

    canvas.drawLine(
      const Offset(-110, aimOffsetY),
      const Offset(-35, aimOffsetY),
      crosshairPaint,
    );
    canvas.drawLine(
      const Offset(35, aimOffsetY),
      const Offset(110, aimOffsetY),
      crosshairPaint,
    );

    final lnbBracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double bracketStart = circleRadius + 12.0;
    final double bracketLength = size.height * 0.42;

    canvas.drawLine(
      Offset(-bracketGapX, aimOffsetY + bracketStart),
      Offset(-bracketGapX, aimOffsetY + bracketLength),
      lnbBracketPaint,
    );
    canvas.drawLine(
      Offset(bracketGapX, aimOffsetY + bracketStart),
      Offset(bracketGapX, aimOffsetY + bracketLength),
      lnbBracketPaint,
    );
    canvas.drawLine(
      Offset(-bracketGapX, aimOffsetY + bracketStart),
      Offset(-bracketGapX + 8, aimOffsetY + bracketStart),
      lnbBracketPaint,
    );
    canvas.drawLine(
      Offset(bracketGapX, aimOffsetY + bracketStart),
      Offset(bracketGapX - 8, aimOffsetY + bracketStart),
      lnbBracketPaint,
    );
    canvas.drawLine(
      Offset(-bracketGapX, aimOffsetY + bracketLength),
      Offset(-bracketGapX + 8, aimOffsetY + bracketLength),
      lnbBracketPaint,
    );
    canvas.drawLine(
      Offset(bracketGapX, aimOffsetY + bracketLength),
      Offset(bracketGapX - 8, aimOffsetY + bracketLength),
      lnbBracketPaint,
    );

    // ==========================================
    // 2. CALCULATE TARGET PLACEMENT
    // ==========================================
    double deltaAzimuth = (targetAzimuth - currentAzimuth + 540) % 360 - 180;

    double targetX = deltaAzimuth * pixelsPerDegreeX;

    // --- THE FIX: LOCK VERTICALLY TO THE AIM OFFSET ---
    // The target will no longer float off the top of the screen if the phone is level.
    // It is permanently pinned to the horizontal aim line.
    double targetY = aimOffsetY;

    // 3. DRAW GUIDANCE ARROWS IF OFF SCREEN
    if (deltaAzimuth > 25.0) {
      _drawDirectionalArrow(
        canvas,
        Offset(size.width / 2 - 40, aimOffsetY),
        true,
      );
    } else if (deltaAzimuth < -25.0) {
      _drawDirectionalArrow(
        canvas,
        Offset(-size.width / 2 + 40, aimOffsetY),
        false,
      );
    }

    // 4. DRAW SATELLITE IF IT IS IN VIEW
    if (deltaAzimuth > -90 && deltaAzimuth < 90) {
      final targetPaint = Paint()
        ..color = isAligned ? _successGreen : _alertOrange
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(targetX, targetY),
          width: 40,
          height: 40,
        ),
        targetPaint,
      );
      canvas.drawCircle(
        Offset(targetX, targetY),
        4,
        Paint()
          ..color = isAligned ? _successGreen : _alertOrange
          ..style = PaintingStyle.fill,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text:
              "$targetName (Orbit: ${orbitSlot ?? "N/A"})\nSet Dish Azimuth: ${targetAzimuth.toStringAsFixed(1)}°",
          style: TextStyle(
            color: isAligned ? _successGreen : _alertOrange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(targetX - (textPainter.width / 2), targetY - 40),
      );
    }

    canvas.restore();
  }

  void _drawDirectionalArrow(Canvas canvas, Offset position, bool isRight) {
    final arrowPaint = Paint()
      ..color = _alertOrange.withValues(alpha: 0.9)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isRight) {
      path.moveTo(position.dx - 20, position.dy - 20);
      path.lineTo(position.dx, position.dy);
      path.lineTo(position.dx - 20, position.dy + 20);
    } else {
      path.moveTo(position.dx + 20, position.dy - 20);
      path.lineTo(position.dx, position.dy);
      path.lineTo(position.dx + 20, position.dy + 20);
    }

    canvas.drawPath(path, arrowPaint);

    canvas.drawPath(
      path,
      Paint()
        ..color = _alertOrange.withValues(alpha: 0.3)
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
    );
  }

  @override
  bool shouldRepaint(covariant ArWorldPainter oldDelegate) {
    return oldDelegate.currentAzimuth != currentAzimuth ||
        oldDelegate.currentRoll != currentRoll ||
        oldDelegate.isAligned != isAligned;
  }
}
