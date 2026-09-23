import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutshell_signin/core/app_exception.dart';
import 'package:nutshell_signin/data/iclass_api.dart';
import 'package:nutshell_signin/domain/models.dart';

import '../fakes.dart';

http.Response response(Object data, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );

void main() {
  test(
    'login encodes form safely and uses exact upstream parameter names',
    () async {
      final api = IclassApi(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://iclass.ucas.edu.cn:8181/app/user/login.action',
          );
          expect(request.method, 'POST');
          expect(request.followRedirects, isFalse);
          final form = request.bodyFields;
          expect(form['phone'], 'student');
          expect(form['password'], ' a&+=中文 ');
          expect(
            form['verificationUrl'],
            contains(r'username=${0}&password=${1}&lx=${2}'),
          );
          expect(form['userLevel'], '1');
          expect(request.headers['sessionId'], isNotEmpty);
          return response({
            'STATUS': '0',
            'result': {'id': 'uid', 'sessionId': 'sid', 'realName': '测试'},
          });
        }),
      );
      final session = await api.login(
        const Credentials(phone: ' student ', password: ' a&+=中文 '),
      );
      expect(session.id, 'uid');
      expect(session.sessionId, 'sid');
      expect(session.realName, '测试');
    },
  );

  test('does not accept a 200 business failure or missing sessionId', () async {
    for (final payload in [
      {
        'STATUS': '1',
        'result': {'id': 'uid', 'sessionId': 'sid'},
      },
      {
        'STATUS': '0',
        'result': {'id': 'uid'},
      },
      {
        'result': {'id': 'uid', 'sessionId': 'sid'},
      },
    ]) {
      final api = IclassApi(client: MockClient((_) async => response(payload)));
      await expectLater(
        api.login(testCredentials),
        throwsA(isA<AppException>()),
      );
    }
  });

  test(
    'queries Beijing calendar day; sign URL uses UUID and corrected milliseconds',
    () async {
      final localNow = DateTime.utc(2026, 9, 18, 17);
      final requests = <http.Request>[];
      final api = IclassApi(
        now: () => localNow,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.contains('get_stu')) {
            expect(request.bodyFields, {
              'id': testSession.id,
              'dateStr': '20260919',
            });
            return response(
              {'STATUS': '0', 'result': <Object>[]},
              headers: {'date': 'Fri, 18 Sep 2026 17:00:05 GMT'},
            );
          }
          return response({'STATUS': '0'});
        }),
      );
      await api.getCourses(testSession);
      await api.signIn(testSession, testCourse(), SignLocation.campus);
      final request = requests.last;
      expect(request.url.queryParameters['timeTableId'], 'test-timetable-uuid');
      expect(
        request.url.queryParameters['timestamp'],
        '${localNow.millisecondsSinceEpoch + 4000}',
      );
      expect(request.bodyFields, {
        'id': testSession.id,
        'longitude': '116.63176727294922',
        'latitude': '40.316001892089844',
      });
      expect(request.headers['sessionId'], testSession.sessionId);
      expect(request.bodyFields.containsKey('timeTableId'), isFalse);
    },
  );

  test('unknown sign STATUS never means success', () async {
    final api = IclassApi(
      client: MockClient((_) async => response({'STATUS': '2'})),
    );
    await expectLater(
      api.signIn(testSession, testCourse(), SignLocation.campus),
      throwsA(isA<AppException>()),
    );
  });

  test('malformed payloads and HTTP errors are sanitized', () async {
    for (final reply in [
      http.Response('private-payload', 500),
      http.Response('<html>private-payload</html>', 200),
      http.Response('[]', 200),
      response({'STATUS': '0', 'result': 'private-payload'}),
    ]) {
      final api = IclassApi(client: MockClient((_) async => reply));
      await expectLater(
        api.getCourses(testSession),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            isNot(contains('private-payload')),
          ),
        ),
      );
    }
  });

  test('401 clears session through a typed error', () async {
    final api = IclassApi(
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      api.getCourses(testSession),
      throwsA(
        isA<AppException>().having(
          (error) => error.sessionExpired,
          'sessionExpired',
          isTrue,
        ),
      ),
    );
  });

  test('timeout does not retry a sign-in mutation', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final api = IclassApi(
      timeout: const Duration(milliseconds: 5),
      client: MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    await expectLater(
      api.signIn(testSession, testCourse(), SignLocation.campus),
      throwsA(isA<AppException>()),
    );
    expect(calls, 1);
    pending.complete(response({'STATUS': '0'}));
  });
}
