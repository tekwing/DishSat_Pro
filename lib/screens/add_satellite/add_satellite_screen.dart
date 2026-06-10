import 'package:flutter/material.dart';
import '../../models/satellite_model.dart';
import '../../data/satellite_registry.dart';

// Shared tactical palette
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _alertOrange = Color(0xFFFF9100);
const Color _successGreen = Color(0xFF00E676);

// Helper class to manage dynamic transponder text controllers safely
class _TransponderForm {
  final TextEditingController freqCtrl = TextEditingController();
  String polarity = 'H';
  final TextEditingController srCtrl = TextEditingController();
  String modulation = 'DVB-S2';

  void dispose() {
    freqCtrl.dispose();
    srCtrl.dispose();
  }
}

class AddSatelliteScreen extends StatefulWidget {
  // Optional parameter: If provided, the screen enters "Edit Mode"
  final Satellite? satelliteToEdit;

  const AddSatelliteScreen({super.key, this.satelliteToEdit});

  @override
  State<AddSatelliteScreen> createState() => _AddSatelliteScreenState();
}

class _AddSatelliteScreenState extends State<AddSatelliteScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _positionCtrl = TextEditingController();
  final TextEditingController _skewCtrl = TextEditingController();

  String _hemisphere = 'E';
  final List<String> _selectedBands = ['Ku'];
  final List<String> _availableBands = ['Ku', 'C', 'Ka'];
  final List<_TransponderForm> _transponders = [];

  // --- PRE-FILL DATA IF EDITING ---
  @override
  void initState() {
    super.initState();
    if (widget.satelliteToEdit != null) {
      final sat = widget.satelliteToEdit!;
      _nameCtrl.text = sat.name;
      _positionCtrl.text = sat.position.toString();
      _hemisphere = sat.hemisphere;
      _skewCtrl.text = sat.lnbSkew.toString();

      _selectedBands.clear();
      _selectedBands.addAll(sat.bands);

      for (var tp in sat.transponders) {
        final tpForm = _TransponderForm();
        tpForm.freqCtrl.text = tp.frequency;
        tpForm.polarity = tp.polarity;
        tpForm.srCtrl.text = tp.symbolRate;
        tpForm.modulation = tp.modulation;
        _transponders.add(tpForm);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _skewCtrl.dispose();
    for (var t in _transponders) {
      t.dispose();
    }
    super.dispose();
  }

  // --- SAVE LOGIC ---
  void _saveSatellite() {
    // This triggers the validators on all TextFormFields
    if (_formKey.currentState!.validate()) {
      List<Transponder> newTransponders = _transponders.map((t) {
        return Transponder(
          frequency: t.freqCtrl.text.trim(),
          polarity: t.polarity,
          symbolRate: t.srCtrl.text.trim(),
          modulation: t.modulation,
        );
      }).toList();

      Satellite newSatellite = Satellite(
        name: _nameCtrl.text.trim().toUpperCase(),
        position: double.tryParse(_positionCtrl.text.trim()) ?? 0.0,
        hemisphere: _hemisphere,
        bands: _selectedBands,
        transponderCount: newTransponders.length,
        lnbSkew: double.tryParse(_skewCtrl.text.trim()) ?? 0.0,
        transponders: newTransponders,
      );

      // Check if we are updating or creating new
      if (widget.satelliteToEdit != null) {
        // Update existing Hive object using its unique key
        SatelliteRepository.updateSatellite(
          widget.satelliteToEdit!.key,
          newSatellite,
        );
      } else {
        // Add completely new
        SatelliteRepository.addSatellite(newSatellite);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _successGreen,
          content: Text(
            "SATELLITE SAVED",
            style: TextStyle(color: _bgDark, fontWeight: FontWeight.bold),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'MANUAL CONFIGURATION',
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
            icon: const Icon(Icons.save, color: _successGreen),
            onPressed: _saveSatellite,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- SATELLITE CORE DETAILS ---
            const _SectionHeader(title: "CORE PARAMETERS"),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _nameCtrl,
              label: "SATELLITE NAME (e.g., ASTRA 19.2)",
              icon: Icons.satellite_alt,
              validator: (val) =>
                  val == null || val.trim().isEmpty ? "Name required" : null,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment
                  .start, // Ensures fields align if error appears
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _positionCtrl,
                    label: "POSITION (°)",
                    icon: Icons.explore,
                    isNumber: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Required";
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null) return "Invalid Number";
                      if (parsed < 0.0 || parsed > 180.0) {
                        return "Must be 0-180°";
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _hemisphere,
                    dropdownColor: _panelColor,
                    style: const TextStyle(
                      color: _accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: _inputDeco("HEMI"),
                    items: ['E', 'W'].map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) => setState(() => _hemisphere = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _skewCtrl,
              label: "BASE LNB SKEW (°)",
              icon: Icons.rotate_right,
              isNumber: true,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Required";
                final parsed = double.tryParse(val.trim());
                if (parsed == null) return "Invalid Number";
                if (parsed < -90.0 || parsed > 90.0) {
                  return "Must be -90° to 90°";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // --- BANDS SELECTION ---
            const Text(
              "SUPPORTED BANDS",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: _availableBands.map((band) {
                final isSelected = _selectedBands.contains(band);
                return FilterChip(
                  label: Text(
                    band,
                    style: TextStyle(
                      color: isSelected ? _bgDark : Colors.white,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: _accentCyan,
                  backgroundColor: _panelColor,
                  checkmarkColor: _bgDark,
                  onSelected: (bool selected) {
                    setState(() {
                      selected
                          ? _selectedBands.add(band)
                          : _selectedBands.remove(band);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // --- TRANSPONDER LIST ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionHeader(title: "TRANSPONDERS"),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _transponders.add(_TransponderForm())),
                  icon: const Icon(Icons.add, color: _accentCyan, size: 18),
                  label: const Text(
                    "ADD TP",
                    style: TextStyle(
                      color: _accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: _accentCyan.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_transponders.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "NO TRANSPONDERS ADDED\nTap 'ADD TP' to configure frequencies.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transponders.length,
              itemBuilder: (context, index) {
                return _buildTransponderCard(index);
              },
            ),

            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  // --- UI BUILDER HELPERS ---

  Widget _buildTransponderCard(int index) {
    final tp = _transponders[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TP ${index + 1}",
                style: const TextStyle(
                  color: _accentCyan,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _transponders.removeAt(index)),
                child: const Icon(
                  Icons.delete_outline,
                  color: _alertOrange,
                  size: 20,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: tp.freqCtrl,
                  label: "FREQ (e.g. 11.950)",
                  isNumber: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Req";
                    if (double.tryParse(val.trim()) == null) return "Inv";
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: tp.polarity,
                  dropdownColor: _panelColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco("POL"),
                  items: ['H', 'V', 'L', 'R'].map((String val) {
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
                  onChanged: (val) => setState(() => tp.polarity = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: tp.srCtrl,
                  label: "SYMBOL RATE (SR)",
                  isNumber: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Req";
                    if (double.tryParse(val.trim()) == null) return "Inv";
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: tp.modulation,
                  dropdownColor: _panelColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco("MOD"),
                  items: ['DVB-S', 'DVB-S2', 'DVB-S2X'].map((String val) {
                    return DropdownMenuItem(value: val, child: Text(val));
                  }).toList(),
                  onChanged: (val) => setState(() => tp.modulation = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      validator: validator,
      decoration: _inputDeco(label, icon: icon),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: icon != null
          ? Icon(icon, color: _accentCyan, size: 20)
          : null,
      filled: true,
      fillColor: _panelColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentCyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _alertOrange, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _alertOrange, width: 1.5),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _accentCyan,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
