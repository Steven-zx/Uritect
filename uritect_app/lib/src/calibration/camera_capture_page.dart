import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../analysis/color_processor_service.dart';
import '../analysis/debug_dashboard_page.dart';
import '../analysis/knn_reference_map.dart';
import 'awb_calibrator.dart';
import 'awb_models.dart';
import 'strip_framing_overlay.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({
    super.key,
    required this.referenceRegion,
    required this.lightKelvin,
    required this.phaseLabel,
    required this.batchId,
    required this.captureDelaySec,
    required this.distanceCm,
    this.controlLevel,
  });

  final WhiteReferenceRegion referenceRegion;
  final int lightKelvin;
  final String phaseLabel;
  final String batchId;
  final int captureDelaySec;
  final double distanceCm;
  final String? controlLevel;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  final AwbCalibrator _calibrator = const AwbCalibrator();
  final ColorProcessorService _colorProcessorService = const ColorProcessorService();
  final TextEditingController _sampleLabelController = TextEditingController();
  final List<ResolutionPreset> _fallbackPresets = const [
    ResolutionPreset.veryHigh,
    ResolutionPreset.high,
    ResolutionPreset.medium,
    ResolutionPreset.low,
  ];

  CameraController? _controller;
  bool _isInitializing = true;
  bool _isReinitializing = false;
  bool _isCapturing = false;
  bool _isExporting = false;
  bool _isDatasetMode = false;
  bool _isDebugMode = false;
  bool _isProcessingDebugFrame = false;
  String _status = 'Initializing camera...';
  int _savedCount = 0;
  int _sessionCounter = 0;
  int _datasetCaptureProgress = 0;
  int _datasetCaptureTotal = 0;
  int _activePresetIndex = -1;
  String _activeCameraLabel = 'Unknown';
  String _lastInitTrace = '';
  List<Offset> _normalizedRoiCenters = const [];
  List<_PadDebugSample> _debugSamples = const [];

  @override
  void initState() {
    super.initState();
    _sampleLabelController.text = widget.batchId;
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopDebugStream();
    _sampleLabelController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    await _initializeWithFallback(startIndex: 0, showAsInitial: true);
  }

  Future<void> _initializeWithFallback({required int startIndex, required bool showAsInitial}) async {
    if (!mounted) return;

    setState(() {
      if (showAsInitial) {
        _isInitializing = true;
      } else {
        _isReinitializing = true;
      }
      _status = 'Initializing camera compatibility mode...';
    });

    final failureTraces = <String>[];

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _isReinitializing = false;
          _status = 'No camera detected on this device.';
          _lastInitTrace = 'No camera returned by availableCameras().';
        });
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _activeCameraLabel = backCamera.name;

      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      for (var index = startIndex; index < _fallbackPresets.length; index++) {
        CameraController? candidate;
        final preset = _fallbackPresets[index];
        try {
          candidate = CameraController(
            backCamera,
            preset,
            enableAudio: false,
            imageFormatGroup:
                Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
          );

          await candidate.initialize();

          try {
            await candidate.setFocusMode(FocusMode.auto);
          } catch (_) {}
          try {
            await candidate.setExposureMode(ExposureMode.auto);
          } catch (_) {}
          try {
            await candidate.setFlashMode(FlashMode.off);
          } catch (_) {}

          if (!mounted) {
            await candidate.dispose();
            return;
          }

          setState(() {
            _controller = candidate;
            _activePresetIndex = index;
            _isInitializing = false;
            _isReinitializing = false;
            _status = 'Camera ready at ${preset.name}. Capture under ${widget.lightKelvin}K.';
            _lastInitTrace = failureTraces.join(' | ');
          });

          if (_isDebugMode) {
            await _startDebugStream();
          }
          return;
        } catch (error) {
          failureTraces.add('${preset.name}: $error');
          if (candidate != null) {
            await candidate.dispose();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isReinitializing = false;
        _status = 'Camera init failed for all compatibility presets.';
        _lastInitTrace = failureTraces.join(' | ');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isReinitializing = false;
        _status = 'Camera init failed: $error';
        _lastInitTrace = '$error';
      });
    }
  }

  Future<bool> _recoverWithLowerPreset() async {
    if (_activePresetIndex < 0 || _activePresetIndex >= _fallbackPresets.length - 1) {
      return false;
    }

    final nextIndex = _activePresetIndex + 1;
    await _initializeWithFallback(startIndex: nextIndex, showAsInitial: false);

    final controller = _controller;
    return controller != null && controller.value.isInitialized;
  }

  Future<void> _setDebugMode(bool enabled) async {
    if (_isDebugMode == enabled) {
      return;
    }

    if (enabled) {
      setState(() {
        _isDebugMode = true;
        _status = 'Debug mode enabled. Sampling RGB/HSV from ROI boxes...';
      });
      await _startDebugStream();
      return;
    }

    await _stopDebugStream();
    if (!mounted) return;
    setState(() {
      _isDebugMode = false;
      _debugSamples = const [];
      _status = 'Debug mode disabled.';
    });
  }

  Future<void> _startDebugStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.startImageStream((image) {
        if (!_isDebugMode || _isProcessingDebugFrame || !mounted) {
          return;
        }
        _isProcessingDebugFrame = true;
        _processDebugFrame(image).whenComplete(() {
          _isProcessingDebugFrame = false;
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Debug stream unavailable on this device configuration.';
      });
    }
  }

  Future<void> _stopDebugStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (!controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  Future<void> _processDebugFrame(CameraImage image) async {
    final centers = _normalizedRoiCenters;
    if (centers.isEmpty) {
      return;
    }

    final samples = <_PadDebugSample>[];

    for (var index = 0; index < math.min(10, centers.length); index++) {
      final center = centers[index];
      final x = (center.dx * image.width).round().clamp(0, image.width - 1);
      final y = (center.dy * image.height).round().clamp(0, image.height - 1);

      final sampledColor = _sampleColorAt(image, x, y);
      final hsv = HSVColor.fromColor(sampledColor);

      samples.add(
        _PadDebugSample(
          index: index + 1,
          color: sampledColor,
          hsv: hsv,
          normalizedCenter: center,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _debugSamples = samples;
    });
  }

  Color _sampleColorAt(CameraImage image, int x, int y) {
    if (image.format.group == ImageFormatGroup.bgra8888 && image.planes.isNotEmpty) {
      final plane = image.planes.first;
      final bytes = plane.bytes;
      final bytesPerPixel = plane.bytesPerPixel ?? 4;
      final index = (y * plane.bytesPerRow) + (x * bytesPerPixel);
      if (index + 3 < bytes.length) {
        final b = bytes[index];
        final g = bytes[index + 1];
        final r = bytes[index + 2];
        return Color.fromARGB(255, r, g, b);
      }
    }

    if (image.planes.length >= 3) {
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yIndex = (y * yPlane.bytesPerRow) + x;
      final uvRow = y ~/ 2;
      final uvCol = x ~/ 2;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;
      final uvIndex = (uvRow * uPlane.bytesPerRow) + (uvCol * uvPixelStride);

      if (yIndex < yPlane.bytes.length && uvIndex < uPlane.bytes.length && uvIndex < vPlane.bytes.length) {
        final yValue = yPlane.bytes[yIndex].toDouble();
        final uValue = uPlane.bytes[uvIndex].toDouble();
        final vValue = vPlane.bytes[uvIndex].toDouble();

        final r = (yValue + (1.402 * (vValue - 128))).round().clamp(0, 255);
        final g = (yValue - (0.344136 * (uValue - 128)) - (0.714136 * (vValue - 128))).round().clamp(0, 255);
        final b = (yValue + (1.772 * (uValue - 128))).round().clamp(0, 255);

        return Color.fromARGB(255, r, g, b);
      }
    }

    return const Color(0xFF000000);
  }

  Future<void> _onCapturePressed() async {
    if (_isDatasetMode) {
      await _captureDatasetBurst();
      return;
    }

    await _captureSingleFrame();
  }

  Future<void> _captureSingleFrame() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _status = 'Camera is not initialized.');
      return;
    }

    if (_isCapturing) {
      return;
    }

    final sessionNumber = _nextSessionNumber();
    final sampleLabel = _effectiveSampleLabel;
    final sessionId = _buildSessionId(sessionNumber: sessionNumber, sampleLabel: sampleLabel);

    setState(() {
      _isCapturing = true;
      _datasetCaptureProgress = 0;
      _datasetCaptureTotal = 1;
      _status = 'Capturing 1/1... Keep phone stable.';
    });

    try {
      await _stopDebugStream();
      final captureResult = await _captureReplicate(
        sessionNumber: sessionNumber,
        sessionId: sessionId,
        sampleLabel: sampleLabel,
        replicateId: 1,
        totalReplicates: 1,
        allowRecovery: true,
      );

      if (!mounted) return;
      if (!captureResult.success) {
        setState(() {
          _status = 'Capture failed and stopped. ${captureResult.message}';
        });
      } else {
        setState(() {
          _datasetCaptureProgress = 1;
          _status =
              'Capture complete. AWB gains -> R:${captureResult.result!.gainR.toStringAsFixed(3)} '
              'G:${captureResult.result!.gainG.toStringAsFixed(3)} '
              'B:${captureResult.result!.gainB.toStringAsFixed(3)}\n'
              'Saved: ${captureResult.persistResult!.rawImagePath}\n'
              'Session ID: $sessionId | Sample Label: $sampleLabel | Replicate: 1/1\n'
              'Session saved count: $_savedCount';
        });

              await _openDebugDashboard(captureResult);
      }

      if (_isDebugMode) {
        await _startDebugStream();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _captureDatasetBurst() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _status = 'Camera is not initialized.');
      return;
    }

    if (_isCapturing) {
      return;
    }

    const totalReplicates = 10;
    const interCaptureDelay = Duration(milliseconds: 150);
    final sessionNumber = _nextSessionNumber();
    final sampleLabel = _effectiveSampleLabel;
    final sessionId = _buildSessionId(sessionNumber: sessionNumber, sampleLabel: sampleLabel);

    setState(() {
      _isCapturing = true;
      _datasetCaptureProgress = 0;
      _datasetCaptureTotal = totalReplicates;
      _status = 'Dataset mode enabled. Capturing 1/$totalReplicates... Do not move the phone.';
    });

    var successCount = 0;

    try {
      await _stopDebugStream();
      for (var replicateId = 1; replicateId <= totalReplicates; replicateId++) {
        if (!mounted) return;

        setState(() {
          _datasetCaptureProgress = replicateId - 1;
          _status =
              'Capturing $replicateId/$totalReplicates... Do not move the phone. '
              'Session ID: $sessionId';
        });

        final captureResult = await _captureReplicate(
          sessionNumber: sessionNumber,
          sessionId: sessionId,
          sampleLabel: sampleLabel,
          replicateId: replicateId,
          totalReplicates: totalReplicates,
          allowRecovery: true,
        );

        if (!captureResult.success) {
          if (!mounted) return;
          setState(() {
            _datasetCaptureProgress = successCount;
            _status =
                'Dataset capture stopped at frame $replicateId/$totalReplicates. '
                '${captureResult.message}';
          });
          return;
        }

        successCount += 1;
        if (!mounted) return;
        setState(() {
          _datasetCaptureProgress = successCount;
          _status =
              'Captured $successCount/$totalReplicates. '
              'Session ID: $sessionId | Sample Label: $sampleLabel';
        });

        if (replicateId < totalReplicates) {
          await Future<void>.delayed(interCaptureDelay);
        }
      }

      if (!mounted) return;
      setState(() {
        _status =
            'Dataset capture complete: $successCount/$totalReplicates frames saved. '
            'Session ID: $sessionId | Sample Label: $sampleLabel';
      });

      if (_isDebugMode) {
        await _startDebugStream();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<_CaptureReplicateResult> _captureReplicate({
    required int sessionNumber,
    required String sessionId,
    required String sampleLabel,
    required int replicateId,
    required int totalReplicates,
    required bool allowRecovery,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _CaptureReplicateResult(
        success: false,
        message: 'Camera is not initialized.',
      );
    }

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      final result = _calibrator.applyReferenceWhiteBalance(
        Uint8List.fromList(bytes),
        widget.referenceRegion,
      );

      final saveResult = await _persistCapture(
        rawBytes: Uint8List.fromList(bytes),
        awbBytes: result.correctedBytes,
        result: result,
        sessionNumber: sessionNumber,
        sessionId: sessionId,
        sampleLabel: sampleLabel,
        replicateId: replicateId,
      );

      return _CaptureReplicateResult(
        success: true,
        message: 'Captured replicate $replicateId/$totalReplicates',
        result: result,
        persistResult: saveResult,
      );
    } catch (error) {
      if (allowRecovery) {
        final recovered = await _recoverWithLowerPreset();
        if (recovered) {
          if (!mounted) {
            return const _CaptureReplicateResult(
              success: false,
              message: 'Widget unmounted during recovery.',
            );
          }

          setState(() {
            _status =
                'Capture recovered by compatibility fallback to ${_fallbackPresets[_activePresetIndex].name}. '
                'Retrying replicate $replicateId/$totalReplicates...';
          });

          return _captureReplicate(
            sessionNumber: sessionNumber,
            sessionId: sessionId,
            sampleLabel: sampleLabel,
            replicateId: replicateId,
            totalReplicates: totalReplicates,
            allowRecovery: false,
          );
        }
      }

      return _CaptureReplicateResult(
        success: false,
        message: 'Capture failed at replicate $replicateId: $error',
      );
    }
  }

  Future<_PersistResult> _persistCapture({
    required Uint8List rawBytes,
    required Uint8List awbBytes,
    required AwbResult result,
    required int sessionNumber,
    required String sessionId,
    required String sampleLabel,
    required int replicateId,
  }) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final calibrationDir = Directory('${baseDir.path}/uritect_calibration');
    if (!await calibrationDir.exists()) {
      await calibrationDir.create(recursive: true);
    }

    final phaseDirName = _phaseDirectoryName;
    final phaseDir = Directory('${calibrationDir.path}/$phaseDirName');
    if (!await phaseDir.exists()) {
      await phaseDir.create(recursive: true);
    }

    final now = DateTime.now();
    final timestampIso = now.toIso8601String();
    final sessionStem = 'IMG_${sessionNumber.toString().padLeft(3, '0')}';
    final rawFileName = '${sessionStem}_$replicateId.jpg';
    final awbFileName = '${sessionStem}_${replicateId}_AWB.jpg';

    final rawImagePath = '${phaseDir.path}/$rawFileName';
    final awbImagePath = '${phaseDir.path}/$awbFileName';

    await File(rawImagePath).writeAsBytes(rawBytes, flush: true);
    await File(awbImagePath).writeAsBytes(awbBytes, flush: true);

    final logPath = '${calibrationDir.path}/calibration_capture_log.csv';
    final logFile = File(logPath);
    if (!await logFile.exists()) {
      await logFile.writeAsString(
        'timestamp_iso8601,session_id,sample_label,replicate_id,phase,light_kelvin,batch_id,control_level,capture_delay_sec,distance_cm,'
        'raw_image_path,awb_image_path,awb_gain_r,awb_gain_g,awb_gain_b,ref_mean_r,ref_mean_g,ref_mean_b\n',
      );
    }

    final csvRow = [
      timestampIso,
      sessionId,
      sampleLabel,
      replicateId.toString(),
      widget.phaseLabel,
      widget.lightKelvin.toString(),
      widget.batchId,
      widget.controlLevel ?? '',
      widget.captureDelaySec.toString(),
      widget.distanceCm.toStringAsFixed(2),
      rawImagePath,
      awbImagePath,
      result.gainR.toStringAsFixed(6),
      result.gainG.toStringAsFixed(6),
      result.gainB.toStringAsFixed(6),
      result.referenceMeanR.toStringAsFixed(6),
      result.referenceMeanG.toStringAsFixed(6),
      result.referenceMeanB.toStringAsFixed(6),
    ].map(_csvEscape).join(',');

    await logFile.writeAsString('$csvRow\n', mode: FileMode.append, flush: true);

    _savedCount += 1;
    return _PersistResult(
      rawImagePath: rawImagePath,
      awbImagePath: awbImagePath,
      logPath: logPath,
    );
  }

  String get _phaseDirectoryName => widget.phaseLabel.toLowerCase().replaceAll(' ', '_');

  String get _effectiveSampleLabel {
    final value = _sampleLabelController.text.trim();
    if (value.isEmpty) {
      return widget.batchId;
    }
    return value;
  }

  int _nextSessionNumber() {
    _sessionCounter += 1;
    return _sessionCounter;
  }

  String _buildSessionId({required int sessionNumber, required String sampleLabel}) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final sanitizedLabel = sampleLabel.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${sanitizedLabel}_S${sessionNumber.toString().padLeft(3, '0')}_$timestamp';
  }

  Future<void> _openDebugDashboard(_CaptureReplicateResult captureResult) async {
    final persisted = captureResult.persistResult;
    final awb = captureResult.result;
    if (persisted == null || awb == null) {
      return;
    }

    if (_normalizedRoiCenters.length != 10) {
      if (!mounted) return;
      setState(() {
        _status =
            'Debug dashboard skipped: ROI centers are not ready yet. Align strip first so all 10 ROI targets are available.';
      });
      return;
    }

    try {
      final results = await _colorProcessorService.extractPadColors(
        File(persisted.rawImagePath),
        _normalizedRoiCenters,
        awbGainR: awb.gainR,
        awbGainG: awb.gainG,
        awbGainB: awb.gainB,
        knnReferenceMap: _buildPlaceholderKnnMap(),
      );

      if (!mounted) return;
      final accepted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => DebugDashboardPage(
            results: results,
            onDiscard: () {
              if (!mounted) return;
              setState(() {
                _status = 'Verification discarded. You can recapture with better alignment.';
              });
            },
            onConfirmAndSave: (verifiedResults) async {
              if (!mounted) return;
              setState(() {
                _status =
                    'Verification confirmed (${verifiedResults.length}/10 analytes). Capture log already saved to CSV.';
              });
            },
          ),
        ),
      );

      if (!mounted) return;
      if (accepted == true) {
        setState(() {
          _status = 'Verification accepted. Proceed to next capture or analysis step.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Failed to build debug dashboard data: $error';
      });
    }
  }

  KnnReferenceMap _buildPlaceholderKnnMap() {
    Map<String, List<ParameterThreshold>> forAnalyte(String name) {
      return {
        name: const [
          ParameterThreshold(
            level: 'Negative',
            referenceColor: Color(0xFFE7E2B7),
            weight: 1.0,
          ),
          ParameterThreshold(
            level: 'Trace',
            referenceColor: Color(0xFFC9CE8B),
            weight: 1.1,
          ),
          ParameterThreshold(
            level: '1+',
            referenceColor: Color(0xFFA3B965),
            weight: 1.2,
          ),
        ],
      };
    }

    final map = <String, List<ParameterThreshold>>{};
    for (final analyte in ColorProcessorService.defaultAnalyteOrder) {
      map.addAll(forAnalyte(analyte));
    }
    return KnnReferenceMap(map: map);
  }

  Future<void> _exportSession() async {
    if (_isCapturing || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
      _status = 'Preparing export package...';
    });

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final calibrationDir = Directory('${baseDir.path}/uritect_calibration');
      final phaseDir = Directory('${calibrationDir.path}/$_phaseDirectoryName');
      final logFile = File('${calibrationDir.path}/calibration_capture_log.csv');

      if (!await calibrationDir.exists()) {
        throw StateError('No calibration data found yet. Capture at least one image first.');
      }

      final exportDir = Directory('${calibrationDir.path}/exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final now = DateTime.now();
      final stamp = now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final exportBaseName = 'session_${_phaseDirectoryName}_${widget.batchId}_$stamp';
      final filteredCsv = File('${exportDir.path}/$exportBaseName.csv');
      final zipFile = File('${exportDir.path}/$exportBaseName.zip');

      final lines = await _buildFilteredCsvLines(logFile);
      await filteredCsv.writeAsString('${lines.join('\n')}\n', flush: true);

      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addFile(filteredCsv, '$exportBaseName.csv');

      if (await phaseDir.exists()) {
        final imageFiles = phaseDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.jpg'))
            .toList();

        for (final imageFile in imageFiles) {
          encoder.addFile(imageFile, 'images/${imageFile.uri.pathSegments.last}');
        }
      }

      encoder.close();

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(filteredCsv.path),
            XFile(zipFile.path),
          ],
          text: 'Uritect calibration export for batch ${widget.batchId} (${widget.phaseLabel})',
          subject: 'Uritect Calibration Export',
        ),
      );

      if (!mounted) return;
      setState(() {
        _status = 'Export ready and shared. CSV: ${filteredCsv.path}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<List<String>> _buildFilteredCsvLines(File logFile) async {
    const header =
        'timestamp_iso8601,session_id,sample_label,replicate_id,phase,light_kelvin,batch_id,control_level,capture_delay_sec,distance_cm,'
        'raw_image_path,awb_image_path,awb_gain_r,awb_gain_g,awb_gain_b,ref_mean_r,ref_mean_g,ref_mean_b';

    if (!await logFile.exists()) {
      return [header];
    }

    final allLines = await logFile.readAsLines();
    final filtered = <String>[header];

    for (final line in allLines.skip(1)) {
      if (line.contains('"${widget.phaseLabel}"') && line.contains('"${widget.batchId}"')) {
        filtered.add(line);
      }
    }

    return filtered;
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String get _activePresetLabel {
    if (_activePresetIndex < 0 || _activePresetIndex >= _fallbackPresets.length) {
      return 'unknown';
    }
    return _fallbackPresets[_activePresetIndex].name;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Capture (${widget.phaseLabel})'),
        actions: [
          IconButton(
            onPressed:
              _isInitializing || _isReinitializing || _isCapturing || _isExporting
                ? null
                : _exportSession,
            tooltip: 'Export session CSV + ZIP',
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : controller == null || !controller.value.isInitialized
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_status),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(controller),
                          IgnorePointer(
                            child: StripFramingOverlay(
                              roiCount: 10,
                              onGeometryChanged: (geometry) {
                                _normalizedRoiCenters = geometry.normalizedRoiCenters();
                              },
                            ),
                          ),
                          if (_isDebugMode)
                            IgnorePointer(
                              child: _DebugOverlay(
                                samples: _debugSamples,
                              ),
                            ),
                        ],
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Light: ${widget.lightKelvin}K | Region: default AWB reference'),
                const SizedBox(height: 8),
                Text('Batch: ${widget.batchId} | Delay: ${widget.captureDelaySec}s | Distance: ${widget.distanceCm}cm'),
                if (widget.controlLevel != null && widget.controlLevel!.isNotEmpty)
                  Text('Control level: ${widget.controlLevel}'),
                const SizedBox(height: 8),
                TextField(
                  controller: _sampleLabelController,
                  enabled: !_isCapturing,
                  decoration: const InputDecoration(
                    labelText: 'Sample Label',
                    hintText: 'e.g., Control_Negative',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dataset Mode (10-frame burst)'),
                  subtitle: const Text('When enabled, captures 10 consecutive frames with replicate logging.'),
                  value: _isDatasetMode,
                  onChanged: (_isCapturing || _isInitializing || _isReinitializing || _isExporting)
                      ? null
                      : (value) {
                          setState(() {
                            _isDatasetMode = value;
                          });
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Debug Mode (ROI RGB/HSV)'),
                  subtitle: const Text('Shows real-time RGB/HSV values for the 10 ROI pads.'),
                  value: _isDebugMode,
                  onChanged: (_isCapturing || _isInitializing || _isReinitializing || _isExporting)
                      ? null
                      : _setDebugMode,
                ),
                if (_isDatasetMode && (_isCapturing || _datasetCaptureTotal > 0))
                  Text('Progress: $_datasetCaptureProgress/$_datasetCaptureTotal'),
                const SizedBox(height: 8),
                Text('Camera: $_activeCameraLabel | Preset: $_activePresetLabel'),
                if (_lastInitTrace.isNotEmpty)
                  Text(
                    'Init trace: $_lastInitTrace',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Text(_status),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _isInitializing || _isReinitializing || _isCapturing || _isExporting
                          ? null
                          : _onCapturePressed,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _isCapturing
                        ? (_isDatasetMode
                            ? 'Capturing $_datasetCaptureProgress/$_datasetCaptureTotal...'
                            : 'Capturing...')
                        : (_isDatasetMode ? 'Capture Dataset (10 Frames)' : 'Capture + Run AWB'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _isInitializing || _isReinitializing || _isCapturing || _isExporting
                          ? null
                          : () => _initializeWithFallback(startIndex: 0, showAsInitial: false),
                  icon: _isReinitializing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt),
                  label: const Text('Reinitialize Camera (Compatibility)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _isInitializing || _isReinitializing || _isCapturing || _isExporting
                          ? null
                          : _exportSession,
                  icon: const Icon(Icons.folder_zip),
                  label: const Text('Export Session (CSV + ZIP)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugOverlay extends StatelessWidget {
  const _DebugOverlay({
    required this.samples,
  });

  final List<_PadDebugSample> samples;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: samples.map((sample) {
            final x = sample.normalizedCenter.dx * constraints.maxWidth;
            final y = sample.normalizedCenter.dy * constraints.maxHeight;

            final label =
                'P${sample.index} '
                'RGB(${sample.color.r},${sample.color.g},${sample.color.b}) '
                'HSV(${sample.hsv.hue.toStringAsFixed(1)},'
                '${sample.hsv.saturation.toStringAsFixed(2)},'
                '${sample.hsv.value.toStringAsFixed(2)})';

            return Positioned(
              left: x - 70,
              top: y - 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white54),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _PersistResult {
  const _PersistResult({
    required this.rawImagePath,
    required this.awbImagePath,
    required this.logPath,
  });

  final String rawImagePath;
  final String awbImagePath;
  final String logPath;
}

class _CaptureReplicateResult {
  const _CaptureReplicateResult({
    required this.success,
    required this.message,
    this.result,
    this.persistResult,
  });

  final bool success;
  final String message;
  final AwbResult? result;
  final _PersistResult? persistResult;
}

class _PadDebugSample {
  const _PadDebugSample({
    required this.index,
    required this.color,
    required this.hsv,
    required this.normalizedCenter,
  });

  final int index;
  final Color color;
  final HSVColor hsv;
  final Offset normalizedCenter;
}
