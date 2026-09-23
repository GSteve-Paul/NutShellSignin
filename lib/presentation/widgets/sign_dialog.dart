import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/locations_controller.dart';
import '../../data/location_store.dart';
import '../../domain/models.dart';

Future<SignLocation?> showSignDialog(
  BuildContext context,
  Course course, {
  required LocationStore store,
}) => showDialog<SignLocation>(
  context: context,
  builder: (_) => _SignDialog(course: course, store: store),
);

class _SignDialog extends StatefulWidget {
  const _SignDialog({required this.course, required this.store});
  final Course course;
  final LocationStore store;
  @override
  State<_SignDialog> createState() => _SignDialogState();
}

class _SignDialogState extends State<_SignDialog> {
  final _formKey = GlobalKey<FormState>();
  final _longitude = TextEditingController(
    text: SignLocation.campus.longitude.toString(),
  );
  final _latitude = TextEditingController(
    text: SignLocation.campus.latitude.toString(),
  );
  final _name = TextEditingController();
  late final LocationsController _locations;
  String? _selectedName;
  String? _nameError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _locations = LocationsController(store: widget.store);
    unawaited(_locations.load());
  }

  @override
  void dispose() {
    _locations.dispose();
    _longitude.dispose();
    _latitude.dispose();
    _name.dispose();
    super.dispose();
  }

  SignLocation get _location => SignLocation(
    longitude: double.parse(_longitude.text.trim()),
    latitude: double.parse(_latitude.text.trim()),
  );

  String? _validate(String? value, double limit) {
    final number = double.tryParse(value?.trim() ?? '');
    return number == null || !number.isFinite || number.abs() > limit
        ? '请输入 -$limit 到 $limit 之间的数值'
        : null;
  }

  void _select(String? name) {
    setState(() {
      _selectedName = name;
      _nameError = null;
      _notice = null;
      _name.text = name ?? '';
      if (name != null) {
        final saved = _locations.locations.firstWhere(
          (item) => item.name == name,
        );
        _longitude.text = saved.location.longitude.toString();
        _latitude.text = saved.location.latitude.toString();
      }
    });
  }

  Future<void> _save() async {
    final validCoordinates = _formKey.currentState!.validate();
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? '请输入地点名称' : null;
      _notice = null;
    });
    if (!validCoordinates || _nameError != null) return;
    final saved = await _locations.save(
      name,
      _location,
      replacingName: _selectedName,
    );
    if (!mounted || !saved) return;
    setState(() {
      _selectedName = name;
      _name.text = name;
      _notice = '地点已保存，下次签到可直接选择。';
    });
  }

  Future<void> _delete() async {
    final name = _selectedName;
    if (name == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除地点'),
        content: Text('删除“$name”？当前填写的经纬度会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final deleted = await _locations.delete(name);
    if (!mounted || !deleted) return;
    _select(null);
    setState(() => _notice = '地点已删除');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _locations,
    builder: (context, _) {
      // A successful rename/delete updates the list before the awaiting callback
      // updates selection. Never feed a stale selection into the dropdown.
      final selected =
          _locations.locations.any((item) => item.name == _selectedName)
          ? _selectedName
          : null;
      return AlertDialog(
        title: const Text('确认签到'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.courseName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.course.teacherName} · ${widget.course.classroomName}',
                  ),
                  const SizedBox(height: 16),
                  const Text('选择已保存地点，或手动填写。初始值为预设校区坐标，并非设备定位。'),
                  const SizedBox(height: 16),
                  if (_locations.busy) const LinearProgressIndicator(),
                  if (_locations.error != null) ...[
                    Text(
                      _locations.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (!_locations.loaded)
                      TextButton(
                        onPressed: _locations.busy ? null : _locations.load,
                        child: const Text('重新加载地点'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (_locations.locations.isNotEmpty) ...[
                    InputDecorator(
                      decoration: const InputDecoration(labelText: '已保存地点'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('saved-location'),
                          value: selected,
                          hint: const Text('选择地点'),
                          isExpanded: true,
                          isDense: true,
                          items: _locations.locations
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.name,
                                  child: Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _locations.busy ? null : _select,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    key: const Key('longitude'),
                    controller: _longitude,
                    enabled: !_locations.busy,
                    decoration: const InputDecoration(
                      labelText: '经度 longitude',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) => _validate(value, 180),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('latitude'),
                    controller: _latitude,
                    enabled: !_locations.busy,
                    decoration: const InputDecoration(labelText: '纬度 latitude'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) => _validate(value, 90),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('location-name'),
                    controller: _name,
                    enabled: _locations.loaded && !_locations.busy,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: '地点名称（保存时填写）',
                      hintText: '例如：教一楼 107',
                      errorText: _nameError,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: !_locations.loaded || _locations.busy
                            ? null
                            : _save,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: Text(_selectedName == null ? '保存地点' : '更新地点'),
                      ),
                      if (_selectedName != null) ...[
                        TextButton(
                          onPressed: _locations.busy
                              ? null
                              : () => _select(null),
                          child: const Text('新建地点'),
                        ),
                        TextButton(
                          onPressed: _locations.busy ? null : _delete,
                          child: const Text('删除地点'),
                        ),
                      ],
                    ],
                  ),
                  if (_notice != null)
                    Semantics(liveRegion: true, child: Text(_notice!)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _locations.busy
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context, _location);
                    }
                  },
            child: const Text('提交签到'),
          ),
        ],
      );
    },
  );
}
