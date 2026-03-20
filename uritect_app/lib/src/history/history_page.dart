import 'dart:io';

import 'package:flutter/material.dart';

import '../analysis/analyte_value_basis.dart';
import '../database/app_database.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isLoading = true;
  List<AnalysisSessionRecord> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await AppDatabase.instance.getAllSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _confirmDeleteSession(AnalysisSessionRecord session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
          'Delete session from ${_formatTimestamp(session.timestamp)}?\n\n'
          'This removes the history record. Image files on disk are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AppDatabase.instance.deleteSession(session.sessionUuid);
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadSessions();
  }

  static String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$m-$d  $h:$min';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadSessions();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_outlined,
                            size: 72, color: Colors.grey.shade400),
                        const SizedBox(height: 20),
                        Text(
                          'No saved sessions yet.',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Capture a strip in single-frame mode, then\n'
                          'tap "Confirm & Save" in the Debug Dashboard.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final subtitle = StringBuffer(session.phase)
                      ..write(' · ')
                      ..write(session.batchId)
                      ..write(' · ')
                      ..write('${session.lightKelvin}K');
                    if (session.controlLevel != null) {
                      subtitle..write(' · ')..write(session.controlLevel!);
                    }
                    if (session.markerConfidence != null) {
                      subtitle..write(' · marker ')
                        ..write(
                          '${(session.markerConfidence! * 100).toStringAsFixed(0)}%',
                        );
                    }

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.biotech,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          _formatTimestamp(session.timestamp),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(subtitle.toString()),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red.shade400,
                          tooltip: 'Delete session',
                          onPressed: () => _confirmDeleteSession(session),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                _SessionDetailPage(session: session),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── Session Detail ──────────────────────────────────────────────────────────

class _SessionDetailPage extends StatefulWidget {
  const _SessionDetailPage({required this.session});

  final AnalysisSessionRecord session;

  @override
  State<_SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<_SessionDetailPage> {
  bool _isLoading = true;
  List<AnalysisResultRecord> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final results = await AppDatabase.instance
        .getResultsForSession(widget.session.sessionUuid);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  static String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$m-$d  $h:$min';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

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
          title: Text('Session · ${_formatTimestamp(session.timestamp)}'),
          backgroundColor: const Color(0xFF121826),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // ── Metadata strip ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1A1F2B),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _MetaChip(label: 'Phase', value: session.phase),
                  _MetaChip(label: 'Batch', value: session.batchId),
                  _MetaChip(
                      label: 'Light', value: '${session.lightKelvin}K'),
                  if (session.controlLevel != null)
                    _MetaChip(
                        label: 'Control', value: session.controlLevel!),
                  if (session.markerConfidence != null)
                    _MetaChip(
                      label: 'Marker',
                      value:
                          '${(session.markerConfidence! * 100).toStringAsFixed(0)}%',
                    ),
                  _MetaChip(
                    label: 'Value Profile',
                    value: analyteValueProfileVersion,
                  ),
                ],
              ),
            ),
            // ── Results grid ──────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'No analyte results saved for this session.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.84,
                          ),
                          itemCount: _results.length,
                          itemBuilder: (context, index) =>
                              _ResultCard(record: _results[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.record});

  final AnalysisResultRecord record;

  @override
  Widget build(BuildContext context) {
    final corrColor =
        Color.fromARGB(255, record.corrR, record.corrG, record.corrB);
    final rawColor =
        Color.fromARGB(255, record.rawR, record.rawG, record.rawB);
    final resolvedValue = resolveAnalyteValue(
      analyteName: record.analyteName,
      nearestMatch: record.nearestMatch,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.analyteName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            _buildVisual(record.cropImagePath, corrColor),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: rawColor,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Raw: (${record.rawR}, ${record.rawG}, ${record.rawB})',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'AWB: (${record.corrR}, ${record.corrG}, ${record.corrB})',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'HSV: ${record.h.toStringAsFixed(1)}° '
              '${(record.s * 100).toStringAsFixed(0)}% '
              '${(record.v * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 1,
            ),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3244),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                record.nearestMatch,
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              resolvedValue.isMapped
                  ? 'Mapped: ${resolvedValue.displayValue} ${resolvedValue.unit}'
                  : 'Mapped: ${resolvedValue.displayValue}',
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Basis: ${resolvedValue.basisTag}',
              style: const TextStyle(color: Colors.white54, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisual(String? cropPath, Color fallbackColor) {
    if (cropPath != null) {
      final file = File(cropPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 42,
            width: double.infinity,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _colorSwatch(fallbackColor),
            ),
          ),
        );
      }
    }
    return _colorSwatch(fallbackColor);
  }

  Widget _colorSwatch(Color color) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
    );
  }
}
