import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show rootBundle;

/// Ported from src/data/municipalities.ts — loads the 104 Libyan baladiyat
/// from the bundled JSON asset.

class Municipality {
  final String id;
  final String name;
  final String englishName;
  final String district;
  final String region;
  final double latitude;
  final double longitude;

  const Municipality({
    required this.id,
    required this.name,
    required this.englishName,
    required this.district,
    required this.region,
    required this.latitude,
    required this.longitude,
  });
}

class MunicipalityData {
  static late final List<Municipality> municipalities;
  static late final Municipality defaultMunicipality;

  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final raw =
        await rootBundle.loadString('assets/data/libya-baladiyat.json');
    final list = jsonDecode(raw) as List<dynamic>;
    municipalities = list
        .map<Municipality>((item) {
          final name = item['name'] as Map<String, dynamic>;
          final parent = item['parent'] as Map<String, dynamic>?;
          final ancestors = item['ancestors'] as List<dynamic>?;
          final geo = item['geo'] as Map<String, dynamic>;
          final parentName = parent?['name'] as Map<String, dynamic>?;
          final ancestorName = (ancestors != null && ancestors.isNotEmpty)
              ? ancestors.first['name'] as Map<String, dynamic>?
              : null;
          return Municipality(
            id: item['id'] as String,
            name: name['local'] as String,
            englishName: name['en'] as String,
            district: parentName?['local'] as String? ?? '',
            region: ancestorName?['local'] as String? ?? '',
            latitude: double.tryParse('${geo['lat']}') ?? 0,
            longitude: double.tryParse('${geo['lon']}') ?? 0,
          );
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    defaultMunicipality = municipalities.firstWhere(
      (place) => place.name == 'طرابلس',
      orElse: () => municipalities.first,
    );
    _loaded = true;
  }

  static Municipality getMunicipality(String id) {
    return municipalities.firstWhere(
      (place) => place.id == id,
      orElse: () => defaultMunicipality,
    );
  }
}
