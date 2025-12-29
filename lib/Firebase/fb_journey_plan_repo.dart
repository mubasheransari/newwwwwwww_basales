import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_services.dart';

/// Journey Plans repository.
///
/// Firestore model:
/// - journeyPlans/{planId}
///     supervisorId, periodType("weekly"|"monthly"), startDate(Timestamp), endDate(Timestamp),
///     createdAt, createdBy
/// - journeyPlans/{planId}/stops/{stopId}
///     locationId, name, allowedLocation(GeoPoint), allowedRadiusMeters, sortIndex
/// - journeyPlans/{planId}/visits/{visitId}
///     locationId, stopName, comment, checkIn, checkOut, dayKey, createdAt
///
/// â IMPORTANT:
/// Do NOT re-define models (FbLocation/FbJourneyPlan/FbJourneyStop) here.
/// They already live in `firebase_services.dart`.
/// Keeping a single source of truth prevents type-mismatch errors.
class FbJourneyPlanRepo {
  static CollectionReference<Map<String, dynamic>> get _plans =>
      Fb.db.collection('journeyPlans');

  // ------------------------------ Admin ------------------------------

  static Future<void> createJourneyPlan({
    required String supervisorId,
    required String periodType, // "weekly" | "monthly"
    required DateTime startDate,
    required DateTime endDate,
    required List<FbLocation> stops,
  }) async {
    if (Fb.uid == null) throw Exception('Not signed in');

    final doc = _plans.doc();
    final batch = Fb.db.batch();

    batch.set(doc, {
      'supervisorId': supervisorId,
      'periodType': periodType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': Fb.uid,
    });

    final stopsCol = doc.collection('stops');
    int i = 0;
    for (final s in stops) {
      final stopId = s.id; // keep same id as locationId for easy matching
      final stopDoc = stopsCol.doc(stopId);
      batch.set(stopDoc, {
        'locationId': s.id,
        'name': s.name,
        'allowedLocation': GeoPoint(s.lat, s.lng),
        'allowedRadiusMeters': s.radiusMeters,
        'sortIndex': i,
      });
      i++;
    }

    await batch.commit();
  }

  static Future<void> deletePlan(String planId) async {
    // NOTE: For large subcollections you should use a Cloud Function.
    // Here we only delete stops + visits in small amounts.
    final ref = _plans.doc(planId);

    final batch = Fb.db.batch();

    final stops = await ref.collection('stops').get();
    for (final d in stops.docs) {
      batch.delete(d.reference);
    }

    final visits = await ref.collection('visits').get();
    for (final d in visits.docs) {
      batch.delete(d.reference);
    }

    batch.delete(ref);
    await batch.commit();
  }

  // ---------------------------- Supervisor ----------------------------

  /// Fetch the active plan for a supervisor where `now` is within start/end dates.
  static Future<FbJourneyPlan?> fetchActivePlanOnce({
    required String supervisorId,
    required DateTime now,
  }) async {
    // ✅ No composite-index needed:
    // Only filter by supervisorId (single-field index), then do date-range + sorting in-memory.
    final q = await _plans.where('supervisorId', isEqualTo: supervisorId).get();

    FbJourneyPlan? best;
    for (final d in q.docs) {
      final plan = FbJourneyPlan.fromDoc(d.id, d.data());
      final inRange = !now.isBefore(plan.startDate) && !now.isAfter(plan.endDate);
      if (!inRange) continue;

      if (best == null || plan.startDate.isAfter(best.startDate)) {
        best = plan;
      }
    }
    return best;
  }

  static Future<List<FbJourneyStop>> fetchStopsOnce({
    required String planId,
  }) async {
    final snap = await _plans
        .doc(planId)
        .collection('stops')
        .orderBy('sortIndex')
        .get();

    return snap.docs.map((d) => FbJourneyStop.fromDoc(d.id, d.data())).toList();
  }

  /// Read visited location ids for a specific day.
  static Future<Set<String>> fetchVisitedLocationIdsForDay({
    required String planId,
    required String dayKey, // yyyy-mm-dd
  }) async {
    final snap = await _plans
        .doc(planId)
        .collection('visits')
        .where('dayKey', isEqualTo: dayKey)
        .get();

    final out = <String>{};
    for (final d in snap.docs) {
      final locId = (d.data()['locationId'] ?? '').toString();
      if (locId.isNotEmpty) out.add(locId);
    }
    return out;
  }

  static Future<void> addVisit({
    required String planId,
    required FbJourneyStop stop,
    required String comment,
    required DateTime? checkIn,
    required DateTime? checkOut,
    String? dayKey,
  }) async {
    if (Fb.uid == null) throw Exception('Not signed in');
    final ref = _plans.doc(planId).collection('visits').doc();
    final now = DateTime.now();

    String _mkDayKey(DateTime dt) {
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    await ref.set({
      // â used by Firestore rules to ensure only the assigned supervisor writes visits
      'supervisorId': Fb.uid,
      'locationId': stop.locationId,
      'stopName': stop.name,
      'comment': comment,
      'checkIn': checkIn == null ? null : Timestamp.fromDate(checkIn),
      'checkOut': checkOut == null ? null : Timestamp.fromDate(checkOut),
      'dayKey': dayKey ?? _mkDayKey(now),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': Fb.uid,
    });
  }
}
