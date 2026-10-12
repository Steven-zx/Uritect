import 'package:flutter/material.dart';
import 'performance_notes_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('About URITECT')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _section(
          'About URITECT',
          'An offline research prototype for reviewing urine dipstick photos and providing follow-up guidance. It does not diagnose disease.',
        ),
        _section(
          'How to Use',
          'Take or select a clear photo. Record its reading time, review the readings, and complete the safety checklist.',
        ),
        _section(
          'Safety and Limitations',
          'Some readings may be uncertain. Do not use this app to confirm or rule out an illness. Seek medical help for serious symptoms, even when a scan fails.',
        ),
        _section(
          'Privacy and Data',
          'Saved history and photos are protected locally and require unlocking. Patient names are optional. Delete records you no longer need. Photo timestamps and strip timing cannot be independently verified by the app.',
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Research Information'),
          subtitle: const Text('Optional performance and methodology details'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PerformanceNotesPage()),
          ),
        ),
      ],
    ),
  );
  Widget _section(String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(text),
      ],
    ),
  );
}
