import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/satellite_model.dart';
import '../../data/satellite_registry.dart';
import '../add_satellite/add_satellite_screen.dart';

import '../../core/providers/active_satellite_provider.dart';

// Premium Tactical Color Palette
const Color _bgDark = Color(0xFF090E17);
const Color _panelColor = Color(0xFF131A2A);
const Color _accentCyan = Color(0xFF00E5FF);
const Color _borderLight = Color(0x0DFFFFFF);

class SatelliteRegistryScreen extends ConsumerStatefulWidget {
  const SatelliteRegistryScreen({super.key});

  @override
  ConsumerState<SatelliteRegistryScreen> createState() =>
      _SatelliteRegistryScreenState();
}

class _SatelliteRegistryScreenState
    extends ConsumerState<SatelliteRegistryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "ALL";

  // --- THE FIX: Changed from a 'final' variable to a live 'getter' ---
  List<Satellite> get _allSatellites => SatelliteRepository.satellites;

  @override
  Widget build(BuildContext context) {
    final activeSatellite = ref.watch(activeSatelliteProvider);

    // Because _allSatellites is now a getter, this .where() loop evaluates
    // a fresh list from the database every single time the screen rebuilds!
    final filteredSatellites = _allSatellites.where((sat) {
      final matchesSearch =
          sat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          sat.position.toString().contains(_searchQuery);
      final matchesFilter =
          _selectedFilter == "ALL" || sat.bands.contains(_selectedFilter);
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "SATELLITE REGISTRY",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentCyan,
        icon: const Icon(Icons.add, color: _bgDark),
        label: const Text(
          "SATELLITE",
          style: TextStyle(color: _bgDark, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          // Wait for the user to finish adding a satellite
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddSatelliteScreen()),
          );
          // Rebuild the UI. The getter will fetch the updated database!
          setState(() {});
        },
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderLight),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Courier',
                  ),
                  cursorColor: _accentCyan,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: "SEARCH BY NAME OR ORBIT...",
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                              size: 16,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: ["ALL", "Ku", "C", "Ka"].map((band) {
                  final isSelected = _selectedFilter == band;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(band == "ALL" ? "ALL FREQ" : "$band-BAND"),
                      selected: isSelected,
                      selectedColor: _accentCyan.withValues(alpha: 0.15),
                      backgroundColor: _panelColor,
                      labelStyle: TextStyle(
                        color: isSelected ? _accentCyan : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? _accentCyan.withValues(alpha: 0.5)
                              : _borderLight,
                        ),
                      ),
                      onSelected: (_) => setState(() => _selectedFilter = band),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: filteredSatellites.isEmpty
                    ? const Center(
                        child: Text(
                          "NO COMPATIBLE SATELLITES FOUND",
                          style: TextStyle(
                            color: Colors.white24,
                            fontFamily: 'Courier',
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filteredSatellites.length,
                        itemBuilder: (context, index) {
                          final sat = filteredSatellites[index];

                          // Highlight if it's the currently active one
                          final isActive = sat.name == activeSatellite.name;

                          // 1. Build the core visual card
                          Widget satelliteCard = Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _accentCyan.withValues(alpha: 0.1)
                                  : _panelColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive ? _accentCyan : _borderLight,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.satellite_alt,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                sat.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Row(
                                children: sat.bands
                                    .map(
                                      (b) => Container(
                                        margin: const EdgeInsets.only(
                                          top: 6,
                                          right: 4,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          "$b-BAND",
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        sat.formattedPosition,
                                        style: const TextStyle(
                                          color: _accentCyan,
                                          fontFamily: 'Courier',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        "${sat.transponderCount} TP Lines",
                                        style: const TextStyle(
                                          color: Colors.white24,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  // Show Edit button for custom, Arrow for defaults
                                  if (sat.isInBox)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: _accentCyan,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AddSatelliteScreen(
                                                  satelliteToEdit: sat,
                                                ),
                                          ),
                                        );
                                        setState(() {});
                                      },
                                    )
                                  else
                                    const Icon(
                                      Icons.keyboard_arrow_right,
                                      color: Colors.white24,
                                    ),
                                ],
                              ),
                              onTap: () {
                                ref
                                        .read(activeSatelliteProvider.notifier)
                                        .state =
                                    sat;
                                Navigator.pop(context);
                              },
                            ),
                          );

                          // 2. Wrap in Dismissible ONLY if it is a custom Hive satellite
                          if (sat.isInBox) {
                            satelliteCard = Dismissible(
                              // Hive provides a unique key for every saved object
                              key: ValueKey(sat.key),
                              direction: DismissDirection
                                  .endToStart, // Swipe right-to-left
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.centerRight,
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              onDismissed: (direction) {
                                // Delete from database
                                SatelliteRepository.removeSatellite(sat);

                                // Refresh the UI
                                setState(() {});

                                // Show a tactical confirmation snackbar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: _bgDark,
                                    content: Text(
                                      "SATELLITE DELETED: ${sat.name}",
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: satelliteCard,
                            );
                          }

                          // 3. Apply the entry animation to whatever card was built
                          return satelliteCard
                              .animate(delay: (index * 40).ms)
                              .fade(duration: 300.ms)
                              .slideY(begin: 0.1);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
