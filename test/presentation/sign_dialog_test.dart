import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/domain/models.dart';
import 'package:nutshell_signin/presentation/widgets/sign_dialog.dart';

import '../fakes.dart';

void main() {
  testWidgets('named coordinates can be saved then selected in a new dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FakeLocationStore();
    SignLocation? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                submitted = await showSignDialog(
                  context,
                  testCourse(),
                  store: store,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('longitude')), '110.25');
    await tester.enterText(find.byKey(const Key('latitude')), '30.5');
    await tester.enterText(find.byKey(const Key('location-name')), '教一楼 107');
    await tester.ensureVisible(find.text('保存地点'));
    await tester.tap(find.text('保存地点'));
    await tester.pumpAndSettle();
    expect(store.saved.single.name, '教一楼 107');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('教一楼 107').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('longitude')))
          .controller!
          .text,
      '110.25',
    );
    await tester.tap(find.text('提交签到'));
    await tester.pumpAndSettle();
    expect(submitted?.longitude, 110.25);
    expect(submitted?.latitude, 30.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage failure still permits manual sign-in without a name', (
    tester,
  ) async {
    SignLocation? submitted;
    final store = FakeLocationStore()..failRead = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                submitted = await showSignDialog(
                  context,
                  testCourse(),
                  store: store,
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('重新加载地点'), findsOneWidget);
    await tester.tap(find.text('提交签到'));
    await tester.pumpAndSettle();
    expect(submitted?.longitude, SignLocation.campus.longitude);
    expect(store.writes, 0);
  });
}
