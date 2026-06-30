import 'package:flutter/material.dart';
import 'local_store.dart';
import 'sync_service.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.instance.init();   // carga sesiones guardadas localmente
  SyncService.instance.start();       // sincronización automática en segundo plano
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitor Ansiedad - Pulsera PPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const LoginScreen(),
    );
  }
}
