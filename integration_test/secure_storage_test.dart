import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native secure storage round-trip and deletion', (tester) async {
    const storage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
      ),
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    );
    final key =
        'cn.nutshell.signin.integration.${DateTime.now().microsecondsSinceEpoch}';
    try {
      await storage.write(key: key, value: 'non-sensitive-integration-fixture');
      expect(await storage.read(key: key), 'non-sensitive-integration-fixture');
      await storage.delete(key: key);
      expect(await storage.read(key: key), isNull);
    } finally {
      await storage.delete(key: key);
    }
  });
}
