import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/app_exception.dart';
import '../core/beijing_time.dart';
import '../domain/models.dart';

abstract interface class CourseGateway {
  DateTime get serverNow;
  Future<UserSession> login(Credentials credentials);
  Future<List<Course>> getCourses(UserSession session);
  Future<void> signIn(
    UserSession session,
    Course course,
    SignLocation location,
  );
}

class IclassApi implements CourseGateway {
  IclassApi({
    required this._client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 20),
  }) : _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration timeout;
  Duration _serverOffset = Duration.zero;

  static const _host = 'iclass.ucas.edu.cn:8181';
  static const _bootstrapSession = String.fromEnvironment(
    'ICLASS_BOOTSTRAP_SESSION',
    defaultValue: '220B4BF64B92633F236393F811A8586A',
  );
  static const _verificationUrl =
      r'http://iclass.ucas.edu.cn:88/ve/webservices/mobileCheck.shtml?method=mobileLogin&username=${0}&password=${1}&lx=${2}';

  @override
  DateTime get serverNow => _now().add(_serverOffset);

  @override
  Future<UserSession> login(Credentials credentials) async {
    final json = await _post(
      '/app/user/login.action',
      sessionId: _bootstrapSession,
      form: {
        'phone': credentials.phone.trim(),
        'password': credentials.password,
        'userLevel': '1',
        'verificationType': '1',
        'verificationUrl': _verificationUrl,
      },
    );
    _requireSuccess(json, '登录失败，请检查账号密码');
    final result = json['result'];
    if (result is! Map<String, dynamic>) {
      throw const AppException('登录响应缺少用户信息');
    }
    final id = result['id']?.toString().trim() ?? '';
    final sessionId = result['sessionId']?.toString().trim() ?? '';
    if (id.isEmpty || sessionId.isEmpty) {
      throw const AppException('登录响应缺少 id 或 sessionId，请重新登录');
    }
    return UserSession(
      id: id,
      sessionId: sessionId,
      realName: result['realName']?.toString() ?? credentials.phone,
    );
  }

  @override
  Future<List<Course>> getCourses(UserSession session) async {
    final json = await _post(
      '/app/course/get_stu_course_sched.action',
      sessionId: session.sessionId,
      form: {'id': session.id, 'dateStr': apiDate(serverNow)},
    );
    _requireSuccess(json, '获取课程失败，请尝试刷新或重新登录');
    final result = json['result'];
    if (result is! List ||
        result.any((item) => item is! Map<String, dynamic>)) {
      throw const AppException('课表响应格式异常');
    }
    final courses = result
        .cast<Map<String, dynamic>>()
        .map(Course.fromJson)
        .toList();
    courses.sort(
      (a, b) => (a.classBeginTime ?? DateTime.utc(9999)).compareTo(
        b.classBeginTime ?? DateTime.utc(9999),
      ),
    );
    return List.unmodifiable(courses);
  }

  @override
  Future<void> signIn(
    UserSession session,
    Course course,
    SignLocation location,
  ) async {
    if (course.timeTableId.isEmpty || !location.isValid) {
      throw const AppException('课次编号或经纬度无效');
    }
    final json = await _post(
      '/app/course/stu_scan_sign.action',
      sessionId: session.sessionId,
      query: {
        'timeTableId': course.timeTableId,
        'timestamp': serverNow
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch
            .toString(),
      },
      form: {
        'id': session.id,
        'longitude': location.longitude.toString(),
        'latitude': location.latitude.toString(),
      },
    );
    _requireSuccess(json, '签到未成功，请刷新课表确认状态');
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required String sessionId,
    required Map<String, String> form,
    Map<String, String>? query,
  }) async {
    final request = http.Request('POST', Uri.https(_host, path, query))
      // Never forward credentials to a redirect destination.
      ..followRedirects = false
      ..headers.addAll({
        'sessionId': sessionId,
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 '
            'Safari/537.36 MicroMessenger/7.0.20.1781',
        'Referer':
            'https://servicewechat.com/wxdd3bd7d4acf54723/'
            '${path.endsWith("stu_scan_sign.action") ? 57 : 56}/page-frame.html',
      })
      ..bodyFields = form;
    final started = _now();
    try {
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      final received = _now();
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AppException('登录已失效，请重新登录', sessionExpired: true);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppException('服务请求失败（HTTP ${response.statusCode}），请稍后重试');
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        try {
          final midpoint = started.add(
            Duration(
              microseconds: received.difference(started).inMicroseconds ~/ 2,
            ),
          );
          _serverOffset = HttpDate.parse(dateHeader).difference(midpoint);
        } on FormatException {
          // Keep the last usable clock offset if Date is absent or invalid.
        }
      }
      return json;
    } on TimeoutException {
      throw const AppException('请求超时；若刚提交签到，请先刷新课表确认，勿连续重试');
    } on FormatException {
      throw const AppException('服务返回了无法识别的数据，请稍后重试');
    } on http.ClientException {
      throw const AppException('网络连接失败，请检查网络后重试');
    } on IOException {
      throw const AppException('无法建立安全连接，请检查网络和系统时间');
    }
  }

  void _requireSuccess(Map<String, dynamic> json, String message) {
    // Only STATUS=0 is established by the upstream contract. HTTP 200 alone
    // is not evidence of login or attendance success. Never echo raw payloads.
    if (json['STATUS']?.toString() != '0') throw AppException(message);
  }
}
