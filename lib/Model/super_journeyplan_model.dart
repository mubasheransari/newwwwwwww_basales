class JourneyPlanSupervisor {
  final String name;
  final double lat;
  final double lng;

  /// Optional link to master location document id (locations/{id}).
  final String? locationId;

  /// Per-stop visit radius (meters). If 0, UI can fallback to a global constant.
  final double radiusMeters;

  bool isVisited;

  // NEW: time fields
  DateTime? checkIn;
  DateTime? checkOut;
  int? durationMinutes;

  JourneyPlanSupervisor({
    required this.name,
    required this.lat,
    required this.lng,
    this.locationId,
    this.radiusMeters = 0,
    this.isVisited = false,
    this.checkIn,
    this.checkOut,
    this.durationMinutes,
  });
}

/// Fallback local sample (used only if Firestore has no journey plan assigned).
final List<JourneyPlanSupervisor> kJourneyPlan = [
  JourneyPlanSupervisor(
    name: 'Paracha Textile Mill (Ghee Unit)',
    lat: 24.887257,
    lng: 66.9772325,
  ),
];
