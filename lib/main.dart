import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/themes/app_theme.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'core/utils/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Jalankan autentikasi sebelum masuk ke UI utama
  bool authenticated = await AuthService.authenticate();

  if (authenticated) {
    runApp(const ProviderScope(child: MyApp()));
  } else {
    // Jika gagal, tampilkan aplikasi yang terkunci atau biarkan kosong
    runApp(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Akses Ditolak'))),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SentraTrade',
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
