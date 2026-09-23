/// A UTC-tagged wall clock for formatting only. Comparisons use real instants.
DateTime beijingWallTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

String apiDate(DateTime instant) {
  final date = beijingWallTime(instant);
  return '${date.year}${twoDigits(date.month)}${twoDigits(date.day)}';
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String courseTime(DateTime? instant) {
  if (instant == null) return '--:--';
  final date = beijingWallTime(instant);
  return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
