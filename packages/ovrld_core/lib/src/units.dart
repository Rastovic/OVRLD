/// Storage is always kg, cm, metres and seconds. Units only exist at the edge
/// of the screen, so switching them never rewrites a single stored value.
library;

enum WeightUnit { kg, lb }

enum DistanceUnit { km, mi }

enum HeightUnit { cm, ftIn }

const double kgPerLb = 0.45359237;
const double metresPerMile = 1609.344;

double kgToDisplay(double kg, WeightUnit unit) =>
    unit == WeightUnit.kg ? kg : kg / kgPerLb;

double displayToKg(double value, WeightUnit unit) =>
    unit == WeightUnit.kg ? value : value * kgPerLb;

String weightLabel(WeightUnit unit) => unit == WeightUnit.kg ? 'kg' : 'lb';

/// The +/- step on the logger, in the unit on screen. A 2.5 kg plate pair is
/// shown as 5 lb, not 5.51 lb: lb users load lb plates.
double displayStep(double incrementKg, WeightUnit unit) {
  if (unit == WeightUnit.kg) return incrementKg;
  final lb = incrementKg / 2.5 * 5;
  final rounded = (lb / 2.5).round() * 2.5;
  return rounded < 2.5 ? 2.5 : rounded;
}

/// Shortest honest number: 100, 102.5, 101.25. Never "100.0".
String formatNumber(double value, {int maxDecimals = 2}) {
  var s = value.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

/// A weight as the user sees it, rounded to what a gym can actually load.
String formatWeight(double kg, WeightUnit unit) {
  final v = kgToDisplay(kg, unit);
  final step = unit == WeightUnit.kg ? 0.25 : 0.5;
  return formatNumber((v / step).round() * step);
}

/// Thousands separated by a thin space, the European way: 8 940.
String formatThousands(num value) {
  final s = value.round().abs().toString();
  final b = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

double metresToDisplay(double metres, DistanceUnit unit) =>
    unit == DistanceUnit.km ? metres / 1000 : metres / metresPerMile;

double displayToMetres(double value, DistanceUnit unit) =>
    unit == DistanceUnit.km ? value * 1000 : value * metresPerMile;

String distanceLabel(DistanceUnit unit) => unit == DistanceUnit.km ? 'km' : 'mi';

/// Seconds per km or per mile. Null when there is no distance to divide by.
double? paceSeconds(int durationSeconds, double metres, DistanceUnit unit) {
  if (metres <= 0 || durationSeconds <= 0) return null;
  return durationSeconds / metresToDisplay(metres, unit);
}

/// km/h or mph.
double? speed(int durationSeconds, double metres, DistanceUnit unit) {
  if (metres <= 0 || durationSeconds <= 0) return null;
  return metresToDisplay(metres, unit) / (durationSeconds / 3600);
}

/// Swim pace, seconds per 100 m. Pools are metric everywhere that matters.
double? pacePer100m(int durationSeconds, double metres) {
  if (metres <= 0 || durationSeconds <= 0) return null;
  return durationSeconds / (metres / 100);
}

/// 5:19 for a pace, 27:41 or 1:07:42 for a duration.
String formatClock(num seconds) {
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// "1h 07m", or "48m" under an hour. For totals in lists, where seconds are noise.
String formatHoursMinutes(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// (feet, inches) for a height in cm.
(int, int) cmToFeetInches(double cm) {
  final totalInches = (cm / 2.54).round();
  return (totalInches ~/ 12, totalInches % 12);
}

double feetInchesToCm(int feet, int inches) => (feet * 12 + inches) * 2.54;
