import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';
import 'analyzing_page.dart';

class CaptureDipstickPage extends StatefulWidget {
  const CaptureDipstickPage({super.key});

  @override
  State<CaptureDipstickPage> createState() => _CaptureDipstickPageState();
}

class _CaptureDipstickPageState extends State<CaptureDipstickPage> {
  CameraController? _cameraController;
  late Future<void> _initializeCameraFuture;
  bool _isCameraReady = false;
  bool _isFlashlightOn = false;
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    _initializeCameraFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available on this device')),
          );
        }
        return;
      }

      final firstCamera = cameras.first;
      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController?.initialize();
      if (mounted) {
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

  Future<void> _capturePhoto() async {
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return;
      }
      final image = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _pendingImagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        setState(() {
          _pendingImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImagePath = null;
    });
  }

  Future<void> _submitSelectedImage() async {
    final imagePath = _pendingImagePath;
    if (imagePath == null) {
      return;
    }

    final exitReason = await Navigator.of(context).push<ScanAnalysisExitReason>(
      MaterialPageRoute(builder: (_) => AnalyzingPage(imagePath: imagePath)),
    );
    if (!mounted) return;
    if (exitReason == ScanAnalysisExitReason.noDipstickFound) {
      await _showNoDipstickDialog();
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
                'Make sure the full dipstick and black marker are visible, flat, and well lit before submitting.',
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
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        return;
      }
      if (_isFlashlightOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _isFlashlightOn = false);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        setState(() => _isFlashlightOn = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling flashlight: $e')),
        );
      }
    }
  }

  Widget _buildCameraFrame() {
    final previewSize = _cameraController?.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(_cameraController!);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  @override
  void dispose() {
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
                  Column(
                    children: [
                      Text(
                        'Capture Dipstick',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primaryMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Place the dipstick within the frame',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 64),
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
                      onClose: _clearPendingImage,
                      child: Image.file(
                        File(_pendingImagePath!),
                        fit: BoxFit.cover,
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
                    onPressed: _submitSelectedImage,
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
                    onTap: _pickFromGallery,
                  ),
                  _CaptureButton(
                    onTap: _pendingImagePath == null
                        ? _capturePhoto
                        : _clearPendingImage,
                  ),
                  _CaptureToolButton(
                    icon: _isFlashlightOn
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    onTap: _toggleFlashlight,
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
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
  final VoidCallback onTap;

  const _CaptureButton({required this.onTap});

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
  final VoidCallback onTap;
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
