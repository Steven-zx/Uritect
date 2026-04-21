import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  static const List<int> _lightOptions = [2700, 4000, 5500];
  static const List<String> _splitOptions = ['train', 'val', 'test'];
  static const List<String> _collectionModeOptions = ['individual', 'burst'];
  static const List<String> _analyteOptions = [
    'Leukocytes',
    'Nitrite',
    'Urobilinogen',
    'Protein',
    'pH',
    'Blood',
    'Specific Gravity',
    'Ketone',
    'Bilirubin',
    'Glucose',
  ];
  static const Map<String, List<String>> _levelOptions = {
    'Leukocytes': ['Neg', 'Trace 15', 'Small 70', 'Moderate 125', 'Large 500'],
    'Nitrite': ['Neg', 'Positive'],
    'Urobilinogen': ['3.2', '16', '32', '64', '128'],
    'Protein': ['Neg', 'Trace', '0.3', '1.0', '3.0', '>=20.0'],
    'pH': ['5.0', '6.0', '6.5', '7.0', '7.5', '8.0', '8.5'],
    'Blood': [
      'Neg',
      'Non-hemolyzed 10',
      'Hemolyzed 10',
      'Small 25',
      'Moderate 80',
      'Large 200',
    ],
    'Specific Gravity': ['1.000', '1.005', '1.010', '1.015', '1.020', '1.025', '1.030'],
    'Ketone': ['Neg', 'Trace 0.5', 'Small 1.5', 'Moderate 4.0', '8.0', 'Large 16'],
    'Bilirubin': ['Neg', 'Small 17', 'Moderate 50', 'Large 100'],
    'Glucose': ['Neg', 'Trace 5', '15 +', '30 ++', '60 +++', '110 ++++'],
  };

  final TextEditingController _batchIdController = TextEditingController();
  final TextEditingController _participantIdController = TextEditingController();
  final TextEditingController _sampleIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final image_picker.ImagePicker _imagePicker = image_picker.ImagePicker();

  List<XFile> _selectedImages = const [];
  String _selectedCollectionMode = 'individual';
  String _selectedAnalyte = 'Leukocytes';
  String _selectedLevel = 'Neg';
  int _selectedLightKelvin = 4000;
  String _selectedSplit = 'train';
  String _statusText =
      'Select a batch, pick a semiquant analyte/level, then build a training-ready package.';
  String _latestZipPath = '';
  String _latestPackageFolderPath = '';
  String _latestEventId = '';
  final List<String> _createdZipPaths = <String>[];
  bool _isProcessing = false;
  bool _isUploading = false;
  String _uploadStatusText = '';

  final TextEditingController _endpointController = TextEditingController();

  bool get _isDesktopTarget {
    if (kIsWeb) {
      return false;
    }

    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  void dispose() {
    _batchIdController.dispose();
    _participantIdController.dispose();
    _sampleIdController.dispose();
    _notesController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _pickBatchImages() async {
    if (_isProcessing) {
      return;
    }

    try {
      final selected = await _selectImages();
      if (!mounted) {
        return;
      }

      if (selected.isEmpty) {
        setState(() {
          _statusText = 'No images selected.';
        });
        return;
      }

      setState(() {
        _selectedImages = selected;
        _statusText =
            'Selected ${selected.length} image(s). Add labels/metadata, then build package.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Image selection failed: $error';
      });
    }
  }

  Future<List<XFile>> _selectImages() async {
    if (_isDesktopTarget) {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
      );

      if (picked == null || picked.files.isEmpty) {
        return const <XFile>[];
      }

      return picked.files
          .map((item) => item.path)
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .map((item) => XFile(item))
          .toList(growable: false);
    }

    final selected = await _imagePicker.pickMultiImage();
    return selected.map((item) => XFile(item.path)).toList(growable: false);
  }

  Future<void> _buildTrainingPackage() async {
    if (_isProcessing) {
      return;
    }

    final batchId = _batchIdController.text.trim().isEmpty
        ? 'batch_unset'
        : _batchIdController.text.trim();
    final participantId = _participantIdController.text.trim();
    final sampleId = _sampleIdController.text.trim();
    final notes = _notesController.text.trim();
    final label = _buildSemiquantLabel();

    if (_selectedImages.isEmpty) {
      setState(() {
        _statusText = 'Please pick at least one image before building package.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = _selectedCollectionMode == 'individual'
          ? 'Building one package per photo for ${_selectedImages.length} image(s). Please wait...'
          : 'Building a burst package for ${_selectedImages.length} image(s). Please wait...';
    });

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final datasetRoot = Directory('${baseDir.path}/uritect_training_dataset');
      final eventsRoot = Directory('${datasetRoot.path}/events');
      final packagesRoot = Directory('${datasetRoot.path}/packages');
      final manifestsRoot = Directory('${datasetRoot.path}/manifests');

      if (!await datasetRoot.exists()) {
        await datasetRoot.create(recursive: true);
      }
      if (!await eventsRoot.exists()) {
        await eventsRoot.create(recursive: true);
      }
      if (!await packagesRoot.exists()) {
        await packagesRoot.create(recursive: true);
      }
      if (!await manifestsRoot.exists()) {
        await manifestsRoot.create(recursive: true);
      }

      final buildResults = <_BuildResult>[];
      if (_selectedCollectionMode == 'individual') {
        for (var index = 0; index < _selectedImages.length; index++) {
          final result = await _buildPackageForImages(
            images: [_selectedImages[index]],
            batchId: batchId,
            participantId: participantId,
            sampleId: sampleId.isEmpty ? 'sample_${index + 1}' : sampleId,
            label: label,
            split: _selectedSplit,
            lightKelvin: _selectedLightKelvin,
            notes: notes,
            eventsRoot: eventsRoot,
            packagesRoot: packagesRoot,
            manifestsRoot: manifestsRoot,
            packageSuffix: index + 1,
          );
          buildResults.add(result);
        }
      } else {
        final result = await _buildPackageForImages(
          images: _selectedImages,
          batchId: batchId,
          participantId: participantId,
          sampleId: sampleId,
          label: label,
          split: _selectedSplit,
          lightKelvin: _selectedLightKelvin,
          notes: notes,
          eventsRoot: eventsRoot,
          packagesRoot: packagesRoot,
          manifestsRoot: manifestsRoot,
        );
        buildResults.add(result);
      }

      if (buildResults.isEmpty) {
        throw StateError('No readable image files were found from your selection.');
      }

      if (!mounted) {
        return;
      }

      final latestResult = buildResults.last;
      setState(() {
        _createdZipPaths
          ..clear()
          ..addAll(buildResults.map((item) => item.zipFile.path));
        _latestZipPath = latestResult.zipFile.path;
        _latestPackageFolderPath = packagesRoot.path;
        _latestEventId = latestResult.eventId;
        _uploadStatusText = '';
        _statusText =
            'Package ready: ${buildResults.length} package(s), ${buildResults.fold<int>(0, (sum, item) => sum + item.imageCount)} image(s). '
            'Latest ZIP: ${latestResult.zipFile.path}';
      });

      if (!_isDesktopTarget && buildResults.length == 1) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(latestResult.zipFile.path)],
            text: 'Uritect semiquant dataset package ${latestResult.eventId}',
            subject: 'Uritect Semiquant Package',
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Failed to build package: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _buildEventId({
    required String batchId,
    required String label,
    required String timestamp,
    int packageSuffix = 0,
  }) {
    final cleanBatchId = _sanitizeToken(batchId);
    final cleanLabel = _sanitizeToken(label);
    final cleanTimestamp = timestamp.replaceAll(':', '-').replaceAll('.', '-');
    final suffix = packageSuffix <= 0 ? '' : '_${packageSuffix.toString().padLeft(3, '0')}';
    return '${cleanBatchId}_${cleanLabel}_$cleanTimestamp$suffix';
  }

  String _buildSemiquantLabel() {
    return '$_selectedAnalyte:$_selectedLevel';
  }

  List<String> _levelsForSelectedAnalyte() {
    return _levelOptions[_selectedAnalyte] ?? const ['Neg'];
  }

  void _syncLevelSelection() {
    final levels = _levelsForSelectedAnalyte();
    if (!levels.contains(_selectedLevel)) {
      _selectedLevel = levels.first;
    }
  }

  Future<_BuildResult> _buildPackageForImages({
    required List<XFile> images,
    required String batchId,
    required String participantId,
    required String sampleId,
    required String label,
    required String split,
    required int lightKelvin,
    required String notes,
    required Directory eventsRoot,
    required Directory packagesRoot,
    required Directory manifestsRoot,
    int packageSuffix = 0,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final eventId = _buildEventId(
      batchId: batchId,
      label: label,
      timestamp: timestamp,
      packageSuffix: packageSuffix,
    );

    final eventDir = Directory('${eventsRoot.path}/$eventId');
    final imagesDir = Directory('${eventDir.path}/images');
    await imagesDir.create(recursive: true);

    final perBatchManifest = File('${eventDir.path}/batch_manifest.csv');
    final perBatchIndex = File('${eventDir.path}/training_index.csv');
    final globalManifest = File('${manifestsRoot.path}/training_manifest.csv');

    if (!await globalManifest.exists()) {
      await globalManifest.writeAsString(
        'timestamp_iso8601,event_id,batch_id,participant_id,sample_id,label,collection_mode,split,photo_index,file_name,relative_image_path,source_image_path,light_kelvin,notes\n',
        flush: true,
      );
    }

    final batchManifestRows = <String>[
      'timestamp_iso8601,event_id,batch_id,participant_id,sample_id,label,collection_mode,split,photo_index,file_name,relative_image_path,source_image_path,light_kelvin,notes',
    ];
    final trainingIndexRows = <String>[
      'relative_image_path,label,split,event_id,batch_id,participant_id,sample_id,collection_mode,light_kelvin',
    ];
    final globalRows = <String>[];
    final copiedFiles = <File>[];
    var skippedFiles = 0;

    for (var index = 0; index < images.length; index++) {
      final picked = images[index];
      final source = File(picked.path);
      if (!await source.exists()) {
        skippedFiles += 1;
        continue;
      }

      final ext = path.extension(source.path);
      final safeExtension = ext.isEmpty ? '.jpg' : ext;
      final fileName = '${(index + 1).toString().padLeft(3, '0')}$safeExtension';
      final destination = File('${imagesDir.path}/$fileName');
      await source.copy(destination.path);
      copiedFiles.add(destination);

      final relativeImagePath = 'events/$eventId/images/$fileName';
      final row = [
        timestamp,
        eventId,
        batchId,
        participantId,
        sampleId,
        label,
        _selectedCollectionMode,
        split,
        (index + 1).toString(),
        fileName,
        relativeImagePath,
        source.path,
        lightKelvin.toString(),
        notes,
      ].map(_csvEscape).join(',');

      batchManifestRows.add(row);
      globalRows.add(row);

      final indexRow = [
        relativeImagePath,
        label,
        split,
        eventId,
        batchId,
        participantId,
        sampleId,
        _selectedCollectionMode,
        lightKelvin.toString(),
      ].map(_csvEscape).join(',');
      trainingIndexRows.add(indexRow);
    }

    if (copiedFiles.isEmpty) {
      throw StateError('No readable image files were found from your selection.');
    }

    await perBatchManifest.writeAsString('${batchManifestRows.join('\n')}\n', flush: true);
    await perBatchIndex.writeAsString('${trainingIndexRows.join('\n')}\n', flush: true);
    if (globalRows.isNotEmpty) {
      await globalManifest.writeAsString(
        '${globalRows.join('\n')}\n',
        mode: FileMode.append,
        flush: true,
      );
    }

    final zipFile = File('${packagesRoot.path}/$eventId.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);
    await encoder.addFile(perBatchManifest, 'batch_manifest.csv');
    await encoder.addFile(perBatchIndex, 'training_index.csv');

    for (final copied in copiedFiles) {
      await encoder.addFile(copied, 'images/${path.basename(copied.path)}');
    }

    await encoder.close();

    if (!await zipFile.exists()) {
      throw StateError('ZIP file was not created.');
    }

    final zipSize = await zipFile.length();
    if (zipSize <= 0) {
      throw StateError('ZIP file is empty.');
    }

    final zipBytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    if (archive.files.isEmpty) {
      throw StateError('ZIP archive has no entries.');
    }

    return _BuildResult(
      eventId: eventId,
      zipFile: zipFile,
      imageCount: copiedFiles.length,
      skippedFiles: skippedFiles,
      archiveEntries: archive.files.length,
    );
  }

  String _sanitizeToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'unset';
    }

    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Future<void> _uploadPackage() async {
    if (_isUploading || _isProcessing) {
      return;
    }

    final endpointRaw = _endpointController.text.trim();
    if (endpointRaw.isEmpty) {
      setState(() {
        _uploadStatusText = 'Please enter a pipeline endpoint URL.';
      });
      return;
    }

    final Uri uri;
    try {
      uri = Uri.parse(endpointRaw);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw const FormatException('URL must start with http:// or https://');
      }
    } catch (e) {
      setState(() {
        _uploadStatusText = 'Invalid URL: $e';
      });
      return;
    }

    if (_latestZipPath.isEmpty) {
      setState(() {
        _uploadStatusText = 'Build a training package first.';
      });
      return;
    }

    final zipFile = File(_latestZipPath);
    if (!await zipFile.exists()) {
      setState(() {
        _uploadStatusText = 'ZIP file not found. Build the package again.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Uploading package...';
    });

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['event_id'] = _latestEventId
        ..fields['batch_id'] = _batchIdController.text.trim()
        ..fields['participant_id'] = _participantIdController.text.trim()
        ..fields['sample_id'] = _sampleIdController.text.trim()
        ..fields['collection_mode'] = _selectedCollectionMode
        ..fields['analyte'] = _selectedAnalyte
        ..fields['level'] = _selectedLevel
        ..fields['label'] = _buildSemiquantLabel()
        ..fields['split'] = _selectedSplit
        ..fields['light_kelvin'] = _selectedLightKelvin.toString()
        ..files.add(
          await http.MultipartFile.fromPath(
            'package',
            zipFile.path,
            filename: path.basename(zipFile.path),
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('Upload timed out after 5 minutes.'),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _uploadStatusText =
              'Upload successful (HTTP ${response.statusCode}). '
              'Event: $_latestEventId';
        });
      } else {
        setState(() {
          _uploadStatusText =
              'Upload failed: HTTP ${response.statusCode}. '
              'Body: ${response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body}';
        });
      }
    } on TimeoutException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _uploadStatusText = 'Upload failed: $e';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _uploadStatusText = 'Upload failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _openLatestZipFolder() async {
    if (!_isDesktopTarget || _latestZipPath.isEmpty) {
      return;
    }

    final archiveFile = File(_latestZipPath);
    if (!await archiveFile.exists()) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Latest ZIP file not found. Build a package again.';
      });
      return;
    }

    try {
      if (Platform.isWindows) {
        final windowsPath = archiveFile.path.replaceAll('/', r'\');
        await Process.start(
          'explorer.exe',
          ['/select,$windowsPath'],
          runInShell: true,
        );
      } else if (Platform.isMacOS) {
        await Process.start('open', ['-R', archiveFile.path], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [archiveFile.parent.path], runInShell: true);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Opened package location: ${archiveFile.path}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Failed to open package location: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uritect Semiquant Collection'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Use this screen to package semiquant strip photos with participant/sample metadata. Individual-photo mode is the default; burst mode stays available for same-sample bursts.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCollectionMode,
            items: _collectionModeOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value == 'individual' ? 'Individual photo each' : '10-photo burst bundle'),
                  ),
                )
                .toList(growable: false),
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCollectionMode = value;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Collection Mode',
              helperText: 'Prefer individual photo each for semiquant ground truth. Use burst only when the same urine sample is captured repeatedly.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _batchIdController,
            enabled: !_isProcessing,
            decoration: const InputDecoration(
              labelText: 'Batch ID',
              hintText: 'e.g., BATCH_01',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _participantIdController,
            enabled: !_isProcessing,
            decoration: const InputDecoration(
              labelText: 'Participant ID',
              hintText: 'e.g., P001',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sampleIdController,
            enabled: !_isProcessing,
            decoration: const InputDecoration(
              labelText: 'Sample ID',
              hintText: 'e.g., P001-S1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedAnalyte,
            items: _analyteOptions
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(growable: false),
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedAnalyte = value;
                      _syncLevelSelection();
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Analyte',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedLevel,
            items: _levelsForSelectedAnalyte()
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(growable: false),
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedLevel = value;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Level',
              helperText: 'This becomes the semiquant label written into the package.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _selectedLightKelvin,
            items: _lightOptions
                .map((value) => DropdownMenuItem(value: value, child: Text('$value K')))
                .toList(growable: false),
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedLightKelvin = value;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Lighting Condition',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedSplit,
            items: _splitOptions
                .map((value) => DropdownMenuItem(value: value, child: Text(value.toUpperCase())))
                .toList(growable: false),
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedSplit = value;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Dataset Split',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            enabled: !_isProcessing,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _pickBatchImages,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _selectedImages.isEmpty
                  ? 'Pick Photos'
                  : 'Picked ${_selectedImages.length} image(s) · Pick Again',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _buildTrainingPackage,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.inventory_2_outlined),
            label: Text(_isProcessing ? 'Building Package...' : 'Build Training Package'),
          ),
          if (_latestZipPath.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Upload to Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _endpointController,
              enabled: !_isUploading && !_isProcessing,
              decoration: const InputDecoration(
                labelText: 'Pipeline Endpoint URL',
                hintText: 'https://your-server/api/upload',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isUploading || _isProcessing ? null : _uploadPackage,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Latest Package'),
            ),
            if (_uploadStatusText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_uploadStatusText),
              ),
            ],
            if (_createdZipPaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Created packages: ${_createdZipPaths.length}'),
            ],
            const SizedBox(height: 8),
          ],
          if (_isDesktopTarget && _latestZipPath.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isProcessing ? null : _openLatestZipFolder,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Latest ZIP Folder'),
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedImages.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected files: ${_selectedImages.length}'),
                  const SizedBox(height: 6),
                  for (final item in _selectedImages.take(5))
                    Text(path.basename(item.path)),
                  if (_selectedImages.length > 5)
                    Text('...and ${_selectedImages.length - 5} more'),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_statusText),
          ),
          if (_latestZipPath.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText('Latest ZIP: $_latestZipPath'),
          ],
          if (_latestPackageFolderPath.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText('Package folder: $_latestPackageFolderPath'),
          ],
          const SizedBox(height: 12),
          const Text(
            'Output includes: batch_manifest.csv, training_index.csv, and ZIP package(s) ready for your training pipeline upload.',
          ),
        ],
      ),
    );
  }
}

class _BuildResult {
  const _BuildResult({
    required this.eventId,
    required this.zipFile,
    required this.imageCount,
    required this.skippedFiles,
    required this.archiveEntries,
  });

  final String eventId;
  final File zipFile;
  final int imageCount;
  final int skippedFiles;
  final int archiveEntries;
}
