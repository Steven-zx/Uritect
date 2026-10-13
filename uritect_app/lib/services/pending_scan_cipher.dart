import 'package:flutter/services.dart';
import 'history_cipher.dart';

/// Write-only public-key sealing; decrypting still requires a history unlock.
abstract interface class PendingScanCipher {
  Future<Uint8List> seal(Uint8List bytes, String context, bool existing);
  Future<Uint8List> open(Uint8List bytes, String context);
}

class PlatformPendingScanCipher implements PendingScanCipher {
  const PlatformPendingScanCipher();
  @override
  Future<Uint8List> seal(
    Uint8List bytes,
    String context,
    bool existing,
  ) async => (await PlatformHistoryCipher.channel.invokeMethod<Uint8List>(
    'sealPending',
    {'bytes': bytes, 'context': context, 'existingSealedRecords': existing},
  ))!;
  @override
  Future<Uint8List> open(Uint8List bytes, String context) async =>
      (await PlatformHistoryCipher.channel.invokeMethod<Uint8List>(
        'openPending',
        {'bytes': bytes, 'context': context},
      ))!;
}
