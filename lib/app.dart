import 'package:flutter/material.dart';

import 'application/signin_controller.dart';
import 'presentation/courses_page.dart';
import 'presentation/login_page.dart';

class NutShellApp extends StatelessWidget {
  const NutShellApp({super.key, required this.controller});
  final SigninController controller;

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B58),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '果壳签到',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => controller.session == null
          ? LoginPage(controller: controller)
          : CoursesPage(controller: controller),
    ),
  );
}
