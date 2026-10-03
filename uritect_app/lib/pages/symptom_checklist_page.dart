import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/renal_followup.dart';
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
  final ScrollController _scrollController = ScrollController();
  int _currentStep = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedSymptoms = {
      for (final symptom in clinicalSymptoms) symptom.id: false,
    };
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSymptom(String id) {
    if (_isSaving) return;
    setState(() {
      selectedSymptoms[id] = !(selectedSymptoms[id] ?? false);
    });
  }

  void _selectSex(String id) {
    if (_isSaving) return;
    setState(() {
      selectedSymptoms['uti_eligible_female'] = id == 'uti_eligible_female';
      selectedSymptoms['uti_eligible_male'] = id == 'uti_eligible_male';
      if (id == 'uti_eligible_male') {
        selectedSymptoms['uti_eligible_nonpregnant'] = false;
        selectedSymptoms['vaginal_discharge'] = false;
        selectedSymptoms['vaginal_irritation'] = false;
        selectedSymptoms['menstruation_or_vaginal_bleeding'] = false;
      } else {
        selectedSymptoms['uti_male_no_diabetes'] = false;
        selectedSymptoms['uti_male_no_suspected_sti'] = false;
      }
    });
  }

  void _setStep(int step) {
    if (_isSaving) return;
    setState(() => _currentStep = step);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _continueToOverallResults() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final checklistResult = ClinicalChecklistResult(
      selectedSymptoms: Map<String, bool>.from(selectedSymptoms),
    );
    final screeningAnalytes = ScreeningFusionEngine.buildAnalytesFromRows(
      widget.scanResult.rows,
    );
    final fusionResult = const ScreeningFusionEngine().fuse(
      analytes: screeningAnalytes,
      scanResult: widget.scanResult,
      checklist: checklistResult,
    );
    final renalFollowupResult = const RenalFollowupEngine().evaluate(
      scanResult: widget.scanResult,
      checklist: checklistResult,
    );

    try {
      final savedRecord = await _historyService.saveCompletedScan(
        scanResult: widget.scanResult,
        checklistResult: checklistResult,
        fusionResult: fusionResult,
        renalFollowupResult: renalFollowupResult,
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<ClinicalSymptom> _items(String category) => clinicalSymptoms
      .where((symptom) => symptom.category == category)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildStepSelector(context),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_currentStep),
                    child: _buildCurrentStep(context),
                  ),
                ),
              ),
            ),
            _buildNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to analyte results',
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primaryMain,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Clinical Checklist',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryMain,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Step ${_currentStep + 1} of 3',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStepSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.fact_check_outlined, size: 18),
              label: Text('UTI'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.health_and_safety_outlined, size: 18),
              label: Text('Safety'),
            ),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.science_outlined, size: 18),
              label: Text('Context'),
            ),
          ],
          selected: {_currentStep},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => _setStep(selection.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    return switch (_currentStep) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntro(
            context,
            icon: Icons.calculate_outlined,
            title: 'Bayesian UTI screening inputs',
            message:
                'Confirm eligibility, then select only symptoms that are actually reported. Unchecked eligibility items remain unknown and stop the ordinary estimate.',
          ),
          _buildSection(
            context,
            title: 'Sex',
            helper:
                'Select one. URITECT applies a separately sourced model for each sex.',
            items: _items('uti_sex'),
            singleSelection: true,
          ),
          _buildSection(
            context,
            title: 'Eligibility confirmations',
            helper: 'Confirm every item that is known to be true.',
            items: _items('uti_eligibility').where((item) {
              if (item.id == 'uti_eligible_nonpregnant') {
                return selectedSymptoms['uti_eligible_female'] == true;
              }
              return true;
            }).toList(),
          ),
          if (selectedSymptoms['uti_eligible_male'] == true)
            _buildSection(
              context,
              title: 'Male-model confirmations',
              helper:
                  'These exclusions match the culture-referenced male study population.',
              items: _items('uti_male_eligibility'),
            ),
          _buildSection(
            context,
            title: 'Acute urinary symptoms',
            helper: selectedSymptoms['uti_eligible_male'] == true
                ? 'Select reported symptoms. Dysuria, frequency or urgency is required for the male estimate; other symptoms inform separate follow-up.'
                : 'Select every symptom currently reported.',
            items: _items('uti'),
          ),
          _buildSection(
            context,
            title: 'Symptoms suggesting another cause',
            helper:
                'Either finding routes to consultation instead of an ordinary lower-UTI estimate.',
            items: selectedSymptoms['uti_eligible_male'] == true
                ? const []
                : _items('differential'),
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntro(
            context,
            icon: Icons.health_and_safety_outlined,
            title: 'Safety and renal follow-up',
            message:
                'These answers are evaluated separately from the Bayesian UTI estimate. Serious combinations can trigger prompt consultation even when the scan is invalid.',
          ),
          _buildSection(
            context,
            title: 'Systemic warning symptoms',
            helper: 'These findings are outside uncomplicated lower UTI.',
            items: _items('systemic'),
          ),
          _buildSection(
            context,
            title: 'Renal follow-up symptoms',
            helper: 'Used by the separate renal rule engine.',
            items: _items('renal'),
          ),
          _buildSection(
            context,
            title: 'Urgent safety questions',
            helper: 'Select every serious symptom or condition that applies.',
            items: _items('renal_safety'),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntro(
            context,
            icon: Icons.biotech_outlined,
            title: 'Test context and reliability',
            message:
                'Record possible interferences, repeat-test history, and strip-quality problems before calculating the final outputs.',
          ),
          _buildSection(
            context,
            title: 'Possible interferences',
            helper: 'Temporary causes may change the renal follow-up action.',
            items: _items('interference').where((item) {
              if (item.id == 'menstruation_or_vaginal_bleeding') {
                return selectedSymptoms['uti_eligible_male'] != true;
              }
              return true;
            }).toList(),
          ),
          _buildSection(
            context,
            title: 'Repeat-test history',
            helper: 'Only select results that were actually confirmed.',
            items: _items('repeat_history'),
          ),
          _buildSection(
            context,
            title: 'Strip and timing checks',
            helper:
                'A quality problem causes a retake rather than a strip-based conclusion.',
            items: _items('test_quality'),
          ),
        ],
      ),
    };
  }

  Widget _buildIntro(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryMain, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String helper,
    required List<ClinicalSymptom> items,
    bool singleSelection = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final selectedCount = items
        .where((item) => selectedSymptoms[item.id] == true)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$selectedCount/${items.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in items)
            _buildChecklistTile(
              context,
              item,
              singleSelection: singleSelection,
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistTile(
    BuildContext context,
    ClinicalSymptom symptom, {
    bool singleSelection = false,
  }) {
    final selected = selectedSymptoms[symptom.id] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? AppColors.primaryMain : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => singleSelection
              ? _selectSex(symptom.id)
              : _toggleSymptom(symptom.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
            child: Row(
              children: [
                Icon(
                  _iconFor(symptom.iconCode),
                  color: selected
                      ? AppColors.primaryMain
                      : AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    symptom.label.replaceAll('\n', ' '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (singleSelection)
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected
                        ? AppColors.primaryMain
                        : AppColors.textSecondary,
                  )
                else
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSymptom(symptom.id),
                    activeColor: AppColors.primaryMain,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    final selectedCount = selectedSymptoms.values
        .where((value) => value)
        .length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.bgMain,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            IconButton.filledTonal(
              tooltip: 'Previous checklist step',
              onPressed: _isSaving ? null : () => _setStep(_currentStep - 1),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : _currentStep < 2
                    ? () => _setStep(_currentStep + 1)
                    : _continueToOverallResults,
                icon: Icon(
                  _currentStep < 2
                      ? Icons.arrow_forward_rounded
                      : Icons.calculate_rounded,
                  size: 20,
                ),
                label: Text(
                  _isSaving
                      ? 'SAVING...'
                      : _currentStep < 2
                      ? 'NEXT'
                      : 'CALCULATE RESULTS ($selectedCount)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String code) {
    return switch (code) {
      'dysuria' => Icons.local_fire_department_rounded,
      'frequency' => Icons.schedule_rounded,
      'suprapubic' => Icons.person_outline_rounded,
      'hematuria' => Icons.water_drop_rounded,
      'discharge' => Icons.info_outline_rounded,
      'irritation' => Icons.report_problem_outlined,
      'flank' => Icons.accessibility_new_rounded,
      'fever' => Icons.thermostat_rounded,
      'nausea' => Icons.sick_outlined,
      'blood_clots' => Icons.bloodtype_rounded,
      'urinary_obstruction' => Icons.block_rounded,
      'reduced_output' => Icons.water_drop_outlined,
      'edema' => Icons.accessibility_new_rounded,
      'breathing' => Icons.air_rounded,
      'hydration' => Icons.local_drink_outlined,
      'serious_illness' => Icons.emergency_rounded,
      'severe_pain' => Icons.warning_amber_rounded,
      'interference' => Icons.science_outlined,
      'exercise' => Icons.fitness_center_rounded,
      'acute_illness' => Icons.medical_services_outlined,
      'uti_context' => Icons.medical_information_outlined,
      'repeat_test' => Icons.replay_rounded,
      'microscopy' => Icons.biotech_outlined,
      'strip_quality' => Icons.fact_check_outlined,
      'timer' => Icons.timer_outlined,
      'eligibility' => Icons.verified_user_outlined,
      _ => Icons.help_outline_rounded,
    };
  }
}
