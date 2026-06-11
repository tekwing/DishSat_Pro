import 'dart:math' as math;
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
import '../setting/settings_menu.dart'; // Ensure correct path for ManualGpsDialog
import 'package:geolocator/geolocator.dart';

// Shared tactical palette
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class LnbSkewScreen extends ConsumerStatefulWidget {
  const LnbSkewScreen({super.key});

  @override
  ConsumerState<LnbSkewScreen> createState() => _LnbSkewScreenState();
}

class _LnbSkewScreenState extends ConsumerState<LnbSkewScreen>
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
      final accelState = ref.read(accelerometerProvider);

      final userLat = locationState.lat!;
      final userLon = locationState.lon!;

      final double targetSkewDegrees = SatelliteMath.getSkew(
        userLat,
        userLon,
        targetSatellite.position,
      );

      final double currentRollDegrees = accelState.roll;

      double delta = (currentRollDegrees - targetSkewDegrees).abs();
      final bool isLocked = delta <= 1.5; // 1.5 degree tolerance

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
  }

  @override
  Widget build(BuildContext context) {
    final targetSatellite = ref.watch(activeSatelliteProvider);
    final locationState = ref.watch(locationProvider);

    // ==========================================
    // UPGRADED GPS LOCK SCREEN w/ ESCAPE HATCH
    // ==========================================
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

    final userLat = locationState.lat!;
    final userLon = locationState.lon!;

    final double targetSkewDegrees = SatelliteMath.getSkew(
      userLat,
      userLon,
      targetSatellite.position,
    );

    final String satName = targetSatellite.name;
    const double toleranceDegrees = 1.5;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            const Text(
              'LNB SKEW CALIBRATION',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            Text(
              satName,
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
            icon: const Icon(Icons.info_outline, color: Color(0xFF00E5FF)),
            onPressed: () {
              ImageTutorialDialog.show(
                context,
                title: "LNB Polarization Skew",
                description:
                    "Rotate the LNB to match the satellite's required polarization angle.",
                instructions: [
                  "Stand in front of the dish facing the LNB.",
                  "Start from the 0° position by pointing the LNB coax connector straight down toward the ground.",
                  "Hold the phone vertically against the back of the LNB so both the phone and LNB are aligned.",
                  "Rotate the LNB and phone together while watching the skew indicator.",
                  "Continue rotating until the target skew angle is reached and the indicator turns green.",
                ],
                imagePath: 'assets/images/tutorial_skew.jpeg',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Column(
                  children: [
                    // ==========================================
                    // 1. TELEMETRY DATA
                    // ==========================================
                    Consumer(
                      builder: (context, ref, child) {
                        final accelState = ref.watch(accelerometerProvider);
                        final double currentRollDegrees = accelState.roll;

                        double delta = currentRollDegrees - targetSkewDegrees;
                        bool isAligned = delta.abs() <= toleranceDegrees;

                        Color primaryIndicatorColor = isAligned
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
                                'TARGET SKEW',
                                '${targetSkewDegrees.toStringAsFixed(1)}°',
                                Colors.white,
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white10,
                              ),
                              _buildDataColumn(
                                'CURRENT ROLL',
                                '${currentRollDegrees.toStringAsFixed(1)}°',
                                primaryIndicatorColor,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    const Spacer(),

                    // ==========================================
                    // 2. HIGH-TECH INCLINOMETER GAUGE
                    // ==========================================
                    Consumer(
                      builder: (context, ref, child) {
                        final accelState = ref.watch(accelerometerProvider);
                        final double currentRollDegrees = accelState.roll;

                        double delta = currentRollDegrees - targetSkewDegrees;
                        bool isAligned = delta.abs() <= toleranceDegrees;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(280, 280),
                              painter: LnbGaugePainter(
                                currentRoll: currentRollDegrees,
                                targetSkew: targetSkewDegrees,
                                isAligned: isAligned,
                              ),
                            ),
                            Container(
                              width: 110,
                              height: 180,
                              decoration: BoxDecoration(
                                color: _bgDark,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isAligned
                                      ? _successGreen
                                      : _borderLight,
                                  width: 2,
                                ),
                                boxShadow: isAligned
                                    ? [
                                        BoxShadow(
                                          color: _successGreen.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.satellite_alt,
                                    color: isAligned
                                        ? _successGreen
                                        : Colors.white54,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${currentRollDegrees.toStringAsFixed(1)}°',
                                    style: TextStyle(
                                      color: isAligned
                                          ? _successGreen
                                          : Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                    const Spacer(),

                    // ==========================================
                    // 3. GUIDANCE INSTRUCTIONS
                    // ==========================================
                    Consumer(
                      builder: (context, ref, child) {
                        final accelState = ref.watch(accelerometerProvider);
                        final double currentRollDegrees = accelState.roll;

                        double delta = targetSkewDegrees - currentRollDegrees;
                        bool isAligned = delta.abs() <= toleranceDegrees;

                        Color bannerColor = isAligned
                            ? _successGreen
                            : _alertOrange;

                        String guidanceText;
                        if (isAligned) {
                          guidanceText = '✓ SKEW MATCHED';
                        } else if (delta > 0) {
                          guidanceText = '⟲ Twist LNB Counter-Clockwise';
                        } else {
                          guidanceText = '⟳ Twist LNB Clockwise';
                        }

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: bannerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: bannerColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            guidanceText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: bannerColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              fontSize: 16,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
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
// CUSTOM LNB SKEW PROTRACTOR
// ==========================================
class LnbGaugePainter extends CustomPainter {
  final double currentRoll;
  final double targetSkew;
  final bool isAligned;

  LnbGaugePainter({
    required this.currentRoll,
    required this.targetSkew,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    canvas.drawCircle(center, radius, trackPaint);

    final tickPaint = Paint()
      ..color = Colors.white38
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = -90; i <= 90; i += 10) {
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;
      tickPaint.strokeWidth = isMajor ? 2.0 : 1.0;

      final angleRad = (i - 90) * (math.pi / 180);

      final outerX = center.dx + (radius + 10) * math.cos(angleRad);
      final outerY = center.dy + (radius + 10) * math.sin(angleRad);

      final innerX =
          center.dx + (radius + 10 - tickLength) * math.cos(angleRad);
      final innerY =
          center.dy + (radius + 10 - tickLength) * math.sin(angleRad);

      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        tickPaint,
      );

      if (isMajor) {
        String label = (i > 0) ? '+$i°' : '$i°';
        if (i == 0) label = '0°';

        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        );
        textPainter.layout();

        final textRadius = radius - 16;
        final textX =
            center.dx +
            textRadius * math.cos(angleRad) -
            (textPainter.width / 2);
        final textY =
            center.dy +
            textRadius * math.sin(angleRad) -
            (textPainter.height / 2);

        textPainter.paint(canvas, Offset(textX, textY));
      }
    }

    final targetRad = (targetSkew - 90) * (math.pi / 180);
    final notchOuter = Offset(
      center.dx + (radius + 15) * math.cos(targetRad),
      center.dy + (radius + 15) * math.sin(targetRad),
    );
    final notchInner = Offset(
      center.dx + (radius - 15) * math.cos(targetRad),
      center.dy + (radius - 15) * math.sin(targetRad),
    );

    final notchColor = isAligned
        ? const Color(0xFF00E676)
        : const Color(0xFF00E5FF);

    canvas.drawLine(
      notchInner,
      notchOuter,
      Paint()
        ..color = notchColor
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      notchOuter,
      6,
      Paint()
        ..color = notchColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final rollRad = (currentRoll - 90) * (math.pi / 180);
    final rollPoint = Offset(
      center.dx + radius * math.cos(rollRad),
      center.dy + radius * math.sin(rollRad),
    );

    final indicatorColor = isAligned
        ? const Color(0xFF00E676)
        : const Color(0xFFFF9100);

    canvas.drawLine(
      center,
      rollPoint,
      Paint()
        ..color = indicatorColor.withValues(alpha: 0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(
      rollPoint,
      10,
      Paint()
        ..color = indicatorColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant LnbGaugePainter oldDelegate) {
    return oldDelegate.currentRoll != currentRoll ||
        oldDelegate.targetSkew != targetSkew ||
        oldDelegate.isAligned != isAligned;
  }
}
