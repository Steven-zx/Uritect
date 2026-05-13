import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../widgets/common_widgets.dart';
import 'capture_dipstick_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
              _buildRecentScanCard(
                context,
                date: 'May 20, 2026',
                time: '10:30 AM',
                risk: 'Moderate Risk',
                statusColor: AppColors.statusModerate,
                icon: Icons.warning_amber_rounded,
                iconBackground: const Color(0xFFFFE8BF),
              ),
              const SizedBox(height: 10),
              _buildRecentScanCard(
                context,
                date: 'May 20, 2026',
                time: '10:30 AM',
                risk: 'Low Risk',
                statusColor: AppColors.statusLow,
                icon: Icons.check,
                iconBackground: const Color(0xFFDDF7E7),
              ),
              const SizedBox(height: 10),
              _buildRecentScanCard(
                context,
                date: 'May 20, 2026',
                time: '10:30 AM',
                risk: 'High Risk',
                statusColor: AppColors.statusHigh,
                icon: Icons.error_outline,
                iconBackground: const Color(0xFFFAD2CE),
              ),
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
                            top: BorderSide(color: AppColors.primaryMain, width: 3),
                            left: BorderSide(color: AppColors.primaryMain, width: 3),
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
                            top: BorderSide(color: AppColors.primaryMain, width: 3),
                            right: BorderSide(color: AppColors.primaryMain, width: 3),
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
                            bottom: BorderSide(color: AppColors.primaryMain, width: 3),
                            left: BorderSide(color: AppColors.primaryMain, width: 3),
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
                            bottom: BorderSide(color: AppColors.primaryMain, width: 3),
                            right: BorderSide(color: AppColors.primaryMain, width: 3),
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CaptureDipstickPage(),
                    ),
                  );
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
        Row(
          children: [
            Text(
              'View all',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.primaryMain),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentScanCard(
    BuildContext context, {
    required String date,
    required String time,
    required String risk,
    required Color statusColor,
    required IconData icon,
    required Color iconBackground,
  }) {
    return Container(
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF303742),
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
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
                risk,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFF1F2D3D)),
        ],
      ),
    );
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
            child: const Icon(Icons.wb_sunny_outlined, color: AppColors.primaryMain, size: 24),
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

  Widget _buildFrameIcon({
    required IconData icon,
    required double size,
    required double iconSize,
  }) {
    const double cornerSize = 16;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.primaryMain, width: 3),
                  left: BorderSide(color: AppColors.primaryMain, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.primaryMain, width: 3),
                  right: BorderSide(color: AppColors.primaryMain, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.primaryMain, width: 3),
                  left: BorderSide(color: AppColors.primaryMain, width: 3),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.primaryMain, width: 3),
                  right: BorderSide(color: AppColors.primaryMain, width: 3),
                ),
              ),
            ),
          ),
          Icon(icon, color: AppColors.primaryLight, size: iconSize),
        ],
      ),
    );
  }
}