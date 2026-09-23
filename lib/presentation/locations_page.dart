import 'dart:async';

import 'package:flutter/material.dart';

import '../application/locations_controller.dart';
import '../data/location_store.dart';
import '../domain/models.dart';
import '../domain/saved_location.dart';
import 'widgets/status_message.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key, required this.store});
  final LocationStore store;

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  late final LocationsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LocationsController(store: widget.store);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit([SavedLocation? location]) => showDialog<void>(
    context: context,
    builder: (_) =>
        _LocationEditor(controller: _controller, existing: location),
  );

  Future<void> _delete(SavedLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除地点'),
        content: Text('确定删除“${location.name}”及其保存的经纬度吗？'),
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
    await _controller.delete(location.name);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('管理已保存地点'),
        actions: [
          IconButton(
            tooltip: '刷新地点',
            onPressed: _controller.busy ? null : _controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _controller.loaded && !_controller.busy
            ? () => _edit()
            : null,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('新增地点'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: [
                const Text('地点保存在本设备，签到时可直接选择。退出账号不会删除这些地点。'),
                const SizedBox(height: 20),
                if (_controller.busy) const LinearProgressIndicator(),
                if (_controller.error != null) ...[
                  StatusMessage(_controller.error!, isError: true),
                  if (!_controller.loaded)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: _controller.busy ? null : _controller.load,
                        child: const Text('重新加载地点'),
                      ),
                    ),
                ],
                if (_controller.loaded && _controller.locations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('暂无已保存地点，点击“新增地点”添加。')),
                  ),
                ..._controller.locations.map(
                  (location) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            '经度：${location.location.longitude}\n纬度：${location.location.latitude}',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: _controller.busy
                                    ? null
                                    : () => _edit(location),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('修改'),
                              ),
                              TextButton.icon(
                                onPressed: _controller.busy
                                    ? null
                                    : () => _delete(location),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _LocationEditor extends StatefulWidget {
  const _LocationEditor({required this.controller, this.existing});
  final LocationsController controller;
  final SavedLocation? existing;

  @override
  State<_LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<_LocationEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _longitude;
  late final TextEditingController _latitude;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final location = widget.existing;
    _name = TextEditingController(text: location?.name ?? '');
    _longitude = TextEditingController(
      text: location?.location.longitude.toString() ?? '',
    );
    _latitude = TextEditingController(
      text: location?.location.latitude.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _longitude.dispose();
    _latitude.dispose();
    super.dispose();
  }

  String? _validateCoordinate(String? input, double limit) {
    final value = double.tryParse(input?.trim() ?? '');
    return value == null || !value.isFinite || value.abs() > limit
        ? '请输入 -$limit 到 $limit 之间的数值'
        : null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.controller.save(
      _name.text,
      SignLocation(
        longitude: double.parse(_longitude.text.trim()),
        latitude: double.parse(_latitude.text.trim()),
      ),
      replacingName: widget.existing?.name,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!saved) _error = widget.controller.error ?? '地点未能保存，请重试';
    });
    if (saved) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.existing == null ? '新增地点' : '修改地点'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) StatusMessage(_error!, isError: true),
                TextFormField(
                  key: const Key('edit-location-name'),
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: '地点名称'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入地点名称' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit-longitude'),
                  controller: _longitude,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: '经度 longitude'),
                  validator: (value) => _validateCoordinate(value, 180),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('edit-latitude'),
                  controller: _latitude,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: '纬度 latitude'),
                  validator: (value) => _validateCoordinate(value, 90),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中…' : '保存'),
        ),
      ],
    ),
  );
}
