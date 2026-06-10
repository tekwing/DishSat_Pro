import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../tracking/active_tracking_screen.dart';
import '../ar_view/ar_view_screen.dart';
import '../radar_view/radar_view_screen.dart';
import '../lnb_skew/lnb_skew.dart';
import '../frequency/frequency.dart';
import '../elevation/elevation_screen.dart';
import '../los_scanner/los_scanner_screen.dart';
import '../spirit_level/spirit_level_screen.dart';
import '../setting/settings_menu.dart';
import '../satellite/satellite_registry_screen.dart';

import '../../core/providers/compass_provider.dart';
import '../../core/providers/location_provider.dart';
import '../../core/providers/active_satellite_provider.dart';

import 'widgets/tool_card_main.dart';
import 'widgets/tool_card_aux.dart';

// ==========================================
// PREMIUM TACTICAL COLOR PALETTE
// ==========================================
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final compassState = ref.watch(compassProvider);
    final locationState = ref.watch(locationProvider);
    final activeSatellite = ref.watch(
      activeSatelliteProvider,
    ); // Watch for UI updates

    final heading = compassState.azimuth;
    final compassAvailable = compassState.isAvailable;
    final gpsAccuracy = locationState.accuracy;
    final isGpsLocked = locationState.isLocked;

    return Scaffold(
      backgroundColor: _bgDark,

      // =========================
      // CUSTOM TOP NAVIGATION
      // =========================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: _accentCyan.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.png',
                width: 26,
                height: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "DISHSAT",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _accentCyan.withValues(alpha: 0.5)),
              ),
              child: const Text(
                "PRO",
                style: TextStyle(
                  color: _accentCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showCompassCalibrationDialog();
            },
            icon: const Icon(Icons.explore, color: _alertOrange, size: 26)
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scaleXY(begin: 0.9, end: 1.15, duration: 1200.ms)
                .fade(begin: 0.4, end: 1, duration: 1200.ms),
            splashRadius: 20,
          ),
          IconButton(
            onPressed: () {
              // SLIDES UP THE COMMAND CENTER MENU!
              GlobalSettingsMenu.show(context);
            },
            icon: const Icon(Icons.settings, color: Colors.white70),
            splashRadius: 20,
          ),
          const SizedBox(width: 12),
        ],
      ),

      // =========================
      // MAIN BODY
      // =========================
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DIAGNOSTIC HEADER ---
              Row(
                children: [
                  Expanded(
                    child: _buildStatusMetric(
                      icon: Icons.gps_fixed,
                      label: "GPS STATUS",
                      value: isGpsLocked ? "LOCKED" : "SEARCHING...",
                      subValue: isGpsLocked
                          ? "Accuracy ±${gpsAccuracy?.toStringAsFixed(0) ?? '--'}m"
                          : null,
                      statusColor: isGpsLocked ? _successGreen : _alertOrange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatusMetric(
                      icon: Icons.compass_calibration,
                      label: "MAGNETIC",
                      value: compassAvailable ? "ACTIVE" : "SEARCHING",
                      subValue: compassAvailable
                          ? "${heading.toStringAsFixed(0)}°"
                          : null,
                      statusColor: compassAvailable
                          ? _accentCyan
                          : _alertOrange,
                    ),
                  ),
                ],
              ).animate().fade().slideY(begin: -0.1),

              const SizedBox(height: 28),

              // --- PRIMARY TRACKING ACTION ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentCyan.withValues(alpha: 0.3)),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00838F), Color(0xFF006064)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _accentCyan.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActiveTrackingScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 18,
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              // CENTER CONTENT (UNCHANGED TEXT, NOT A BUTTON)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      )
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .fade(begin: 0.4, end: 1),

                                  const SizedBox(width: 16),

                                  const Text(
                                    "INITIATE TRACKING",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),

                              // TOP-RIGHT AFFORDANCE INDICATOR
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Icon(
                                  Icons.north_east_rounded,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 18,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // SATELLITE DROPDOWN / TARGET SELECTOR
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SatelliteRegistryScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _accentCyan.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.satellite_alt,
                                    color: _accentCyan,
                                    size: 16,
                                  ),

                                  const SizedBox(width: 8),

                                  // --- THE FIX: Wrapped in Flexible and added overflow: ellipsis ---
                                  Flexible(
                                    child: Text(
                                      "TARGET: ${activeSatellite.name} (${activeSatellite.formattedPosition})",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _accentCyan,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: _accentCyan,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate(delay: 200.ms).fade().scale(begin: const Offset(0.98, 0.98)),

              const SizedBox(height: 36),

              // =========================
              // TECHNICIAN TOOLKIT GRID
              // =========================
              _buildSectionHeader("DIAGNOSTIC INSTRUMENTS"),
              const SizedBox(height: 16),

              GridView(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220, // card width limit
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  PremiumMainToolCard(
                    icon: Icons.view_in_ar,
                    title: "AR View",
                    subtitle: "Live Satellite Overlay",
                    color: Colors.purpleAccent,
                    delay: 300,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ArViewScreen()),
                      );
                    },
                  ),
                  PremiumMainToolCard(
                    icon: Icons.radar,
                    title: "Radar Graph",
                    subtitle: "2D Signal Tracking",
                    color: _accentCyan,
                    delay: 400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GraphViewScreen(),
                        ),
                      );
                    },
                  ),
                  PremiumMainToolCard(
                    icon: Icons.rotate_90_degrees_ccw,
                    title: "LNB Skew",
                    subtitle: "Rotate for Signal Lock",
                    color: _alertOrange,
                    delay: 500,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LnbSkewScreen(),
                        ),
                      );
                    },
                  ),

                  PremiumMainToolCard(
                    icon: Icons.terrain,
                    title: "Elevation",
                    subtitle: "Vertical Satellite Angle",
                    color: Colors.pinkAccent,
                    delay: 800,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ElevationScreen(),
                      ),
                    ),
                  ),
                  PremiumMainToolCard(
                    icon: Icons.visibility,
                    title: "LOS Scanner",
                    subtitle: "Check Obstructions to Satellite Path",
                    color: Colors.blueAccent,
                    delay: 700,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LOSScannerScreen(),
                      ),
                    ),
                  ),
                  PremiumMainToolCard(
                    icon: Icons.broadcast_on_personal,
                    title: "Transponders",
                    subtitle: "Satellite Frequency Data",
                    color: _successGreen,
                    delay: 600,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TransponderScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              PremiumWideToolCard(
                icon: Icons.straighten,
                title: "Level Meter",
                subtitle: "Measure Tilt Accuracy",
                color: Colors.blueAccent,
                delay: 700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LinearSpiritLevelScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompassCalibrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: _panelColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.compass_calibration,
                  color: _accentCyan,
                  size: 60,
                ),

                const SizedBox(height: 16),

                const Text(
                  "COMPASS CALIBRATION",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                const _FigureEightAnimation(),

                const SizedBox(height: 20),

                const Text(
                  "Before using dish alignment tools, move your phone in a figure-8 pattern several times.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accentCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _successGreen,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Hold phone flat",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _successGreen,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Move in figure-8 pattern",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _successGreen,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Rotate in all directions",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentCyan,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "UNDERSTOOD",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildStatusMetric({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FigureEightAnimation extends StatefulWidget {
  const _FigureEightAnimation();

  @override
  State<_FigureEightAnimation> createState() => _FigureEightAnimationState();
}

class _FigureEightAnimationState extends State<_FigureEightAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 140,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          return CustomPaint(painter: FigureEightPainter(controller.value));
        },
      ),
    );
  }
}

class FigureEightPainter extends CustomPainter {
  final double progress;

  FigureEightPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();

    for (double t = 0; t <= math.pi * 2; t += 0.02) {
      final x = size.width / 2 + 70 * math.sin(t);
      final y = size.height / 2 + 40 * math.sin(t) * math.cos(t);

      if (t == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, pathPaint);

    final t = progress * math.pi * 2;

    final dotX = size.width / 2 + 70 * math.sin(t);

    final dotY = size.height / 2 + 40 * math.sin(t) * math.cos(t);

    canvas.drawCircle(Offset(dotX, dotY), 10, Paint()..color = _accentCyan);

    final glowPaint = Paint()
      ..color = _accentCyan.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(Offset(dotX, dotY), 22, glowPaint);
  }

  @override
  bool shouldRepaint(covariant FigureEightPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
