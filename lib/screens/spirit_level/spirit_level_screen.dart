import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/accelerometer_provider.dart';
import '../tutorial/tutorial_dialog.dart';

// Shared tactical palette
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
// const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class LinearSpiritLevelScreen extends ConsumerWidget {
  const LinearSpiritLevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double toleranceDegrees = 1.0;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Column(
          children: [
            Text(
              'DUAL-VIAL SPIRIT LEVEL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            Text(
              'LINEAR HORIZONTAL & VERTICAL GAUGE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
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
                title: "Mast Plumb Calibration",
                description:
                    "Ensure the pole is perfectly vertical before mounting the dish.",
                instructions: [
                  "Place the flat back of your phone directly against the side of the metal mast pole.",
                  "Adjust the base mount bolts.",
                  "Stop when the bubble is perfectly centered in the crosshairs and turns green.",
                ],
                imagePath:
                    'assets/images/tutorial_level.jpg', // Add your image here
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 1. LIVE DIGITAL READOUTS (Consumer Isolated)
              Consumer(
                builder: (context, ref, child) {
                  final accelState = ref.watch(accelerometerProvider);
                  final double xTilt = accelState.roll;
                  final double yTilt = accelState.elevation;

                  final bool xLevel = xTilt.abs() <= toleranceDegrees;
                  final bool yLevel = yTilt.abs() <= toleranceDegrees;

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
                          'HORIZONTAL VIAL',
                          '${xTilt.toStringAsFixed(1)}°',
                          xLevel ? _successGreen : _alertOrange,
                          xLevel ? 'LEVEL' : 'TILTED',
                        ),
                        Container(width: 1, height: 50, color: Colors.white10),
                        _buildDataColumn(
                          'VERTICAL VIAL',
                          '${yTilt.toStringAsFixed(1)}°',
                          yLevel ? _successGreen : _alertOrange,
                          yLevel ? 'PLUMB' : 'TILTED',
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // 2. THE PHYSICAL SPIRIT LEVEL BODY (Consumer Isolated & Fully Responsive)
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final accelState = ref.watch(accelerometerProvider);
                    final double xTilt = accelState.roll;
                    final double yTilt = accelState.elevation;

                    final bool xLevel = xTilt.abs() <= toleranceDegrees;
                    final bool yLevel = yTilt.abs() <= toleranceDegrees;

                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111622),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: (xLevel && yLevel)
                              ? _successGreen
                              : Colors.white10,
                          width: (xLevel && yLevel) ? 2.0 : 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: LinearLevelPainter(
                            xTilt: xTilt,
                            yTilt: yTilt,
                            xLevel: xLevel,
                            yLevel: yLevel,
                            tolerance: toleranceDegrees,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 3. HARDWARE ALIGNMENT STATUS BANNER (Consumer Isolated)
              Consumer(
                builder: (context, ref, child) {
                  final accelState = ref.watch(accelerometerProvider);
                  final bool xLevel = accelState.roll.abs() <= toleranceDegrees;
                  final bool yLevel =
                      accelState.elevation.abs() <= toleranceDegrees;

                  final bool fullyLevel = xLevel && yLevel;
                  final Color bannerColor = fullyLevel
                      ? _successGreen
                      : _alertOrange;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bannerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      fullyLevel
                          ? '✓ STRUCTURE IS PERFECTLY ALIGNED'
                          : 'ADJUST SURFACE UNTIL BOTH VIALS ARE CENTERED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: bannerColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataColumn(
    String label,
    String value,
    Color color,
    String status,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            fontFamily: 'Courier',
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// TACTICAL DUAL-VIAL LEVEL CUSTOM PAINTER
// ==========================================
class LinearLevelPainter extends CustomPainter {
  final double xTilt;
  final double yTilt;
  final bool xLevel;
  final bool yLevel;
  final double tolerance;

  LinearLevelPainter({
    required this.xTilt,
    required this.yTilt,
    required this.xLevel,
    required this.yLevel,
    required this.tolerance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. BASE MATH & SENSITIVITY CONFIG
    // We max out the bubble tracking drift at 12 degrees of physical slope
    const double maxVisibleDegrees = 12.0;

    // Define structural dimensions for the fluid tubes
    final double horizontalTubeWidth = size.width * 0.65;
    const double horizontalTubeHeight = 44.0;
    final Offset horizontalTubeCenter = Offset(
      size.width / 2,
      size.height * 0.32,
    );

    const double verticalTubeWidth = 44.0;
    final double verticalTubeHeight = size.height * 0.40;
    final Offset verticalTubeCenter = Offset(
      size.width / 2,
      size.height * 0.70,
    );

    // ==========================================
    // 2. PAINT THE HORIZONTAL VIAL (X-AXIS)
    // ==========================================
    final Rect hTubeRect = Rect.fromCenter(
      center: horizontalTubeCenter,
      width: horizontalTubeWidth,
      height: horizontalTubeHeight,
    );
    _drawFluidVial(canvas, hTubeRect, xLevel, true);

    // Calculate Horizontal Bubble Drift
    final double hPixelsPerDegree =
        (horizontalTubeWidth - 36) / (maxVisibleDegrees * 2);
    // Bubble drifts along X axis. Inverted to replicate physical fluid aerodynamics.
    double bubbleX = horizontalTubeCenter.dx - (xTilt * hPixelsPerDegree);

    // Safety clamp bubble inside the glass end-walls
    final double hMaxClamp = (horizontalTubeWidth / 2) - 20;
    bubbleX = bubbleX.clamp(
      horizontalTubeCenter.dx - hMaxClamp,
      horizontalTubeCenter.dx + hMaxClamp,
    );

    _drawLiquidBubble(canvas, Offset(bubbleX, horizontalTubeCenter.dy), xLevel);
    _drawVialCenterBracket(
      canvas,
      hTubeRect,
      tolerance * hPixelsPerDegree,
      true,
    );

    // ==========================================
    // 3. PAINT THE VERTICAL VIAL (Y-AXIS)
    // ==========================================
    final Rect vTubeRect = Rect.fromCenter(
      center: verticalTubeCenter,
      width: verticalTubeWidth,
      height: verticalTubeHeight,
    );
    _drawFluidVial(canvas, vTubeRect, yLevel, false);

    // Calculate Vertical Bubble Drift
    final double vPixelsPerDegree =
        (verticalTubeHeight - 36) / (maxVisibleDegrees * 2);
    // Bubble drifts along Y axis. Inverted to follow physical gravity kinetics.
    double bubbleY = verticalTubeCenter.dy + (yTilt * vPixelsPerDegree);

    // Safety clamp bubble inside the glass end-walls
    final double vMaxClamp = (verticalTubeHeight / 2) - 20;
    bubbleY = bubbleY.clamp(
      verticalTubeCenter.dy - vMaxClamp,
      verticalTubeCenter.dy + vMaxClamp,
    );

    _drawLiquidBubble(canvas, Offset(verticalTubeCenter.dx, bubbleY), yLevel);
    _drawVialCenterBracket(
      canvas,
      vTubeRect,
      tolerance * vPixelsPerDegree,
      false,
    );
  }

  // Helper: Draws the glass outer frame containing the neon liquid matrix
  void _drawFluidVial(
    Canvas canvas,
    Rect tubeRect,
    bool isLevel,
    bool isHorizontal,
  ) {
    final Color colorTheme = isLevel ? _successGreen : _alertOrange;

    // Fluid Core Backing Fill
    final Paint fluidPaint = Paint()
      ..color = colorTheme.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tubeRect, const Radius.circular(8)),
      fluidPaint,
    );

    // Glass Outer Wall Border Rim
    final Paint glassRimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(tubeRect, const Radius.circular(8)),
      glassRimPaint,
    );
  }

  // Helper: Paints the high-visibility neon air bubble floating in the tube
  void _drawLiquidBubble(Canvas canvas, Offset position, bool isLevel) {
    final Color bubbleColor = isLevel ? _successGreen : _alertOrange;

    // Glowing Neon Ambient Mesh Aura
    canvas.drawCircle(
      position,
      16,
      Paint()
        ..color = bubbleColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Solid Glass Bubble Rim Boundary
    canvas.drawCircle(
      position,
      12,
      Paint()
        ..color = bubbleColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Filled Core Liquid center
    canvas.drawCircle(
      position,
      8,
      Paint()
        ..color = bubbleColor
        ..style = PaintingStyle.fill,
    );

    // Specular Light Highlight reflection node (3D Glass Orb Illusion)
    canvas.drawCircle(
      Offset(position.dx - 3, position.dy - 3),
      2.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );
  }

  // Helper: Paints the precise alignment marker lines `|  |` directly onto the center of the vials
  void _drawVialCenterBracket(
    Canvas canvas,
    Rect tubeRect,
    double toleranceWidth,
    bool isHorizontal,
  ) {
    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (isHorizontal) {
      // Left Center Bracket Line
      canvas.drawLine(
        Offset(tubeRect.center.dx - toleranceWidth - 6, tubeRect.top),
        Offset(tubeRect.center.dx - toleranceWidth - 6, tubeRect.bottom),
        linePaint,
      );
      // Right Center Bracket Line
      canvas.drawLine(
        Offset(tubeRect.center.dx + toleranceWidth + 6, tubeRect.top),
        Offset(tubeRect.center.dx + toleranceWidth + 6, tubeRect.bottom),
        linePaint,
      );
    } else {
      // Top Center Bracket Line
      canvas.drawLine(
        Offset(tubeRect.left, tubeRect.center.dy - toleranceWidth - 6),
        Offset(tubeRect.right, tubeRect.center.dy - toleranceWidth - 6),
        linePaint,
      );
      // Bottom Center Bracket Line
      canvas.drawLine(
        Offset(tubeRect.left, tubeRect.center.dy + toleranceWidth + 6),
        Offset(tubeRect.right, tubeRect.center.dy + toleranceWidth + 6),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LinearLevelPainter oldDelegate) {
    return oldDelegate.xTilt != xTilt ||
        oldDelegate.yTilt != yTilt ||
        oldDelegate.xLevel != xLevel ||
        oldDelegate.yLevel != yLevel;
  }
}
