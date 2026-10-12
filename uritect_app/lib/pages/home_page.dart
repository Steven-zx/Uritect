import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/saved_scan_record.dart';
import '../services/scan_history_service.dart';
import '../services/history_cipher.dart';
import '../widgets/common_widgets.dart';
import 'capture_dipstick_page.dart';
import 'protected_history_page.dart';
import 'about_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ScanHistoryService _historyService = const ScanHistoryService();
  late Future<List<SavedScanRecord>> _recordsFuture;
  bool _historyUnlocked = false;
  bool _unlocking = false;
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordsFuture = Future.value([]);
  }

  Future<void> _refreshHistory() async {
    if (_unlocking) return;
    _unlocking = true;
    try {
      await HistoryPrivacy.acquire(this);
      final records = await _historyService.loadRecords();
      await _historyService.authenticate();
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await HistoryPrivacy.release(this);
        return;
      }
      await HistoryPrivacy.acquire(this);
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        await HistoryPrivacy.release(this);
        return;
      }
      setState(() {
        _historyUnlocked = true;
        _recordsFuture = Future.value(records);
      });
      _historyTimer?.cancel();
      final remaining =
          _historyService.cipher.remainingSession - const Duration(seconds: 2);
      _historyTimer = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        _hideHistory,
      );
    } catch (e) {
      await HistoryPrivacy.release(this);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(historyAccessMessage(e))));
      }
    } finally {
      _unlocking = false;
    }
  }

  void _hideHistory() {
    _historyTimer?.cancel();
    if (mounted) {
      setState(() {
        _historyUnlocked = false;
        _recordsFuture = Future.value([]);
      });
    }
    unawaited(HistoryPrivacy.release(this));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hideHistory();
    } else if (!_historyUnlocked) {
      unawaited(HistoryPrivacy.release(this));
    }
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    unawaited(HistoryPrivacy.release(this));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _deleteScanRecord(SavedScanRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scan?'),
        content: Text(
          'Remove the scan from ${_formatDate(record.savedAt)} at ${_formatTime(record.savedAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.statusHigh),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    bool deleted;
    try {
      deleted = await _historyService.deleteRecord(record.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion could not be completed: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    _refreshHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(deleted ? 'Scan deleted.' : 'Scan was already removed.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildReadyCard(context),
              const SizedBox(height: 24),
              _buildRecentScansHeader(context),
              const SizedBox(height: 12),
              _buildRecentScansList(context),
              const SizedBox(height: 20),
              _buildTipCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const AppLogo(size: 64),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to URITECT',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryMain,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'About URITECT',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
          icon: const Icon(Icons.info_outline),
        ),
      ],
    );
  }

  Widget _buildReadyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F5F5), Color(0xFFF1FAFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCDE8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: AppColors.primaryDark,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OFFLINE SCREENING',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Start with a clear photo',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.primaryDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture or upload your dipstick, then complete the safety checklist.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CaptureDipstickPage(),
                  ),
                );
                if (mounted && _historyUnlocked) await _refreshHistory();
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('START SCAN'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScansHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Recent Scans',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        TextButton(
          onPressed: _unlocking ? null : _refreshHistory,
          child: Row(
            children: [
              Text(
                _historyUnlocked ? 'Refresh' : 'Unlock',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _historyUnlocked ? Icons.refresh_rounded : Icons.lock_outline,
                size: 16,
                color: AppColors.primaryMain,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentScansList(BuildContext context) {
    if (!_historyUnlocked) {
      return OutlinedButton.icon(
        onPressed: _refreshHistory,
        icon: const Icon(Icons.lock_outline),
        label: const Text('Unlock saved history'),
      );
    }
    return FutureBuilder<List<SavedScanRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryMain,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text('History could not be loaded: ${snapshot.error}');
        }
        final records = snapshot.data ?? const <SavedScanRecord>[];
        if (records.isEmpty) {
          return Column(
            children: [
              if (ScanHistoryService.recoveryNotice != null)
                Text(ScanHistoryService.recoveryNotice!),
              _buildEmptyHistoryCard(context),
            ],
          );
        }

        final recent = records.take(5).toList();
        return Column(
          children: [
            if (ScanHistoryService.recoveryNotice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(ScanHistoryService.recoveryNotice!),
              ),
            for (var index = 0; index < recent.length; index++) ...[
              _buildRecentScanCard(context, recent[index]),
              if (index != recent.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyHistoryCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'No saved scans yet. Completed scans will appear here after symptoms are added.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildRecentScanCard(BuildContext context, SavedScanRecord record) {
    final statusColor = _actionColor(record.clinicalAction);
    final icon = _actionIcon(record.clinicalAction);
    final iconBackground = _actionIconBackground(record.clinicalAction);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProtectedHistoryPage(recordId: record.id),
          ),
        );
        if (mounted) await _refreshHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildHistoryLeading(record, icon, statusColor, iconBackground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.patientName ?? 'Unnamed patient',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF303742),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDate(record.savedAt)} · ${_formatTime(record.savedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          record.scanResult.isLegacyUnverified
                              ? 'Unverified archive'
                              : record.clinicalAction,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProtectedHistoryPage(
                      recordId: record.id,
                      editNameInitially: true,
                    ),
                  ),
                );
                if (mounted) await _refreshHistory();
              },
              tooltip: record.patientName == null
                  ? 'Add patient name'
                  : 'Edit patient name',
              icon: const Icon(Icons.edit_outlined, size: 20),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              onPressed: () => _deleteScanRecord(record),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AppColors.statusHigh,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Delete scan',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryLeading(
    SavedScanRecord record,
    IconData icon,
    Color statusColor,
    Color iconBackground,
  ) {
    if (record.scanResult.imagePath.endsWith('.enc')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: FutureBuilder<Uint8List>(
          future: _historyService.readImage(record.scanResult.imagePath),
          builder: (context, snapshot) => snapshot.hasData
              ? Image.memory(
                  snapshot.data!,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                )
              : SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(icon, color: statusColor),
                ),
        ),
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
      child: Icon(icon, color: statusColor, size: 20),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'Prompt medical consultation suggested':
        return AppColors.statusHigh;
      case 'Consultation suggested':
        return AppColors.statusModerate;
      case 'Insufficient evidence':
        return AppColors.primaryMain;
      default:
        return AppColors.statusLow;
    }
  }

  Color _actionIconBackground(String action) {
    switch (action) {
      case 'Prompt medical consultation suggested':
        return const Color(0xFFFAD2CE);
      case 'Consultation suggested':
        return const Color(0xFFFFE8BF);
      case 'Insufficient evidence':
        return const Color(0xFFEAF6FB);
      default:
        return const Color(0xFFDDF7E7);
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'Prompt medical consultation suggested':
        return Icons.error_outline;
      case 'Consultation suggested':
        return Icons.warning_amber_rounded;
      case 'Insufficient evidence':
        return Icons.info_outline_rounded;
      default:
        return Icons.check;
    }
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  Widget _buildTipCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const ExpansionTile(
        leading: Icon(Icons.checklist_rounded, color: AppColors.primaryMain),
        title: Text('Before You Scan'),
        subtitle: Text('Tips for accurate results'),
        shape: Border(),
        collapsedShape: Border(),
        childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          Text(
            '• Show all ten pads and the handle.\n• Use a plain background and even light.\n• Tap to focus and hold steady.\n• Follow the strip’s reading times.',
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
