import 'package:flutter/material.dart';

import 'root_page.dart';

/// End the scan/review flow with a real dashboard as the only remaining route.
void returnToDashboard(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil<void>(
    MaterialPageRoute(builder: (_) => const RootPage()),
    (_) => false,
  );
}
