import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Central place for Firebase instances used across the app.
class Fb {
  Fb._();

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static User? get user => auth.currentUser;
  static String? get uid => auth.currentUser?.uid;
}

class FbUserProfile {
  final String uid;
  final String email;
  final String name;
  final String empCode;
  final String? locationId;
  final String? locationName;
  final double allowedLat;
  final double allowedLng;
  final double allowedRadiusMeters;

  const FbUserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.empCode,
    this.locationId,
    this.locationName,
    required this.allowedLat,
    required this.allowedLng,
    required this.allowedRadiusMeters,
  });

  static FbUserProfile fromDoc(String uid, Map<String, dynamic> d) {
    final gp = d['allowedLocation'];
    double lat = 0;
    double lng = 0;
    if (gp is GeoPoint) {
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (gp is Map) {
      lat = (gp['lat'] as num?)?.toDouble() ?? 0;
      lng = (gp['lng'] as num?)?.toDouble() ?? 0;
    }

    return FbUserProfile(
      uid: uid,
      email: (d['email'] ?? '').toString(),
      name: (d['name'] ?? 'User').toString(),
      empCode: (d['empCode'] ?? '--').toString(),
      locationId: d['locationId']?.toString(),
      locationName: d['locationName']?.toString(),
      allowedLat: lat,
      allowedLng: lng,
      allowedRadiusMeters: (d['allowedRadiusMeters'] as num?)?.toDouble() ?? 100,
    );
  }
}

class FbUserRepo {
  static CollectionReference<Map<String, dynamic>> get _col =>
      Fb.db.collection('users');

  /// Reads the user profile from Firestore.
  /// If it doesn't exist, creates a minimal one (admin can update location later).
  static Future<FbUserProfile> getOrCreateProfile({
    required User user,
  }) async {
    final ref = _col.doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'email': user.email ?? '',
        'name': user.displayName ?? 'User',
        'empCode': user.email ?? user.uid,
        // Default allowedLocation is (0,0). Admin must set correct coords.
        'allowedLocation': const GeoPoint(0, 0),
        'allowedRadiusMeters': 100,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final snap2 = await ref.get();
    final data = snap2.data() ?? <String, dynamic>{};
    return FbUserProfile.fromDoc(user.uid, data);
  }
}

class FbAttendanceRepo {
  static Future<void> addAttendance({
    required String uid,
    required String action, // IN / OUT
    required double lat,
    required double lng,
    required double distanceMeters,
    required bool withinAllowed,
    required String deviceId,
  }) async {
    await Fb.db
        .collection('users')
        .doc(uid)
        .collection('attendance')
        .add({
      'action': action,
      'lat': lat,
      'lng': lng,
      'distanceMeters': distanceMeters,
      'withinAllowed': withinAllowed,
      'deviceId': deviceId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class FbSalesRepo {
  static Future<void> addOrder({
    required String uid,
    required Map<String, dynamic> orderJson,
  }) async {
    await Fb.db.collection('users').doc(uid).collection('sales').add({
      ...orderJson,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Simple admin check using a Firestore document.
///
/// If a document exists at `admins/{uid}`, that account is treated as an admin.
/// This avoids needing Cloud Functions / custom claims.
class FbAdminRepo {
  static Future<bool> isAdmin(String uid) async {
    try {
      // We only need to check whether /admins/{uid} exists.
      // If Firestore rules block this read, the app must NOT crash.
      final doc = await Fb.db.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}

class FbLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  const FbLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
  });

  static FbLocation fromDoc(String id, Map<String, dynamic> d) {
    final gp = d['allowedLocation'];
    double lat = 0;
    double lng = 0;
    if (gp is GeoPoint) {
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (gp is Map) {
      lat = (gp['lat'] as num?)?.toDouble() ?? 0;
      lng = (gp['lng'] as num?)?.toDouble() ?? 0;
    }
    return FbLocation(
      id: id,
      name: (d['name'] ?? '').toString(),
      lat: lat,
      lng: lng,
      radiusMeters: (d['allowedRadiusMeters'] as num?)?.toDouble() ?? 100,
    );
  }
}

/// Master locations configured by admin.
///
/// Collection: locations/{locationId}
class FbLocationRepo {
  static CollectionReference<Map<String, dynamic>> get _col =>
      Fb.db.collection('locations');

  /// Raw snapshots stream for screens that use `StreamBuilder<QuerySnapshot<...>>`.
  /// (Kept to avoid changing existing UI code.)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLocations() {
    return _col.orderBy('name').snapshots();
  }

  static Stream<List<FbLocation>> watchLocations() {
    return _col.orderBy('name').snapshots().map((q) {
      return q.docs
          .map((d) => FbLocation.fromDoc(d.id, d.data()))
          .toList(growable: false);
    });
  }

  static Future<List<FbLocation>> fetchLocationsOnce() async {
    final q = await _col.orderBy('name').get();
    return q.docs
        .map((d) => FbLocation.fromDoc(d.id, d.data()))
        .toList(growable: false);
  }

  static Future<void> upsertLocation({
    String? id,
    required String name,
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final ref = (id == null || id.isEmpty) ? _col.doc() : _col.doc(id);
    await ref.set({
      'name': name.trim(),
      'allowedLocation': GeoPoint(lat, lng),
      'allowedRadiusMeters': radiusMeters,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> deleteLocation(String id) async {
    await _col.doc(id).delete();
  }

  /// Helper for user-side location selection screen:
  /// - reads locations/{locationId}
  /// - writes locationId/locationName/allowedLocation/allowedRadiusMeters to users/{uid}
  static Future<void> setCurrentUserLocationFromLocation(String locationId) async {
    final uid = Fb.uid;
    if (uid == null) {
      throw Exception('No active session. Please login again.');
    }

    final snap = await _col.doc(locationId).get();
    if (!snap.exists) {
      throw Exception('Selected location not found');
    }

    final data = snap.data() ?? <String, dynamic>{};
    final loc = FbLocation.fromDoc(snap.id, data);
    await applyLocationToUser(uid: uid, location: loc);
  }

  /// Saves the selected master location onto the user's profile.
  static Future<void> applyLocationToUser({
    required String uid,
    required FbLocation location,
  }) async {
    await Fb.db.collection('users').doc(uid).set({
      'locationId': location.id,
      'locationName': location.name,
      'allowedLocation': GeoPoint(location.lat, location.lng),
      'allowedRadiusMeters': location.radiusMeters,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}



class FbSupervisorProfile {
  final String uid;
  final String name;
  final String email;
  final String cnic;
  final String city;

  const FbSupervisorProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.cnic,
    required this.city,
  });

  static FbSupervisorProfile fromDoc(String uid, Map<String, dynamic> d) {
    return FbSupervisorProfile(
      uid: uid,
      name: (d['name'] ?? '').toString(),
      email: (d['email'] ?? '').toString(),
      cnic: (d['cnic'] ?? '').toString(),
      city: (d['city'] ?? '').toString(),
    );
  }
}

/// Supervisors are created by Admin from the Admin app.
/// Collection: supervisors/{uid}
class FbSupervisorRepo {
  static CollectionReference<Map<String, dynamic>> get _col =>
      Fb.db.collection('supervisors');

  static Stream<List<FbSupervisorProfile>> watchSupervisors() {
    return _col.orderBy('name').snapshots().map((q) {
      return q.docs
          .map((d) => FbSupervisorProfile.fromDoc(d.id, d.data()))
          .toList(growable: false);
    });
  }

  static Future<bool> isSupervisor(String uid) async {
    // 1) Prefer supervisors/{uid} doc (admin-created supervisor profile)
    try {
      final doc = await _col.doc(uid).get();
      if (doc.exists) return true;
    } catch (_) {
      // If rules don't allow reading supervisors collection for this user,
      // we still try the fallback below.
    }

    // 2) Fallback: users/{uid}.role == "supervisor"
    try {
      final userDoc = await Fb.db.collection('users').doc(uid).get();
      if (!userDoc.exists) return false;

      final role = (userDoc.data()?['role'] ?? '').toString().toLowerCase();
      return role == 'supervisor';
    } catch (_) {
      return false;
    }
  }

  /// Creates a supervisor Firebase Auth account WITHOUT logging out the admin,
  /// using a secondary Firebase app instance.
  static Future<void> createSupervisor({
    required String name,
    required String email,
    required String cnic,
    required String city,
    required String password,
  }) async {
    // Safety: only allow if current user is admin
    final currentUid = Fb.uid;
    if (currentUid == null) throw Exception('Not signed in');
    final admin = await FbAdminRepo.isAdmin(currentUid);
    if (!admin) throw Exception('Only admin can create supervisors');

    // Create in secondary app to avoid switching current auth session.
    final primaryApp = Firebase.app();
    final secondaryName = 'secondary_auth_app';
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app(secondaryName);
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryName,
        options: primaryApp.options,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    UserCredential cred;
    try {
      cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Re-throw with readable message for UI.
      throw Exception(e.message ?? e.code);
    } finally {
      // Ensure admin session not affected.
      await secondaryAuth.signOut();
    }

    final uid = cred.user?.uid;
    if (uid == null) throw Exception('Could not create supervisor user');

    // Save supervisor profile in Firestore
    await _col.doc(uid).set({
      'role': 'supervisor',
      'name': name.trim(),
      'email': email.trim(),
      'cnic': cnic.trim(),
      'city': city.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUid,
    }, SetOptions(merge: true));
  }

  static Future<void> deleteSupervisor(String uid) async {
    // Note: This only deletes Firestore profile, NOT the Auth user (needs Admin SDK).
    await _col.doc(uid).delete();
  }
}

/* -------------------------------------------------------------------------- */
/*                             Journey Plan Models                            */
/* -------------------------------------------------------------------------- */

class FbJourneyStop {
  final String id;
  final String locationId;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  bool isVisited;
  DateTime? checkIn;
  DateTime? checkOut;
  int? durationMinutes;

  FbJourneyStop({
    required this.id,
    required this.locationId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    this.isVisited = false,
    this.checkIn,
    this.checkOut,
    this.durationMinutes,
  });

  static FbJourneyStop fromDoc(String id, Map<String, dynamic> d) {
    final gp = d['allowedLocation'];
    double lat = 0;
    double lng = 0;
    if (gp is GeoPoint) {
      lat = gp.latitude;
      lng = gp.longitude;
    } else if (gp is Map) {
      lat = (gp['lat'] as num?)?.toDouble() ?? 0;
      lng = (gp['lng'] as num?)?.toDouble() ?? 0;
    }

    return FbJourneyStop(
      id: id,
      locationId: (d['locationId'] ?? '').toString(),
      name: (d['name'] ?? '').toString(),
      lat: lat,
      lng: lng,
      radiusMeters: (d['allowedRadiusMeters'] as num?)?.toDouble() ?? 100,
    );
  }
}

class FbJourneyPlan {
  final String id;
  final String supervisorId;
  final String periodType; // weekly/monthly
  final DateTime startDate;
  final DateTime endDate;

  const FbJourneyPlan({
    required this.id,
    required this.supervisorId,
    required this.periodType,
    required this.startDate,
    required this.endDate,
  });

  static DateTime _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static FbJourneyPlan fromDoc(String id, Map<String, dynamic> d) {
    return FbJourneyPlan(
      id: id,
      supervisorId: (d['supervisorId'] ?? '').toString(),
      periodType: (d['periodType'] ?? 'weekly').toString(),
      startDate: _toDate(d['startDate']),
      endDate: _toDate(d['endDate']),
    );
  }
}

/// Journey plans are created by Admin for each supervisor.
///
/// Firestore structure:
/// journeyPlans/{planId}
///   - supervisorId, periodType, startDate, endDate, createdAt, createdBy
/// journeyPlans/{planId}/stops/{stopId}
///   - locationId, name, allowedLocation (GeoPoint), allowedRadiusMeters
/// journeyPlans/{planId}/visits/{visitId}
///   - stopId, locationId, name, comment, checkIn, checkOut, durationMinutes, dateKey, createdAt
class FbJourneyRepo {
  static CollectionReference<Map<String, dynamic>> get _plans =>
      Fb.db.collection('journeyPlans');

  static CollectionReference<Map<String, dynamic>> _stops(String planId) =>
      _plans.doc(planId).collection('stops');

  static CollectionReference<Map<String, dynamic>> _visits(String planId) =>
      _plans.doc(planId).collection('visits');

  static String dateKey(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _inRange(DateTime day, DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return !day.isBefore(s) && !day.isAfter(e);
  }

  /// Admin: create plan + stops (selected from master locations).
  static Future<String> createPlan({
    required String supervisorId,
    required String periodType,
    required DateTime startDate,
    required DateTime endDate,
    required List<FbLocation> selectedLocations,
  }) async {
    final uid = Fb.uid;
    if (uid == null) throw Exception('Not signed in');

    final doc = _plans.doc();
    await doc.set({
      'supervisorId': supervisorId,
      'periodType': periodType,
      'startDate': Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)),
      'endDate': Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    });

    final batch = Fb.db.batch();
    for (final loc in selectedLocations) {
      final stopRef = _stops(doc.id).doc();
      batch.set(stopRef, {
        'locationId': loc.id,
        'name': loc.name,
        'allowedLocation': GeoPoint(loc.lat, loc.lng),
        'allowedRadiusMeters': loc.radiusMeters,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return doc.id;
  }

  /// Admin: list plans for a supervisor
  static Stream<List<FbJourneyPlan>> watchPlansForSupervisor(String supervisorId) {
    return _plans
        .where('supervisorId', isEqualTo: supervisorId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((q) => q.docs
            .map((d) => FbJourneyPlan.fromDoc(d.id, d.data()))
            .toList(growable: false));
  }

  /// Supervisor: fetch the current active plan for today.
  /// We keep the query simple (where supervisorId) and filter locally
  /// to avoid requiring composite indexes.
  static Future<FbJourneyPlan?> fetchActivePlanForToday({
    required String supervisorId,
  }) async {
    final today = DateTime.now();
    final q = await _plans
        .where('supervisorId', isEqualTo: supervisorId)
        .orderBy('startDate', descending: true)
        .limit(15)
        .get();

    for (final d in q.docs) {
      final plan = FbJourneyPlan.fromDoc(d.id, d.data());
      if (_inRange(today, plan.startDate, plan.endDate)) {
        return plan;
      }
    }
    return null;
  }

  static Stream<List<FbJourneyStop>> watchStops(String planId) {
    return _stops(planId).orderBy('name').snapshots().map((q) {
      return q.docs
          .map((d) => FbJourneyStop.fromDoc(d.id, d.data()))
          .toList(growable: false);
    });
  }

  static Stream<Map<String, Map<String, dynamic>>> watchTodayVisitsMap(String planId) {
    final key = dateKey(DateTime.now());
    return _visits(planId)
        .where('dateKey', isEqualTo: key)
        .snapshots()
        .map((q) {
      final out = <String, Map<String, dynamic>>{};
      for (final d in q.docs) {
        final m = d.data();
        final stopId = (m['stopId'] ?? '').toString();
        if (stopId.isNotEmpty) out[stopId] = m;
      }
      return out;
    });
  }

  /// Supervisor: add a visit record for a stop
  static Future<void> addVisit({
    required String planId,
    required FbJourneyStop stop,
    required String comment,
    required double currentLat,
    required double currentLng,
    required DateTime checkIn,
    required DateTime checkOut,
    required int durationMinutes,
  }) async {
    final uid = Fb.uid;
    if (uid == null) throw Exception('Not signed in');

    await _visits(planId).add({
      'supervisorId': uid,
      'stopId': stop.id,
      'locationId': stop.locationId,
      'name': stop.name,
      'comment': comment,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': Timestamp.fromDate(checkOut),
      'durationMinutes': durationMinutes,
      'dateKey': dateKey(DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
