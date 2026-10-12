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
    final message = scan.rows.isNotEmpty && scan.hasQuarantinedOrientationModel
        ? 'Archived readings are unverified. Do not rely on this record.'
        : scan.rows.isNotEmpty && scan.isLegacyUnverified
        ? 'This saved record lacks the checks required for current screening.'
        : p?.isDuplicate == true
        ? 'Previously saved photo. Repeat review only.'
        : p?.isEarlierPhoto == true
        ? 'An earlier photo was used. Current-specimen screening is unavailable.'
        : p != null && !p.canSupportCurrentContext
        ? 'Photo or timing details are unconfirmed. Current-specimen screening is unavailable.'
        : null;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
