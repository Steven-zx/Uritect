import 'dart:convert';
import 'dart:io';
import 'dart:math' show min, max;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' as image_picker;

import 'analyte_result.dart';
import 'analyte_value_basis.dart';
import 'color_processor_service.dart';
import 'knn_reference_map.dart';

// ---------------------------------------------------------------------------
// Default normalized (0–1) marker positions for a vertical strip.
// Pads sit at x ≈ 0.5, spaced every ~9 % from the top.
List<Offset> _defaultMarkers() => List.generate(
      10,
      (i) => Offset(0.5, 0.05 + i * 0.09),
    );

// ---------------------------------------------------------------------------
// ScanPage widget
// ---------------------------------------------------------------------------

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // -- image --
  File? _imageFile;
  int _imageWidth = 1;
  int _imageHeight = 1;

  // -- markers (normalized 0-1 image coordinates) --
  late List<Offset> _markers = _defaultMarkers();
  Offset? _awbMarker; // null → no AWB correction
  int? _activeDrag; // 0-9 = pad, 10 = AWB reference

  // -- modes --
  bool _awbTapMode = false;
  bool _isAnalyzing = false;

  // -- results --
  List<AnalyteResult>? _results;
  List<AnalyteValueResolution>? _resolved;
  String _statusText = '';

  // -- model --
  KnnReferenceMap? _knnMap;
  String _modelLabel = '';

  // -- picker --
  final _imagePicker = image_picker.ImagePicker();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadKnnMap();
  }

  Future<void> _loadKnnMap() async {
    try {
      final raw = await rootBundle.loadString('assets/knn_reference_map.json');
      final jsonData = json.decode(raw) as Map<String, dynamic>;
      final map = KnnReferenceMap.fromJson(jsonData);
      final version = jsonData['version'] as String? ?? '?';
      final source = jsonData['source'] as String? ?? '?';
      final totalSamples = (jsonData['total_samples'] as num?)?.toInt() ?? 0;
      setState(() {
        _knnMap = map;
        _modelLabel = totalSamples == 0
            ? 'Baseline reference ($version)'
            : 'Trained reference ($version, $totalSamples samples)';
      });
    } catch (_) {
      setState(() {
        _knnMap = const KnnReferenceMap(map: {});
        _modelLabel = 'No reference map loaded';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Image picking
  // ---------------------------------------------------------------------------

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> _pickImage() async {
    String? path;

    if (_isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
      );
      path = result?.files.first.path;
    } else {
      final picked = await _imagePicker.pickImage(
        source: image_picker.ImageSource.camera,
      );
      path = picked?.path;
    }

    if (path == null || path.isEmpty) return;

    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      setState(() {
        _statusText = 'Could not decode image. Try a different file.';
      });
      return;
    }

    setState(() {
      _imageFile = File(path!);
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;
      _markers = _defaultMarkers();
      _awbMarker = null;
      _awbTapMode = false;
      _results = null;
      _resolved = null;
      _statusText =
          'Image loaded. Drag the numbered circles to each pad, then tap Analyze.';
    });
  }

  Future<void> _pickFromGallery() async {
    String? path;
    if (_isDesktop) {
      await _pickImage();
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: image_picker.ImageSource.gallery,
    );
    path = picked?.path;
    if (path == null || path.isEmpty) return;

    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    setState(() {
      _imageFile = File(path!);
      _imageWidth = decoded.width;
      _imageHeight = decoded.height;
      _markers = _defaultMarkers();
      _awbMarker = null;
      _results = null;
      _resolved = null;
      _statusText = 'Image loaded. Position the markers on each pad, then Analyze.';
    });
  }

  // ---------------------------------------------------------------------------
  // AWB gain computation
  // ---------------------------------------------------------------------------

  (double, double, double) _computeAwbGains(
    img.Image decoded,
    Offset normRef,
  ) {
    final cx =
        (normRef.dx * decoded.width).round().clamp(0, decoded.width - 1);
    final cy =
        (normRef.dy * decoded.height).round().clamp(0, decoded.height - 1);
    const half = 20;
    double sumR = 0, sumG = 0, sumB = 0;
    int count = 0;
    for (var y = cy - half; y <= cy + half; y++) {
      for (var x = cx - half; x <= cx + half; x++) {
        if (x >= 0 && x < decoded.width && y >= 0 && y < decoded.height) {
          final pixel = decoded.getPixel(x, y);
          sumR += pixel.r.toDouble();
          sumG += pixel.g.toDouble();
          sumB += pixel.b.toDouble();
          count++;
        }
      }
    }
    if (count == 0) return (1.0, 1.0, 1.0);
    final meanR = sumR / count;
    final meanG = sumG / count;
    final meanB = sumB / count;
    final maxMean = max(meanR, max(meanG, meanB));
    if (maxMean < 10) return (1.0, 1.0, 1.0);
    return (maxMean / meanR, maxMean / meanG, maxMean / meanB);
  }

  // ---------------------------------------------------------------------------
  // Analysis
  // ---------------------------------------------------------------------------

  Future<void> _analyze() async {
    if (_imageFile == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Analyzing…';
      _results = null;
      _resolved = null;
    });

    try {
      final bytes = await _imageFile!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw StateError('Cannot decode image.');

      var gainR = 1.0, gainG = 1.0, gainB = 1.0;
      if (_awbMarker != null) {
        (gainR, gainG, gainB) = _computeAwbGains(decoded, _awbMarker!);
      }

      const service = ColorProcessorService();
      final results = await service.extractPadColors(
        _imageFile!,
        _markers.map((p) => ui.Offset(p.dx, p.dy)).toList(),
        awbGainR: gainR,
        awbGainG: gainG,
        awbGainB: gainB,
        knnReferenceMap: _knnMap,
      );

      final resolved = results
          .map(
            (r) => resolveAnalyteValue(
              analyteName: r.analyteName,
              nearestMatch: r.nearestMatch,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _results = results;
        _resolved = resolved;
        _statusText = 'Analysis complete.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Analysis failed: $error';
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Coordinate helpers (normalized ↔ widget)
  // ---------------------------------------------------------------------------

  ({Offset origin, double scale, Size displayed}) _imageBounds(
    Size widgetSize,
  ) {
    final scaleX = widgetSize.width / _imageWidth;
    final scaleY = widgetSize.height / _imageHeight;
    final scale = min(scaleX, scaleY);
    final dw = _imageWidth * scale;
    final dh = _imageHeight * scale;
    final ox = (widgetSize.width - dw) / 2;
    final oy = (widgetSize.height - dh) / 2;
    return (origin: Offset(ox, oy), scale: scale, displayed: Size(dw, dh));
  }

  Offset _toWidget(Offset norm, Size widgetSize) {
    final b = _imageBounds(widgetSize);
    return Offset(
      b.origin.dx + norm.dx * b.displayed.width,
      b.origin.dy + norm.dy * b.displayed.height,
    );
  }

  Offset? _toNorm(Offset widget, Size widgetSize) {
    final b = _imageBounds(widgetSize);
    final x = (widget.dx - b.origin.dx) / b.displayed.width;
    final y = (widget.dy - b.origin.dy) / b.displayed.height;
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Dipstick'),
        actions: [
          if (_imageFile != null)
            IconButton(
              tooltip: 'Reset markers',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {
                _markers = _defaultMarkers();
                _awbMarker = null;
                _awbTapMode = false;
                _results = null;
                _resolved = null;
                _statusText = 'Markers reset to default positions.';
              }),
            ),
        ],
      ),
      body: _imageFile == null ? _buildEmptyState() : _buildScanBody(),
    );
  }

  // -- Empty state -----------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 24),
            const Text(
              'Load a dipstick photo to analyze\nall 10 urinalysis parameters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _modelLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickImage,
              icon: Icon(_isDesktop ? Icons.folder_open : Icons.camera_alt),
              label: Text(_isDesktop ? 'Pick Image' : 'Take Photo'),
            ),
            if (!_isDesktop) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Gallery'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -- Scan body -------------------------------------------------------------

  Widget _buildScanBody() {
    return Column(
      children: [
        // Image + marker overlay
        Expanded(
          flex: 5,
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildImageArea(constraints.biggest),
          ),
        ),
        // Controls
        _buildControls(),
        // Results
        if (_results != null)
          Expanded(
            flex: 4,
            child: _buildResultsList(),
          ),
      ],
    );
  }

  // -- Image area with draggable markers -------------------------------------

  Widget _buildImageArea(Size size) {
    return GestureDetector(
      onPanStart: (d) {
        if (_awbTapMode) return;
        final allPositions = [
          ..._markers,
          if (_awbMarker != null) _awbMarker!,
        ];
        for (var i = 0; i < allPositions.length; i++) {
          final wp = _toWidget(allPositions[i], size);
          if ((wp - d.localPosition).distance < 28) {
            setState(() => _activeDrag = i);
            return;
          }
        }
      },
      onPanUpdate: (d) {
        if (_awbTapMode || _activeDrag == null) return;
        final norm = _toNorm(d.localPosition, size);
        if (norm == null) return;
        setState(() {
          if (_activeDrag! < 10) {
            _markers[_activeDrag!] = norm;
          } else {
            _awbMarker = norm;
          }
        });
      },
      onPanEnd: (_) => setState(() => _activeDrag = null),
      onTapDown: _awbTapMode
          ? (d) {
              final norm = _toNorm(d.localPosition, size);
              if (norm != null) {
                setState(() {
                  _awbMarker = norm;
                  _awbTapMode = false;
                  _statusText =
                      'White reference set. Tap Analyze when ready.';
                });
              }
            }
          : null,
      child: Stack(
        children: [
          // Image
          Image.file(
            _imageFile!,
            fit: BoxFit.contain,
            width: size.width,
            height: size.height,
          ),
          // Marker overlay
          CustomPaint(
            size: size,
            painter: _MarkerPainter(
              markers: _markers
                  .map((n) => _toWidget(n, size))
                  .toList(),
              awbPosition:
                  _awbMarker != null ? _toWidget(_awbMarker!, size) : null,
              activeIndex: _activeDrag,
              results: _results,
            ),
          ),
          // AWB tap mode hint
          if (_awbTapMode)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Tap the white strip plastic for white reference',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -- Controls row ----------------------------------------------------------

  Widget _buildControls() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(
                    _isDesktop ? Icons.folder_open : Icons.camera_alt,
                    size: 18,
                  ),
                  label: Text(
                    _isDesktop ? 'New Image' : 'New Photo',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _awbTapMode = !_awbTapMode;
                    if (_awbTapMode) {
                      _statusText =
                          'Tap the white strip plastic for AWB reference.';
                    }
                  }),
                  icon: Icon(
                    _awbMarker != null
                        ? Icons.wb_sunny
                        : Icons.wb_sunny_outlined,
                    size: 18,
                    color: _awbTapMode
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  label: Text(
                    _awbMarker != null ? 'AWB ✓' : 'Set AWB',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAnalyzing ? null : _analyze,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.science_outlined, size: 18),
                  label: Text(
                    _isAnalyzing ? 'Analyzing…' : 'Analyze',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (_statusText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          Text(
            _modelLabel,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // -- Results list ----------------------------------------------------------

  Widget _buildResultsList() {
    final results = _results!;
    final resolved = _resolved!;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final result = results[i];
        final value = resolved[i];

        final observedColor = Color.fromARGB(
          255,
           (result.correctedRgb.r * 255.0).round() & 0xff,
           (result.correctedRgb.g * 255.0).round() & 0xff,
           (result.correctedRgb.b * 255.0).round() & 0xff,
        );

        final levelText = value.isMapped
            ? value.matchedLevel
            : result.nearestMatch.contains(':')
                ? result.nearestMatch.split(':').last.trim()
                : result.nearestMatch;

        final displayText = value.isMapped
            ? '${value.displayValue} ${value.unit}'
            : '—';

        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          leading: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: observedColor,
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Text(
            result.analyteName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(displayText, style: const TextStyle(fontSize: 11)),
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _levelColor(levelText)
                  .withAlpha(40),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _levelColor(levelText).withAlpha(120),
              ),
            ),
            child: Text(
              levelText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: _levelColor(levelText),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _levelColor(String level) {
    final l = level.toLowerCase();
    if (l == 'negative' || l == 'normal') {
      return Colors.green.shade700;
    }
    if (l == 'trace') return Colors.orange.shade700;
    if (l.contains('+') ||
        l == 'positive' ||
        l == 'pending' ||
        l.startsWith('high')) {
      return Colors.red.shade700;
    }
    return Theme.of(context).colorScheme.onSurface;
  }
}

// ---------------------------------------------------------------------------
// Custom painter for markers
// ---------------------------------------------------------------------------

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({
    required this.markers,
    required this.awbPosition,
    required this.activeIndex,
    required this.results,
  });

  final List<Offset> markers;
  final Offset? awbPosition;
  final int? activeIndex;
  final List<AnalyteResult>? results;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < markers.length; i++) {
      _drawPadMarker(
        canvas,
        markers[i],
        '${i + 1}',
        active: activeIndex == i,
        result: results != null && results!.length > i
            ? results![i]
            : null,
      );
    }
    if (awbPosition != null) {
      _drawAwbMarker(canvas, awbPosition!, active: activeIndex == 10);
    }
  }

  void _drawPadMarker(
    Canvas canvas,
    Offset pos,
    String label, {
    required bool active,
    AnalyteResult? result,
  }) {
    const radius = 14.0;

    // Outer ring
    canvas.drawCircle(
      pos,
      radius + 1,
      Paint()
        ..color = Colors.black.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Fill: show measured color when available, else cyan
    Color fill;
    if (result != null) {
      fill = Color.fromARGB(
        190,
          (result.correctedRgb.r * 255.0).round() & 0xff,
          (result.correctedRgb.g * 255.0).round() & 0xff,
          (result.correctedRgb.b * 255.0).round() & 0xff,
      );
    } else {
      fill = active
          ? Colors.yellow.withAlpha(200)
          : Colors.cyan.withAlpha(180);
    }

    canvas.drawCircle(pos, radius, Paint()..color = fill);

    // Label
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color:
              ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawAwbMarker(Canvas canvas, Offset pos, {required bool active}) {
    const r = 12.0;
    final path = Path()
      ..moveTo(pos.dx, pos.dy - r)
      ..lineTo(pos.dx + r, pos.dy)
      ..lineTo(pos.dx, pos.dy + r)
      ..lineTo(pos.dx - r, pos.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = (active ? Colors.yellow : Colors.white).withAlpha(200),
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'W',
        style: TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => true;
}
