/// Owner-transcribed URS-10T reading schedule, supplied 2026-10-12.
/// Manufacturer and IFU tolerances remain unverified. This is not a timing sensor.
class StripReadingSchedule {
  static const version = 'owner_reported_urs10t_20261012';
  static const secondsByCode = <String, int>{
    'LEU': 60,
    'NIT': 60,
    'URO': 60,
    'PRO': 60,
    'pH': 60,
    'BLD': 60,
    'SG': 45,
    'KET': 40,
    'BIL': 30,
    'GLU': 30,
  };

  static bool reportedTimeMatches(String code, double? seconds) =>
      seconds != null &&
      seconds.isFinite &&
      secondsByCode.containsKey(code) &&
      seconds == secondsByCode[code];

  static const guidance =
      'Reported strip schedule: bilirubin/glucose 30 s; ketone 40 s; '
      'specific gravity 45 s; leukocytes/nitrite/urobilinogen/protein/pH/blood 60 s. '
      'One photo cannot meet all four reading times. Other pad values are image review only. '
      'Manufacturer and timing tolerances are not yet verified.';
}
