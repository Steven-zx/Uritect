import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/clinical_symptoms.dart';
import '../models/checklist_draft.dart';
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
  final ChecklistDraft _draft = ChecklistDraft();
  Map<String, bool> get selectedSymptoms => _draft.result().selectedSymptoms;
  final ScanHistoryService _historyService = const ScanHistoryService();
  final ScrollController _scrollController = ScrollController();
  int _currentStep = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _answer(String id, String value) {
    if (_isSaving) return;
    setState(() => _draft.answer(id, value));
  }

  void _advance() {
    final missing = _requiredIds().any((id) => !_draft.answers.containsKey(id));
    if (missing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Answer each question, or choose Not sure, before continuing.',
          ),
        ),
      );
      return;
    }
    if (_currentStep < 4) {
      _setStep(_currentStep + 1);
    } else {
      _continueToOverallResults();
    }
  }

  List<String> _requiredIds() => switch (_currentStep) {
    0 => ['age_band', 'uti_eligible_female'],
    1 => [
      if (_draft.female) ...[
        'uti_eligible_nonpregnant',
        'menstruation_or_vaginal_bleeding',
        'vaginal_discharge',
        'vaginal_irritation',
      ],
      'dysuria',
      'frequency',
      'urgency',
      'suprapubic',
      if (_draft.answers['uti_eligible_age_18_64'] == 'yes') ...[
        'uti_eligible_no_catheter',
        'uti_eligible_no_urologic_abnormality',
        'uti_eligible_not_immunocompromised',
        if (_draft.male) ...[
          'uti_male_no_diabetes',
          'uti_male_no_suspected_sti',
        ],
      ],
    ],
    2 => [
      'safety_review',
      if (_draft.answers['safety_review'] != 'no') ...checklistSafetyIds,
      if (_draft.answers['edema'] == 'yes') 'persistent_edema',
    ],
    3 => ['renal_history'],
    _ => ['quality_review'],
  };

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

    final checklistResult = _draft.result();
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
        SnackBar(
          content: Text('Results are available but were not saved: $error'),
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OverallResultsPage(
            scanResult: widget.scanResult,
            clinicalChecklistResult: checklistResult,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
                  'Step ${_currentStep + 1} of 5',
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

  Widget _buildStepSelector(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        LinearProgressIndicator(value: (_currentStep + 1) / 5),
        const SizedBox(height: 8),
        Text(
          const [
            'Basic information',
            'Your pathway',
            'Safety',
            'Follow-up context',
            'Test quality',
          ][_currentStep],
        ),
      ],
    ),
  );

  bool _padNeedsContext(String code) {
    if (!widget.scanResult.isReliableForInterpretation) return true;
    final rows = widget.scanResult.rows.where((r) => r.code == code);
    if (rows.isEmpty) return true;
    return ![
      'neg',
      'negative',
    ].contains(rows.first.result.trim().toLowerCase());
  }

  Widget _question(String id, {String? label, bool inverted = false}) {
    final text =
        label ??
        clinicalSymptoms
            .firstWhere((s) => s.id == id)
            .label
            .replaceAll('\n', ' ');
    String? value = _draft.answers[id];
    if (inverted && value != null && value != 'unsure') {
      value = value == 'yes' ? 'no' : 'yes';
    }
    return Padding(
      key: ValueKey('question_$id'),
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final answer in ['yes', 'no', 'unsure'])
                    ChoiceChip(
                      key: ValueKey('$id:$answer'),
                      label: Text(
                        answer == 'yes'
                            ? 'Yes'
                            : answer == 'no'
                            ? 'No'
                            : 'Not sure',
                      ),
                      selected: value == answer,
                      onSelected: _isSaving
                          ? null
                          : (_) => _answer(
                              id,
                              inverted && answer != 'unsure'
                                  ? answer == 'yes'
                                        ? 'no'
                                        : 'yes'
                                  : answer,
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    final proteinContext = _padNeedsContext('PRO');
    final bloodContext =
        _padNeedsContext('BLD') || selectedSymptoms['hematuria'] == true;
    final history = _draft.answers['renal_history'];
    final renalContext =
        proteinContext ||
        bloodContext ||
        history == 'yes' ||
        history == 'unsure' ||
        selectedSymptoms['edema'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentStep == 0) ...[
          _buildIntro(
            context,
            icon: Icons.person_outline,
            title: 'Basic information',
            message:
                'Age and sex determine the research pathway. Safety guidance remains available outside the intended population.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: const Key('age_band'),
            initialValue: _draft.answers['age_band'],
            decoration: const InputDecoration(
              labelText: 'Age range',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'under18', child: Text('Under 18')),
              DropdownMenuItem(value: '18_64', child: Text('18–64')),
              DropdownMenuItem(value: '65plus', child: Text('65 or older')),
              DropdownMenuItem(value: 'unsure', child: Text('Not sure')),
            ],
            onChanged: _isSaving
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _draft.answers['age_band'] = v;
                      _draft.answer(
                        'uti_eligible_age_18_64',
                        v == '18_64'
                            ? 'yes'
                            : v == 'unsure'
                            ? 'unsure'
                            : 'no',
                      );
                    });
                  },
          ),
          const SizedBox(height: 18),
          const Text('Sex'),
          Wrap(
            spacing: 8,
            children: [
              for (final sex in ['female', 'male'])
                ChoiceChip(
                  key: ValueKey('sex_$sex'),
                  label: Text(sex == 'female' ? 'Female' : 'Male'),
                  selected: sex == 'female' ? _draft.female : _draft.male,
                  onSelected: _isSaving
                      ? null
                      : (_) => setState(() => _draft.sex(sex)),
                ),
            ],
          ),
          if (_draft.answers.containsKey('age_band') &&
              _draft.answers['uti_eligible_age_18_64'] != 'yes')
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'A numerical UTI research estimate is unavailable for this age range. Continue for safety and follow-up guidance.',
              ),
            ),
        ],
        if (_currentStep == 1) ...[
          _buildIntro(
            context,
            icon: Icons.fact_check_outlined,
            title: _draft.female ? 'Female pathway' : 'Male pathway',
            message: 'Answer what is known. Not sure is kept separate from No.',
          ),
          if (_draft.female) ...[
            _question(
              'uti_eligible_nonpregnant',
              label: 'Are you currently pregnant?',
              inverted: true,
            ),
            _question(
              'menstruation_or_vaginal_bleeding',
              label: 'Are you menstruating or experiencing vaginal bleeding?',
            ),
          ],
          _question('dysuria', label: 'Pain or burning when urinating?'),
          _question(
            'frequency',
            label: 'Urinating more frequently than usual?',
          ),
          _question('urgency', label: 'An urgent need to urinate?'),
          _question(
            'suprapubic',
            label: 'Pain or discomfort in your lower abdomen?',
          ),
          if (_draft.female) ...[
            _question('vaginal_discharge'),
            _question('vaginal_irritation'),
          ],
          if (_draft.answers['uti_eligible_age_18_64'] == 'yes') ...[
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'Your health background',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _question(
              'uti_eligible_no_catheter',
              label: 'Do you have a urinary catheter?',
              inverted: true,
            ),
            _question(
              'uti_eligible_no_urologic_abnormality',
              label: 'Any known urinary tract abnormality?',
              inverted: true,
            ),
            _question(
              'uti_eligible_not_immunocompromised',
              label: 'Do you have a weakened immune system?',
              inverted: true,
            ),
            if (_draft.male) ...[
              _question(
                'uti_male_no_diabetes',
                label: 'Do you have diabetes?',
                inverted: true,
              ),
              _question(
                'uti_male_no_suspected_sti',
                label: 'Any suspected sexually transmitted infection?',
                inverted: true,
              ),
            ],
          ],
        ],
        if (_currentStep == 2) ...[
          _buildIntro(
            context,
            icon: Icons.health_and_safety_outlined,
            title: 'Safety screening',
            message:
                'Fever/chills, back or flank pain, nausea/vomiting, visible blood or clots, difficulty or reduced urination, swelling, breathing trouble, confusion/fainting/severe weakness, severe pain, or inability to keep fluids down.',
          ),
          _question(
            'safety_review',
            label: 'Are any of these symptoms or problems present?',
          ),
          if (_draft.answers['safety_review'] != null &&
              _draft.answers['safety_review'] != 'no') ...[
            for (final id in checklistSafetyIds) _question(id),
            if (_draft.answers['edema'] == 'yes' ||
                _draft.answers['edema'] == 'unsure')
              _question('persistent_edema'),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Safety advice is evaluated independently, even when the scan fails.',
            ),
          ),
        ],
        if (_currentStep == 3) ...[
          _buildIntro(
            context,
            icon: Icons.biotech_outlined,
            title: 'Follow-up context',
            message:
                'Additional questions appear for protein/blood findings, related symptoms, or a previous abnormal result.',
          ),
          _question(
            'renal_history',
            label:
                'Any previous abnormal protein or blood result, or a repeat test being followed up?',
          ),
          if (renalContext) ...[
            for (final item in clinicalSymptoms.where(
              (s) =>
                  s.category == 'interference' &&
                  s.id != 'menstruation_or_vaginal_bleeding',
            ))
              _question(item.id),
            if (proteinContext || history == 'yes' || history == 'unsure') ...[
              _question('repeat_protein_present'),
              _question('repeat_abnormal_resolved'),
            ],
            if (bloodContext || history == 'yes' || history == 'unsure') ...[
              _question('repeat_blood_present'),
              _question('blood_microscopy_confirmed'),
            ],
          ] else if (history == 'no')
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'No additional protein/blood context questions are needed for the reported findings.',
              ),
            ),
        ],
        if (_currentStep == 4) ...[
          _buildIntro(
            context,
            icon: Icons.science_outlined,
            title: 'Test quality',
            message:
                'Confirm expiry, pad condition, supported URS-10T profile, and the specified reading time. The app cannot verify these automatically.',
          ),
          _question(
            'quality_review',
            label:
                'Was there any strip, timing, collection, or procedure problem?',
          ),
          if (_draft.answers['quality_review'] != null &&
              _draft.answers['quality_review'] != 'no') ...[
            for (final item in clinicalSymptoms.where(
              (s) => s.category == 'test_quality',
            ))
              _question(item.id),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'A test problem may prevent reliable readings. Review the procedure before repeating the scan.',
              ),
            ),
          ],
        ],
      ],
    );
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
                    fontWeight: FontWeight.w600,
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

  Widget _buildNavigation(BuildContext context) {
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
                    : _currentStep < 4
                    ? _advance
                    : _advance,
                icon: Icon(
                  _currentStep < 4
                      ? Icons.arrow_forward_rounded
                      : Icons.calculate_rounded,
                  size: 20,
                ),
                label: Text(
                  _isSaving
                      ? 'SAVING...'
                      : _currentStep < 4
                      ? 'NEXT'
                      : 'VIEW RESULTS',
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
}
