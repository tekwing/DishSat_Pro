import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ensure this path matches your project structure
import '../../core/providers/active_satellite_provider.dart';

const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);

class TransponderScreen extends ConsumerWidget {
  // CLEAN ARCHITECTURE: No constructor parameters needed.
  const TransponderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. WATCH GLOBAL STATE
    // We instantly get the globally selected satellite.
    final satellite = ref.watch(activeSatelliteProvider);

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${satellite.name} FREQUENCIES",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: satellite.transponders.length,
        itemBuilder: (context, index) {
          final tp = satellite.transponders[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${tp.frequency} GHz",
                      style: const TextStyle(
                        color: _accentCyan,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Courier',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${tp.polarity} • SR ${tp.symbolRate} • ${tp.modulation}",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Icon(
                  tp.polarity == "H"
                      ? Icons.arrow_forward
                      : Icons.arrow_downward,
                  color: tp.polarity == "H" ? Colors.orange : Colors.lightBlue,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
