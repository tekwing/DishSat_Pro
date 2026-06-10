import 'package:hive_flutter/hive_flutter.dart';
import '../models/satellite_model.dart';

class SatelliteRepository {
  static const String boxName = 'custom_satellites';

  // 1. The hardcoded master list (Defaults)
  static final List<Satellite> _defaultSatellites = [
    Satellite(
      name: "GSAT-15",
      position: 93.5,
      hemisphere: "E",
      bands: ["Ku"],
      transponderCount: 24,
      lnbSkew: 40,
      transponders: [
        Transponder(
          frequency: "11.950",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.990",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.110",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.150",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.230",
          polarity: "H",
          symbolRate: "45000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.275",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.340",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.380",
          polarity: "V",
          symbolRate: "45000",
          modulation: "DVB-S2",
        ),
      ],
    ),

    Satellite(
      name: "NSS-6",
      position: 95.0,
      hemisphere: "E",
      bands: ["Ku"],
      transponderCount: 12,
      lnbSkew: 40,
      transponders: [
        Transponder(
          frequency: "11.727",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.765",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.823",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.861",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.919",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.957",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.015",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.053",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
      ],
    ),

    Satellite(
      name: "ST-2",
      position: 88.0,
      hemisphere: "E",
      bands: ["Ku"],
      transponderCount: 41,
      lnbSkew: 14.8,
      transponders: [
        Transponder(
          frequency: "11.472",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.510",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.548",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.586",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.624",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.662",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.700",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.738",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
      ],
    ),

    Satellite(
      name: "GSAT-10",
      position: 83.0,
      hemisphere: "E",
      bands: ["Ku"],
      transponderCount: 30,
      lnbSkew: 12.5,
      transponders: [
        Transponder(
          frequency: "11.512",
          polarity: "H",
          symbolRate: "29500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.549",
          polarity: "V",
          symbolRate: "29500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.586",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.623",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.660",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.697",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.734",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.771",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
      ],
    ),

    Satellite(
      name: "INSAT-4A",
      position: 83.0,
      hemisphere: "E",
      bands: ["C"],
      transponderCount: 24,
      lnbSkew: 13.0,
      transponders: [
        Transponder(
          frequency: "3.650",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.685",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.720",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.755",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.790",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.825",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.860",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.895",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
      ],
    ),

    Satellite(
      name: "EUTELSAT 70B",
      position: 70.5,
      hemisphere: "E",
      bands: ["Ku"],
      transponderCount: 48,
      lnbSkew: 9.5,
      transponders: [
        Transponder(
          frequency: "11.470",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.510",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.548",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.594",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.660",
          polarity: "H",
          symbolRate: "45000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.720",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.020",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.060",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
      ],
    ),

    Satellite(
      name: "INTELSAT 20",
      position: 68.5,
      hemisphere: "E",
      bands: ["C"],
      transponderCount: 68,
      lnbSkew: 8.0,
      transponders: [
        Transponder(
          frequency: "11.512",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.550",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.590",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.630",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.670",
          polarity: "H",
          symbolRate: "45000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.710",
          polarity: "V",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.020",
          polarity: "H",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.060",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "3.650",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.685",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.720",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.755",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.790",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S",
        ),
        Transponder(
          frequency: "3.825",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S",
        ),
      ],
    ),

    Satellite(
      name: "MEASAT-3",
      position: 91.5,
      hemisphere: "E",
      bands: ["Ku"],
      transponderCount: 48,
      lnbSkew: 16.2,
      transponders: [
        Transponder(
          frequency: "11.492",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.515",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.538",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.561",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.584",
          polarity: "H",
          symbolRate: "27500",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "11.607",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.188",
          polarity: "H",
          symbolRate: "45000",
          modulation: "DVB-S2",
        ),
        Transponder(
          frequency: "12.230",
          polarity: "V",
          symbolRate: "30000",
          modulation: "DVB-S2",
        ),
      ],
    ),
  ];

  // 2. Dynamic Getter: Merges Defaults + Hive Storage
  static List<Satellite> get satellites {
    final customBox = Hive.box<Satellite>(boxName);
    // Grab all custom saved items and append them to the defaults
    return [..._defaultSatellites, ...customBox.values];
  }

  // 3. Write to physical storage
  static Future<void> addSatellite(Satellite satellite) async {
    final customBox = Hive.box<Satellite>(boxName);
    await customBox.add(satellite);
  }

  // 4. Delete from physical storage
  static Future<void> removeSatellite(Satellite satellite) async {
    // Only delete if it belongs to the Hive database (prevents deleting defaults)
    if (satellite.isInBox) {
      await satellite.delete();
    }
  }

  // Update an existing satellite in physical storage
  static Future<void> updateSatellite(
    dynamic key,
    Satellite updatedSatellite,
  ) async {
    final customBox = Hive.box<Satellite>(boxName);
    await customBox.put(
      key,
      updatedSatellite,
    ); // .put() overwrites the existing entry
  }
}
