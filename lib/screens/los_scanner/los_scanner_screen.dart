import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:camera/camera.dart';

import '../../core/providers/compass_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/active_satellite_provider.dart';
import '../../core/providers/camera_provider.dart';
import '../../core/utils/satellite_math.dart';
import '../../core/providers/settings_provider.dart';
import '../tutorial/tutorial_dialog.dart';
import '../setting/settings_menu.dart';
import '../../core/providers/accelerometer_provider.dart';
import 'package:geolocator/geolocator.dart';

// ==========================================
// PREMIUM COLORS
// ==========================================
const Color _bgDark = Color(0xFF090E17);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);

class LOSScannerScreen extends ConsumerStatefulWidget {
  const LOSScannerScreen({super.key});

  @override
  ConsumerState<LOSScannerScreen> createState() => _LOSScannerScreenState();
}

class _LOSScannerScreenState extends ConsumerState<LOSScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isPinging = true;
  bool _isAppInForeground = true;

  late AudioPlayer _audioPlayer;

  bool _wasLocked = false;
  bool _wasSoundEnabled = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _startProximityLoop();
  }

  Future<void> _startProximityLoop() async {
    while (_isPinging && mounted) {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      ref.invalidate(cameraProvider);
      _wasLocked = !_wasLocked;
      _wasSoundEnabled = false;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _isAppInForeground = false;
      _audioPlayer.stop();
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
    final cameraAsync = ref.watch(cameraProvider);

    // ==========================================
    // UPGRADED GPS LOCK SCREEN w/ ESCAPE HATCH
    // ==========================================
    if (!locationState.isLocked ||
        locationState.lat == null ||
        locationState.lon == null ||
        (locationState.lat == 0.0 && locationState.lon == 0.0)) {
      final bool hasError = locationState.error != null;

      final bool isHardwareOff =
          hasError && locationState.error!.contains("TURN ON");
      final bool isPermDeniedForever =
          hasError && locationState.error!.contains("PERMANENTLY DENIED");
      final bool isFirstTimeAsking =
          hasError && locationState.error == "PERMISSION REQUIRED";

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: _bgDark,
          body: Stack(
            children: [
              Center(
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
                        isFirstTimeAsking
                            ? "LOCATION REQUIRED"
                            : (hasError
                                  ? "GPS UNAVAILABLE"
                                  : "AWAITING SATELLITES"),
                        style: TextStyle(
                          color: hasError ? Colors.redAccent : _alertOrange,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isFirstTimeAsking
                            ? "To calculate satellite angles, the app needs your location. Choose a method below:"
                            : (hasError
                                  ? "${locationState.error!.toUpperCase()}\n\nPlease fix this in your device settings, or enter coordinates manually."
                                  : "Searching for hardware GPS lock...\n\nPlease wait, or enter your coordinates manually to bypass."),
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

                      const SizedBox(height: 24),

                      if (isFirstTimeAsking ||
                          isHardwareOff ||
                          isPermDeniedForever) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              isFirstTimeAsking
                                  ? Icons.my_location
                                  : Icons.settings,
                              color: Colors.white,
                            ),
                            label: Text(
                              isFirstTimeAsking
                                  ? "GRANT GPS PERMISSION"
                                  : (isHardwareOff
                                        ? "TURN ON GPS"
                                        : "OPEN APP SETTINGS"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFirstTimeAsking
                                  ? _alertOrange
                                  : Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              if (isFirstTimeAsking) {
                                ref
                                    .read(locationProvider.notifier)
                                    .promptForPermission();
                              } else if (isHardwareOff) {
                                Geolocator.openLocationSettings();
                              } else if (isPermDeniedForever) {
                                Geolocator.openAppSettings();
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

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
                            backgroundColor: _accentCyan.withValues(
                              alpha: 0.05,
                            ),
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
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ),
              ),
            ],
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

    final double targetElevationDegrees = SatelliteMath.getElevation(
      userLat,
      userLon,
      targetSatellite.position,
    );

    final trueAzimuth = SatelliteMath.getAzimuth(
      userLat: userLat,
      userLon: userLon,
      satLon: targetSatellite.position,
      useTrueNorth: settings.useTrueNorth,
      magneticDeclination: currentLocalDeclination,
    );

    const double toleranceDegrees = 2.0;

    return Scaffold(
      backgroundColor: Colors.black,

      // 🛑 THE FIX: Entire UI is wrapped in the camera state!
      body: cameraAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _accentCyan)),

        // ==========================================
        // CAMERA ERROR SCREEN
        // ==========================================
        error: (error, stack) {
          final isPermanentlyDenied = error.toString().contains(
            'PERMISSION_PERMANENTLY_DENIED',
          );

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.redAccent,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "CAMERA REQUIRED",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPermanentlyDenied
                        ? "You previously denied camera access.\n\nPlease open your device settings and allow camera permissions to use the AR visualizer."
                        : "Initialization failed: $error",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (isPermanentlyDenied)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.settings, color: _accentCyan),
                        label: const Text(
                          "OPEN APP SETTINGS",
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
                          Geolocator.openAppSettings();
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // THE FIX: Adding the "GO BACK" button so they aren't stuck!
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text(
                        "GO BACK",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },

        // ==========================================
        // ACTIVE AR UI (Only shows if camera is working)
        // ==========================================
        data: (controller) {
          return Stack(
            children: [
              // 1. CAMERA BACKGROUND
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 1080,
                    height: controller.value.previewSize?.width ?? 1920,
                    child: CameraPreview(controller),
                  ),
                ),
              ),

              // 2. TRUE AR HUD PAINTER (Azimuth + Elevation)
              Positioned.fill(
                child: Consumer(
                  builder: (context, ref, child) {
                    final accelState = ref.watch(accelerometerProvider);
                    final compassState = ref.watch(compassProvider);

                    final double currentElevationDegrees = accelState.elevation;
                    final double currentAzimuthDegrees = compassState.azimuth;

                    // Calculate Deltas for locking
                    double elDelta =
                        (currentElevationDegrees - targetElevationDegrees)
                            .abs();

                    double azDelta = (trueAzimuth - currentAzimuthDegrees)
                        .abs();
                    if (azDelta > 180) azDelta = 360 - azDelta;

                    bool isAligned =
                        (elDelta <= toleranceDegrees) &&
                        (azDelta <= toleranceDegrees);

                    return CustomPaint(
                      painter: ArTrackingPainter(
                        currentElevation: currentElevationDegrees,
                        targetElevation: targetElevationDegrees,
                        currentAzimuth: currentAzimuthDegrees,
                        targetAzimuth: trueAzimuth,
                        isAligned: isAligned,
                        targetName: targetSatellite.name,
                        orbitSlot: targetSatellite.formattedPosition,
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
                    // TOP BAR
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
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _accentCyan.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "LINE OF SIGHT AR",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "TARGET: ${targetSatellite.name} [ ${targetSatellite.formattedPosition} ]",
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _accentCyan,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
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
                                title: "Line-of-Sight Check",
                                description:
                                    "Verify that the satellite signal path is clear of trees, buildings, or other obstacles.",
                                instructions: [
                                  "Stand at the location where the dish will be installed.",
                                  "Hold the phone upright as if taking a photo of the sky.",
                                  "Point the camera toward the sky and follow the on-screen satellite marker.",
                                  "Keep the center pointer aligned with the satellite position shown on the screen.",
                                  "Check for any trees, buildings, poles, walls, or other objects blocking the view in that direction.",
                                  "If the satellite marker appears behind an obstacle, choose a different dish installation location.",
                                ],
                                imagePath: 'assets/images/tutorial_los.jpg',
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // BOTTOM TELEMETRY AND GUIDANCE
                    Consumer(
                      builder: (context, ref, child) {
                        final accelState = ref.watch(accelerometerProvider);
                        final compassState = ref.watch(compassProvider);

                        final double currentElevationDegrees =
                            accelState.elevation;
                        final double currentAzimuthDegrees =
                            compassState.azimuth;

                        double elDelta =
                            targetElevationDegrees - currentElevationDegrees;

                        double azDelta = trueAzimuth - currentAzimuthDegrees;
                        azDelta = (azDelta + 540) % 360 - 180;

                        bool isAligned =
                            (elDelta.abs() <= toleranceDegrees) &&
                            (azDelta.abs() <= toleranceDegrees);

                        Color bannerColor = isAligned
                            ? _successGreen
                            : _alertOrange;

                        String guidanceText;
                        if (isAligned) {
                          guidanceText =
                              "✓ TARGET ACQUIRED - CHECK FOR OBSTACLES";
                        } else if (azDelta.abs() > 10) {
                          guidanceText =
                              "TURN ${azDelta > 0 ? 'RIGHT' : 'LEFT'} TO FIND AZIMUTH";
                        } else {
                          guidanceText =
                              "TILT ${elDelta > 0 ? 'UP' : 'DOWN'} TO FIND ELEVATION";
                        }

                        return Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: bannerColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildDataColumn(
                                    'TARGET AZIMUTH',
                                    '${trueAzimuth.toStringAsFixed(1)}°',
                                    (azDelta.abs() <= toleranceDegrees)
                                        ? _successGreen
                                        : Colors.white,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    color: Colors.white24,
                                  ),
                                  _buildDataColumn(
                                    'TARGET ELEVATION',
                                    '${targetElevationDegrees.toStringAsFixed(1)}°',
                                    (elDelta.abs() <= toleranceDegrees)
                                        ? _successGreen
                                        : Colors.white,
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white24, height: 24),
                              Text(
                                guidanceText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: bannerColor,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                  fontSize: 12,
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
          );
        },
      ),
    );
  }

  Widget _buildDataColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }
}

// ==========================================
// AR CAMERA OVERLAY PAINTER
// ==========================================
class ArTrackingPainter extends CustomPainter {
  final double currentElevation;
  final double targetElevation;
  final double currentAzimuth;
  final double targetAzimuth;
  final bool isAligned;
  final String targetName;
  final String? orbitSlot;

  ArTrackingPainter({
    required this.currentElevation,
    required this.targetElevation,
    required this.currentAzimuth,
    required this.targetAzimuth,
    required this.isAligned,
    required this.targetName,
    required this.orbitSlot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final double pixelsPerDegreeY = size.height / 60.0;
    final double pixelsPerDegreeX = size.width / 45.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final centerColor = isAligned ? _successGreen : _accentCyan;
    final centerPaint = Paint()
      ..color = centerColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(-30, 0), const Offset(-10, 0), centerPaint);
    canvas.drawLine(const Offset(10, 0), const Offset(30, 0), centerPaint);
    canvas.drawLine(const Offset(0, -30), const Offset(0, -10), centerPaint);
    canvas.drawLine(const Offset(0, 10), const Offset(0, 30), centerPaint);

    final double targetYPos =
        -(targetElevation - currentElevation) * pixelsPerDegreeY;

    double azDiff = targetAzimuth - currentAzimuth;
    azDiff = (azDiff + 540) % 360 - 180;
    final double targetXPos = azDiff * pixelsPerDegreeX;

    final bool isVisibleVertically =
        targetYPos > -size.height / 2 && targetYPos < size.height / 2;
    final bool isVisibleHorizontally =
        targetXPos > -size.width / 2 && targetXPos < size.width / 2;

    if (isVisibleVertically && isVisibleHorizontally) {
      final targetColor = isAligned ? _successGreen : _alertOrange;

      final namePainter = TextPainter(textDirection: TextDirection.ltr);
      namePainter.text = TextSpan(
        text: "$targetName [ ${orbitSlot ?? ''} ]",
        style: TextStyle(
          color: targetColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      );
      namePainter.layout();

      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      final iconStr = String.fromCharCode(Icons.satellite_alt.codePoint);

      iconPainter.text = TextSpan(
        text: iconStr,
        style: TextStyle(
          color: targetColor,
          fontSize: 32,
          fontFamily: Icons.satellite_alt.fontFamily,
          package: Icons.satellite_alt.fontPackage,
        ),
      );
      iconPainter.layout();

      iconPainter.paint(
        canvas,
        Offset(
          targetXPos - iconPainter.width / 2,
          targetYPos - iconPainter.height / 2,
        ),
      );

      namePainter.paint(
        canvas,
        Offset(
          targetXPos - namePainter.width / 2,
          targetYPos + iconPainter.height / 2 + 5,
        ),
      );
    } else {
      double clampedX = targetXPos.clamp(
        -size.width / 2 + 20,
        size.width / 2 - 20,
      );
      double clampedY = targetYPos.clamp(
        -size.height / 2 + 20,
        size.height / 2 - 20,
      );

      final double angleToTarget = math.atan2(
        targetYPos - clampedY,
        targetXPos - clampedX,
      );

      _drawDirectionalArrow(canvas, Offset(clampedX, clampedY), angleToTarget);
    }

    canvas.restore();
  }

  void _drawDirectionalArrow(Canvas canvas, Offset position, double angle) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);

    final arrowPaint = Paint()
      ..color = _alertOrange.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(15, 0);
    path.lineTo(-10, 10);
    path.lineTo(-5, 0);
    path.lineTo(-10, -10);
    path.close();

    canvas.drawPath(path, arrowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArTrackingPainter oldDelegate) {
    return oldDelegate.currentElevation != currentElevation ||
        oldDelegate.targetElevation != targetElevation ||
        oldDelegate.currentAzimuth != currentAzimuth ||
        oldDelegate.targetAzimuth != targetAzimuth ||
        oldDelegate.isAligned != isAligned;
  }
}
