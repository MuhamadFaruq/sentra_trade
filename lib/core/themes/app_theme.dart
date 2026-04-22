import 'package:flutter/material.dart';

import '../theme.dart';

class AppTheme {
  AppTheme._();

  /// Dark theme utama aplikasi – didelegasikan ke [SentraTheme].
  static ThemeData get darkTheme => SentraTheme.dark();
}

