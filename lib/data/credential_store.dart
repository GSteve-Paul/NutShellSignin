import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/models.dart';

abstract interface class CredentialStore {
  Future<Credentials?> read();
  Future<void> save(Credentials credentials);
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'cn.nutshell.signin.credentials.v1';

  @override
  Future<Credentials?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic> ||
        json['phone'] is! String ||
        json['password'] is! String ||
        (json['phone'] as String).isEmpty ||
        (json['password'] as String).isEmpty) {
      throw const FormatException('Invalid stored credentials');
    }
    return Credentials(
      phone: json['phone'] as String,
      password: json['password'] as String,
    );
  }

  @override
  Future<void> save(Credentials credentials) => _storage.write(
    key: _key,
    value: jsonEncode({
      'phone': credentials.phone,
      'password': credentials.password,
    }),
  );

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
