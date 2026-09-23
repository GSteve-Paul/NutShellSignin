import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/saved_location.dart';

abstract interface class LocationStore {
  Future<List<SavedLocation>> read();
  Future<void> write(List<SavedLocation> locations);
}

/// Uses a separate key so deleting login credentials preserves saved locations.
class SecureLocationStore implements LocationStore {
  SecureLocationStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'cn.nutshell.signin.locations.v1';

  @override
  Future<List<SavedLocation>> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return const [];
    final json = jsonDecode(value);
    if (json is! List || json.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Invalid saved locations');
    }
    final locations = json
        .cast<Map<String, dynamic>>()
        .map(SavedLocation.fromJson)
        .toList();
    if (locations.map((item) => item.name).toSet().length != locations.length) {
      throw const FormatException('Duplicate location names');
    }
    return List.unmodifiable(locations);
  }

  @override
  Future<void> write(List<SavedLocation> locations) => _storage.write(
    key: _key,
    value: jsonEncode(locations.map((item) => item.toJson()).toList()),
  );
}
