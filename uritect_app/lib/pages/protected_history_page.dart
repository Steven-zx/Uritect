import 'dart:async';
import 'package:flutter/material.dart';
import '../models/saved_scan_record.dart';
import '../services/scan_history_service.dart';
import '../services/history_cipher.dart';
import 'overall_results_page.dart';
import 'renal_results_page.dart';

class ProtectedHistoryPage extends StatefulWidget {
  final String recordId;
  final bool renalOnly;
  final bool editNameInitially;
  final ScanHistoryService historyService;
  const ProtectedHistoryPage({
    super.key,
    required this.recordId,
    this.renalOnly = false,
    this.editNameInitially = false,
    this.historyService = const ScanHistoryService(),
  });
  @override
  State<ProtectedHistoryPage> createState() => _ProtectedHistoryPageState();
}

class _ProtectedHistoryPageState extends State<ProtectedHistoryPage>
    with WidgetsBindingObserver {
  ScanHistoryService get service => widget.historyService;
  SavedScanRecord? record;
  Timer? timer;
  String? error;
  bool loading = false;
  bool editingName = false;
  bool savingName = false;
  final nameController = TextEditingController();
  final nameForm = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlock();
  }

  Future<void> _unlock() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await HistoryPrivacy.acquire(this);
      final records = await service.loadRecords();
      await service.authenticate();
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
      final matches = records.where((r) => r.id == widget.recordId);
      setState(() {
        record = matches.isEmpty ? null : matches.first;
        if (record != null && widget.editNameInitially) {
          nameController.text = record!.patientName ?? '';
          editingName = true;
        }
      });
      if (matches.isEmpty) error = 'This record is no longer available.';
      timer?.cancel();
      final remaining = service.cipher.remainingSession - Duration(seconds: 2);
      timer = Timer(remaining.isNegative ? Duration.zero : remaining, _hide);
    } catch (e) {
      await HistoryPrivacy.release(this);
      if (mounted) setState(() => error = historyAccessMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _hide() {
    timer?.cancel();
    nameController.clear();
    if (mounted) {
      setState(() {
        record = null;
        editingName = false;
      });
    }
    unawaited(HistoryPrivacy.release(this));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _hide();
    } else if (record == null) {
      unawaited(HistoryPrivacy.release(this));
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    nameController.dispose();
    unawaited(HistoryPrivacy.release(this));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (record != null && editingName) {
      return Scaffold(
        appBar: AppBar(title: const Text('Patient name')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: nameForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('patient_name_input'),
                    controller: nameController,
                    enabled: !savingName,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Patient name (optional)',
                      helperText:
                          'Stored in encrypted history. Leave blank to remove the name.',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      try {
                        SavedScanRecord.normalizePatientName(value);
                        return null;
                      } on ArgumentError catch (e) {
                        return e.message.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: savingName ? null : _savePatientName,
                    child: Text(savingName ? 'Saving…' : 'Save name'),
                  ),
                  TextButton(
                    onPressed: savingName
                        ? null
                        : () {
                            nameController.clear();
                            setState(() => editingName = false);
                          },
                    child: const Text('Cancel'),
                  ),
                  if (error != null) Text(error!, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (record != null && widget.renalOnly) {
      return RenalResultsPage(
        scanResult: record!.scanResult,
        checklistResult: record!.checklistResult,
      );
    }
    if (record != null) {
      return OverallResultsPage(
        scanResult: record!.scanResult,
        clinicalChecklistResult: record!.checklistResult,
        savedUtiEstimate: record!.recordedUtiEstimate,
        historyService: service,
        patientName: record!.patientName,
        onEditPatientName: () {
          nameController.text = record!.patientName ?? '';
          setState(() {
            editingName = true;
            error = null;
          });
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Saved history')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 36),
              const SizedBox(height: 12),
              Text(error ?? 'History is locked.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (loading)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: _unlock,
                  child: const Text('Unlock history'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePatientName() async {
    if (savingName || record == null || !nameForm.currentState!.validate()) {
      return;
    }
    final id = record!.id;
    final name = nameController.text;
    setState(() => savingName = true);
    try {
      final updated = await service.updatePatientName(id, name);
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      if (record != null) {
        nameController.clear();
        setState(() {
          record = updated;
          editingName = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = historyAccessMessage(e));
    } finally {
      if (mounted) setState(() => savingName = false);
    }
  }
}
