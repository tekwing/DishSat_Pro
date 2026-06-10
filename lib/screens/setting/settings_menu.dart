import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORTANT: Adjust this path to where you saved the provider!
import '../../core/providers/settings_provider.dart';
import '../../core/providers/location_provider.dart';
import '../tutorial/tool_help_guide_screen.dart'; // Adjust path if needed

// Shared tactical palette
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);

class GlobalSettingsMenu extends ConsumerWidget {
  const GlobalSettingsMenu({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const GlobalSettingsMenu(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    // Watch location state to show if override is active
    final locationState = ref.watch(locationProvider);
    final bool isOverrideActive = locationState.isManualOverride;

    return Container(
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: _accentCyan.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            spreadRadius: 5,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Text(
                      "COMMAND CENTER",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "GLOBAL APP CONFIGURATION",
                      style: TextStyle(
                        color: _accentCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const Divider(
                      color: Colors.white10,
                      height: 32,
                      thickness: 1,
                    ),

                    _buildMenuButton(
                      context,
                      icon: Icons.menu_book_rounded,
                      title: "FIELD CALIBRATION GUIDE",
                      subtitle: "Interactive visual manual for all tools",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ToolHelpGuideScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- MANUAL GPS OVERRIDE BUTTON ---
                    _buildMenuButton(
                      context,
                      icon: Icons.edit_location_alt_outlined,
                      title: "MANUAL GPS OVERRIDE",
                      subtitle: isOverrideActive
                          ? "OVERRIDE ACTIVE [ ${locationState.lat?.toStringAsFixed(2)}, ${locationState.lon?.toStringAsFixed(2)} ]"
                          : "Force specific Lat/Lon coordinates",
                      isActive: isOverrideActive, // Highlight orange if active
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const ManualGpsDialog(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // --- NEW: DISH OFFSET SLIDER ---
                    _buildSliderOption(
                      title: "PARABOLIC OFFSET ANGLE",
                      subtitle: "Subtracts curve angle from true elevation",
                      value: settings.dishOffsetAngle,
                      onChanged: (val) =>
                          settingsNotifier.setDishOffsetAngle(val),
                    ),
                    const SizedBox(height: 12),

                    // --- WIRE UP THE TOGGLES ---
                    _buildToggleSwitch(
                      icon: Icons.explore,
                      title: "USE TRUE NORTH",
                      subtitle: "Adjust azimuth for magnetic declination",
                      value: settings.useTrueNorth,
                      onChanged: (val) => settingsNotifier.toggleTrueNorth(val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleSwitch(
                      icon: Icons.volume_up,
                      title: "AUDIO FEEDBACK",
                      subtitle: "Targeting beeps and lock sounds",
                      value: settings.enableSound,
                      onChanged: (val) => settingsNotifier.toggleSound(val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleSwitch(
                      icon: Icons.lightbulb,
                      title: "PREVENT SCREEN SLEEP",
                      subtitle: "Keep display on while tools are active",
                      value: settings.preventScreenOff,
                      onChanged: (val) => settingsNotifier.toggleScreenOff(val),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleSwitch(
                      icon: Icons.vibration,
                      title: "HAPTIC FEEDBACK",
                      subtitle: "Vibrate on satellite alignment lock",
                      value: settings.enableVibration,
                      onChanged: (val) => settingsNotifier.toggleVibration(val),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? _alertOrange.withValues(alpha: 0.1) : _panelColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? _alertOrange.withValues(alpha: 0.5)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? _alertOrange : _accentCyan, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? _alertOrange : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isActive
                          ? _alertOrange.withValues(alpha: 0.8)
                          : Colors.white54,
                      fontSize: 11,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isActive ? _alertOrange : Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderOption({
    required String title,
    required String subtitle,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _accentCyan.withValues(alpha: 0.3)),
                ),
                child: Text(
                  "-${value.toStringAsFixed(1)}°",
                  style: const TextStyle(
                    color: _accentCyan,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Courier',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: _accentCyan,
              inactiveTrackColor: Colors.white10,
              thumbColor: _accentCyan,
              overlayColor: _accentCyan.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 35.0,
              divisions: 70, // Snaps to every 0.5 degrees
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: value, activeColor: _accentCyan, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ==========================================
// MANUAL GPS DIALOG UI
// ==========================================
class ManualGpsDialog extends ConsumerStatefulWidget {
  const ManualGpsDialog({super.key});

  @override
  ConsumerState<ManualGpsDialog> createState() => _ManualGpsDialogState();
}

class _ManualGpsDialogState extends ConsumerState<ManualGpsDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final locState = ref.read(locationProvider);
    if (locState.isManualOverride == true) {
      _latCtrl.text = locState.lat?.toString() ?? '';
      _lonCtrl.text = locState.lon?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  void _saveOverride() {
    if (_formKey.currentState!.validate()) {
      final double lat = double.parse(_latCtrl.text.trim());
      final double lon = double.parse(_lonCtrl.text.trim());

      ref.read(locationProvider.notifier).setManualLocation(lat, lon);
      Navigator.pop(context);
    }
  }

  void _clearOverride() {
    ref.read(locationProvider.notifier).clearManualLocation();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasExistingOverride =
        ref.watch(locationProvider).isManualOverride == true;

    return Dialog(
      backgroundColor: _bgDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _accentCyan, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.satellite_alt, color: _accentCyan, size: 40),
              const SizedBox(height: 16),
              const Text(
                "GPS OVERRIDE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Force the app to calculate math from a custom location instead of hardware sensors.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _latCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: _inputDeco("Latitude (e.g. 34.05)"),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Required";
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null) return "Invalid Number";
                  if (parsed < -90.0 || parsed > 90.0) {
                    return "Must be -90 to 90";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lonCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: _inputDeco("Longitude (e.g. -118.24)"),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Required";
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null) return "Invalid Number";
                  if (parsed < -180.0 || parsed > 180.0) {
                    return "Must be -180 to 180";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveOverride,
                  child: const Text(
                    "ENGAGE OVERRIDE",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (hasExistingOverride) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _alertOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _alertOrange.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    onPressed: _clearOverride,
                    child: const Text(
                      "RESTORE LIVE GPS",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: _panelColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentCyan),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _alertOrange),
      ),
    );
  }
}
