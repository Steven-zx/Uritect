import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/theme.dart';
import 'pages/app_splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship with the APK; startup must never fetch them over the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uritect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppSplashPage(),
    );
  }
}
