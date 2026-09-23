/// Values use the upstream API's field names at the network boundary.
class Credentials {
  const Credentials({required this.phone, required this.password});
  final String phone;
  final String password;
}

class UserSession {
  const UserSession({
    required this.id,
    required this.sessionId,
    required this.realName,
  });
  final String id;
  final String sessionId;
  final String realName;
}

class SignLocation {
  const SignLocation({required this.longitude, required this.latitude});
  // Compatibility defaults from UCASCoureLogin. They are not a GPS reading.
  static const campus = SignLocation(
    longitude: 116.63176727294922,
    latitude: 40.316001892089844,
  );
  final double longitude;
  final double latitude;
  bool get isValid =>
      longitude.isFinite &&
      latitude.isFinite &&
      longitude >= -180 &&
      longitude <= 180 &&
      latitude >= -90 &&
      latitude <= 90;
}

class Course {
  const Course({
    required this.timeTableId,
    required this.courseName,
    required this.teacherName,
    required this.classroomName,
    required this.signStatus,
    required this.classBeginTime,
    required this.classEndTime,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    final timeTableId =
        ['uuid', 'timeTableId', 'id', 'UUID', 'ID']
            .map(text)
            .where((value) => value.isNotEmpty && value != 'null')
            .firstOrNull ??
        '';
    return Course(
      timeTableId: timeTableId,
      courseName: text('courseName'),
      teacherName: text('teacherName'),
      classroomName: text('classroomName'),
      signStatus: text('signStatus'),
      classBeginTime: _parseBeijingTime(text('classBeginTime')),
      classEndTime: _parseBeijingTime(text('classEndTime')),
    );
  }

  final String timeTableId;
  final String courseName;
  final String teacherName;
  final String classroomName;
  final String signStatus;
  final DateTime? classBeginTime;
  final DateTime? classEndTime;

  bool get isSigned => signStatus == '1';

  String? signDisabledReason(DateTime now) {
    if (isSigned) return '已签到';
    if (timeTableId.isEmpty) return '缺少课次编号';
    final begin = classBeginTime;
    final end = classEndTime;
    if (begin == null || end == null || end.isBefore(begin)) return '课程时间异常';
    if (now.isBefore(begin.subtract(const Duration(minutes: 30)))) return '未开始';
    if (now.isAfter(end)) return '已结束';
    return null;
  }

  static DateTime? _parseBeijingTime(String value) {
    if (value.isEmpty) return null;
    final normalized = value.replaceFirst(' ', 'T');
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(normalized);
    return DateTime.tryParse(hasZone ? normalized : '$normalized+08:00');
  }
}
