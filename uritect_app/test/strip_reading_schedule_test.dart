import 'package:flutter_test/flutter_test.dart';
import 'package:uritect_app/models/scan_provenance.dart';
import 'package:uritect_app/models/strip_reading_schedule.dart';
import 'provisional_readings_test.dart' as fixture;

void main() {
  test('60 second image supports required UTI pads but not early pads', () {
    final scan = fixture.baseScan();
    expect(
      scan.hasUsableAnalytesForCurrentInterpretation({'LEU', 'NIT', 'BLD'}),
      isTrue,
    );
    expect(
      scan.hasUsableAnalytesForCurrentInterpretation({'PRO', 'BLD'}),
      isTrue,
    );
    for (final code in ['SG', 'KET', 'BIL', 'GLU']) {
      expect(scan.hasUsableAnalytesForCurrentInterpretation({code}), isFalse);
    }
    expect(scan.isUsableForCurrentInterpretation, isFalse);
    expect(
      scan.rows,
      hasLength(10),
    ); // Review values remain, without timing claims.
  });

  test('30 second image permits only bilirubin and glucose timing', () {
    final original = fixture.baseScan();
    final scan = original.copyWith(
      provenance: ScanProvenance.fromJson({
        ...original.provenance!.toJson(),
        'secondsAfterDipping': 30,
      }),
    );
    expect(
      scan.hasUsableAnalytesForCurrentInterpretation({'BIL', 'GLU'}),
      isTrue,
    );
    expect(fixture.estimate(scan).isCalculable, isFalse);
    expect(fixture.renal(scan).scanValid, isFalse);
  });

  test('45 second SG and 40 second ketone are not a 60 second UTI capture', () {
    expect(StripReadingSchedule.reportedTimeMatches('SG', 45), isTrue);
    expect(StripReadingSchedule.reportedTimeMatches('KET', 40), isTrue);
    expect(StripReadingSchedule.reportedTimeMatches('LEU', 45), isFalse);
    expect(StripReadingSchedule.reportedTimeMatches('KET', 60), isFalse);
  });

  test(
    'no unprovided tolerance is invented for missing or mismatched timing',
    () {
      for (final time in [
        null,
        double.nan,
        double.infinity,
        -1.0,
        59.0,
        60.1,
      ]) {
        expect(StripReadingSchedule.reportedTimeMatches('LEU', time), isFalse);
      }
      expect(StripReadingSchedule.reportedTimeMatches('UNKNOWN', 60), isFalse);
    },
  );
}
