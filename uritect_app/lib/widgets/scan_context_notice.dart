import 'package:flutter/material.dart';
import '../models/scan_model.dart';

class ScanContextNotice extends StatelessWidget {
  final ScanResult scan;
  final bool compact;
  const ScanContextNotice({
    super.key,
    required this.scan,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = scan.provenance;
    final messages = <String>[
      if (scan.isLegacyUnverified)
        'Unverified archive: this record lacks the safety evidence required for a new interpretation.',
      if (p != null)
        p.isImported
            ? 'Imported photo. Analysis date is not the specimen or photo date.'
            : 'Photo captured in URITECT.',
      if (p != null && p.specimenCode != null)
        'Specimen code: ${p.specimenCode}',
      if (p?.secondsAfterDipping != null)
        'Reported reading time: ${p!.secondsAfterDipping!.toStringAsFixed(1)} seconds after dipping (self-reported).',
      if (p?.isDuplicate == true)
        'Previously saved image: repeat review only. A new analysis does not establish a new specimen.',
      if (p?.isEarlierPhoto == true)
        'Photo metadata reports an earlier date. Metadata is unverified; this is review only.',
      if (p?.similarImageOf != null)
        'A visually similar saved image was found. Similarity does not prove duplication; verify the specimen.',
      if (p != null && !p.canSupportCurrentContext)
        'Current specimen, timing or duplicate checks are incomplete. Current-result screening is withheld; the safety checklist remains available.',
    ];
    if (messages.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffeef7f8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: compact
          ? ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                scan.isLegacyUnverified
                    ? 'Archived readings are unverified'
                    : p != null && !p.canSupportCurrentContext
                    ? 'Review only: current-result screening unavailable'
                    : p?.isImported == true
                    ? 'Imported photo'
                    : 'Photo captured in URITECT',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              children: [Text(messages.join('\n\n'))],
            )
          : Text(
              messages.join('\n\n'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
    );
  }
}
