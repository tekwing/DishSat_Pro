import 'dart:math' as math;
import 'package:flutter/material.dart';

// Shared tactical palette
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);
const Color _borderLight = Color(0x0DFFFFFF);

class ToolHelpGuideScreen extends StatelessWidget {
  const ToolHelpGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: _bgDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'FIELD CALIBRATION GUIDE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorColor: _accentCyan,
            labelColor: _accentCyan,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1,
            ),
            tabs: const [
              Tab(text: "1. MAST LEVEL"),
              Tab(text: "2. LINE OF SIGHT"),
              Tab(text: "3. LNB SKEW"),
              Tab(text: "4. ELEVATION"),
              Tab(text: "5. AR COMPASS"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HelpTabContent(
              title: "Mast Plumb Calibration",
              description:
                  "Before assembling the dish, the mounting mast pole must be 100% vertical. If the pole is tilted even slightly, all future satellite calculations will fail.",
              instructions: [
                "Place the flat back of the phone directly against the metal mast pole.",
                "Ensure the phone remains in vertical Portrait orientation.",
                "Adjust the structural mount braces until BOTH the horizontal and vertical fluid bubble vials slide into the center brackets and flash green.",
              ],
              diagramType: _DiagramType.mastLevel,
            ),
            _HelpTabContent(
              title: "Line-of-Sight Clinometer",
              description:
                  "Used at eye level to inspect the signal path before choosing a structural drilling footprint on the roof. Detects hidden tree branches or wall obstructions.",
              instructions: [
                "Hold the smartphone up in front of your face like taking a vertical photo.",
                "Tilt your phone up/down until the crosshairs line up with the target altitude horizon marker.",
                "Look through the camera screen along the glowing guide line. If branches, buildings, or power cables cross this path, you must relocate your mount.",
              ],
              diagramType: _DiagramType.clinometer,
            ),
            _HelpTabContent(
              title: "LNB Polarization Skew",
              description:
                  "Aligns the internal matching dipole pins inside the horn with the horizontal/vertical transponder wave planes coming down from the geostationary satellite orbit.",
              instructions: [
                "Loosen the LNB collar clamp screws slightly so it can rotate.",
                "Stand IN FRONT of the dish assembly, facing the LNB.",
                "Establish the 0° baseline: rotate the LNB so the coaxial cable connector pin points straight down at the ground.",
                "Place the back of your phone flat against the rear terminal cap of the plastic LNB feedhorn (with the phone pointing straight up).",
                "Twist the LNB body and the phone together simultaneously until the indicator needle seats firmly inside the locked target notch.",
              ],
              diagramType: _DiagramType.lnbSkew,
            ),
            _HelpTabContent(
              title: "Dish Elevation Pitch",
              description:
                  "Calibrates the exact upward vertical pointing index angle of the reflector offset relative to the gravity horizon plane based on your absolute GPS coordinate.",
              instructions: [
                "Loosen the elevation locking hex nuts on the side of the metal dish pivot bracket.",
                "Press the back of your phone completely flat against the support metal arm directly holding the dish so now the phone's back faces the sky.",
                "Slowly tilt the entire dish shell assembly up or down until the sliding scale line docks safely inside the central aeronautical brackets.",
              ],
              diagramType: _DiagramType.elevation,
            ),
            _HelpTabContent(
              title: "AR Compass Tracking",
              description:
                  "The final left/right rotational alignment step (Azimuth) to establish the direct, high-gain vector link with the selected satellite array footprint.",
              instructions: [
                "Stand directly behind the dish bracket, looking straight over the dish center axis line.",
                "Hold the phone completely flat and level (face up) like a standard magnetic fluid pocket compass.",
                "If the orange calibration banner flashes, rotate the phone dynamically in a 3D figure-8 pattern to dump hard-iron environmental interference.",
                "Slowly rotate the physical dish chassis left or right until the sweep indicator locks onto the absolute target satellite azimuth path.",
              ],
              diagramType: _DiagramType.arCompass,
            ),
          ],
        ),
      ),
    );
  }
}

enum _DiagramType { mastLevel, clinometer, lnbSkew, elevation, arCompass }

class _HelpTabContent extends StatelessWidget {
  final String title;
  final String description;
  final List<String> instructions;
  final _DiagramType diagramType;

  const _HelpTabContent({
    required this.title,
    required this.description,
    required this.instructions,
    required this.diagramType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic Canvas Area (Responsive vector space)
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0C1322),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderLight),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: _HelpDiagramPainter(type: diagramType),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Description Headers
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const Divider(color: Colors.white10, height: 24),
          // Step-by-Step Walkthrough List
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: instructions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: _panelColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                              color: _accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          instructions[index],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// VECTOR VECTOR GRAPHICS ENGINE FOR DIAGRAMS
// ==========================================
class _HelpDiagramPainter extends CustomPainter {
  final _DiagramType type;
  _HelpDiagramPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final accentPaint = Paint()
      ..color = _accentCyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final orangePaint = Paint()
      ..color = _alertOrange
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    switch (type) {
      // 1. DIAGRAM: MAST PLUMB LEVEL SETUP
      case _DiagramType.mastLevel:
        // Draw physical pole mount
        canvas.drawRect(
          Rect.fromLTWH(
            center.dx - 15,
            size.height * 0.1,
            30,
            size.height * 0.8,
          ),
          linePaint,
        );
        // Draw structural wall brace base
        canvas.drawLine(
          Offset(center.dx - 15, size.height * 0.7),
          Offset(center.dx - 70, size.height * 0.8),
          linePaint,
        );
        canvas.drawLine(
          Offset(center.dx - 70, size.height * 0.5),
          Offset(center.dx - 70, size.height * 0.9),
          linePaint,
        );

        // Draw Mobile phone held flat vertically against the side
        final phoneRect = Rect.fromLTWH(
          center.dx + 16,
          center.dy - 60,
          45,
          110,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(phoneRect, const Radius.circular(6)),
          accentPaint
            ..style = PaintingStyle.fill
            ..color = _panelColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(phoneRect, const Radius.circular(6)),
          accentPaint
            ..style = PaintingStyle.stroke
            ..color = _accentCyan
            ..strokeWidth = 2,
        );

        // Draw alignment arrow indicators pointing phone to pole
        canvas.drawLine(
          Offset(center.dx + 12, center.dy),
          Offset(center.dx - 5, center.dy),
          orangePaint..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset(center.dx - 5, center.dy),
          Offset(center.dx + 2, center.dy - 5),
          orangePaint,
        );
        canvas.drawLine(
          Offset(center.dx - 5, center.dy),
          Offset(center.dx + 2, center.dy + 5),
          orangePaint,
        );
        break;

      // 2. DIAGRAM: CLINOMETER OBSTRUCTION INSPECTOR
      case _DiagramType.clinometer:
        // Draw standing technician profile vector node
        canvas.drawCircle(
          Offset(center.dx - 80, center.dy + 20),
          12,
          linePaint,
        );
        canvas.drawLine(
          Offset(center.dx - 80, center.dy + 32),
          Offset(center.dx - 80, center.dy + 90),
          linePaint,
        );
        canvas.drawLine(
          Offset(center.dx - 80, center.dy + 45),
          Offset(center.dx - 55, center.dy + 30),
          linePaint,
        ); // Arm holding phone

        // Mobile device held vertically up
        final clPhone = Rect.fromCenter(
          center: Offset(center.dx - 50, center.dy + 25),
          width: 12,
          height: 28,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(clPhone, const Radius.circular(2)),
          accentPaint
            ..style = PaintingStyle.fill
            ..color = _accentCyan,
        );

        // Line of Sight rays firing outward to deep space satellite path
        final losPaint = Paint()
          ..color = _successGreen
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(center.dx - 50, center.dy + 25),
          Offset(size.width * 0.9, center.dy - 60),
          losPaint,
        );

        // Obstruction object (Tree/Building outline skeleton)
        canvas.drawRect(
          Rect.fromLTWH(size.width * 0.65, center.dy + 10, 45, 80),
          linePaint,
        );
        // Cloud/Leaf cluster canopy
        canvas.drawCircle(
          Offset(size.width * 0.72, center.dy + 10),
          30,
          linePaint
            ..style = PaintingStyle.fill
            ..color = Colors.white.withValues(alpha: 0.03),
        );
        canvas.drawCircle(
          Offset(size.width * 0.72, center.dy + 10),
          30,
          linePaint
            ..style = PaintingStyle.stroke
            ..color = Colors.white12,
        );
        break;

      // 3. DIAGRAM: LNB POLARIZATION SKEW TWIST
      case _DiagramType.lnbSkew:
        // Draw large circle representing circular face view of LNB Feedhorn back cap
        canvas.drawCircle(center, 65, linePaint..strokeWidth = 3);
        canvas.drawCircle(
          center,
          8,
          linePaint..style = PaintingStyle.fill,
        ); // Center shaft

        // Coaxial output pin rotating baseline path index
        canvas.drawLine(
          center,
          Offset(center.dx, center.dy + 65),
          linePaint..strokeWidth = 1.5,
        );

        // Phone clamped flat onto the face rotating with skew offset vector
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(
          28 * math.pi / 180,
        ); // Simulate an active 28-degree offset skew rotation twist

        final skewPhone = Rect.fromCenter(
          center: Offset.zero,
          width: 45,
          height: 95,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(skewPhone, const Radius.circular(6)),
          orangePaint
            ..style = PaintingStyle.fill
            ..color = _panelColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(skewPhone, const Radius.circular(6)),
          orangePaint
            ..style = PaintingStyle.stroke
            ..color = _alertOrange
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset.zero,
          const Offset(0, 45),
          orangePaint
            ..strokeWidth = 3
            ..color = _successGreen,
        ); // Level line on tool

        canvas.restore();
        break;

      // 4. DIAGRAM: DISH ELEVATION ANGLE SETUP
      case _DiagramType.elevation:
        // Draw parabolic curved antenna dish profile side view arc path
        final dishPath = Path()
          ..moveTo(center.dx - 40, center.dy - 80)
          ..quadraticBezierTo(
            center.dx - 80,
            center.dy,
            center.dx - 40,
            center.dy + 80,
          );
        canvas.drawPath(dishPath, linePaint..strokeWidth = 4);

        // Draw structural support feedhorn arm pointing outward from dish center
        canvas.drawLine(
          Offset(center.dx - 65, center.dy + 40),
          Offset(center.dx + 30, center.dy + 55),
          linePaint..strokeWidth = 3,
        );
        // Plastic LNB housing shape box outline
        canvas.drawRect(
          Rect.fromLTWH(center.dx + 20, center.dy + 35, 20, 20),
          linePaint,
        );

        // Phone held flat directly on top of the straight LNB bracket arm
        canvas.save();
        canvas.translate(center.dx - 15, center.dy + 47);
        canvas.rotate(
          11 * math.pi / 180,
        ); // Reflective true installation pitch tilt angle incline

        final elPhone = Rect.fromLTWH(-30, -8, 65, 14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(elPhone, const Radius.circular(3)),
          accentPaint
            ..style = PaintingStyle.fill
            ..color = _panelColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(elPhone, const Radius.circular(3)),
          accentPaint
            ..style = PaintingStyle.stroke
            ..color = _accentCyan
            ..strokeWidth = 1.5,
        );

        canvas.restore();
        break;

      // 5. DIAGRAM: AR ORBITAL COMPASS ALIGNMENT
      case _DiagramType.arCompass:
        // Draw flat horizon plate circle view grid mapping floor
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy + 40),
            width: 160,
            height: 60,
          ),
          linePaint,
        );

        // Telemetry beam vector rising up to targeted Clarke geostationary arc belt
        canvas.drawLine(
          center,
          Offset(center.dx + 50, size.height * 0.15),
          orangePaint
            ..strokeWidth = 1.5
            ..color = _alertOrange.withValues(alpha: 0.4),
        );
        canvas.drawCircle(
          Offset(center.dx + 50, size.height * 0.15),
          6,
          orangePaint
            ..style = PaintingStyle.fill
            ..color = _alertOrange,
        );

        // Phone held completely level horizontally (flat inside hand view looking down)
        final flatPhone = Rect.fromCenter(
          center: Offset(center.dx, center.dy + 15),
          width: 75,
          height: 45,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(flatPhone, const Radius.circular(4)),
          accentPaint
            ..style = PaintingStyle.fill
            ..color = _panelColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(flatPhone, const Radius.circular(4)),
          accentPaint
            ..style = PaintingStyle.stroke
            ..color = _accentCyan
            ..strokeWidth = 2,
        );

        // Radar sweeping crosshair grid intersection projected lines onto phone surface
        canvas.drawLine(
          Offset(center.dx - 25, center.dy + 15),
          Offset(center.dx + 25, center.dy + 15),
          accentPaint
            ..strokeWidth = 1
            ..color = _accentCyan.withValues(alpha: 0.4),
        );
        canvas.drawLine(
          Offset(center.dx, center.dy - 3),
          Offset(center.dx, center.dy + 33),
          accentPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
