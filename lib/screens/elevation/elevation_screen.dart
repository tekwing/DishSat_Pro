import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/providers/accelerometer_provider.dart';
import '../../core/providers/active_satellite_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/utils/satellite_math.dart';
import '../../core/providers/settings_provider.dart';
import '../tutorial/tutorial_dialog.dart';
import '../setting/settings_menu.dart';
import 'package:geolocator/geolocator.dart';

const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class ElevationScreen extends ConsumerStatefulWidget {
  const ElevationScreen({super.key});

  @override
  ConsumerState<ElevationScreen> createState() => _ElevationScreenState();
}

class _ElevationScreenState extends ConsumerState<ElevationScreen>
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
      final targetSatellite = ref.read(activeSatelliteProvider);
      final accelState = ref.read(accelerometerProvider);

      if (!locationState.isLocked ||
          locationState.lat == null ||
          locationState.lon == null) {
        await _audioPlayer.stop();
        _wasSoundEnabled = false;
        _wasLocked = false;
        await Future.delayed(const Duration(milliseconds: 1000));
        continue;
      }

      final trueElevation = SatelliteMath.getElevation(
        locationState.lat!,
        locationState.lon!,
        targetSatellite.position,
      );

      // Apply Offset here
      final targetPhysicalElevation = trueElevation - settings.dishOffsetAngle;
      final currentElevation = accelState.elevation;

      double diffElevation = (targetPhysicalElevation - currentElevation).abs();
      final bool isLocked = diffElevation <= 1.0;

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
        if (_wasSoundEnabled) await _audioPlayer.stop();
      }

      if (isLocked && settings.enableVibration) HapticFeedback.heavyImpact();

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

      // Determine exactly what state we are in
      final bool isHardwareOff =
          hasError && locationState.error!.contains("TURN ON");
      final bool isPermDeniedForever =
          hasError && locationState.error!.contains("PERMANENTLY DENIED");
      // This is our new state for first-time users!
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

                      // ---------------------------------------------
                      // ESCAPE HATCH 1: AUTO GPS / OS SETTINGS
                      // ---------------------------------------------
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
                                // Triggers the native popup we just made!
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

                      // ---------------------------------------------
                      // ESCAPE HATCH 2: MANUAL OVERRIDE
                      // ---------------------------------------------
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

              // UI BACK BUTTON
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

    // ==========================================
    // ELEVATION CALCULATIONS
    // ==========================================
    final userLat = locationState.lat!;
    final userLon = locationState.lon!;

    final trueElevation = SatelliteMath.getElevation(
      userLat,
      userLon,
      targetSatellite.position,
    );

    final targetPhysicalElevation = trueElevation - settings.dishOffsetAngle;

    const double toleranceDegrees = 1.0;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            const Text(
              'ELEVATION CALIBRATION',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            Text(
              targetSatellite.name,
              style: TextStyle(
                color: _accentCyan.withValues(alpha: 0.8),
                fontSize: 11,
                fontFamily: 'Courier',
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: _accentCyan),
            onPressed: () {
              ImageTutorialDialog.show(
                context,
                title: "Dish Elevation Pitch",
                description:
                    "Adjust the dish's vertical tilt using the mounting elevation value shown on the screen.",
                instructions: [
                  "Loosen the elevation adjustment bolts on the dish mount.",
                  "Hold the phone parallel to the mounting bracket on the back of the dish and adjust the dish until the target value is reached.",
                  "The screen shows both the True Elevation and the Mounting Elevation.",
                  "Mounting Elevation includes the dish offset angle and is the value used to physically set the dish.",
                  "The default dish offset is 22°, which is common for most Ku-band offset dishes.",
                  "If your dish uses a different offset angle, update it in Settings before alignment.",
                  "Slowly tilt the dish up or down until the current elevation matches the mounting elevation target.",
                  "When alignment is achieved, the value will turn green and the app can confirm with sound or vibration if enabled.",
                ],
                imagePath: 'assets/images/tutorial_elevation.jpg',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    // TELEMETRY PANEL
                    Consumer(
                      builder: (context, ref, child) {
                        final accelState = ref.watch(accelerometerProvider);

                        final currentElevation = accelState.elevation;

                        final isAligned =
                            (targetPhysicalElevation - currentElevation)
                                .abs() <=
                            toleranceDegrees;

                        final statusColor = isAligned
                            ? _successGreen
                            : _alertOrange;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _panelColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildDataColumn(
                                'SAT EL',
                                '${trueElevation.toStringAsFixed(1)}°',
                                Colors.white54,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white10,
                              ),
                              _buildDataColumn(
                                'MOUNT EL',
                                '${targetPhysicalElevation.toStringAsFixed(1)}°',
                                _accentCyan,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white10,
                              ),
                              _buildDataColumn(
                                'CURRENT',
                                '${currentElevation.toStringAsFixed(1)}°',
                                statusColor,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final accelState = ref.watch(accelerometerProvider);

                          final currentElevation = accelState.elevation;

                          final isAligned =
                              (targetPhysicalElevation - currentElevation)
                                  .abs() <=
                              toleranceDegrees;

                          return Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C1322),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isAligned
                                    ? _successGreen
                                    : Colors.white10,
                                width: isAligned ? 2.0 : 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: PitchLadderPainter(
                                  currentElevation: currentElevation,
                                  targetElevation: targetPhysicalElevation,
                                  isAligned: isAligned,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    Consumer(
                      builder: (context, ref, child) {
                        final accelState = ref.watch(accelerometerProvider);

                        final current = accelState.elevation;

                        final delta = targetPhysicalElevation - current;

                        final isAligned = delta.abs() <= toleranceDegrees;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: (isAligned ? _successGreen : _alertOrange)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (isAligned ? _successGreen : _alertOrange)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isAligned
                                ? '✓ ELEVATION MATCHED'
                                : (delta > 0
                                      ? '⇡ Tilt Dish UP'
                                      : '⇣ Tilt Dish DOWN'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isAligned ? _successGreen : _alertOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }
}

// ==========================================
// CUSTOM PITCH LADDER HUD PAINTER
// ==========================================
class PitchLadderPainter extends CustomPainter {
  final double currentElevation;
  final double targetElevation;
  final bool isAligned;

  PitchLadderPainter({
    required this.currentElevation,
    required this.targetElevation,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double pixelsPerDegree = 12.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = -90; i <= 90; i += 5) {
      final isMajor = i % 10 == 0;
      final double tickWidth = isMajor ? 60.0 : 30.0;
      final double yPos = -(i - currentElevation) * pixelsPerDegree;

      if (yPos > -size.height / 2 - 20 && yPos < size.height / 2 + 20) {
        final double gap = isMajor ? 30.0 : 40.0;

        canvas.drawLine(
          Offset(-tickWidth - gap, yPos),
          Offset(-gap, yPos),
          tickPaint,
        );
        canvas.drawLine(
          Offset(gap, yPos),
          Offset(tickWidth + gap, yPos),
          tickPaint,
        );

        if (isMajor) {
          textPainter.text = TextSpan(
            text: '$i°',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
            ),
          );
          textPainter.layout();

          textPainter.paint(
            canvas,
            Offset(-tickWidth - gap - 30, yPos - textPainter.height / 2),
          );
          textPainter.paint(
            canvas,
            Offset(tickWidth + gap + 10, yPos - textPainter.height / 2),
          );
        }
      }
    }

    final double targetYPos =
        -(targetElevation - currentElevation) * pixelsPerDegree;

    final targetColor = isAligned ? _successGreen : _alertOrange;
    final targetPaint = Paint()
      ..color = targetColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(-90, targetYPos),
      Offset(90, targetYPos),
      targetPaint,
    );

    final path = Path();
    path.moveTo(-110, targetYPos - 10);
    path.lineTo(-90, targetYPos);
    path.lineTo(-110, targetYPos + 10);

    path.moveTo(110, targetYPos - 10);
    path.lineTo(90, targetYPos);
    path.lineTo(110, targetYPos + 10);

    canvas.drawPath(path, targetPaint);

    final centerColor = isAligned ? _successGreen : _accentCyan;
    final centerPaint = Paint()
      ..color = centerColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const double bracketWidth = 40.0;
    const double bracketHeight = 15.0;
    const double centerGap = 20.0;

    final leftBracket = Path()
      ..moveTo(-centerGap, -bracketHeight)
      ..lineTo(-centerGap - bracketWidth, -bracketHeight)
      ..lineTo(-centerGap - bracketWidth, bracketHeight)
      ..lineTo(-centerGap, bracketHeight);
    canvas.drawPath(leftBracket, centerPaint);

    final rightBracket = Path()
      ..moveTo(centerGap, -bracketHeight)
      ..lineTo(centerGap + bracketWidth, -bracketHeight)
      ..lineTo(centerGap + bracketWidth, bracketHeight)
      ..lineTo(centerGap, bracketHeight);
    canvas.drawPath(rightBracket, centerPaint);

    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()
        ..color = centerColor
        ..style = PaintingStyle.fill,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PitchLadderPainter oldDelegate) {
    return oldDelegate.currentElevation != currentElevation ||
        oldDelegate.targetElevation != targetElevation ||
        oldDelegate.isAligned != isAligned;
  }
}
