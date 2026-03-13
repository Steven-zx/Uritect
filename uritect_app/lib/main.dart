import 'package:flutter/material.dart';
import 'src/calibration/calibration_page.dart';
import 'src/database/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warm the database so first access is instant.
  await AppDatabase.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uritect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const CalibrationPage(),
    );
  }
}
