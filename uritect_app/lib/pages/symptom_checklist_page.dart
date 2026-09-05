import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/scan_model.dart';
import '../models/screening_fusion.dart';
import '../services/scan_history_service.dart';
import 'overall_results_page.dart';

class SymptomChecklistPage extends StatefulWidget {
  final ScanResult scanResult;

  const SymptomChecklistPage({super.key, required this.scanResult});

  @override
  State<SymptomChecklistPage> createState() => _SymptomChecklistPageState();
}

class _SymptomChecklistPageState extends State<SymptomChecklistPage> {
  late Map<String, bool> selectedSymptoms;
  final ScanHistoryService _historyService = const ScanHistoryService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedSymptoms = {for (final s in clinicalSymptoms) s.id: false};
  }

  void _toggleSymptom(String id) {
    if (_isSaving) return;
    setState(() {
      selectedSymptoms[id] = !(selectedSymptoms[id] ?? false);
    });
  }

  Future<void> _continueToOverallResults() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    final checklistResult = ClinicalChecklistResult(
      selectedSymptoms: Map<String, bool>.from(selectedSymptoms),
    );
    final screeningAnalytes = ScreeningFusionEngine.buildAnalytesFromRows(
      widget.scanResult.rows,
    );
    final fusionResult = const ScreeningFusionEngine().fuse(
      analytes: screeningAnalytes,
      checklist: checklistResult,
    );

    try {
      final savedRecord = await _historyService.saveCompletedScan(
        scanResult: widget.scanResult,
        checklistResult: checklistResult,
        fusionResult: fusionResult,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OverallResultsPage(
            scanResult: savedRecord.scanResult,
            clinicalChecklistResult: savedRecord.checklistResult,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save scan history: $error')),
      );
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
    final utiSymptoms = clinicalSymptoms
        .where((s) => s.category == 'uti')
        .toList();
    final systemicSymptoms = clinicalSymptoms
        .where((s) => s.category == 'systemic')
        .toList();
    final followUpSymptoms = clinicalSymptoms
        .where((s) => s.category == 'followup')
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 64),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Symptom Checklist',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryMain,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select the symptoms observed\nin the patient.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.25,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Symptoms list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryHeader(
                        context,
                        'Localized UTI Symptoms',
                      ),
                      const SizedBox(height: 12),
                      ...utiSymptoms.map(
                        (symptom) => _buildSymptomTile(context, symptom),
                      ),
                      const SizedBox(height: 28),
                      _buildCategoryHeader(
                        context,
                        'Systemic Warning Symptoms',
                      ),
                      const SizedBox(height: 12),
                      ...systemicSymptoms.map(
                        (symptom) => _buildSymptomTile(context, symptom),
                      ),
                      const SizedBox(height: 28),
                      _buildCategoryHeader(
                        context,
                        'Follow-up Indicators',
                      ),
                      const SizedBox(height: 12),
                      ...followUpSymptoms.map(
                        (symptom) => _buildSymptomTile(context, symptom),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              // Continue button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _continueToOverallResults,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _isSaving ? 'SAVING...' : 'CONTINUE',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: AppColors.border, thickness: 1),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryMain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomTile(BuildContext context, ClinicalSymptom symptom) {
    final isSelected = selectedSymptoms[symptom.id] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _toggleSymptom(symptom.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryMain : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForSymptom(symptom.iconCode),
                  color: AppColors.primaryMain,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  symptom.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSymptom(symptom.id),
                activeColor: AppColors.primaryMain,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primaryMain
                      : const Color(0xFFCDD5DC),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSymptom(String iconCode) {
    switch (iconCode) {
      case 'dysuria':
        return Icons.local_fire_department_rounded;
      case 'frequency':
        return Icons.wc_rounded;
      case 'suprapubic':
        return Icons.person_rounded;
      case 'hematuria':
        return Icons.water_drop_rounded;
      case 'flank':
        return Icons.person_rounded;
      case 'fever':
        return Icons.thermostat_rounded;
      case 'edema':
        return Icons.person_rounded;
      case 'nausea':
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
