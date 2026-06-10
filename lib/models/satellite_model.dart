import 'package:hive/hive.dart';

// This tells Flutter a generated file is coming
part 'satellite_model.g.dart';

@HiveType(typeId: 0)
class Transponder extends HiveObject {
  @HiveField(0)
  final String frequency; // e.g. "12.380 GHz"

  @HiveField(1)
  final String polarity; // H / V

  @HiveField(2)
  final String symbolRate; // e.g. "27500"

  @HiveField(3)
  final String modulation; // DVB-S2 etc

  @HiveField(4)
  final bool isActive;

  Transponder({
    required this.frequency,
    required this.polarity,
    required this.symbolRate,
    required this.modulation,
    this.isActive = true,
  });
}

@HiveType(typeId: 1)
class Satellite extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final double position;

  @HiveField(2)
  final String hemisphere; // 'E' or 'W'

  @HiveField(3)
  final List<String> bands; // ['Ku', 'C']

  @HiveField(4)
  final int transponderCount;

  @HiveField(5)
  final double lnbSkew;

  @HiveField(6)
  final List<Transponder> transponders;

  Satellite({
    required this.name,
    required this.position,
    required this.hemisphere,
    required this.bands,
    required this.transponderCount,
    required this.lnbSkew,
    required this.transponders,
  });

  String get formattedPosition => "$position°$hemisphere";
}
