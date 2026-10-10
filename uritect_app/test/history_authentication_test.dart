import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/services/history_cipher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cipher = PlatformHistoryCipher();
  bool allowed = true;
  String? operationError;
  setUp(() {
    allowed = true;
    operationError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformHistoryCipher.channel, (call) async {
          if (call.method == 'authenticate') {
            return {'authenticated': allowed, 'remainingMillis': 120000};
          }
          if (call.method == 'lock') return null;
          if (operationError != null) {
            throw PlatformException(code: operationError!);
          }
          return Uint8List.fromList([1, 2, 3]);
        });
  });
  tearDown(() async {
    await cipher.lock();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PlatformHistoryCipher.channel, null);
  });
  test(
    'failed native key access invalidates the displayed unlock session',
    () async {
      await cipher.authenticate();
      expect(cipher.remainingSession, greaterThan(Duration.zero));
      operationError = 'HISTORY_LOCKED';
      await expectLater(
        cipher.decrypt(Uint8List.fromList([1]), 'uritect:test'),
        throwsA(isA<PlatformException>()),
      );
      expect(cipher.remainingSession, Duration.zero);
      operationError = null;
      await cipher.authenticate();
      expect(await cipher.encrypt(Uint8List.fromList([1]), 'uritect:test'), [
        1,
        2,
        3,
      ]);
    },
  );
  test(
    'cancelled reauthentication cannot retain an earlier unlock session',
    () async {
      await cipher.authenticate();
      allowed = false;
      await expectLater(cipher.authenticate(), throwsStateError);
      expect(cipher.remainingSession, Duration.zero);
    },
  );
  test(
    'locked history and integrity failures have different recovery messages',
    () {
      final locked = historyAccessMessage(
        PlatformException(code: 'HISTORY_LOCKED'),
      );
      final corrupt = historyAccessMessage(
        PlatformException(code: 'HISTORY_INTEGRITY_ERROR'),
      );
      expect(locked, contains('PIN'));
      expect(locked, isNot(contains('PlatformException')));
      expect(corrupt, contains('recovery'));
      expect(corrupt, isNot(contains('PIN')));
    },
  );
}
