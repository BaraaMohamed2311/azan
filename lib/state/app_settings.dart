import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/municipalities.dart';
import '../logic/prayer.dart';

/// Ported from src/context/AppSettingsContext.tsx — persisted preferences
/// with a resolved "place" (GPS override > chosen municipality > default).

class GpsPlace {
  final String name;
  final double latitude;
  final double longitude;
  const GpsPlace(this.name, this.latitude, this.longitude);

  Map<String, dynamic> toJson() =>
      {'name': name, 'latitude': latitude, 'longitude': longitude};

  static GpsPlace fromJson(Map<String, dynamic> json) => GpsPlace(
        json['name'] as String,
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );
}

class AppPreferences {
  final String municipalityId;
  final GpsPlace? gpsPlace;
  final CalculationMethodKey calculationMethod;
  final bool notificationsEnabled;
  final String soundMode; // 'system' | 'silent'
  final int hijriOffset; // -1, 0, 1
  final int quranFontScale; // -2..3

  const AppPreferences({
    required this.municipalityId,
    required this.gpsPlace,
    required this.calculationMethod,
    required this.notificationsEnabled,
    required this.soundMode,
    required this.hijriOffset,
    required this.quranFontScale,
  });

  static const defaults = AppPreferences(
    municipalityId: '', // replaced at load time with طرابلس
    gpsPlace: null,
    calculationMethod: CalculationMethodKey.egyptian,
    notificationsEnabled: !kIsWeb, // web must ask permission from a click
    soundMode: 'system',
    hijriOffset: 0,
    quranFontScale: 0,
  );

  AppPreferences copyWith({
    String? municipalityId,
    GpsPlace? gpsPlace,
    bool clearGpsPlace = false,
    CalculationMethodKey? calculationMethod,
    bool? notificationsEnabled,
    String? soundMode,
    int? hijriOffset,
    int? quranFontScale,
  }) {
    return AppPreferences(
      municipalityId: municipalityId ?? this.municipalityId,
      gpsPlace: clearGpsPlace ? null : (gpsPlace ?? this.gpsPlace),
      calculationMethod: calculationMethod ?? this.calculationMethod,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundMode: soundMode ?? this.soundMode,
      hijriOffset: hijriOffset ?? this.hijriOffset,
      quranFontScale: quranFontScale ?? this.quranFontScale,
    );
  }

  Map<String, dynamic> toJson() => {
        'municipalityId': municipalityId,
        'gpsPlace': gpsPlace?.toJson(),
        'calculationMethod': calculationMethod.name,
        'notificationsEnabled': notificationsEnabled,
        'soundMode': soundMode,
        'hijriOffset': hijriOffset,
        'quranFontScale': quranFontScale,
      };

  static AppPreferences fromJson(Map<String, dynamic> json) {
    final methodRaw = json['calculationMethod'] as String?;
    return AppPreferences(
      municipalityId:
          json['municipalityId'] as String? ?? AppPreferences.defaults.municipalityId,
      gpsPlace: json['gpsPlace'] == null
          ? null
          : GpsPlace.fromJson(json['gpsPlace'] as Map<String, dynamic>),
      calculationMethod: CalculationMethodKey.values.firstWhere(
        (m) => m.name == methodRaw,
        orElse: () => CalculationMethodKey.egyptian,
      ),
      notificationsEnabled: json['notificationsEnabled'] as bool? ??
          AppPreferences.defaults.notificationsEnabled,
      soundMode: json['soundMode'] as String? ?? 'system',
      hijriOffset: (json['hijriOffset'] as num?)?.toInt() ?? 0,
      quranFontScale: (json['quranFontScale'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppSettings extends ChangeNotifier {
  static const _storageKey = 'athan-libya:preferences:v1';

  AppPreferences _preferences;
  bool _ready = false;

  AppSettings() : _preferences = AppPreferences.defaults;

  AppPreferences get preferences => _preferences;
  bool get ready => _ready;

  Municipality get place {
    final gps = _preferences.gpsPlace;
    if (gps != null) {
      return Municipality(
        id: 'gps',
        name: gps.name,
        englishName: '',
        district: '',
        region: '',
        latitude: gps.latitude,
        longitude: gps.longitude,
      );
    }
    return MunicipalityData.getMunicipality(_preferences.municipalityId);
  }

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final stored = sp.getString(_storageKey);
      if (stored != null) {
        _preferences = AppPreferences.fromJson(
            jsonDecode(stored) as Map<String, dynamic>);
      }
    } catch (_) {
      // keep defaults on any storage error
    }
    if (_preferences.municipalityId.isEmpty) {
      _preferences =
          _preferences.copyWith(municipalityId: MunicipalityData.defaultMunicipality.id);
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_storageKey, jsonEncode(_preferences.toJson()));
    } catch (_) {}
  }

  void updatePreferences(AppPreferences Function(AppPreferences) patcher) {
    _preferences = patcher(_preferences);
    notifyListeners();
    _persist();
  }

  void chooseMunicipality(String id) {
    _preferences = _preferences.copyWith(municipalityId: id, clearGpsPlace: true);
    notifyListeners();
    _persist();
  }

  void useGpsPlace(double latitude, double longitude) {
    _preferences = _preferences.copyWith(
      gpsPlace: GpsPlace('موقعي الحالي', latitude, longitude),
    );
    notifyListeners();
    _persist();
  }
}
