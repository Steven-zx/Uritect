import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'awb_calibrator.dart';
import 'awb_models.dart';

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
  String _status = 'Initializing camera...';
  int _savedCount = 0;
  int _activePresetIndex = -1;
  String _activeCameraLabel = 'Unknown';
  String _lastInitTrace = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
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
            imageFormatGroup: ImageFormatGroup.jpeg,
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

  Future<void> _captureAndCalibrate({bool allowRecovery = true}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      setState(() => _status = 'Camera is not initialized.');
      return;
    }

    if (_isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _status = 'Capturing image...';
    });

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
      );

      if (!mounted) return;
      setState(() {
        _status =
            'Capture complete. AWB gains -> R:${result.gainR.toStringAsFixed(3)} '
            'G:${result.gainG.toStringAsFixed(3)} B:${result.gainB.toStringAsFixed(3)}\n'
            'Saved: ${saveResult.rawImagePath}\n'
            'Session saved count: $_savedCount';
      });
    } catch (error) {
      if (allowRecovery) {
        final recovered = await _recoverWithLowerPreset();
        if (recovered) {
          if (!mounted) return;
          setState(() {
            _status =
                'Capture recovered by compatibility fallback to ${_fallbackPresets[_activePresetIndex].name}. Retrying...';
          });
          await _captureAndCalibrate(allowRecovery: false);
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _status = 'Capture failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<_PersistResult> _persistCapture({
    required Uint8List rawBytes,
    required Uint8List awbBytes,
    required AwbResult result,
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
    final timestampSafe = timestampIso.replaceAll(':', '-').replaceAll('.', '-');
    final baseName = '${widget.batchId}_${widget.lightKelvin}K_$timestampSafe';

    final rawImagePath = '${phaseDir.path}/${baseName}_raw.jpg';
    final awbImagePath = '${phaseDir.path}/${baseName}_awb.jpg';

    await File(rawImagePath).writeAsBytes(rawBytes, flush: true);
    await File(awbImagePath).writeAsBytes(awbBytes, flush: true);

    final logPath = '${calibrationDir.path}/calibration_capture_log.csv';
    final logFile = File(logPath);
    if (!await logFile.exists()) {
      await logFile.writeAsString(
        'timestamp_iso8601,phase,light_kelvin,batch_id,control_level,capture_delay_sec,distance_cm,'
        'raw_image_path,awb_image_path,awb_gain_r,awb_gain_g,awb_gain_b,ref_mean_r,ref_mean_g,ref_mean_b\n',
      );
    }

    final csvRow = [
      timestampIso,
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
            .where(
              (file) =>
                  file.path.toLowerCase().endsWith('.jpg') &&
                  file.uri.pathSegments.last.startsWith('${widget.batchId}_'),
            )
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
        'timestamp_iso8601,phase,light_kelvin,batch_id,control_level,capture_delay_sec,distance_cm,'
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
                            child: CustomPaint(
                              painter: _FrameGuidePainter(),
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
                          : _captureAndCalibrate,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_isCapturing ? 'Capturing...' : 'Capture + Run AWB'),
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

class _FrameGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final guideWidth = size.width * 0.72;
    final guideHeight = size.height * 0.56;
    final guideRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: guideWidth,
      height: guideHeight,
    );

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(12)),
      clearPaint,
    );
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(12)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final cornerLength = 24.0;

    void drawCorner(Offset start, Offset horizontalEnd, Offset verticalEnd) {
      canvas.drawLine(start, horizontalEnd, cornerPaint);
      canvas.drawLine(start, verticalEnd, cornerPaint);
    }

    drawCorner(
      guideRect.topLeft,
      guideRect.topLeft + Offset(cornerLength, 0),
      guideRect.topLeft + Offset(0, cornerLength),
    );
    drawCorner(
      guideRect.topRight,
      guideRect.topRight + Offset(-cornerLength, 0),
      guideRect.topRight + Offset(0, cornerLength),
    );
    drawCorner(
      guideRect.bottomLeft,
      guideRect.bottomLeft + Offset(cornerLength, 0),
      guideRect.bottomLeft + Offset(0, -cornerLength),
    );
    drawCorner(
      guideRect.bottomRight,
      guideRect.bottomRight + Offset(-cornerLength, 0),
      guideRect.bottomRight + Offset(0, -cornerLength),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
