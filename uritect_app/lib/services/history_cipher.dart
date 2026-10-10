import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

abstract interface class HistoryCipher {
  Duration get remainingSession;
  Future<void> authenticate();
  Future<Uint8List> encrypt(Uint8List bytes, String context);
  Future<Uint8List> decrypt(Uint8List bytes, String context);
  Future<void> lock();
}

class PlatformHistoryCipher implements HistoryCipher {
  const PlatformHistoryCipher();
  static const channel = MethodChannel('ph.edu.wvsu.uritect/history_security');
  static DateTime? _expiresAt;
  @override
  Duration get remainingSession {
    final remaining = _expiresAt?.difference(DateTime.now()) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Future<void> authenticate() async {
    _expiresAt = null;
    final result = await channel.invokeMapMethod<String, dynamic>(
      'authenticate',
    );
    if (result?['authenticated'] != true) {
      throw StateError('History remains locked. Authentication was cancelled.');
    }
    _expiresAt = DateTime.now().add(
      Duration(milliseconds: (result!['remainingMillis'] as num).toInt()),
    );
  }

  @override
  Future<Uint8List> encrypt(Uint8List bytes, String context) =>
      _protectedOperation('encrypt', bytes, context);
  @override
  Future<Uint8List> decrypt(Uint8List bytes, String context) =>
      _protectedOperation('decrypt', bytes, context);

  Future<Uint8List> _protectedOperation(
    String method,
    Uint8List bytes,
    String context,
  ) async {
    try {
      return (await channel.invokeMethod<Uint8List>(method, {
        'bytes': bytes,
        'context': context,
      }))!;
    } on PlatformException {
      _expiresAt = null;
      rethrow;
    }
  }

  @override
  Future<void> lock() async {
    _expiresAt = null;
    await channel.invokeMethod<void>('lock');
  }
}

String historyAccessMessage(Object error) {
  if (error is PlatformException) {
    switch (error.code) {
      case 'HISTORY_LOCKED':
        return 'History remains locked. Try again using your device PIN, pattern or password. Your saved files were preserved.';
      case 'HISTORY_KEY_UNAVAILABLE':
        return 'The history encryption key is unavailable. Your saved files were preserved. Do not clear app data or reinstall the app.';
      case 'HISTORY_INTEGRITY_ERROR':
        return 'Saved history could not be verified. Your files were preserved for recovery.';
      default:
        return error.message ??
            'History could not be unlocked. Your files were preserved.';
    }
  }
  return error.toString();
}

class HistoryCorruptionException implements Exception {
  final String message;
  const HistoryCorruptionException(this.message);
  @override
  String toString() => message;
}

/// Protect saved-history screenshots and recent-app previews. Each visible
/// history screen holds its own lease so opening a child cannot unlock its parent.
class HistoryPrivacy {
  static final Set<Object> _owners = {};
  static Future<void> acquire(Object owner) async {
    _owners.add(owner);
    try {
      await PlatformHistoryCipher.channel.invokeMethod<void>('privacy', {
        'enabled': true,
      });
    } catch (_) {
      _owners.remove(owner);
      rethrow;
    }
  }

  static Future<void> release(Object owner) async {
    _owners.remove(owner);
    try {
      // Remove plaintext widgets before permitting screenshots of the new screen.
      await SchedulerBinding.instance.endOfFrame;
      await PlatformHistoryCipher.channel.invokeMethod<void>('privacy', {
        'enabled': _owners.isNotEmpty,
      });
    } catch (_) {
      /* Native secure flag remains in place if the channel is unavailable. */
    }
  }
}
