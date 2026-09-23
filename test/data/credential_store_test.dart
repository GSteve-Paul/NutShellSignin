import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/data/credential_store.dart';
import 'package:nutshell_signin/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'new adapter instance restores both fields and clear removes only its record',
    () async {
      const storage = FlutterSecureStorage();
      await storage.write(key: 'unrelated-fixture', value: 'preserve');
      final store = SecureCredentialStore(storage: storage);
      expect(await store.read(), isNull);
      await store.save(
        const Credentials(phone: 'student', password: ' p&+=中文 '),
      );
      final restarted = SecureCredentialStore(storage: storage);
      final restored = await restarted.read();
      expect(restored?.phone, 'student');
      expect(restored?.password, ' p&+=中文 ');
      await restarted.clear();
      expect(await store.read(), isNull);
      expect(await storage.read(key: 'unrelated-fixture'), 'preserve');
    },
  );

  test(
    'corrupt stored credentials are rejected instead of partially autofilled',
    () async {
      const storage = FlutterSecureStorage();
      final store = SecureCredentialStore(storage: storage);
      await store.save(
        const Credentials(phone: 'student', password: 'password'),
      );
      final key = (await storage.readAll()).keys.single;
      await storage.write(key: key, value: '{"phone":"student"}');
      await expectLater(store.read(), throwsFormatException);
    },
  );
}
