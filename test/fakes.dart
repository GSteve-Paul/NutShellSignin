import 'dart:async';
import 'package:nutshell_signin/data/location_store.dart';
import 'package:nutshell_signin/domain/saved_location.dart';

import 'package:nutshell_signin/core/app_exception.dart';
import 'package:nutshell_signin/data/credential_store.dart';
import 'package:nutshell_signin/data/iclass_api.dart';
import 'package:nutshell_signin/domain/models.dart';

final testNow = DateTime.utc(2026, 9, 18, 10, 30);
const testCredentials = Credentials(
  phone: 'test-student',
  password: 'test-password',
);
const testSession = UserSession(
  id: 'test-user-id',
  sessionId: 'test-session-id',
  realName: '测试同学',
);

Course testCourse({String signStatus = '0'}) => Course(
  timeTableId: 'test-timetable-uuid',
  courseName: '测试课程',
  teacherName: '测试教师',
  classroomName: '测试教室',
  signStatus: signStatus,
  classBeginTime: testNow,
  classEndTime: testNow.add(const Duration(hours: 2)),
);

class FakeStore implements CredentialStore {
  Credentials? saved;
  bool failRead = false;
  bool failSave = false;
  bool failClear = false;
  int saveCount = 0;
  @override
  Future<Credentials?> read() async {
    if (failRead) throw StateError('Locked');
    return saved;
  }

  @override
  Future<void> save(Credentials credentials) async {
    if (failSave) throw StateError('Locked');
    saved = credentials;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    if (failClear) throw StateError('Locked');
    saved = null;
  }
}

class FakeGateway implements CourseGateway {
  int loginCount = 0;
  int signCount = 0;
  bool failLogin = false;
  bool failCourses = false;
  bool expireSession = false;
  bool failSign = false;
  bool confirmSign = true;
  Completer<void>? signGate;
  List<Course> courses = [testCourse()];
  @override
  DateTime get serverNow => testNow;
  @override
  Future<UserSession> login(Credentials credentials) async {
    loginCount++;
    if (failLogin) throw const AppException('登录失败');
    return testSession;
  }

  @override
  Future<List<Course>> getCourses(UserSession session) async {
    if (expireSession) throw const AppException('登录已失效', sessionExpired: true);
    if (failCourses) throw const AppException('课表加载失败');
    return courses;
  }

  @override
  Future<void> signIn(
    UserSession session,
    Course course,
    SignLocation location,
  ) async {
    signCount++;
    if (signGate != null) await signGate!.future;
    if (failSign) throw const AppException('签到请求超时');
    if (confirmSign) courses = [testCourse(signStatus: '1')];
  }
}

class FakeLocationStore implements LocationStore {
  List<SavedLocation> saved = [];
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<List<SavedLocation>> read() async {
    if (failRead) throw StateError('Locked');
    return List.of(saved);
  }

  @override
  Future<void> write(List<SavedLocation> locations) async {
    if (failWrite) throw StateError('Locked');
    saved = List.of(locations);
    writes++;
  }
}
