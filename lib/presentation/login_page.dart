import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/signin_controller.dart';
import 'widgets/status_message.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final SigninController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_restore);
    _restore();
  }

  void _restore() {
    if (_restored || widget.controller.initializing) return;
    _restored = true;
    final credentials = widget.controller.initialCredentials;
    if (credentials != null) {
      _phone.text = credentials.phone;
      _password.text = credentials.password;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_restore);
    _phone.clear();
    _password.clear();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await widget.controller.login(_phone.text, _password.text);
    TextInput.finishAutofillContext(shouldSave: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          size: 36,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '果壳签到',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('登录，查看今天的课程。', style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 32),
                      if (state.error != null)
                        StatusMessage(state.error!, isError: true),
                      if (state.storageWarning != null)
                        StatusMessage(state.storageWarning!, isError: true),
                      if (state.initializing) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        const Text('正在读取已保存的账号密码…'),
                      ] else ...[
                        TextFormField(
                          key: const Key('phone'),
                          controller: _phone,
                          enabled: !state.busy,
                          decoration: const InputDecoration(
                            labelText: '学号',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.username],
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '请输入学号'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('password'),
                          controller: _password,
                          enabled: !state.busy,
                          obscureText: _obscure,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!state.busy) _login();
                          },
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure ? '显示密码' : '隐藏密码',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? '请输入密码' : null,
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('记住账号密码'),
                          subtitle: const Text('保存到系统安全存储，下次打开自动填入。'),
                          value: state.rememberCredentials,
                          onChanged: state.busy
                              ? null
                              : state.setRememberCredentials,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('login'),
                            onPressed: state.busy ? null : _login,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: state.loggingIn
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('登录'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '中国科学院大学 · 课程签到',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
