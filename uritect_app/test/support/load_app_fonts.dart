import 'package:flutter/services.dart';

/// Load the real bundled font faces for phone screenshot/layout checks.
Future<void> loadAppFonts() async {
  final loader = FontLoader('Poppins');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await loader.load();
}
