import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/app.dart';
import 'package:nutshell_signin/application/signin_controller.dart';
import 'package:nutshell_signin/domain/models.dart';
import 'package:nutshell_signin/domain/saved_location.dart';
import 'package:nutshell_signin/presentation/locations_page.dart';

import '../fakes.dart';

Future<void> fillEditor(
  WidgetTester tester, {
  required String name,
  String longitude = '110.25',
  String latitude = '30.5',
}) async {
  await tester.enterText(find.byKey(const Key('edit-location-name')), name);
  await tester.enterText(find.byKey(const Key('edit-longitude')), longitude);
  await tester.enterText(find.byKey(const Key('edit-latitude')), latitude);
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'account menu manages locations and sign-in uses updated coordinates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FakeLocationStore();
      final controller = SigninController(
        gateway: FakeGateway(),
        store: FakeStore(),
        locationStore: store,
      );
      await controller.initialize();
      await controller.login('student', 'password');
      await tester.pumpWidget(NutShellApp(controller: controller));
      await tester.tap(find.byTooltip('账号与地点'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理已保存地点'));
      await tester.pumpAndSettle();
      expect(controller.session, isNotNull);
      expect(find.textContaining('暂无已保存地点'), findsOneWidget);
      await tester.tap(find.text('新增地点'));
      await tester.pumpAndSettle();
      await fillEditor(tester, name: '教一楼');
      expect(store.saved.single.name, '教一楼');
      expect(find.text('经度：110.25\n纬度：30.5'), findsOneWidget);
      await tester.tap(find.text('修改'));
      await tester.pumpAndSettle();
      await fillEditor(tester, name: '教二楼', longitude: '115', latitude: '35');
      expect(store.saved.single.name, '教二楼');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(controller.session, isNotNull);
      await tester.tap(find.text('签到'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saved-location')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('教二楼').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('longitude')))
            .controller!
            .text,
        '115.0',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('账号与地点'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('管理已保存地点'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(store.saved, hasLength(1));
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      expect(store.saved, isEmpty);
      expect(find.textContaining('暂无已保存地点'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'invalid input and write failure keep editor open and preserve data',
    (tester) async {
      final store = FakeLocationStore()
        ..saved = [
          const SavedLocation(name: '旧地点', location: SignLocation.campus),
        ];
      await tester.pumpWidget(MaterialApp(home: LocationsPage(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增地点'));
      await tester.pumpAndSettle();
      await fillEditor(tester, name: '新地点', longitude: '181');
      expect(find.text('请输入 -180.0 到 180.0 之间的数值'), findsOneWidget);
      expect(store.writes, 0);
      store.failWrite = true;
      await fillEditor(tester, name: '新地点');
      expect(find.byKey(const Key('edit-location-name')), findsOneWidget);
      expect(find.textContaining('地点未能保存'), findsWidgets);
      expect(store.saved.single.name, '旧地点');
      store.failWrite = false;
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-location-name')), findsNothing);
      expect(store.saved, hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
