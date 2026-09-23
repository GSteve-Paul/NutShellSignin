import 'package:flutter/foundation.dart';

import '../core/app_exception.dart';
import '../data/credential_store.dart';
import '../data/iclass_api.dart';
import '../data/location_store.dart';
import '../domain/models.dart';

/// Owns application state. Widgets never issue HTTP or secure-storage calls.
class SigninController extends ChangeNotifier {
  SigninController({
    required this._gateway,
    required this._store,
    LocationStore? locationStore,
  }) : locationStore = locationStore ?? SecureLocationStore();

  final LocationStore locationStore;

  final CourseGateway _gateway;
  final CredentialStore _store;
  UserSession? _session;
  Credentials? _initialCredentials;
  List<Course> _courses = const [];
  bool _initializing = true;
  bool _loggingIn = false;
  bool _loadingCourses = false;
  bool _changingStorage = false;
  bool _rememberCredentials = true;
  String? _signingTimeTableId;
  String? _error;
  String? _storageWarning;
  String? _notice;
  DateTime? _updatedAt;
  bool _disposed = false;

  UserSession? get session => _session;
  Credentials? get initialCredentials => _initialCredentials;
  List<Course> get courses => _courses;
  bool get initializing => _initializing;
  bool get loggingIn => _loggingIn;
  bool get loadingCourses => _loadingCourses;
  bool get changingStorage => _changingStorage;
  bool get rememberCredentials => _rememberCredentials;
  String? get signingTimeTableId => _signingTimeTableId;
  String? get error => _error;
  String? get storageWarning => _storageWarning;
  String? get notice => _notice;
  DateTime? get updatedAt => _updatedAt;

  DateTime get serverNow => _gateway.serverNow;
  bool get busy =>
      _initializing ||
      _loggingIn ||
      _loadingCourses ||
      _changingStorage ||
      _signingTimeTableId != null;

  Future<void> initialize() async {
    _initializing = true;
    _emit();
    try {
      _initialCredentials = await _store.read();
      _storageWarning = null;
    } catch (_) {
      _initialCredentials = null;
      _storageWarning = '无法读取系统安全存储，请解锁钥匙串或密钥环。仍可手动登录。';
    } finally {
      _initializing = false;
      _emit();
    }
  }

  Future<bool> setRememberCredentials(bool value) async {
    if (busy) return false;
    if (value) {
      _rememberCredentials = true;
      _emit();
      return true;
    }
    // A failed deletion must not look like a successful opt-out.
    _changingStorage = true;
    _emit();
    try {
      await _store.clear();
      _initialCredentials = null;
      _rememberCredentials = false;
      _storageWarning = null;
      return true;
    } catch (_) {
      _storageWarning = '未能删除已保存的账号密码，请解锁系统安全存储后重试。';
      return false;
    } finally {
      _changingStorage = false;
      _emit();
    }
  }

  Future<void> login(String phone, String password) async {
    if (busy || _session != null) return;
    if (phone.trim().isEmpty || password.isEmpty) {
      _error = '请输入学号和密码';
      _emit();
      return;
    }
    _loggingIn = true;
    _error = null;
    _notice = null;
    _emit();
    final credentials = Credentials(phone: phone.trim(), password: password);
    try {
      final authenticated = await _gateway.login(credentials);
      // Persist only credentials which have authenticated successfully.
      try {
        if (_rememberCredentials) {
          await _store.save(credentials);
        } else {
          await _store.clear();
        }
        _storageWarning = null;
      } catch (_) {
        _storageWarning = _rememberCredentials
            ? '本次登录成功，但账号密码未能保存。请检查系统安全存储。'
            : '本次登录成功，但旧账号密码未能删除。请检查系统安全存储。';
      }
      _initialCredentials = null;
      _session = authenticated;
      _courses = const [];
      await _loadCourses();
    } catch (exception) {
      await _handleError(exception);
    } finally {
      _loggingIn = false;
      _emit();
    }
  }

  Future<void> refreshCourses() async {
    if (busy || _session == null) return;
    _error = null;
    _notice = null;
    await _loadCourses();
  }

  Future<bool> _loadCourses() async {
    final current = _session;
    if (current == null) return false;
    _loadingCourses = true;
    _emit();
    try {
      _courses = List.unmodifiable(await _gateway.getCourses(current));
      _updatedAt = serverNow;
      return true;
    } catch (exception) {
      await _handleError(exception);
      return false;
    } finally {
      _loadingCourses = false;
      _emit();
    }
  }

  Future<void> signIn(Course course, SignLocation location) async {
    if (busy || _session == null) return;
    _error = null;
    _notice = null;
    final disabledReason = course.signDisabledReason(serverNow);
    if (disabledReason != null) {
      _error = '无法签到：$disabledReason';
      _emit();
      return;
    }
    if (!location.isValid) {
      _error = '请输入有效的经纬度';
      _emit();
      return;
    }
    _signingTimeTableId = course.timeTableId;
    _emit();
    try {
      await _gateway.signIn(_session!, course, location);
      final refreshed = await _loadCourses();
      if (refreshed) {
        final confirmed = _courses.any(
          (item) => item.timeTableId == course.timeTableId && item.isSigned,
        );
        _notice = confirmed ? '签到成功，课表已确认。' : '请求已受理，课表尚未确认签到，请稍后刷新。';
      } else if (_session != null) {
        _notice = '签到请求已受理，课表刷新失败，请手动刷新确认。';
      }
    } catch (exception) {
      await _handleError(exception);
      // Do not retry a mutation whose outcome may be unknown.
    } finally {
      _signingTimeTableId = null;
      _emit();
    }
  }

  /// Signing out clears the in-memory session, but keeps the explicit remember
  /// choice. A separate action deletes persisted credentials.
  Future<void> logout({bool forget = false}) async {
    if (busy) return;
    if (forget) {
      if (!await setRememberCredentials(false)) return;
    }
    _session = null;
    _courses = const [];
    _updatedAt = null;
    _error = null;
    _notice = null;
    await initialize();
  }

  Future<void> _handleError(Object exception) async {
    _error = exception is AppException ? exception.message : '操作失败，请稍后重试';
    if (exception is AppException && exception.sessionExpired) {
      _session = null;
      _courses = const [];
      _updatedAt = null;
      _initialCredentials = null;
      try {
        _initialCredentials = await _store.read();
      } catch (_) {
        _storageWarning = '无法读取保存的账号密码，请手动输入或解锁系统安全存储。';
      }
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _initialCredentials = null;
    _session = null;
    super.dispose();
  }
}
