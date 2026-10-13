import 'dart:io';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';
import '../models/scan_analysis_exit_reason.dart';
import '../services/scan_provenance_service.dart';
import '../services/scan_history_service.dart';
import '../models/scan_provenance.dart';
import '../widgets/scan_provenance_dialog.dart';
import '../widgets/scan_camera_preview.dart';
import 'analyzing_page.dart';

class CaptureDipstickPage extends StatefulWidget {
  const CaptureDipstickPage({super.key});

  @override
  State<CaptureDipstickPage> createState() => _CaptureDipstickPageState();
}

class _CaptureDipstickPageState extends State<CaptureDipstickPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  late Future<void> _initializeCameraFuture;
  bool _isCameraReady = false;
  bool _isFlashlightOn = false;
  bool _showPadGuide = false;
  bool _isCapturing = false;
  bool _isPicking = false;
  bool _isSubmitting = false;
  bool _appActive = true;
  int _cameraEpoch = 0;
  String? _pendingImagePath;
  String _pendingSource = 'unknown';
  DateTime? _pendingAcquiredAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _initializeCameraFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!mounted || !_appActive) return;
    final epoch = ++_cameraEpoch;
    try {
      final cameras = await availableCameras();
      if (!mounted || !_appActive || epoch != _cameraEpoch) return;
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available on this device')),
          );
        }
        return;
      }

      final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        firstCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      _cameraController = controller;
      await controller.initialize();
      if (!mounted || !_appActive || epoch != _cameraEpoch) {
        await controller.dispose();
        return;
      }
      await _setAutomaticMetering(const Offset(0.5, 0.5));
      if (mounted && _appActive && epoch == _cameraEpoch) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  bool get _busy => _isCapturing || _isPicking || _isSubmitting;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    ++_cameraEpoch;
    if (!active) {
      setState(() {
        _isCameraReady = false;
        _isFlashlightOn = false;
      });
    }
    // Serialize release/reinitialization so gallery and lock-screen transitions
    // cannot leave a stale controller or open two cameras at once.
    _initializeCameraFuture = _initializeCameraFuture.then((_) async {
      final controller = _cameraController;
      _cameraController = null;
      await controller?.dispose();
      if (mounted && _appActive) await _initializeCamera();
    });
    setState(() {});
  }

  Future<void> _capturePhoto() async {
    if (_busy || !_appActive) return;
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return;
      }
      setState(() => _isCapturing = true);
      final image = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _pendingImagePath = image.path;
          _pendingSource = 'camera';
          _pendingAcquiredAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _setAutomaticMetering(Offset point) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    // Some devices support only a subset of these controls. Keep each optional
    // so unsupported metering never disables capture or the other controls.
    for (final configure in <Future<void> Function()>[
      () => controller.setFocusMode(FocusMode.auto),
      () => controller.setExposureMode(ExposureMode.auto),
      () => controller.setFocusPoint(point),
      () => controller.setExposurePoint(point),
    ]) {
      try {
        await configure();
      } on CameraException {
        // Retain the device's default for this unsupported setting.
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() {
          _pendingImagePath = pickedFile.path;
          _pendingSource = 'import';
          _pendingAcquiredAt = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _clearPendingImage() {
    if (_isSubmitting || _isCapturing || _isPicking) return;
    final previous = _pendingImagePath;
    if (previous != null) {
      unawaited(const ScanHistoryService().discardTemporaryImage(previous));
    }
    setState(() {
      _pendingImagePath = null;
      _pendingSource = 'unknown';
      _pendingAcquiredAt = null;
    });
  }

  Future<void> _submitSelectedImage() async {
    final imagePath = _pendingImagePath;
    if (_busy || imagePath == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    ScanAnalysisExitReason? exitReason;
    try {
      final identity = await const ScanProvenanceService().inspect(imagePath);
      ImageMatch? match;
      bool duplicateCheckCompleted = true;
      try {
        match = await const ScanHistoryService().findDuplicate(
          promptForAuthentication: false,
          contentSha256: identity.contentHash,
          pixelSha256: identity.pixelHash,
          fingerprint: identity.fingerprint,
        );
      } catch (_) {
        duplicateCheckCompleted = false;
      }
      if (!mounted) return;
      final provenance = await showDialog<ScanProvenance>(
        context: context,
        builder: (_) => ScanProvenanceDialog(
          identity: identity,
          source: _pendingSource,
          acquiredAt: _pendingAcquiredAt,
          duplicateOf: match?.exact == true ? match?.recordId : null,
          similarImageOf: match?.exact == false ? match?.recordId : null,
          duplicateCheckCompleted: duplicateCheckCompleted,
        ),
      );
      if (!mounted || provenance == null) return;
      exitReason = await Navigator.of(context).push<ScanAnalysisExitReason>(
        MaterialPageRoute(
          builder: (_) =>
              AnalyzingPage(imagePath: imagePath, provenance: provenance),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('The image could not be prepared: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;
    if (exitReason == ScanAnalysisExitReason.noDipstickFound) {
      await _showNoDipstickDialog();
    } else if (exitReason == ScanAnalysisExitReason.scanAgain) {
      _clearPendingImage();
    }
  }

  Future<void> _showNoDipstickDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.bgCard,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.statusModerate,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No dipstick found',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure the full dipstick strip is visible, flat, and well lit before submitting.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearPendingImage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'SCAN AGAIN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
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

  Future<void> _toggleFlashlight() async {
    if (_busy || !_appActive) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final epoch = _cameraEpoch;
    final turnOn = !_isFlashlightOn;
    try {
      await controller.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      if (mounted && _appActive && epoch == _cameraEpoch) {
        setState(() => _isFlashlightOn = turnOn);
      }
    } catch (e) {
      if (mounted && _appActive && epoch == _cameraEpoch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling flashlight: $e')),
        );
      }
    }
  }

  Widget _buildCameraFrame() {
    // CameraPreview handles the active capture orientation and aspect ratio.
    // Show the full view: a cover fit hides background that analysis still sees.
    return ScanCameraPreview(
      controller: _cameraController!,
      onFocus: _setAutomaticMetering,
      showAlignmentGuide: _showPadGuide,
    );
  }

  @override
  void dispose() {
    final previous = _pendingImagePath;
    if (previous != null) {
      unawaited(const ScanHistoryService().discardTemporaryImage(previous));
    }
    WidgetsBinding.instance.removeObserver(this);
    ++_cameraEpoch;
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 64,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 24),
                        color: AppColors.primaryMain,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Capture Dipstick',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.primaryMain,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Show the full strip. Tap the pads to focus.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: IconButton(
                      tooltip: _showPadGuide
                          ? 'Hide 10-pad guide'
                          : 'Show 10-pad guide',
                      isSelected: _showPadGuide,
                      color: AppColors.primaryMain,
                      icon: const Icon(Icons.grid_on_rounded),
                      selectedIcon: const Icon(Icons.grid_off_rounded),
                      onPressed:
                          _busy || !_isCameraReady || _pendingImagePath != null
                          ? null
                          : () =>
                                setState(() => _showPadGuide = !_showPadGuide),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<void>(
                future: _initializeCameraFuture,
                builder: (context, snapshot) {
                  if (_pendingImagePath != null) {
                    return _ScanPreviewFrame(
                      onClose: _busy ? null : _clearPendingImage,
                      child: Image.file(
                        File(_pendingImagePath!),
                        fit: BoxFit.contain,
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.done) {
                    if (_isCameraReady && _cameraController != null) {
                      return _ScanPreviewFrame(child: _buildCameraFrame());
                    } else {
                      return _ScanPreviewFrame(
                        child: Center(
                          child: Text(
                            'Camera not available',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                  }
                  return const _ScanPreviewFrame(
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_pendingImagePath != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submitSelectedImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'SUBMIT',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CaptureToolButton(
                    icon: Icons.photo_outlined,
                    onTap: _busy ? null : _pickFromGallery,
                  ),
                  _CaptureButton(
                    key: const Key('capture_shutter'),
                    onTap: _busy
                        ? null
                        : _pendingImagePath == null
                        ? _capturePhoto
                        : _clearPendingImage,
                  ),
                  _CaptureToolButton(
                    icon: _isFlashlightOn
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    onTap: _busy ? null : _toggleFlashlight,
                    isActive: _isFlashlightOn,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanPreviewFrame extends StatelessWidget {
  static const double _frameAspectRatio = 0.82;
  static const double _cornerRadius = 28;

  final Widget child;
  final VoidCallback? onClose;

  const _ScanPreviewFrame({required this.child, this.onClose});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 16;
        final idealHeight = availableWidth / _frameAspectRatio;
        final frameHeight = idealHeight <= constraints.maxHeight
            ? idealHeight
            : constraints.maxHeight;
        final frameWidth = frameHeight == idealHeight
            ? availableWidth
            : frameHeight * _frameAspectRatio;

        return Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(_cornerRadius),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_cornerRadius),
                        border: Border.all(
                          color: const Color(0xFF0B88FF),
                          width: 2,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                ),
                if (onClose != null)
                  Positioned(
                    top: -14,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _CaptureButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryMain,
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryMain.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  const _CaptureToolButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: isActive
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryMain.withValues(alpha: 0.15),
              )
            : null,
        child: Icon(
          icon,
          color: isActive ? AppColors.primaryMain : AppColors.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
