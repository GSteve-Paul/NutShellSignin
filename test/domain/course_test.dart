import 'package:flutter_test/flutter_test.dart';
import 'package:nutshell_signin/core/beijing_time.dart';
import 'package:nutshell_signin/domain/models.dart';

void main() {
  test('UUID precedence, Beijing timestamps and sign window boundaries', () {
    final course = Course.fromJson({
      'id': 'row-id',
      'uuid': 'uuid',
      'signStatus': 0,
      'classBeginTime': '2026-09-18 18:30:00',
      'classEndTime': '2026-09-18 20:05:00',
    });
    expect(course.timeTableId, 'uuid');
    expect(course.classBeginTime, DateTime.utc(2026, 9, 18, 10, 30));
    expect(course.signDisabledReason(DateTime.utc(2026, 9, 18, 9, 59)), '未开始');
    expect(course.signDisabledReason(DateTime.utc(2026, 9, 18, 10)), isNull);
    expect(course.signDisabledReason(DateTime.utc(2026, 9, 18, 12, 5)), isNull);
    expect(course.signDisabledReason(DateTime.utc(2026, 9, 18, 12, 6)), '已结束');
  });
  test('missing fields never produce a signable course', () {
    expect(Course.fromJson({}).signDisabledReason(DateTime.now()), isNotNull);
  });
  test('Beijing date rolls over regardless of device timezone', () {
    expect(apiDate(DateTime.utc(2026, 12, 31, 16)), '20270101');
    expect(courseTime(DateTime.utc(2026, 9, 18, 10, 30)), '18:30');
  });
  test('NaN, infinity and out-of-range coordinates rejected', () {
    expect(
      const SignLocation(longitude: double.nan, latitude: 0).isValid,
      isFalse,
    );
    expect(
      const SignLocation(longitude: 0, latitude: double.infinity).isValid,
      isFalse,
    );
    expect(const SignLocation(longitude: 181, latitude: 90).isValid, isFalse);
  });
}
