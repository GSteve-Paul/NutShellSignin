import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/data/credential_store.dart';
import 'package:nutshell_signin/data/location_store.dart';
import 'package:nutshell_signin/domain/models.dart';
import 'package:nutshell_signin/domain/saved_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'locations survive adapter recreation and clearing login credentials',
    () async {
      final store = SecureLocationStore();
      expect(await store.read(), isEmpty);
      await store.write([
        const SavedLocation(name: '教室', location: SignLocation.campus),
      ]);
      final credentials = SecureCredentialStore();
      await credentials.save(
        const Credentials(phone: 'student', password: 'test'),
      );
      await credentials.clear();
      final restored = await SecureLocationStore().read();
      expect(restored.single.name, '教室');
      expect(restored.single.location.latitude, SignLocation.campus.latitude);
    },
  );

  test(
    'invalid stored coordinates are rejected without overwriting data',
    () async {
      const storage = FlutterSecureStorage();
      final store = SecureLocationStore(storage: storage);
      await store.write([
        const SavedLocation(name: '教室', location: SignLocation.campus),
      ]);
      final key = (await storage.readAll()).keys.single;
      const invalid = '[{"name":"教室","longitude":181,"latitude":30}]';
      await storage.write(key: key, value: invalid);
      await expectLater(store.read(), throwsFormatException);
      expect(await storage.read(key: key), invalid);
    },
  );
}
