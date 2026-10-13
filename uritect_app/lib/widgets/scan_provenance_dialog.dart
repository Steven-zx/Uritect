import 'package:flutter/material.dart';
import '../models/scan_provenance.dart';
import '../services/scan_provenance_service.dart';

class ScanProvenanceDialog extends StatefulWidget {
  final ImageIdentity identity;
  final String source;
  final DateTime? acquiredAt;
  final String? duplicateOf;
  final String? similarImageOf;
  final bool duplicateCheckCompleted;
  const ScanProvenanceDialog({
    super.key,
    required this.identity,
    required this.source,
    this.acquiredAt,
    this.duplicateOf,
    this.similarImageOf,
    required this.duplicateCheckCompleted,
  });
  @override
  State<ScanProvenanceDialog> createState() => _ScanProvenanceDialogState();
}

class _ScanProvenanceDialogState extends State<ScanProvenanceDialog> {
  final code = TextEditingController();
  final timing = TextEditingController();
  String selectedTime = 'unknown';
  bool confirmed = false;
  @override
  void dispose() {
    code.dispose();
    timing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Review Photo'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Make sure the full dipstick is clear and photographed at the correct reading time.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('photo_reading_time'),
              initialValue: selectedTime,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Time after dipping',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'unknown', child: Text('I’m not sure')),
                DropdownMenuItem(value: '30', child: Text('30 seconds')),
                DropdownMenuItem(value: '40', child: Text('40 seconds')),
                DropdownMenuItem(value: '45', child: Text('45 seconds')),
                DropdownMenuItem(value: '60', child: Text('60 seconds')),
                DropdownMenuItem(value: 'other', child: Text('Another time')),
              ],
              onChanged: (value) => setState(() {
                selectedTime = value ?? 'unknown';
                timing.text =
                    selectedTime == 'unknown' || selectedTime == 'other'
                    ? ''
                    : selectedTime;
              }),
            ),
            if (selectedTime == 'other')
              TextField(
                controller: timing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Number of seconds',
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Unknown timing means review only. Each pad has its own reading time.',
              style: TextStyle(fontSize: 12),
            ),
            if (widget.duplicateOf != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('This photo is already saved. Repeat review only.'),
              ),
            if (widget.similarImageOf != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'A similar saved photo was found. Check that this is the current specimen.',
                ),
              ),
            if (!widget.duplicateCheckCompleted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Saved photos could not be checked. Review only.'),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (v) => setState(() => confirmed = v ?? false),
              title: const Text('This photo is from the current specimen.'),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text('Research Details'),
              children: [
                TextField(
                  controller: code,
                  maxLength: 64,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Specimen code (optional)',
                    helperText: 'Use a code, not a patient name.',
                  ),
                ),
                const Text(
                  'A specimen code is required for current-specimen screening. Without it, photo review and the safety checklist remain available.',
                  style: TextStyle(fontSize: 12),
                ),
                if (widget.identity.reportedPhotoDate != null)
                  Text(
                    'Unverified photo date: ${widget.identity.reportedPhotoDate}',
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final seconds = double.tryParse(timing.text.trim());
          Navigator.pop(
            context,
            ScanProvenance(
              source: widget.source,
              analyzedAt: DateTime.now(),
              capturedAt: widget.acquiredAt,
              reportedPhotoDate: widget.identity.reportedPhotoDate,
              contentSha256: widget.identity.contentHash,
              pixelSha256: widget.identity.pixelHash,
              imageFingerprint: widget.identity.fingerprint,
              duplicateOf: widget.duplicateOf,
              similarImageOf: widget.similarImageOf,
              specimenCode: code.text.trim().isEmpty ? null : code.text.trim(),
              secondsAfterDipping:
                  seconds != null && seconds.isFinite && seconds >= 0
                  ? seconds
                  : null,
              currentSpecimenConfirmed: confirmed,
              duplicateCheckCompleted: widget.duplicateCheckCompleted,
            ),
          );
        },
        child: const Text('Analyze Photo'),
      ),
    ],
  );
}
