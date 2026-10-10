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
  bool confirmed = false;
  @override
  void dispose() {
    code.dispose();
    timing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.source == 'camera'
          ? 'Record this capture'
          : 'Review imported photo',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.source == 'camera'
                ? 'Capture time is recorded by this app. Strip timing still depends on your report.'
                : 'This is an imported image. Analysis time is not the photo or specimen date. Photo metadata can be absent or edited.',
          ),
          if (widget.identity.reportedPhotoDate != null)
            Text(
              'Photo metadata date: ${widget.identity.reportedPhotoDate} (unverified)',
            ),
          if (widget.duplicateOf != null)
            const Text(
              'An identical image is already saved. This repeat is image review only.',
            ),
          if (widget.similarImageOf != null)
            const Text(
              'A similar image is already saved. Similarity does not establish specimen identity; confirm the specimen code and timing carefully.',
            ),
          if (!widget.duplicateCheckCompleted)
            const Text(
              'Saved images could not be checked. This analysis is image review only.',
            ),
          TextField(
            controller: code,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: 'Study/specimen code',
              helperText: 'Use a code, not a patient name.',
            ),
          ),
          TextField(
            controller: timing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Seconds after dipping (self-reported)',
              helperText: 'Leave blank if unknown. Follow the strip IFU.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: confirmed,
            onChanged: (v) => setState(() => confirmed = v ?? false),
            title: const Text(
              'This photo belongs to this current specimen and was taken at its required reading time.',
            ),
          ),
          const Text(
            'Unknown timing or specimen details allow image review and the safety checklist, but not a current-specimen screening estimate.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
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
        child: const Text('Analyze image'),
      ),
    ],
  );
}
