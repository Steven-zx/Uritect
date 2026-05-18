import 'dart:io';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/saved_scan_record.dart';
import '../services/scan_history_service.dart';
import '../widgets/common_widgets.dart';
import 'capture_dipstick_page.dart';
import 'overall_results_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScanHistoryService _historyService = const ScanHistoryService();
  late Future<List<SavedScanRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _historyService.loadRecords();
  }

  void _refreshHistory() {
    setState(() {
      _recordsFuture = _historyService.loadRecords();
    });
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

    final deleted = await _historyService.deleteRecord(record.id);
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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 26),
              _buildReadyCard(context),
              const SizedBox(height: 30),
              _buildRecentScansHeader(context),
              const SizedBox(height: 12),
              _buildRecentScansList(context),
              const SizedBox(height: 26),
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
        const AppLogo(),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, Health Worker',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primaryMain,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Good Morning!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReadyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                            left: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                            right: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                            left: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                            right: BorderSide(
                              color: AppColors.primaryMain,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/photos/dipstick icon.png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      'Ready to analyze?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use your smartphone to\nanalyze urine dipstick and get\ninstant insight.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.25,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const CaptureDipstickPage(),
                      ),
                    )
                    .then((_) => _refreshHistory());
              },
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: const Text(
                'START SCAN',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
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
        Text(
          'Recent Scans',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: _refreshHistory,
          child: Row(
            children: [
              Text(
                'Refresh',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.refresh_rounded,
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

        final records = snapshot.data ?? const <SavedScanRecord>[];
        if (records.isEmpty) {
          return _buildEmptyHistoryCard(context);
        }

        final recent = records.take(5).toList();
        return Column(
          children: [
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
    final statusColor = _riskColor(record.riskBucket);
    final icon = _riskIcon(record.riskBucket);
    final iconBackground = _riskIconBackground(record.riskBucket);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OverallResultsPage(
              scanResult: record.scanResult,
              clinicalChecklistResult: record.checklistResult,
            ),
          ),
        );
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
                    _formatDate(record.savedAt),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF303742),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(record.savedAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
                Text(
                  '${record.riskBucket} Risk',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
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
    final imageFile = File(record.scanResult.imagePath);
    if (record.scanResult.imagePath.isNotEmpty && imageFile.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Image.file(imageFile, width: 38, height: 38, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
      child: Icon(icon, color: statusColor, size: 20),
    );
  }

  Color _riskColor(String riskBucket) {
    switch (riskBucket) {
      case 'High':
        return AppColors.statusHigh;
      case 'Moderate':
        return AppColors.statusModerate;
      default:
        return AppColors.statusLow;
    }
  }

  Color _riskIconBackground(String riskBucket) {
    switch (riskBucket) {
      case 'High':
        return const Color(0xFFFAD2CE);
      case 'Moderate':
        return const Color(0xFFFFE8BF);
      default:
        return const Color(0xFFDDF7E7);
    }
  }

  IconData _riskIcon(String riskBucket) {
    switch (riskBucket) {
      case 'High':
        return Icons.error_outline;
      case 'Moderate':
        return Icons.warning_amber_rounded;
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
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD2E9F3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              color: AppColors.primaryMain,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip of the day',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryMain,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ensure good lighting and proper dipstick\nhandling for accurate results.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
