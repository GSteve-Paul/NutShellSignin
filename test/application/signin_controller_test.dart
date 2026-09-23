import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/application/signin_controller.dart';
import 'package:nutshell_signin/domain/models.dart';

import '../fakes.dart';

void main() {
  late FakeStore store;
  late FakeGateway gateway;
  late SigninController controller;
  setUp(() {
    store = FakeStore();
    gateway = FakeGateway();
    controller = SigninController(gateway: gateway, store: store);
  });
  tearDown(() => controller.dispose());

  Future<void> login() async {
    await controller.initialize();
    await controller.login(testCredentials.phone, testCredentials.password);
  }

  test(
    'startup restores credentials without logging in automatically',
    () async {
      store.saved = testCredentials;
      await controller.initialize();
      expect(controller.initialCredentials, same(testCredentials));
      expect(gateway.loginCount, 0);
      expect(controller.session, isNull);
    },
  );

  test('failed login never overwrites saved credentials', () async {
    store.saved = testCredentials;
    gateway.failLogin = true;
    await login();
    expect(store.saveCount, 0);
    expect(store.saved, same(testCredentials));
    expect(controller.session, isNull);
    expect(controller.error, isNotNull);
  });

  test('successful login persists and immediately loads courses', () async {
    await login();
    expect(store.saveCount, 1);
    expect(controller.session, testSession);
    expect(controller.courses, hasLength(1));
    expect(controller.initialCredentials, isNull);
  });

  test(
    'storage failure does not prevent manual login or save plaintext',
    () async {
      store.failRead = true;
      store.failSave = true;
      await login();
      expect(controller.session, testSession);
      expect(controller.storageWarning, isNotNull);
      expect(store.saved, isNull);
    },
  );

  test('opt-out deletes previously saved credentials immediately', () async {
    store.saved = testCredentials;
    await controller.initialize();
    await controller.setRememberCredentials(false);
    expect(store.saved, isNull);
    await controller.login('student', 'password');
    expect(store.saveCount, 0);
    expect(store.saved, isNull);
  });

  test(
    'failed credential deletion stays visible and does not claim removal',
    () async {
      store.saved = testCredentials;
      store.failClear = true;
      await controller.initialize();
      await controller.setRememberCredentials(false);
      expect(controller.rememberCredentials, isTrue);
      expect(controller.storageWarning, isNotNull);
      expect(store.saved, isNotNull);
    },
  );

  test(
    'sign checks refreshed signStatus and blocks concurrent submissions',
    () async {
      await login();
      gateway.signGate = Completer<void>();
      final request = controller.signIn(testCourse(), SignLocation.campus);
      await controller.signIn(testCourse(), SignLocation.campus);
      expect(gateway.signCount, 1);
      gateway.signGate!.complete();
      await request;
      expect(controller.notice, contains('课表已确认'));
      expect(controller.courses.single.isSigned, isTrue);
    },
  );

  test(
    'accepted request without confirmed attendance is not shown as success',
    () async {
      gateway.confirmSign = false;
      await login();
      await controller.signIn(testCourse(), SignLocation.campus);
      expect(controller.notice, contains('尚未确认'));
      expect(controller.notice, isNot(contains('签到成功')));
    },
  );

  test('sign failure retains course state and does not retry', () async {
    gateway.failSign = true;
    await login();
    await controller.signIn(testCourse(), SignLocation.campus);
    expect(gateway.signCount, 1);
    expect(controller.courses.single.isSigned, isFalse);
    expect(controller.error, contains('超时'));
  });

  test('signed courses cannot be submitted again', () async {
    await login();
    await controller.signIn(testCourse(signStatus: '1'), SignLocation.campus);
    expect(gateway.signCount, 0);
  });

  test('session expiration drops session and private course data', () async {
    await login();
    gateway.expireSession = true;
    await controller.refreshCourses();
    expect(controller.session, isNull);
    expect(controller.courses, isEmpty);
    expect(controller.initialCredentials?.phone, testCredentials.phone);
  });

  test(
    'forget reports a failed deletion even when remember was already off',
    () async {
      await controller.initialize();
      await controller.setRememberCredentials(false);
      await controller.login('student', 'password');
      store.failClear = true;
      await controller.logout(forget: true);
      expect(controller.session, isNotNull);
      expect(controller.storageWarning, contains('未能删除'));
    },
  );

  test('logout keeps saved credentials; forget deletes them', () async {
    await login();
    await controller.logout();
    expect(controller.session, isNull);
    expect(controller.initialCredentials?.phone, testCredentials.phone);
    await controller.login(testCredentials.phone, testCredentials.password);
    await controller.logout(forget: true);
    expect(store.saved, isNull);
    expect(controller.initialCredentials, isNull);
  });
}
