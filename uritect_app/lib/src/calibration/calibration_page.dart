import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'camera_capture_page.dart';
import 'awb_models.dart';

enum CalibrationPhase { phase0WhiteCard, phase1Dipstick }

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  static const _lightOptions = [2700, 4000, 5500];
  static const _controlLevels = ['L1', 'L2', 'L3'];

  final _sampleIdController = TextEditingController();
  final _delayController = TextEditingController(text: '60');
  final _distanceController = TextEditingController(text: '20');

  CalibrationPhase _selectedPhase = CalibrationPhase.phase0WhiteCard;
  int _selectedLight = 4000;
  String _selectedControlLevel = 'L1';
  String _statusText = 'Set your calibration metadata, then start collecting images.';

  final _defaultRegion = const WhiteReferenceRegion(
    xNorm: 0.05,
    yNorm: 0.08,
    widthNorm: 0.10,
    heightNorm: 0.15,
  );

  @override
  void dispose() {
    _sampleIdController.dispose();
    _delayController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _generateChecklistEntry() {
    final sampleId = _sampleIdController.text.trim();
    if (sampleId.isEmpty) {
      setState(() {
        _statusText = 'Enter a sample/batch ID before generating an entry.';
      });
      return;
    }

    setState(() {
      if (_selectedPhase == CalibrationPhase.phase0WhiteCard) {
        _statusText =
            'Phase 0 checklist ready -> batch=$sampleId, light=${_selectedLight}K, target=30-50 white-card images, '
            'delay=${_delayController.text}s, distance=${_distanceController.text}cm, '
            'ref=[${_defaultRegion.xNorm}, ${_defaultRegion.yNorm}, ${_defaultRegion.widthNorm}, ${_defaultRegion.heightNorm}]';
      } else {
        _statusText =
            'Phase 1 checklist ready -> sample=$sampleId, light=${_selectedLight}K, level=$_selectedControlLevel, '
            'delay=${_delayController.text}s, distance=${_distanceController.text}cm, '
            'ref=[${_defaultRegion.xNorm}, ${_defaultRegion.yNorm}, ${_defaultRegion.widthNorm}, ${_defaultRegion.heightNorm}]';
      }
    });
  }

  String get _phaseTitle {
    if (_selectedPhase == CalibrationPhase.phase0WhiteCard) {
      return 'Phase 0: White-Card AWB Pre-Calibration';
    }
    return 'Phase 1: Dipstick AWB Calibration Dataset Capture';
  }

  String get _phaseDescription {
    if (_selectedPhase == CalibrationPhase.phase0WhiteCard) {
      return 'Collect white-reference images under 2700K / 4000K / 5500K to stabilize AWB gains '
          'before dipstick data collection.';
    }
    return 'Collect strip images under 2700K / 4000K / 5500K with strict timing and distance. '
        'This screen prepares consistent metadata before capture integration.';
  }

  bool get _isMobileCameraTarget {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _openCameraCapture() async {
    final batchId = _sampleIdController.text.trim();
    if (batchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Sample/Batch ID before opening camera capture.')),
      );
      return;
    }

    final captureDelaySec = int.tryParse(_delayController.text.trim());
    if (captureDelaySec == null || captureDelaySec < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture Delay must be a valid non-negative integer.')),
      );
      return;
    }

    final distanceCm = double.tryParse(_distanceController.text.trim());
    if (distanceCm == null || distanceCm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera Distance must be a valid positive number.')),
      );
      return;
    }

    if (!_isMobileCameraTarget) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera capture is enabled for Android/iOS. Run on a phone to access camera hardware.',
          ),
        ),
      );
      return;
    }

    final phaseLabel =
        _selectedPhase == CalibrationPhase.phase0WhiteCard ? 'Phase 0 White Card' : 'Phase 1 Dipstick';

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraCapturePage(
          referenceRegion: _defaultRegion,
          lightKelvin: _selectedLight,
          phaseLabel: phaseLabel,
          batchId: batchId,
          captureDelaySec: captureDelaySec,
          distanceCm: distanceCm,
          controlLevel:
              _selectedPhase == CalibrationPhase.phase1Dipstick ? _selectedControlLevel : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uritect Calibration Start')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _phaseTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _phaseDescription,
          ),
          const SizedBox(height: 16),
          SegmentedButton<CalibrationPhase>(
            segments: const [
              ButtonSegment(
                value: CalibrationPhase.phase0WhiteCard,
                label: Text('Phase 0 (White Card)'),
              ),
              ButtonSegment(
                value: CalibrationPhase.phase1Dipstick,
                label: Text('Phase 1 (Dipstick)'),
              ),
            ],
            selected: {_selectedPhase},
            onSelectionChanged: (value) {
              setState(() {
                _selectedPhase = value.first;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sampleIdController,
            decoration: const InputDecoration(
              labelText: 'Sample/Batch ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedLight,
            items: _lightOptions
                .map((value) => DropdownMenuItem(value: value, child: Text('$value K')))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedLight = value);
            },
            decoration: const InputDecoration(
              labelText: 'Lighting Condition',
              border: OutlineInputBorder(),
            ),
          ),
          if (_selectedPhase == CalibrationPhase.phase1Dipstick) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedControlLevel,
              items: _controlLevels
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedControlLevel = value);
              },
              decoration: const InputDecoration(
                labelText: 'Control Level',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _delayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Capture Delay (sec)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _distanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Camera Distance (cm)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _generateChecklistEntry,
            child: const Text('Generate Calibration Checklist Entry'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openCameraCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Open Camera Capture'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusText),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedPhase == CalibrationPhase.phase0WhiteCard
                  ? 'Phase 0 target: 30-50 images per lighting condition. Keep same paper/card, same angle, same distance.'
                  : 'Phase 1 target: at least 20 images per control level for each lighting condition (minimum 180 images total).',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Next code step: connect camera capture and pass image bytes into AwbCalibrator.applyReferenceWhiteBalance().',
          ),
          const SizedBox(height: 8),
          const Text('AWB service scaffold is ready in lib/src/calibration/awb_calibrator.dart.'),
        ],
      ),
    );
  }
}
