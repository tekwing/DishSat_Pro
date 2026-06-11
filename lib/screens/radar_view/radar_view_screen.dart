import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/providers/compass_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/active_satellite_provider.dart';
import '../../core/utils/satellite_math.dart';
import '../../core/providers/settings_provider.dart';
import '../setting/settings_menu.dart';
import '../tutorial/tutorial_dialog.dart';

const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class GraphViewScreen extends ConsumerStatefulWidget {
  const GraphViewScreen({super.key});

  @override
  ConsumerState<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends ConsumerState<GraphViewScreen>
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

      double diffAzimuth = (trueAzimuth - currentAzimuth);
      diffAzimuth = (diffAzimuth + 540) % 360 - 180;

      // --- AZIMUTH ONLY LOCK ---
      bool isAzimuthLocked = diffAzimuth.abs() < 2.0;
      bool isFullyLocked = isAzimuthLocked;

      if (settings.enableSound) {
        if (isFullyLocked != _wasLocked || !_wasSoundEnabled) {
          await _audioPlayer.stop();
          if (isFullyLocked) {
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

      if (isFullyLocked && settings.enableVibration) {
        HapticFeedback.heavyImpact();
      }

      _wasLocked = isFullyLocked;
      _wasSoundEnabled = settings.enableSound;

      await Future.delayed(
        isFullyLocked
            ? const Duration(milliseconds: 1000)
            : const Duration(milliseconds: 500),
      );
    }
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
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "2D COMPASS ALIGNMENT",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: _accentCyan),
            onPressed: () {
              ImageTutorialDialog.show(
                context,
                title: "Dish Elevation Pitch",
                description: "Set the exact upward vertical tilt of the dish.",
                instructions: [
                  "Position device securely on dish or LNB assembly for stable tracking visibility.",
                  "Maintain steady handling to preserve sensor alignment accuracy.",
                  "Follow live orbital radar guidance for azimuth correction.",
                  "Achieve lock when radar centroid aligns and status indicator turns GREEN.",
                ],
                imagePath: 'assets/images/tutorial_radar.jpeg',
              );
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final compassState = ref.watch(compassProvider);

          final currentAzimuth = compassState.azimuth;

          double diffAzimuth = trueAzimuth - currentAzimuth;
          diffAzimuth = (diffAzimuth + 540) % 360 - 180;

          bool isAzimuthLocked = diffAzimuth.abs() < 2.0;

          // The compass only cares if the Azimuth is locked
          bool isFullyLocked = isAzimuthLocked;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
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

                  // ==========================================
                  // GUIDANCE CARDS (NOW 3 COLUMNS)
                  // ==========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isFullyLocked
                          ? _successGreen.withValues(alpha: 0.15)
                          : _panelColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFullyLocked ? _successGreen : _borderLight,
                      ),
                    ),
                    child: isFullyLocked
                        ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: _successGreen,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "TARGET LOCKED",
                                    style: TextStyle(
                                      color: _successGreen,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fade(begin: 0.5, end: 1)
                        : Row(
                            children: [
                              Expanded(
                                child: _buildGuidanceInstruction(
                                  isAzimuthLocked
                                      ? "ALIGNED"
                                      : (diffAzimuth > 0
                                            ? "TURN RIGHT"
                                            : "TURN LEFT"),
                                  "${diffAzimuth.abs().toStringAsFixed(1)}°",
                                  isAzimuthLocked
                                      ? _successGreen
                                      : _alertOrange,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white10,
                              ),

                              // --- NEW: TRUE SATELLITE ELEVATION ---
                              Expanded(
                                child: _buildAzimuthMatchData(
                                  "AZIMUTH",
                                  currentAzimuth,
                                  isAzimuthLocked,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white10,
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      targetSatellite.name.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      targetSatellite.formattedPosition,
                                      style: const TextStyle(
                                        color: _alertOrange,
                                        fontFamily: 'Courier',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "TGT: ${trueAzimuth.toStringAsFixed(1)}°",
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontFamily: 'Courier',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size.square(double.infinity),
                              painter: CompassGraphPainter(
                                targetAzimuth: trueAzimuth,
                                targetElevation:
                                    trueElevation, // Visual dot uses true elevation!
                                currentAzimuth: currentAzimuth,
                                isLocked: isFullyLocked,
                              ),
                            ),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _bgDark, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Adjusted slightly smaller to fit beautifully in 3 columns
  Widget _buildGuidanceInstruction(String action, String amount, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          action,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            style: TextStyle(
              color: color,
              fontFamily: 'Courier',
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAzimuthMatchData(String label, double current, bool isLocked) {
    Color valueColor = isLocked ? _successGreen : _accentCyan;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          "${current.toStringAsFixed(1)}°",
          style: TextStyle(
            color: valueColor,
            fontFamily: 'Courier',
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

// ==========================================
// TACTICAL COMPASS PAINTER
// ==========================================
class CompassGraphPainter extends CustomPainter {
  final double targetAzimuth;
  final double targetElevation;
  final double currentAzimuth;
  final bool isLocked;

  CompassGraphPainter({
    required this.targetAzimuth,
    required this.targetElevation,
    required this.currentAzimuth,
    required this.isLocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final Color dynamicColor = isLocked
        ? const Color(0xFF00E676)
        : const Color(0xFFFF9100);

    final bgPaint = Paint()
      ..color = _panelColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxRadius, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.66, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.33, ringPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = const TextStyle(
      color: Colors.white54,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    final headingStyle = const TextStyle(
      color: _accentCyan,
      fontWeight: FontWeight.w900,
      fontSize: 18,
    );

    for (int i = 0; i < 360; i += 15) {
      double angle = (i - currentAzimuth - 90) * math.pi / 180;

      bool isCardinal = (i % 90 == 0);
      double tickLength = isCardinal ? 12 : 6;

      Offset outerPoint = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      Offset innerPoint = Offset(
        center.dx + (maxRadius - tickLength) * math.cos(angle),
        center.dy + (maxRadius - tickLength) * math.sin(angle),
      );

      canvas.drawLine(
        innerPoint,
        outerPoint,
        Paint()
          ..color = isCardinal ? Colors.white54 : Colors.white12
          ..strokeWidth = isCardinal ? 2.0 : 1.0,
      );

      if (isCardinal) {
        String label = '';
        if (i == 0) label = 'N';
        if (i == 90) label = 'E';
        if (i == 180) label = 'S';
        if (i == 270) label = 'W';

        textPainter.text = TextSpan(
          text: label,
          style: (i == currentAzimuth.round() % 360)
              ? headingStyle
              : labelStyle,
        );
        textPainter.layout();

        Offset textOffset = Offset(
          center.dx +
              (maxRadius - 28) * math.cos(angle) -
              textPainter.width / 2,
          center.dy +
              (maxRadius - 28) * math.sin(angle) -
              textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }

    final headingPaint = Paint()
      ..color = _accentCyan.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(center, Offset(center.dx, 0), headingPaint);

    double relativeAzimuth = targetAzimuth - currentAzimuth;
    double azRad = (relativeAzimuth - 90) * math.pi / 180;

    const double centerEl = 90.0;
    const double edgeEl = 20.0;

    double el = targetElevation;
    if (el > centerEl) el = centerEl;
    if (el < edgeEl) el = edgeEl;

    double distance = maxRadius * ((centerEl - el) / (centerEl - edgeEl));

    double x = center.dx + distance * math.cos(azRad);
    double y = center.dy + distance * math.sin(azRad);

    final beamPaint = Paint()
      ..color = dynamicColor.withValues(alpha: 0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(center, Offset(x, y), beamPaint);

    canvas.drawCircle(
      Offset(x, y),
      18,
      Paint()
        ..color = dynamicColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    final iconStr = String.fromCharCode(Icons.satellite_alt.codePoint);
    final iconPainter = TextPainter(
      text: TextSpan(
        text: iconStr,
        style: TextStyle(
          color: dynamicColor,
          fontSize: 22,
          fontFamily: Icons.satellite_alt.fontFamily,
          package: Icons.satellite_alt.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(x - (iconPainter.width / 2), y - (iconPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant CompassGraphPainter oldDelegate) {
    return oldDelegate.currentAzimuth != currentAzimuth ||
        oldDelegate.targetAzimuth != targetAzimuth ||
        oldDelegate.targetElevation != targetElevation ||
        oldDelegate.isLocked != isLocked;
  }
}
