import 'dart:async';

import 'package:flutter/material.dart';

import '../application/signin_controller.dart';
import '../core/beijing_time.dart';
import '../domain/models.dart';
import 'locations_page.dart';
import 'widgets/sign_dialog.dart';
import 'widgets/status_message.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key, required this.controller});
  final SigninController controller;
  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> with WidgetsBindingObserver {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-evaluate the sign-in time window even if the user leaves the page open.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.refreshCourses();
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _sign(Course course) async {
    final location = await showSignDialog(
      context,
      course,
      store: widget.controller.locationStore,
    );
    if (!mounted || location == null) return;
    await widget.controller.signIn(course, location);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller;
    final theme = Theme.of(context);
    final date = beijingWallTime(state.updatedAt ?? state.serverNow);
    final signed = state.courses.where((course) => course.isSigned).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('果壳签到'),
        actions: [
          IconButton(
            tooltip: '刷新课表',
            onPressed: state.busy ? null : state.refreshCourses,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: '账号与地点',
            enabled: !state.busy,
            onSelected: (value) async {
              switch (value) {
                case 'locations':
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => LocationsPage(store: state.locationStore),
                    ),
                  );
                case 'logout':
                  await state.logout();
                case 'forget':
                  await state.logout(forget: true);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(state.session?.realName ?? ''),
              ),
              const PopupMenuItem(value: 'locations', child: Text('管理已保存地点')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('退出登录')),
              const PopupMenuItem(value: 'forget', child: Text('退出并删除保存的账号密码')),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refreshCourses,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.all(24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    '今日课程',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${date.year} 年 ${date.month} 月 ${date.day} 日 · 北京时间',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${state.session?.realName ?? ''}，你好',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '共 ${state.courses.length} 条课次 · 已签到 $signed 条',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (state.storageWarning != null)
                    StatusMessage(state.storageWarning!, isError: true),
                  if (state.error != null)
                    StatusMessage(state.error!, isError: true),
                  if (state.notice != null) StatusMessage(state.notice!),
                  if (state.loadingCourses)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (!state.loadingCourses && state.courses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            state.error == null
                                ? Icons.event_available_outlined
                                : Icons.cloud_off_outlined,
                            size: 56,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(state.error == null ? '今天暂无课程' : '暂时无法加载课程'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: state.busy ? null : state.refreshCourses,
                            icon: const Icon(Icons.refresh),
                            label: const Text('重新获取'),
                          ),
                        ],
                      ),
                    ),
                  ...state.courses.map(
                    (course) => _CourseCard(
                      course: course,
                      now: state.serverNow,
                      busy: state.busy,
                      signing: state.signingTimeTableId == course.timeTableId,
                      onSign: () => _sign(course),
                    ),
                  ),
                  if (state.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '最近更新 ${courseTime(state.updatedAt)} · 开课前 30 分钟至下课可提交签到',
                        style: theme.textTheme.bodySmall,
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
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.now,
    required this.busy,
    required this.signing,
    required this.onSign,
  });
  final Course course;
  final DateTime now;
  final bool busy;
  final bool signing;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = course.signDisabledReason(now);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${courseTime(course.classBeginTime)} — ${courseTime(course.classEndTime)}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              course.courseName.isEmpty ? '未命名课程' : course.courseName,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text(
                  '教师 · ${course.teacherName.isEmpty ? '未提供' : course.teacherName}',
                ),
                Text(
                  '教室 · ${course.classroomName.isEmpty ? '未提供' : course.classroomName}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: busy || reason != null ? null : onSign,
                icon: signing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        course.isSigned
                            ? Icons.check_circle_outline
                            : Icons.how_to_reg_outlined,
                      ),
                label: Text(signing ? '正在签到…' : reason ?? '签到'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
