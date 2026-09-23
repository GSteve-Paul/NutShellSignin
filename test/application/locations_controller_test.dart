import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/application/locations_controller.dart';
import 'package:nutshell_signin/domain/models.dart';

import '../fakes.dart';

void main() {
  test(
    'save, reload, rename and delete persist across controller instances',
    () async {
      final store = FakeLocationStore();
      final first = LocationsController(store: store);
      final second = LocationsController(store: store);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.load();
      expect(await first.save(' 教一楼 ', SignLocation.campus), isTrue);
      await second.load();
      expect(second.locations.single.name, '教一楼');
      expect(
        second.locations.single.location.longitude,
        SignLocation.campus.longitude,
      );
      expect(
        await second.save(
          '教二楼',
          const SignLocation(longitude: 110, latitude: 30),
          replacingName: '教一楼',
        ),
        isTrue,
      );
      await first.load();
      expect(first.locations.single.name, '教二楼');
      expect(first.locations.single.location.latitude, 30);
      expect(await first.delete('教二楼'), isTrue);
      await second.load();
      expect(second.locations, isEmpty);
    },
  );

  test(
    'duplicate names and invalid coordinates cannot overwrite stored data',
    () async {
      final store = FakeLocationStore();
      final controller = LocationsController(store: store);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.save('教室', SignLocation.campus);
      expect(
        await controller.save(
          '教室',
          const SignLocation(longitude: 1, latitude: 1),
        ),
        isFalse,
      );
      expect(
        await controller.save(
          '新地点',
          const SignLocation(longitude: double.nan, latitude: 1),
        ),
        isFalse,
      );
      expect(await controller.save('', SignLocation.campus), isFalse);
      expect(store.writes, 1);
      expect(
        store.saved.single.location.longitude,
        SignLocation.campus.longitude,
      );
    },
  );

  test(
    'failed writes and deletions retain the last successfully saved list',
    () async {
      final store = FakeLocationStore();
      final controller = LocationsController(store: store);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.save('教室', SignLocation.campus);
      store.failWrite = true;
      expect(await controller.save('新地点', SignLocation.campus), isFalse);
      expect(await controller.delete('教室'), isFalse);
      expect(controller.locations.single.name, '教室');
      expect(store.saved.single.name, '教室');
      expect(controller.error, isNotNull);
    },
  );

  test(
    'failed load prevents overwriting unread data and allows retry',
    () async {
      final store = FakeLocationStore()..failRead = true;
      final controller = LocationsController(store: store);
      addTearDown(controller.dispose);
      await controller.load();
      expect(await controller.save('教室', SignLocation.campus), isFalse);
      expect(store.writes, 0);
      store.failRead = false;
      await controller.load();
      expect(await controller.save('教室', SignLocation.campus), isTrue);
    },
  );
}
