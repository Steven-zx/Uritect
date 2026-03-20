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
  static const List<String> _labelOptions = ['Normal', 'Abnormal'];

  final TextEditingController _batchIdController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final image_picker.ImagePicker _imagePicker = image_picker.ImagePicker();

  List<XFile> _selectedImages = const [];
  String _selectedLabel = 'Normal';
  int _selectedLightKelvin = 4000;
  String _selectedSplit = 'train';
  String _statusText =
      'Select a batch, add label, pick images, then build a training-ready package.';
  String _latestZipPath = '';
  String _latestPackageFolderPath = '';
  String _latestEventId = '';
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

    final label = _selectedLabel;
    final batchId = _batchIdController.text.trim().isEmpty
        ? 'batch_unset'
        : _batchIdController.text.trim();

    if (_selectedImages.isEmpty) {
      setState(() {
        _statusText = 'Please pick at least one image before building package.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText =
          'Building package for ${_selectedImages.length} image(s). Please wait...';
    });

    try {
      final now = DateTime.now();
      final timestamp = now.toIso8601String();
      final eventId = _buildEventId(batchId: batchId, label: label, timestamp: timestamp);
      final notes = _notesController.text.trim();

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

      final eventDir = Directory('${eventsRoot.path}/$eventId');
      final imagesDir = Directory('${eventDir.path}/images');
      await imagesDir.create(recursive: true);

      final perBatchManifest = File('${eventDir.path}/batch_manifest.csv');
      final perBatchIndex = File('${eventDir.path}/training_index.csv');
      final globalManifest = File('${manifestsRoot.path}/training_manifest.csv');

      if (!await globalManifest.exists()) {
        await globalManifest.writeAsString(
          'timestamp_iso8601,event_id,batch_id,label,split,photo_index,file_name,relative_image_path,source_image_path,light_kelvin,notes\n',
          flush: true,
        );
      }

      final batchManifestRows = <String>[
        'timestamp_iso8601,event_id,batch_id,label,split,photo_index,file_name,relative_image_path,source_image_path,light_kelvin,notes',
      ];
      final trainingIndexRows = <String>[
        'relative_image_path,label,split,event_id,batch_id,light_kelvin',
      ];
      final globalRows = <String>[];
      final copiedFiles = <File>[];
      var skippedFiles = 0;

      for (var index = 0; index < _selectedImages.length; index++) {
        final picked = _selectedImages[index];
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
          label,
          _selectedSplit,
          (index + 1).toString(),
          fileName,
          relativeImagePath,
          source.path,
          _selectedLightKelvin.toString(),
          notes,
        ].map(_csvEscape).join(',');

        batchManifestRows.add(row);
        globalRows.add(row);

        final indexRow = [
          relativeImagePath,
          label,
          _selectedSplit,
          eventId,
          batchId,
          _selectedLightKelvin.toString(),
        ].map(_csvEscape).join(',');
        trainingIndexRows.add(indexRow);
      }

      if (copiedFiles.isEmpty) {
        throw StateError(
          'No readable image files were found from your selection. Please re-pick files from a local folder.',
        );
      }

      await perBatchManifest.writeAsString(
        '${batchManifestRows.join('\n')}\n',
        flush: true,
      );
      await perBatchIndex.writeAsString(
        '${trainingIndexRows.join('\n')}\n',
        flush: true,
      );
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

      if (!mounted) {
        return;
      }

      setState(() {
        _latestZipPath = zipFile.path;
        _latestPackageFolderPath = packagesRoot.path;
        _latestEventId = eventId;
        _uploadStatusText = '';
        _statusText =
            'Package ready: ${copiedFiles.length} image(s) prepared '
            '(${archive.files.length} ZIP entries). '
            '${skippedFiles > 0 ? 'Skipped $skippedFiles unreadable file(s). ' : ''}'
            'ZIP: ${zipFile.path}';
      });

      if (!_isDesktopTarget) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipFile.path)],
            text: 'Uritect dataset package $eventId',
            subject: 'Uritect Training Package',
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
  }) {
    final cleanBatchId = _sanitizeToken(batchId);
    final cleanLabel = _sanitizeToken(label);
    final cleanTimestamp = timestamp.replaceAll(':', '-').replaceAll('.', '-');
    return '${cleanBatchId}_${cleanLabel}_$cleanTimestamp';
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
        ..fields['label'] = _selectedLabel
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
        title: const Text('Uritect Data Collection'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Camera capture is disabled. This app now collects existing images, labels them, and builds training-ready packages.',
          ),
          const SizedBox(height: 16),
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
          DropdownButtonFormField<String>(
            initialValue: _selectedLabel,
            items: _labelOptions
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(growable: false),
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedLabel = value;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Label',
              helperText: 'Use binary labels only for current data collection.',
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
                  ? 'Pick Batch Images'
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
          if (_latestZipPath.isNotEmpty) ...[const SizedBox(height: 16), const Divider(), const SizedBox(height: 8), const Text('Upload to Pipeline', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), TextField(controller: _endpointController, enabled: !_isUploading && !_isProcessing, decoration: const InputDecoration(labelText: 'Pipeline Endpoint URL', hintText: 'https://your-server/api/upload', border: OutlineInputBorder()), keyboardType: TextInputType.url), const SizedBox(height: 8), FilledButton.icon(onPressed: _isUploading || _isProcessing ? null : _uploadPackage, icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload_outlined), label: Text(_isUploading ? 'Uploading...' : 'Upload Package')), if (_uploadStatusText.isNotEmpty) ...[const SizedBox(height: 8), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(8)), child: SelectableText(_uploadStatusText))], const SizedBox(height: 8)],
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
            'Output includes: batch_manifest.csv, training_index.csv, and a ZIP package ready for your training pipeline upload.',
          ),
        ],
      ),
    );
  }
}
