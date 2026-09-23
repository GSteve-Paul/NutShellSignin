import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/app.dart';
import 'package:nutshell_signin/application/signin_controller.dart';

import '../fakes.dart';

void main() {
  testWidgets('prefills saved credentials and requires an explicit login tap', (
    tester,
  ) async {
    final gateway = FakeGateway();
    final controller = SigninController(
      gateway: gateway,
      locationStore: FakeLocationStore(),
      store: FakeStore()..saved = testCredentials,
    );
    await controller.initialize();
    await tester.pumpWidget(NutShellApp(controller: controller));
    expect(find.text('test-student'), findsOneWidget);
    final password = tester.widget<TextFormField>(
      find.byKey(const Key('password')),
    );
    expect(password.controller!.text, 'test-password');
    expect(gateway.loginCount, 0);
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle();
    expect(find.text('今日课程'), findsOneWidget);
    expect(find.text('测试课程'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'phone-sized screen supports login, confirmation and verified sign-in',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = SigninController(
        gateway: FakeGateway(),
        locationStore: FakeLocationStore(),
        store: FakeStore(),
      );
      await controller.initialize();
      await tester.pumpWidget(NutShellApp(controller: controller));
      await tester.enterText(find.byKey(const Key('phone')), 'student');
      await tester.enterText(find.byKey(const Key('password')), 'password');
      await tester.ensureVisible(find.byKey(const Key('login')));
      await tester.tap(find.byKey(const Key('login')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('签到'));
      await tester.pumpAndSettle();
      expect(find.text('确认签到'), findsOneWidget);
      await tester.tap(find.text('提交签到'));
      await tester.pumpAndSettle();
      expect(find.text('签到成功，课表已确认。'), findsOneWidget);
      expect(find.text('已签到'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
