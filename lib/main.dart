import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'application/signin_controller.dart';
import 'data/credential_store.dart';
import 'data/iclass_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppRoot());
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();
  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _client = http.Client();
  late final SigninController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SigninController(
      gateway: IclassApi(client: _client),
      store: SecureCredentialStore(),
    );
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NutShellApp(controller: _controller);
}
