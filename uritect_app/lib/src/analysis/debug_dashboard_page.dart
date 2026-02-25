import 'package:flutter/material.dart';

import 'analyte_result.dart';

class DebugDashboardPage extends StatefulWidget {
  const DebugDashboardPage({
    super.key,
    required this.results,
    this.onConfirmAndSave,
    this.onDiscard,
  });

  final List<AnalyteResult> results;
  final Future<void> Function(List<AnalyteResult> results)? onConfirmAndSave;
  final VoidCallback? onDiscard;

  @override
  State<DebugDashboardPage> createState() => _DebugDashboardPageState();
}

class _DebugDashboardPageState extends State<DebugDashboardPage> {
  bool _isSaving = false;

  Future<void> _handleDiscard() async {
    widget.onDiscard?.call();
    if (mounted) {
      Navigator.of(context).maybePop(false);
    }
  }

  Future<void> _handleConfirmAndSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final callback = widget.onConfirmAndSave;
      if (callback != null) {
        await callback(widget.results);
      }

      if (!mounted) return;
      Navigator.of(context).maybePop(true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.results;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        cardColor: const Color(0xFF1A1F2B),
        colorScheme: Theme.of(context).colorScheme.copyWith(
              surface: const Color(0xFF1A1F2B),
              onSurface: Colors.white,
            ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debug Verification Dashboard'),
          backgroundColor: const Color(0xFF121826),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  return _AnalyteCard(result: cards[index]);
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF121826),
                  border: Border(
                    top: BorderSide(color: Color(0xFF2A3244)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _handleDiscard,
                        icon: const Icon(Icons.close),
                        label: const Text('Discard'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF5D6B86)),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _handleConfirmAndSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isSaving ? 'Saving...' : 'Confirm & Save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyteCard extends StatelessWidget {
  const _AnalyteCard({required this.result});

  final AnalyteResult result;

  @override
  Widget build(BuildContext context) {
    final raw = result.rawRgb;
    final hsv = result.hsv;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.analyteName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original Crop', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(
                          result.sampledCropPng,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('No Crop', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Processed Color', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: result.correctedRgb,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Raw RGB: R:${raw.r}, G:${raw.g}, B:${raw.b}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'HSV: H:${hsv.hue.toStringAsFixed(1)}°, '
              'S:${(hsv.saturation * 100).toStringAsFixed(0)}%, '
              'V:${(hsv.value * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nearest Match',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              result.nearestMatch,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
