import 'dart:math' as math;

double distanceInKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

String formatTimeHM(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final am = t.hour >= 12 ? 'PM' : 'AM';
  return '$h12:$mm $am';
}