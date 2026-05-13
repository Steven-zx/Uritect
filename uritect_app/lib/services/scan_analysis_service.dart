import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/dipstick_results_data.dart';
import '../models/scan_model.dart';

class ScanAnalysisService {
  const ScanAnalysisService();

  static const String _physicalDeviceDefaultAndroidServer = 'http://192.168.1.213:8000';
  static const String _emulatorDefaultAndroidServer = 'http://10.0.2.2:8000';
  static const String _desktopDefaultServer = 'http://127.0.0.1:8000';

  bool _looksLikeAndroidEmulator() {
    if (!Platform.isAndroid) {
      return false;
    }

    final version = Platform.operatingSystemVersion.toLowerCase();
    return version.contains('sdk') ||
        version.contains('emulator') ||
        version.contains('genymotion') ||
        version.contains('x86') ||
        version.contains('google_sdk');
  }

  Future<bool> _probeServer(Uri serverBaseUri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(serverBaseUri.resolve('/health'));
      final response = await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode == 200;
    } on Exception {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uri> _resolveScanServerBaseUri() async {
    const overrideUrl = String.fromEnvironment('SCAN_SERVER_BASE_URL');
    if (overrideUrl.isNotEmpty) {
      print('[ScanService] Using override URL: $overrideUrl');
      return Uri.parse(overrideUrl);
    }

    if (Platform.isAndroid) {
      final candidates = <Uri>[
        Uri.parse(_looksLikeAndroidEmulator()
            ? _emulatorDefaultAndroidServer
            : _physicalDeviceDefaultAndroidServer),
        Uri.parse(_looksLikeAndroidEmulator()
            ? _physicalDeviceDefaultAndroidServer
            : _emulatorDefaultAndroidServer),
      ];

      for (final candidate in candidates) {
        print('[ScanService] Probing Android scan server candidate: $candidate');
        if (await _probeServer(candidate)) {
          print('[ScanService] Using reachable Android scan server: $candidate');
          return candidate;
        }
      }

      final fallback = candidates.first;
      print('[ScanService] No Android candidate responded on /health, falling back to: $fallback');
      return fallback;
    }

    print('[ScanService] Using localhost URL: $_desktopDefaultServer');
    return Uri.parse(_desktopDefaultServer);
  }

  bool _supportsLocalPythonFallback() {
    return !(Platform.isAndroid || Platform.isIOS || Platform.isFuchsia);
  }

  String _connectionGuidance(Uri serverBaseUri) {
    final host = serverBaseUri.host;
    if (Platform.isAndroid) {
      return 'The app could not reach the scan server at $serverBaseUri. '
          'If you are using an emulator, start the server on your PC and keep the default Android endpoint (10.0.2.2:8000). '
          'If you are using a physical device, use the PC\'s LAN IP and launch with --dart-define=SCAN_SERVER_BASE_URL=http://<your-pc-ip>:8000. '
          'Make sure port 8000 is open and the Python scan server is running.';
    }

    return 'The app could not reach the scan server at $serverBaseUri. '
        'Start the local Python scan server in the Uritect workspace and make sure port 8000 is available on $host.';
  }

  Directory _findWorkspaceRoot() {
    var directory = Directory.current.absolute;
    while (true) {
      final candidate = File('${directory.path}${Platform.pathSeparator}pipeline${Platform.pathSeparator}scan_dipstick.py');
      if (candidate.existsSync()) {
        return directory;
      }

      final parent = directory.parent;
      if (parent.path == directory.path) {
        break;
      }
      directory = parent;
    }
    throw StateError('Could not locate the Uritect workspace root.');
  }

  String _resolvePythonExecutable(Directory root) {
    final venvPython = File('${root.path}${Platform.pathSeparator}.venv${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe');
    if (venvPython.existsSync()) {
      return venvPython.path;
    }
    return 'python';
  }

  DipstickResultStatus _statusFromProbability(double probability) {
    return probability >= 0.5 ? DipstickResultStatus.moderate : DipstickResultStatus.negative;
  }

  ScanResult _scanResultFromJson(Map<String, dynamic> payload) {
    final rowsJson = (payload['analytes'] as List<dynamic>? ?? const <dynamic>[]);
    final rows = rowsJson.map((item) {
      final row = item as Map<String, dynamic>;
      return DipstickResultRow(
        code: row['code'] as String? ?? '',
        name: row['name'] as String? ?? '',
        result: row['display_value'] as String? ?? 'Unavailable',
        referenceRange: row['reference_range'] as String? ?? 'Reference unavailable',
        status: _statusFromProbability((row['abnormal_probability'] as num?)?.toDouble() ?? 0.0),
      );
    }).toList(growable: false);

    final screeningProbabilities = <String, double>{};
    final screeningJson = payload['screening_probabilities'];
    if (screeningJson is Map<String, dynamic>) {
      for (final entry in screeningJson.entries) {
        screeningProbabilities[entry.key] = (entry.value as num?)?.toDouble() ?? 0.0;
      }
    }

    final scanId = payload['id'] as String? ?? 'scan_pending';
    final imagePath = payload['image_path'] as String? ?? '';
    final modelVersion = payload['model_version'] as String? ?? 'trained_v4_hsv';
    final riskBucket = payload['risk_bucket'] as String? ?? 'Moderate';
    final posteriorProbability = (payload['posterior_probability'] as num?)?.toDouble() ?? 0.0;
    final confidence = (payload['confidence'] as num?)?.toDouble() ?? posteriorProbability;
  final padsDetected = payload['pads_detected'] as int?;
  final padsUnavailable = payload['pads_unavailable'] as int?;

    return ScanResult(
      id: scanId,
      date: DateTime.now(),
      imagePath: imagePath,
      status: riskBucket.toLowerCase(),
      confidence: confidence,
      posteriorProbability: posteriorProbability,
      riskBucket: riskBucket,
      modelVersion: modelVersion,
      rows: rows,
      screeningProbabilities: screeningProbabilities,
      padsDetected: padsDetected,
      padsUnavailable: padsUnavailable,
    );
  }

  Future<ScanResult> analyze({
    required String imagePath,
    void Function(double progress, String stage)? onProgress,
  }) async {
    final progressCallback = onProgress;
    final serverBaseUri = await _resolveScanServerBaseUri();
    final uri = serverBaseUri.resolve('/scan');
    final file = File(imagePath);
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest('POST', uri);
      
      // Ask server for async processing so we can receive progress events.
      request.headers['Prefer'] = 'respond-async';
      print('[scan_analysis] Setting Prefer header to: respond-async');
      
      final filename = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'upload.jpg';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);
      
      print('[scan_analysis] Response status: ${response.statusCode}');
      print('[scan_analysis] Response headers: ${response.headers}');
      
      final respBody = response.body;
      if (response.statusCode == 202) {
        final decoded = jsonDecode(respBody) as Map<String, dynamic>?;
        final scanId = decoded?['id'] as String?;
        if (scanId == null) {
          throw StateError('Scan server accepted async request but returned no id.');
        }

        print('[scan_analysis] Got scan_id: $scanId, connecting to SSE endpoint');

        // Connect to SSE endpoint and wait for result event
        final eventsUri = serverBaseUri.resolve('/scan_events/$scanId');
        print('[scan_analysis] SSE URI: $eventsUri');
        
        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 10);
        
        try {
          final eventsRequest = await httpClient.getUrl(eventsUri);
          print('[scan_analysis] SSE request created, sending...');
          
          final eventsResponse = await eventsRequest.close().timeout(const Duration(seconds: 10));
          print('[scan_analysis] SSE response status: ${eventsResponse.statusCode}');
          
          if (eventsResponse.statusCode != 200) {
            throw StateError('Failed to subscribe to scan events: HTTP ${eventsResponse.statusCode}');
          }

          // Read stream and parse SSE-style data lines starting with 'data: '
          print('[scan_analysis] Waiting for SSE events...');
          final bodyStream = eventsResponse.transform(utf8.decoder).transform(const LineSplitter());
          var lastError = '';
          await for (final line in bodyStream) {
            if (line.startsWith('data: ')) {
              final jsonText = line.substring(6);
              try {
                final ev = jsonDecode(jsonText) as Map<String, dynamic>;
                final type = ev['type'] as String? ?? 'progress';
                print('[scan_analysis] Received event type: $type');
                
                if (type == 'progress') {
                  final stage = ev['stage'] as String? ?? 'processing';
                  final progress = (ev['progress'] as num?)?.toDouble() ?? 0.0;
                  print('[scan_analysis] Progress: $progress% - $stage');
                  progressCallback?.call(progress.clamp(0.0, 100.0), stage);
                } else if (type == 'result') {
                  final payload = ev['payload'];
                  if (payload is Map<String, dynamic>) {
                    print('[scan_analysis] Received result');
                    progressCallback?.call(100.0, 'complete');
                    return _scanResultFromJson(payload);
                  }
                } else if (type == 'error') {
                  final err = ev['error'] as String? ?? 'unknown error';
                  print('[scan_analysis] Server error: $err');
                  lastError = err;
                  // Don't continue reading more events, throw immediately
                  throw StateError('Scan analysis failed: $err');
                }
              } catch (e) {
                print('[scan_analysis] Error processing SSE event: $e');
                if (e is StateError && e.message.startsWith('Scan analysis failed:')) {
                  rethrow;
                }
              }
            }
          }

          if (lastError.isNotEmpty) {
            throw StateError('Scan analysis failed: $lastError');
          }

          throw StateError('Scan events stream closed without result.');
        } on SocketException catch (e) {
          print('[scan_analysis] Socket error: $e');
          throw StateError('Network error connecting to SSE endpoint: $e');
        } on TimeoutException catch (e) {
          print('[scan_analysis] Timeout: $e');
          throw StateError('Timeout waiting for SSE events: $e');
        }
      }

      if (response.statusCode != 200) {
        throw StateError('${_connectionGuidance(serverBaseUri)} HTTP ${response.statusCode}: $respBody');
      }

      final decoded = jsonDecode(respBody);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Scan server returned invalid JSON payload.');
      }

      progressCallback?.call(100.0, 'complete');

      return _scanResultFromJson(decoded);
    } catch (e) {
      print('[scan_analysis] Caught exception: $e');
      
      // If the error is from server analysis, don't show connection guidance
      if (e is StateError && e.message.startsWith('Scan analysis failed:')) {
        rethrow;
      }
      
      if (!_supportsLocalPythonFallback()) {
        throw StateError(_connectionGuidance(serverBaseUri));
      }

      // Fallback: spawn python script (legacy behavior)
      final root = _findWorkspaceRoot();
      final pythonExecutable = _resolvePythonExecutable(root);
      final scriptPath = '${root.path}${Platform.pathSeparator}pipeline${Platform.pathSeparator}scan_dipstick.py';
      final mapPath = '${root.path}${Platform.pathSeparator}pipeline${Platform.pathSeparator}output${Platform.pathSeparator}knn_reference_map.json';
      final legacyMapPath = '${root.path}${Platform.pathSeparator}pipeline${Platform.pathSeparator}output${Platform.pathSeparator}knn_reference_map_20260323_baseline_restored.json';
      final resolvedMapPath = File(mapPath).existsSync() ? mapPath : legacyMapPath;

      final result = await Process.run(
        pythonExecutable,
        [
          scriptPath,
          '--image',
          imagePath,
          '--map',
          resolvedMapPath,
        ],
        workingDirectory: root.path,
      );

      if (result.exitCode != 0) {
        throw StateError('Scan analysis failed: ${result.stderr} (fallback)');
      }

      final stdoutText = result.stdout.toString().trim();
      if (stdoutText.isEmpty) {
        throw StateError('Scan analysis returned no data (fallback).');
      }

      final decoded = jsonDecode(stdoutText);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('Scan analysis returned an invalid payload (fallback).');
      }

      progressCallback?.call(100.0, 'complete');

      return _scanResultFromJson(decoded);
    }
  }
}