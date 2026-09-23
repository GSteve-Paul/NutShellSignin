import 'package:flutter/foundation.dart';

import '../data/location_store.dart';
import '../domain/models.dart';
import '../domain/saved_location.dart';

class LocationsController extends ChangeNotifier {
  LocationsController({required this._store});
  final LocationStore _store;
  List<SavedLocation> _locations = const [];
  bool _busy = false;
  bool _loaded = false;
  bool _disposed = false;
  String? _error;

  List<SavedLocation> get locations => _locations;
  bool get busy => _busy;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _emit();
    try {
      _locations = List.unmodifiable(await _store.read());
      _loaded = true;
    } catch (_) {
      _loaded = false;
      _error = '无法读取已保存地点，请解锁系统安全存储后重试。仍可手动输入坐标签到。';
    } finally {
      _busy = false;
      _emit();
    }
  }

  Future<bool> save(
    String name,
    SignLocation location, {
    String? replacingName,
  }) async {
    if (_busy || !_loaded) return false;
    name = name.trim();
    if (name.isEmpty || name.length > 40 || !location.isValid) {
      _error = '请输入 1～40 个字符的地点名称及有效经纬度';
      _emit();
      return false;
    }
    if (_locations.any(
      (item) => item.name == name && item.name != replacingName,
    )) {
      _error = '已有同名地点，请使用其他名称';
      _emit();
      return false;
    }
    final next = _locations.toList();
    final index = next.indexWhere((item) => item.name == replacingName);
    final saved = SavedLocation(name: name, location: location);
    if (replacingName != null && index < 0) return false;
    if (index < 0) {
      next.add(saved);
    } else {
      next[index] = saved;
    }
    return _persist(next, '地点未能保存，请检查系统安全存储后重试');
  }

  Future<bool> delete(String name) async {
    if (_busy || !_loaded) return false;
    return _persist(
      _locations.where((item) => item.name != name).toList(),
      '地点未能删除，请检查系统安全存储后重试',
    );
  }

  Future<bool> _persist(List<SavedLocation> next, String failureMessage) async {
    _busy = true;
    _error = null;
    _emit();
    try {
      await _store.write(next);
      _locations = List.unmodifiable(next);
      return true;
    } catch (_) {
      _error = failureMessage;
      return false;
    } finally {
      _busy = false;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
