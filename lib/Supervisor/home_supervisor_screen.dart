// journey_plan_map_screen.dart
// ✅ FULL UPDATED CODE (fixed FbJourneyStop + fixed alias usage + cleaned duplicate imports)
// NOTE: Keep your other files as-is. This file alone is updated.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:new_amst_flutter/Data/distance_utils.dart';
import 'package:new_amst_flutter/Firebase/fb_journey_plan_repo.dart' as jp;
import 'package:new_amst_flutter/Firebase/firebase_services.dart';
import 'package:new_amst_flutter/Model/super_journeyplan_model.dart';
import 'package:new_amst_flutter/Screens/auth_screen.dart';

/* --------------------------- Constants --------------------------- */

const kText = Color(0xFF1E1E1E);
const kMuted = Color(0xFF707883);
const kShadow = Color(0x14000000);

const _kGrad = LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// distance limit in meters to allow marking as visited
const double kVisitRadiusMeters = 13000;

// storage keys
const String _pendingVisitKey = 'pending_visit_v1';
const String _pendingVisitCheckInKey = 'pending_visit_checkin_v1';
const String _journeyDateKey = 'journey_date_v1';

String _visitedKeyFor(String date) => 'visited_$date';
String _endedKeyFor(String date) => 'journey_ended_$date';
String _visitDetailsKeyFor(String date) => 'visit_details_$date';

String _dateKey(DateTime dt) {
  final y = dt.year.toString();
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// If you already have these helpers in another file, keep yours.
// If not, these are safe fallbacks.
String formatTimeHM(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/* --------------------------- Helper Class --------------------------- */

class _JourneyWithDistance {
  final JourneyPlanSupervisor supervisor;
  final double distanceKm;

  _JourneyWithDistance({
    required this.supervisor,
    required this.distanceKm,
  });
}

/* --------------------------- Main Screen --------------------------- */

class JourneyPlanMapScreen extends StatefulWidget {
  const JourneyPlanMapScreen({super.key});

  @override
  State<JourneyPlanMapScreen> createState() => _JourneyPlanMapScreenState();
}

class _JourneyPlanMapScreenState extends State<JourneyPlanMapScreen> {
  Position? _currentPos;
  String? _error;
  bool _loading = true;

  // splash/map loading flags
  bool _mapCreated = false;
  bool _locationReady = false;
  bool _showSplash = true;

  late List<JourneyPlanSupervisor> _all;

  // Firestore journey plan doc id for today
  String? _planId;

  List<_JourneyWithDistance> _items = [];

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  final GetStorage _box = GetStorage();
  late String _todayKey;

  int get _totalLocations => _all.length;
  int get _completedLocations =>
      _all.where((x) => x.isVisited == true).length;

  @override
  void initState() {
    super.initState();
    _all = <JourneyPlanSupervisor>[];
    _todayKey = _dateKey(DateTime.now());

    _restoreDayState();
    _loadTodayPlan();

    _initLocation().then((_) async {
      await _restorePendingPopup();
      _maybeShowJourneyEnded();
    });
  }

  // Load today's journey plan (created by admin) from Firestore.
  Future<void> _loadTodayPlan() async {
    final uid = Fb.uid;
    if (uid == null) {
      setState(() {
        _error = 'Not signed in. Please login again.';
        _loading = false;
        _showSplash = false;
      });
      return;
    }

    try {
      final plan = await jp.FbJourneyPlanRepo.fetchActivePlanOnce(
        supervisorId: uid,
        now: DateTime.now(),
      );

      if (plan == null) {
        setState(() {
          _error = 'No journey plan assigned for today.';
          _loading = false;
          _showSplash = false;
        });
        return;
      }

      _planId = plan.id;

      final stops = await jp.FbJourneyPlanRepo.fetchStopsOnce(planId: plan.id);

      // Build UI list from stops
      _all = stops
          .map(
            (s) => JourneyPlanSupervisor(
              name: s.name,
              lat: s.lat,
              lng: s.lng,
              locationId: s.locationId,
              radiusMeters: s.radiusMeters,
            ),
          )
          .toList(growable: true);

      // Restore local day state after we have the dynamic list
      _restoreDayState();

      // Mark visited from Firestore (today visits)
      final visitedIds = await jp.FbJourneyPlanRepo.fetchVisitedLocationIdsForDay(
        planId: plan.id,
        dayKey: _todayKey,
      );

      for (final stop in _all) {
        final locId = stop.locationId;
        if (locId != null && locId.isNotEmpty && visitedIds.contains(locId)) {
          stop.isVisited = true;
        }
      }

      if (!mounted) return;

      if (_currentPos != null) {
        _computeDistancesAndMarkers();
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Failed to load journey plan: $e';
        _loading = false;
        _showSplash = false;
      });
    }
  }

  /* --------------------------- Daily persistence --------------------------- */

  void _restoreDayState() {
    final lastDate = _box.read<String>(_journeyDateKey);
    if (lastDate != _todayKey) {
      // new day -> reset day-related data
      _box.write(_journeyDateKey, _todayKey);
      _box.remove(_pendingVisitKey);
      _box.remove(_pendingVisitCheckInKey);
      if (lastDate != null) {
        _box.remove(_visitedKeyFor(lastDate));
        _box.remove(_endedKeyFor(lastDate));
        _box.remove(_visitDetailsKeyFor(lastDate));
      }
      for (final item in _all) {
        item.isVisited = false;
        item.checkIn = null;
        item.checkOut = null;
        item.durationMinutes = null;
      }
    } else {
      // same day -> restore visited list
      final raw = _box.read<List>(_visitedKeyFor(_todayKey)) ?? [];
      final visitedNames = raw.cast<String>();

      // restore visit details map
      final rawDetails = _box.read(_visitDetailsKeyFor(_todayKey));
      Map<String, dynamic> details = {};
      if (rawDetails is Map) {
        details = Map<String, dynamic>.from(rawDetails);
      }

      for (final item in _all) {
        item.isVisited = visitedNames.contains(item.name);

        final entry = details[item.name];
        if (entry is Map) {
          final checkInStr = entry['checkIn'] as String?;
          final checkOutStr = entry['checkOut'] as String?;
          final dur = entry['durationMinutes'];

          item.checkIn = checkInStr != null ? DateTime.tryParse(checkInStr) : null;
          item.checkOut = checkOutStr != null ? DateTime.tryParse(checkOutStr) : null;
          item.durationMinutes = (dur is int)
              ? dur
              : (dur is num)
                  ? dur.toInt()
                  : null;
        }
      }
    }
  }

  /* --------------------------- Location & distance --------------------------- */

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled.';
          _loading = false;
          _showSplash = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied.';
          _loading = false;
          _showSplash = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPos = pos;
      _computeDistancesAndMarkers();

      _locationReady = true;
      _maybeHideSplash();
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
        _loading = false;
        _showSplash = false;
      });
    }
  }

  void _computeDistancesAndMarkers() {
    if (_currentPos == null) {
      setState(() {
        _error = 'Current location unavailable.';
        _loading = false;
      });
      return;
    }

    final lat1 = _currentPos!.latitude;
    final lon1 = _currentPos!.longitude;

    _items = _all
        .map(
          (s) => _JourneyWithDistance(
            supervisor: s,
            distanceKm: distanceInKm(lat1, lon1, s.lat, s.lng),
          ),
        )
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    _buildMarkers();

    setState(() {
      _loading = false;
      _error = null;
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat1, lon1),
            zoom: 12.5,
          ),
        ),
      );
    }
  }

  void _buildMarkers() {
    final markers = <Marker>{};

    if (_currentPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPos!.latitude, _currentPos!.longitude),
          infoWindow: const InfoWindow(title: 'You are here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    for (final item in _items) {
      final stop = item.supervisor;
      markers.add(
        Marker(
          markerId: MarkerId(stop.name),
          position: LatLng(stop.lat, stop.lng),
          infoWindow: InfoWindow(
            title: stop.name,
            snippet: '${item.distanceKm.toStringAsFixed(1)} km away',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            stop.isVisited ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  /* ---------------------- Splash handling ---------------------- */

  void _maybeHideSplash() {
    if (!_mapCreated || !_locationReady || !_showSplash) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _showSplash = false;
      });
    });
  }

  /* ---------------------- Visit flow ---------------------- */

  void _onToggleVisited(_JourneyWithDistance item) {
    // 1) if today already ended, block everything
    final journeyEnded = _box.read<bool>(_endedKeyFor(_todayKey)) ?? false;
    if (journeyEnded) {
      _maybeShowJourneyEnded();
      return;
    }

    // 2) if already visited (checked out), do NOT allow another visit
    if (item.supervisor.isVisited) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You have already checked out from ${item.supervisor.name} today.'),
        ),
      );
      return;
    }

    // 3) require current location
    if (_currentPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available yet.')),
      );
      return;
    }

    // 4) distance check
    final dKm = distanceInKm(
      _currentPos!.latitude,
      _currentPos!.longitude,
      item.supervisor.lat,
      item.supervisor.lng,
    );
    final dMeters = dKm * 1000;

    final limitMeters = (item.supervisor.radiusMeters > 0)
        ? item.supervisor.radiusMeters
        : kVisitRadiusMeters;

    if (dMeters > limitMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You must be at ${item.supervisor.name} (within ${limitMeters.toStringAsFixed(0)} m).\n'
            'Current distance: ${dMeters.toStringAsFixed(0)} m',
          ),
        ),
      );
      return;
    }

    // 5) start visit flow
    _startVisitFlow(item.supervisor);
  }

  void _startVisitFlow(JourneyPlanSupervisor stop) {
    final now = DateTime.now();
    _box.write(_pendingVisitKey, stop.name);
    _box.write(_pendingVisitCheckInKey, now.toIso8601String()); // store check-in
    _showVisitPopup(stop);
  }

  Future<void> _restorePendingPopup() async {
    final pendingName = _box.read<String>(_pendingVisitKey);
    if (pendingName == null) return;

    JourneyPlanSupervisor? stop;
    for (final s in _all) {
      if (s.name == pendingName) {
        stop = s;
        break;
      }
    }
    if (stop == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showVisitPopup(stop!);
    });
  }

  Future<void> _showVisitPopup(JourneyPlanSupervisor stop) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        XFile? pickedImage;
        final commentCtrl = TextEditingController();
        bool submitting = false;

        return WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (ctx, setState) {
              Future<void> _pickImage() async {
                final picker = ImagePicker();
                final img = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (img != null) {
                  setState(() => pickedImage = img);
                }
              }

              final canSubmit =
                  pickedImage != null && commentCtrl.text.trim().isNotEmpty && !submitting;

              return AlertDialog(
                backgroundColor: Colors.white.withOpacity(0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                titlePadding: const EdgeInsets.only(top: 16, left: 20, right: 20),
                contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visit details',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: kText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.name,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 13,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.grey.shade100,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: pickedImage == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.camera_alt_rounded, size: 32, color: kMuted),
                                    SizedBox(height: 6),
                                    Text(
                                      'Capture outlet photo',
                                      style: TextStyle(
                                        fontFamily: 'ClashGrotesk',
                                        color: kMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(File(pickedImage!.path), fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F53FD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Take Photo',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Comments',
                          style: const TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: commentCtrl,
                        maxLines: 4,
                        minLines: 3,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Write 3–4 lines about display, stock, etc.',
                          hintStyle: const TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 12,
                            color: kMuted,
                          ),
                          fillColor: const Color(0xFFF2F3F5),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 13,
                          color: kText,
                        ),
                      ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C6FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: canSubmit
                          ? () {
                              setState(() => submitting = true);
                              Navigator.of(ctx).pop(<String, dynamic>{
                                'imagePath': pickedImage!.path,
                                'comment': commentCtrl.text.trim(),
                              });
                            }
                          : null,
                      child: submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      final checkInIso = _box.read<String>(_pendingVisitCheckInKey);
      DateTime? checkIn;
      if (checkInIso != null) {
        checkIn = DateTime.tryParse(checkInIso);
      }

      final checkOut = DateTime.now();
      final durationMinutes = checkIn != null ? checkOut.difference(checkIn).inMinutes : 0;

      _box.remove(_pendingVisitKey);
      _box.remove(_pendingVisitCheckInKey);

      _markVisitedPersist(
        stop,
        comment: (result['comment'] ?? '').toString(),
        checkIn: checkIn,
        checkOut: checkOut,
        durationMinutes: durationMinutes,
      );
    }
  }

  void _markVisitedPersist(
    JourneyPlanSupervisor stop, {
    required String comment,
    DateTime? checkIn,
    DateTime? checkOut,
    int? durationMinutes,
  }) {
    setState(() {
      stop.isVisited = true;
      stop.checkIn = checkIn;
      stop.checkOut = checkOut;
      stop.durationMinutes = durationMinutes;
    });

    // 1) mark as visited for UI
    final visitedKey = _visitedKeyFor(_todayKey);
    final raw = _box.read<List>(visitedKey) ?? [];
    final visited = raw.cast<String>();
    if (!visited.contains(stop.name)) visited.add(stop.name);
    _box.write(visitedKey, visited);

    // 2) store visit details
    final detailsKey = _visitDetailsKeyFor(_todayKey);
    final rawDetails = _box.read(detailsKey);
    final details = (rawDetails is Map)
        ? Map<String, dynamic>.from(rawDetails)
        : <String, dynamic>{};

    details[stop.name] = {
      'checkIn': checkIn?.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'comment': comment,
    };
    _box.write(detailsKey, details);

    // 3) Persist visit to Firestore ✅ (FIXED: use jp. prefix everywhere)
    final planId = _planId;
    final locId = stop.locationId;

    if (planId != null && locId != null && locId.isNotEmpty) {
      jp.FbJourneyPlanRepo.addVisit(
        planId: planId,
        // FbJourneyStop model is defined in firebase_services.dart
        stop: FbJourneyStop(
          id: locId,
          locationId: locId,
          name: stop.name,
          // ✅ match constructor in firebase_services.dart
          lat: stop.lat,
          lng: stop.lng,
          radiusMeters: stop.radiusMeters,
        ),
        comment: comment,
        checkIn: checkIn,
        checkOut: checkOut,
      );
    }

    _buildMarkers();

    // 4) if all completed, end journey for today
    if (_completedLocations == _totalLocations) {
      _box.write(_endedKeyFor(_todayKey), true);
      _maybeShowJourneyEnded();
    }
  }

  /* --------------------------- Journey ended popup --------------------------- */

  void _maybeShowJourneyEnded() {
    final ended = _box.read<bool>(_endedKeyFor(_todayKey)) ?? false;
    if (!ended) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showJourneyEndedDialog();
    });
  }

  Future<void> _showJourneyEndedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Today's journey ended",
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'You have visited all outlets planned for today.\n\n'
              'Please come back tomorrow to start a new journey.',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* --------------------------- BUILD --------------------------- */

  Future<void> _logout() async {
    final storage = GetStorage();
    await storage.remove("supervisor_loggedIn");

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _currentPos != null;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: _kGrad),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasLocation
                      ? GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(_currentPos!.latitude, _currentPos!.longitude),
                            zoom: 12.0,
                          ),
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          compassEnabled: true,
                          markers: _markers,
                          onMapCreated: (c) {
                            _mapController = c;
                            _mapCreated = true;
                            _maybeHideSplash();
                          },
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                ),

                // top gradient overlay
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 30,
                        child: _PrimaryGradientButton(
                          text: 'Logout',
                          onPressed: _logout,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!_loading && _error != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'ClashGrotesk',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                if (!_loading && _error == null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 260),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.3,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Nearby Outlets',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                          fontFamily: 'ClashGrotesk',
                                        ),
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${_items.length} stops',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'ClashGrotesk',
                                            ),
                                          ),
                                          Text(
                                            'Done: $_completedLocations',
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'ClashGrotesk',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                                    itemCount: _items.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) {
                                      final item = _items[i];
                                      return _GlassJourneyCard(
                                        index: i + 1,
                                        data: item,
                                        onTap: () {
                                          _mapController?.animateCamera(
                                            CameraUpdate.newCameraPosition(
                                              CameraPosition(
                                                target: LatLng(
                                                  item.supervisor.lat,
                                                  item.supervisor.lng,
                                                ),
                                                zoom: 15.5,
                                              ),
                                            ),
                                          );
                                        },
                                        onToggleVisited: () => _onToggleVisited(item),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Splash overlay
          if (_showSplash)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.map_rounded, size: 72, color: Color(0xFF7F53FD)),
                    SizedBox(height: 16),
                    Text(
                      'Loading map & outlets...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kText,
                      ),
                    ),
                    SizedBox(height: 12),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* --------------------------- UI Widgets --------------------------- */

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  }) : super(key: key);

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  static const _grad = LinearGradient(
    colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: _grad,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassJourneyCard extends StatelessWidget {
  const _GlassJourneyCard({
    required this.index,
    required this.data,
    required this.onTap,
    required this.onToggleVisited,
  });

  final int index;
  final _JourneyWithDistance data;
  final VoidCallback onTap;
  final VoidCallback onToggleVisited;

  @override
  Widget build(BuildContext context) {
    final stop = data.supervisor;
    final distText = '${data.distanceKm.toStringAsFixed(1)} km';

    String? timeText;
    if (stop.checkIn != null && stop.checkOut != null) {
      final inStr = formatTimeHM(stop.checkIn!);
      final outStr = formatTimeHM(stop.checkOut!);
      if (stop.durationMinutes != null) {
        timeText = '$inStr – $outStr • ${stop.durationMinutes} min';
      } else {
        timeText = '$inStr – $outStr';
      }
    } else if (stop.checkIn != null) {
      timeText = 'Check-in: ${formatTimeHM(stop.checkIn!)}';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withOpacity(0.5),
            width: 0.9,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.white, Color(0xFFECFEFF)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'ClashGrotesk',
                    color: kText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ClashGrotesk',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        distText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'ClashGrotesk',
                        ),
                      ),
                    ],
                  ),
                  if (timeText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'ClashGrotesk',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onToggleVisited,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: stop.isVisited
                      ? Colors.greenAccent.withOpacity(0.18)
                      : Colors.orangeAccent.withOpacity(0.18),
                  border: Border.all(
                    color: stop.isVisited ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stop.isVisited
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: stop.isVisited ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      stop.isVisited ? 'Visited' : 'Pending',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'ClashGrotesk',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}









// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:new_amst_flutter/Data/distance_utils.dart';
// import 'package:new_amst_flutter/Firebase/fb_journey_plan_repo.dart' as jp;

// import 'package:new_amst_flutter/Model/super_journeyplan_model.dart';
// import 'dart:ui';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:get_storage/get_storage.dart';
// import '../Firebase/firebase_services.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:get_storage/get_storage.dart';
// import '../Firebase/firebase_services.dart';
// import 'dart:io';
// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:get_storage/get_storage.dart';
// import '../Firebase/firebase_services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:new_amst_flutter/Bloc/auth_bloc.dart';
// import 'package:new_amst_flutter/Bloc/auth_event.dart';
// import 'package:new_amst_flutter/Bloc/auth_state.dart';
// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get_storage/get_storage.dart';
// import '../Firebase/firebase_services.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:new_amst_flutter/Screens/auth_screen.dart';
// import 'package:new_amst_flutter/Firebase/firebase_services.dart';
// /* --------------------------- Constants --------------------------- */

// const kText = Color(0xFF1E1E1E);
// const kMuted = Color(0xFF707883);
// const kShadow = Color(0x14000000);

// const _kGrad = LinearGradient(
//   colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
//   begin: Alignment.topLeft,
//   end: Alignment.bottomRight,
// );

// // distance limit in meters to allow marking as visited
// const double kVisitRadiusMeters = 13000;

// // storage keys
// const String _pendingVisitKey = 'pending_visit_v1';
// const String _pendingVisitCheckInKey = 'pending_visit_checkin_v1';
// const String _journeyDateKey = 'journey_date_v1';

// String _visitedKeyFor(String date) => 'visited_$date';
// String _endedKeyFor(String date) => 'journey_ended_$date';
// String _visitDetailsKeyFor(String date) => 'visit_details_$date';

// String _dateKey(DateTime dt) {
//   final y = dt.year.toString();
//   final m = dt.month.toString().padLeft(2, '0');
//   final d = dt.day.toString().padLeft(2, '0');
//   return '$y-$m-$d';
// }

// /* --------------------------- Helper Class --------------------------- */

// class _JourneyWithDistance {
//   final JourneyPlanSupervisor supervisor;
//   final double distanceKm;

//   _JourneyWithDistance({
//     required this.supervisor,
//     required this.distanceKm,
//   });
// }

// /* --------------------------- Main Screen --------------------------- */

// class JourneyPlanMapScreen extends StatefulWidget {
//   const JourneyPlanMapScreen({super.key});

//   @override
//   State<JourneyPlanMapScreen> createState() => _JourneyPlanMapScreenState();
// }

// class _JourneyPlanMapScreenState extends State<JourneyPlanMapScreen> {
//   Position? _currentPos;
//   String? _error;
//   bool _loading = true;

//   // splash/map loading flags
//   bool _mapCreated = false;
//   bool _locationReady = false;
//   bool _showSplash = true;

//   late List<JourneyPlanSupervisor> _all;

//   // Firestore journey plan doc id for today
//   String? _planId;

//   List<_JourneyWithDistance> _items = [];

//   GoogleMapController? _mapController;
//   final Set<Marker> _markers = {};

//   final GetStorage _box = GetStorage();
//   late String _todayKey;

//   int get _totalLocations => _all.length;
//   int get _completedLocations =>
//       _all.where((jp) => jp.isVisited == true).length;

//   @override
//   void initState() {
//     super.initState();
//     _all = <JourneyPlanSupervisor>[];
//     _loadTodayPlan();
//     _todayKey = _dateKey(DateTime.now());
//     _restoreDayState();
//     _initLocation().then((_) async {
//       await _restorePendingPopup();
//       _maybeShowJourneyEnded();
//     });
//   }

//   // Load today's journey plan (created by admin) from Firestore.
//   Future<void> _loadTodayPlan() async {
//     final uid = Fb.uid;
//     if (uid == null) {
//       setState(() {
//         _error = 'Not signed in. Please login again.';
//         _loading = false;
//         _showSplash = false;
//       });
//       return;
//     }

//     try {
//       final plan = await jp.FbJourneyPlanRepo.fetchActivePlanOnce(
//         supervisorId: uid,
//         now: DateTime.now(),
//       );
//       if (plan == null) {
//         setState(() {
//           _error = 'No journey plan assigned for today.';
//           _loading = false;
//           _showSplash = false;
//         });
//         return;
//       }

//       _planId = plan.id;

//       final stops = await jp.FbJourneyPlanRepo.fetchStopsOnce(planId: plan.id);

//       // Build UI list from stops
//       _all = stops
//           .map(
//             (s) => JourneyPlanSupervisor(
//               name: s.name,
//               lat: s.lat,
//               lng: s.lng,
//               locationId: s.locationId,
//               radiusMeters: s.radiusMeters,
//             ),
//           )
//           .toList(growable: true);

//       // Restore local day state after we have the dynamic list
//       _restoreDayState();

//       // Mark visited from Firestore (today visits)
//       final todayKey = _todayKey;
//       final visitedIds = await jp.FbJourneyPlanRepo.fetchVisitedLocationIdsForDay(
//         planId: plan.id,
//         dayKey: todayKey,
//       );
//       for (final jp in _all) {
//         if (jp.locationId != null && visitedIds.contains(jp.locationId)) {
//           jp.isVisited = true;
//         }
//       }

//       if (!mounted) return;
//       // If location already available, recalc markers and list
//       if (_currentPos != null) {
//         _computeDistancesAndMarkers();
//       }

//       setState(() {});
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to load journey plan: $e';
//         _loading = false;
//         _showSplash = false;
//       });
//     }
//   }


//   /* --------------------------- Daily persistence --------------------------- */

//   void _restoreDayState() {
//     final lastDate = _box.read<String>(_journeyDateKey);
//     if (lastDate != _todayKey) {
//       // new day -> reset day-related data
//       _box.write(_journeyDateKey, _todayKey);
//       _box.remove(_pendingVisitKey);
//       _box.remove(_pendingVisitCheckInKey);
//       if (lastDate != null) {
//         _box.remove(_visitedKeyFor(lastDate));
//         _box.remove(_endedKeyFor(lastDate));
//         _box.remove(_visitDetailsKeyFor(lastDate));
//       }
//       for (final jp in _all) {
//         jp.isVisited = false;
//         jp.checkIn = null;
//         jp.checkOut = null;
//         jp.durationMinutes = null;
//       }
//     } else {
//       // same day -> restore visited list
//       final raw = _box.read<List>(_visitedKeyFor(_todayKey)) ?? [];
//       final visitedNames = raw.cast<String>();

//       // restore visit details map
//       final rawDetails = _box.read(_visitDetailsKeyFor(_todayKey));
//       Map<String, dynamic> details = {};
//       if (rawDetails is Map) {
//         details = Map<String, dynamic>.from(rawDetails);
//       }

//       for (final jp in _all) {
//         jp.isVisited = visitedNames.contains(jp.name);

//         final entry = details[jp.name];
//         if (entry is Map) {
//           final checkInStr = entry['checkIn'] as String?;
//           final checkOutStr = entry['checkOut'] as String?;
//           final dur = entry['durationMinutes'];

//           jp.checkIn =
//               checkInStr != null ? DateTime.tryParse(checkInStr) : null;
//           jp.checkOut =
//               checkOutStr != null ? DateTime.tryParse(checkOutStr) : null;
//           jp.durationMinutes = (dur is int)
//               ? dur
//               : (dur is num)
//                   ? dur.toInt()
//                   : null;
//         }
//       }
//     }
//   }

//   /* --------------------------- Location & distance --------------------------- */

//   Future<void> _initLocation() async {
//     try {
//       final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         setState(() {
//           _error = 'Location services are disabled.';
//           _loading = false;
//           _showSplash = false;
//         });
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         setState(() {
//           _error = 'Location permission denied.';
//           _loading = false;
//           _showSplash = false;
//         });
//         return;
//       }

//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       _currentPos = pos;
//       _computeDistancesAndMarkers();
//       _locationReady = true;
//       _maybeHideSplash();
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to get location: $e';
//         _loading = false;
//         _showSplash = false;
//       });
//     }
//   }

//   void _computeDistancesAndMarkers() {
//     if (_currentPos == null) {
//       setState(() {
//         _error = 'Current location unavailable.';
//         _loading = false;
//       });
//       return;
//     }

//     final lat1 = _currentPos!.latitude;
//     final lon1 = _currentPos!.longitude;

//     _items = _all
//         .map(
//           (jp) => _JourneyWithDistance(
//             supervisor: jp,
//             distanceKm: distanceInKm(lat1, lon1, jp.lat, jp.lng),
//           ),
//         )
//         .toList()
//       ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

//     _buildMarkers();

//     setState(() {
//       _loading = false;
//       _error = null;
//     });

//     if (_mapController != null) {
//       _mapController!.animateCamera(
//         CameraUpdate.newCameraPosition(
//           CameraPosition(
//             target: LatLng(lat1, lon1),
//             zoom: 12.5,
//           ),
//         ),
//       );
//     }
//   }

//   void _buildMarkers() {
//     final markers = <Marker>{};

//     if (_currentPos != null) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId('current_location'),
//           position: LatLng(_currentPos!.latitude, _currentPos!.longitude),
//           infoWindow: const InfoWindow(title: 'You are here'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueAzure,
//           ),
//         ),
//       );
//     }

//     for (final item in _items) {
//       final jp = item.supervisor;
//       markers.add(
//         Marker(
//           markerId: MarkerId(jp.name),
//           position: LatLng(jp.lat, jp.lng),
//           infoWindow: InfoWindow(
//             title: jp.name,
//             snippet: '${item.distanceKm.toStringAsFixed(1)} km away',
//           ),
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             jp.isVisited ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
//           ),
//         ),
//       );
//     }

//     setState(() {
//       _markers
//         ..clear()
//         ..addAll(markers);
//     });
//   }

//   /* ---------------------- Splash handling (approx 90% loaded) ---------------------- */

//   void _maybeHideSplash() {
//     if (!_mapCreated || !_locationReady || !_showSplash) return;

//     // fake "90% loaded": small delay after both map & location are ready
//     Future.delayed(const Duration(seconds: 2), () {
//       if (!mounted) return;
//       setState(() {
//         _showSplash = false;
//       });
//     });
//   }

//   /* ---------------------- Forced popup / visited flow ---------------------- */

//   void _onToggleVisited(_JourneyWithDistance item) {
//     // 1) if today already ended, block everything
//     final journeyEnded = _box.read<bool>(_endedKeyFor(_todayKey)) ?? false;
//     if (journeyEnded) {
//       _maybeShowJourneyEnded();
//       return;
//     }

//     // 2) if already visited (checked out), do NOT allow another visit
//     if (item.supervisor.isVisited) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'You have already checked out from ${item.supervisor.name} today.',
//           ),
//         ),
//       );
//       return;
//     }

//     // 3) require current location
//     if (_currentPos == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Current location not available yet.'),
//         ),
//       );
//       return;
//     }

//     // 4) distance check
//     final dKm = distanceInKm(
//       _currentPos!.latitude,
//       _currentPos!.longitude,
//       item.supervisor.lat,
//       item.supervisor.lng,
//     );
//     final dMeters = dKm * 1000;

//     final limitMeters = (item.supervisor.radiusMeters > 0)
//         ? item.supervisor.radiusMeters
//         : kVisitRadiusMeters;

//     if (dMeters > limitMeters) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'You must be at ${item.supervisor.name} (within '
//             '${limitMeters.toStringAsFixed(0)} m).\n'
//             'Current distance: ${dMeters.toStringAsFixed(0)} m',
//           ),
//         ),
//       );
//       return;
//     }

//     // 5) start visit flow (check-in now)
//     _startVisitFlow(item.supervisor);
//   }

//   void _startVisitFlow(JourneyPlanSupervisor jp) {
//     final now = DateTime.now();
//     _box.write(_pendingVisitKey, jp.name);
//     _box.write(_pendingVisitCheckInKey, now.toIso8601String()); // store check-in
//     _showVisitPopup(jp);
//   }

//   Future<void> _restorePendingPopup() async {
//     final pendingName = _box.read<String>(_pendingVisitKey);
//     if (pendingName == null) return;

//     JourneyPlanSupervisor? jp;
//     for (final s in _all) {
//       if (s.name == pendingName) {
//         jp = s;
//         break;
//       }
//     }
//     if (jp == null) return;

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _showVisitPopup(jp!);
//     });
//   }

//   Future<void> _showVisitPopup(JourneyPlanSupervisor jp) async {
//     final result = await showDialog<Map<String, dynamic>?>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) {
//         XFile? pickedImage;
//         final commentCtrl = TextEditingController();
//         bool submitting = false;

//         return WillPopScope(
//           onWillPop: () async => false,
//           child: StatefulBuilder(
//             builder: (ctx, setState) {
//               Future<void> _pickImage() async {
//                 final picker = ImagePicker();
//                 final img = await picker.pickImage(
//                   source: ImageSource.camera,
//                   imageQuality: 80,
//                 );
//                 if (img != null) {
//                   setState(() => pickedImage = img);
//                 }
//               }

//               final canSubmit = pickedImage != null &&
//                   commentCtrl.text.trim().isNotEmpty &&
//                   !submitting;

//               return AlertDialog(
//                 backgroundColor: Colors.white.withOpacity(0.95),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 titlePadding:
//                     const EdgeInsets.only(top: 16, left: 20, right: 20),
//                 contentPadding:
//                     const EdgeInsets.fromLTRB(20, 8, 20, 16),
//                 title: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Visit details',
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontWeight: FontWeight.w700,
//                         fontSize: 18,
//                         color: kText,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       jp.name,
//                       style: const TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 13,
//                         color: kMuted,
//                       ),
//                     ),
//                   ],
//                 ),
//                 content: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Container(
//                         height: 160,
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: Colors.grey.shade300,
//                           ),
//                           color: Colors.grey.shade100,
//                         ),
//                         clipBehavior: Clip.antiAlias,
//                         child: pickedImage == null
//                             ? Center(
//                                 child: Column(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: const [
//                                     Icon(Icons.camera_alt_rounded,
//                                         size: 32, color: kMuted),
//                                     SizedBox(height: 6),
//                                     Text(
//                                       'Capture outlet photo',
//                                       style: TextStyle(
//                                         fontFamily: 'ClashGrotesk',
//                                         color: kMuted,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               )
//                             : Image.file(
//                                 File(pickedImage!.path),
//                                 fit: BoxFit.cover,
//                               ),
//                       ),
//                       const SizedBox(height: 12),
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton.icon(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF7F53FD),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(14),
//                             ),
//                           ),
//                           onPressed: _pickImage,
//                           icon: const Icon(Icons.camera_alt_rounded,
//                               size: 18, color: Colors.white),
//                           label: const Text(
//                             'Take Photo',
//                             style: TextStyle(
//                               fontFamily: 'ClashGrotesk',
//                               color: Colors.white,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: Text(
//                           'Comments',
//                           style: const TextStyle(
//                             fontFamily: 'ClashGrotesk',
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: kText,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 6),
//                       TextField(
//                         controller: commentCtrl,
//                         maxLines: 4,
//                         minLines: 3,
//                         onChanged: (_) => setState(() {}),
//                         decoration: InputDecoration(
//                           hintText:
//                               'Write 3–4 lines about display, stock, etc.',
//                           hintStyle: const TextStyle(
//                             fontFamily: 'ClashGrotesk',
//                             fontSize: 12,
//                             color: kMuted,
//                           ),
//                           fillColor: const Color(0xFFF2F3F5),
//                           filled: true,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(14),
//                             borderSide: BorderSide.none,
//                           ),
//                         ),
//                         style: const TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontSize: 13,
//                           color: kText,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 actionsPadding:
//                     const EdgeInsets.fromLTRB(20, 0, 20, 12),
//                 actions: [
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF00C6FF),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(18),
//                         ),
//                         padding: const EdgeInsets.symmetric(vertical: 10),
//                       ),
//                       onPressed: canSubmit
//                           ? () async {
//                               setState(() => submitting = true);
//                               Navigator.of(ctx).pop(<String, dynamic>{
//                                 'imagePath': pickedImage!.path,
//                                 'comment': commentCtrl.text.trim(),
//                               });
//                             }
//                           : null,
//                       child: submitting
//                           ? const SizedBox(
//                               height: 18,
//                               width: 18,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 valueColor:
//                                     AlwaysStoppedAnimation<Color>(Colors.white),
//                               ),
//                             )
//                           : const Text(
//                               'Submit',
//                               style: TextStyle(
//                                 fontFamily: 'ClashGrotesk',
//                                 fontWeight: FontWeight.w700,
//                                 color: Colors.white,
//                               ),
//                             ),
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),
//         );
//       },
//     );

//     if (result != null) {
//       // compute checkout & duration
//       final checkInIso = _box.read<String>(_pendingVisitCheckInKey);
//       DateTime? checkIn;
//       if (checkInIso != null) {
//         checkIn = DateTime.tryParse(checkInIso);
//       }
//       final checkOut = DateTime.now();
//       final durationMinutes =
//           checkIn != null ? checkOut.difference(checkIn).inMinutes : 0;

//       _box.remove(_pendingVisitKey);
//       _box.remove(_pendingVisitCheckInKey);

//       _markVisitedPersist(
//         jp,
//         checkIn: checkIn,
//         checkOut: checkOut,
//         durationMinutes: durationMinutes,
//       );
//     }
//   }

//   void _markVisitedPersist(
//     JourneyPlanSupervisor jp, {
//     DateTime? checkIn,
//     DateTime? checkOut,
//     int? durationMinutes,
//   }) {
//     setState(() {
//       jp.isVisited = true;
//       jp.checkIn = checkIn;
//       jp.checkOut = checkOut;
//       jp.durationMinutes = durationMinutes;
//     });

//     // 1) mark as visited for UI
//     final visitedKey = _visitedKeyFor(_todayKey);
//     final raw = _box.read<List>(visitedKey) ?? [];
//     final visited = raw.cast<String>();
//     if (!visited.contains(jp.name)) {
//       visited.add(jp.name);
//     }
//     _box.write(visitedKey, visited);

//     // 2) store visit details (check-in, check-out, duration)
//     final detailsKey = _visitDetailsKeyFor(_todayKey);
//     final rawDetails = _box.read(detailsKey);
//     Map<String, dynamic> details;
//     if (rawDetails is Map) {
//       details = Map<String, dynamic>.from(rawDetails);
//     } else {
//       details = {};
//     }
//     details[jp.name] = {
//       'checkIn': checkIn?.toIso8601String(),
//       'checkOut': checkOut?.toIso8601String(),
//       'durationMinutes': durationMinutes,
//     };
//     _box.write(detailsKey, details);

//     // 2b) Persist visit to Firestore (so Admin can see progress)
//     final planId = _planId;
//     if (planId != null && jp.locationId != null && jp.locationId!.isNotEmpty) {
//       FbJourneyPlanRepo.addVisit(
//   planId: planId,
//   stop: FbJourneyStop(
//     id: (jp.locationId ?? jp.name).toString(),
//     locationId: (jp.locationId ?? '').toString(),
//     name: jp.name,
//     lat: jp.lat,
//     lng: jp.lng,
//     radiusMeters: jp.radiusMeters,
//    // sortIndex: 0, // ✅ required (we don’t need it for visits, but constructor needs it)
//   ),
//   comment: '', // (you can pass your comment later)
//   checkIn: checkIn,
//   checkOut: checkOut,
// );

//       // Fire-and-forget. If it fails, we still keep local state.
//       // FbJourneyPlanRepo.addVisit(
//       //   planId: planId,
//       //   stop: FbJourneyStop(
//       //     id: jp.locationId ?? jp.name,
//       //     locationId: jp.locationId ?? '',
//       //     name: jp.name,
//       //     lat: jp.lat,
//       //     lng: jp.lng,
//       //     radiusMeters: jp.radiusMeters,
//       //   ),
//       //   comment: '',
//       //   checkIn: checkIn,
//       //   checkOut: checkOut,
//       // );
//     }

//     _buildMarkers();

//     // 3) if all completed, end journey for today
//     if (_completedLocations == _totalLocations) {
//       _box.write(_endedKeyFor(_todayKey), true);
//       _maybeShowJourneyEnded();
//     }
//   }

//   /* --------------------------- Journey ended popup --------------------------- */

//   void _maybeShowJourneyEnded() {
//     final ended = _box.read<bool>(_endedKeyFor(_todayKey)) ?? false;
//     if (!ended) return;

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _showJourneyEndedDialog();
//     });
//   }

//   Future<void> _showJourneyEndedDialog() async {
//     await showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) {
//         return WillPopScope(
//           onWillPop: () async => false,
//           child: AlertDialog(
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             title: const Text(
//               "Today's journey ended",
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//             content: const Text(
//               'You have visited all outlets planned for today.\n\n'
//               'Please come back tomorrow to start a new journey.',
//               style: TextStyle(
//                 fontFamily: 'ClashGrotesk',
//                 fontSize: 13,
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(ctx).pop();
//                 },
//                 child: const Text(
//                   'OK',
//                   style: TextStyle(
//                     fontFamily: 'ClashGrotesk',
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   /* --------------------------- RECENTER BUTTON --------------------------- */

//   Future<void> _recenterOnUser() async {
//     if (_mapController == null) return;

//     if (_currentPos == null) {
//       setState(() => _loading = true);
//       await _initLocation();
//       setState(() => _loading = false);
//       if (_currentPos == null) return;
//     }

//     final target = LatLng(
//       _currentPos!.latitude,
//       _currentPos!.longitude,
//     );

//     await _mapController!.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: target,
//           zoom: 15.0,
//         ),
//       ),
//     );
//   }

//   /* --------------------------- BUILD --------------------------- */

//   @override
//   Widget build(BuildContext context) {
//     final hasLocation = _currentPos != null;

//     logout()async{
//       var storage = GetStorage();
  

//   await storage.remove("supervisor_loggedIn");

//   if (!context.mounted) return;

//   Navigator.of(context).pushAndRemoveUntil(
//     MaterialPageRoute(builder: (_) => const AuthScreen()),
//     (route) => false,
//   );


//     }


//     return Scaffold(
//       body: Stack(
//         children: [
//           Container(
//             decoration: const BoxDecoration(
//               gradient: _kGrad,
//             ),
//             child: Stack(
//               children: [
//                 Positioned.fill(
//                   child: hasLocation
//                       ? GoogleMap(
//                           initialCameraPosition: CameraPosition(
//                             target: LatLng(
//                               _currentPos!.latitude,
//                               _currentPos!.longitude,
//                             ),
//                             zoom: 12.0,
//                           ),
//                           myLocationEnabled: true,
//                           myLocationButtonEnabled: false,
//                           compassEnabled: true,
//                           markers: _markers,
//                           onMapCreated: (c) {
//                             _mapController = c;
//                             _mapCreated = true;
//                             _maybeHideSplash();
//                           },
//                         )
//                       : const Center(
//                           child: CircularProgressIndicator(
//                             valueColor:
//                                 AlwaysStoppedAnimation<Color>(Colors.white),
//                           ),
//                         ),
//                 ),

//                 // top gradient overlay
//                 Container(
//                   height: 96,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [
//                         Colors.black.withOpacity(0.4),
//                         Colors.transparent,
//                       ],
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                     ),
//                   ),
//                 ),

//                 // header
//                 Padding(
//                   padding:
//                        EdgeInsets.symmetric(horizontal: 26, vertical: 40),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: Padding(
//                           padding:  EdgeInsets.only(bottom: 0),
//                           child: Row(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children:  [

//                              SizedBox(
//   width: 100,
//   height: 30,
//   child: _PrimaryGradientButton(
//     text: 'Logout',
//     onPressed: logout,
//     // loading: true, // optional, if you want a spinner
//   ),
// ),

     
//                               // Text(
//                               //   'Journey Plan',
//                               //   style: TextStyle(
//                               //     color: Colors.white,
//                               //     fontSize: 25,
//                               //     fontWeight: FontWeight.bold,
//                               //   ),
//                               // ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 if (!_loading && _error != null)
//                   Center(
//                     child: Container(
//                       padding:  EdgeInsets.symmetric(
//                           horizontal: 16, vertical: 12),
//                       margin:  EdgeInsets.symmetric(horizontal: 24),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.6),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Text(
//                         _error!,
//                         textAlign: TextAlign.center,
//                         style:  TextStyle(
//                           color: Colors.white,
//                           fontFamily: 'ClashGrotesk',
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ),

//                 if (!_loading && _error == null)
//                   Align(
//                     alignment: Alignment.bottomCenter,
//                     child: Padding(
//                       padding:  EdgeInsets.fromLTRB(12, 0, 12, 16),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(20),
//                         child: BackdropFilter(
//                           filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
//                           child: Container(
//                             width: double.infinity,
//                             constraints:  BoxConstraints(maxHeight: 260),
//                             decoration: BoxDecoration(
//                               color: Colors.white.withOpacity(0.16),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(
//                                 color: Colors.white.withOpacity(0.35),
//                                 width: 1.3,
//                               ),
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Padding(
//                                   padding:  EdgeInsets.fromLTRB(
//                                       16, 10, 16, 4),
//                                   child: Row(
//                                     children: [
//                                       const Text(
//                                         'Nearby Outlets',
//                                         style: TextStyle(
//                                           color: Colors.black,
//                                           fontWeight: FontWeight.w900,
//                                           fontSize: 15,
//                                           fontFamily: 'ClashGrotesk',
//                                         ),
//                                       ),
//                                       const Spacer(),
//                                       Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.end,
//                                         children: [
//                                           Text(
//                                             '${_items.length} stops',
//                                             style: const TextStyle(
//                                               color: Colors.black,
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.w900,
//                                               fontFamily: 'ClashGrotesk',
//                                             ),
//                                           ),
//                                           Text(
//                                             'Done: $_completedLocations',
//                                             style: const TextStyle(
//                                               color: Colors.greenAccent,
//                                               fontSize: 12,
//                                               fontWeight: FontWeight.w900,
//                                               fontFamily: 'ClashGrotesk',
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Expanded(
//                                   child: ListView.separated(
//                                     padding: const EdgeInsets.fromLTRB(
//                                         12, 4, 12, 12),
//                                     itemCount: _items.length,
//                                     separatorBuilder: (_, __) =>
//                                         const SizedBox(height: 8),
//                                     itemBuilder: (_, i) {
//                                       final item = _items[i];
//                                       return _GlassJourneyCard(
//                                         index: i + 1,
//                                         data: item,
//                                         onTap: () {
//                                           _mapController?.animateCamera(
//                                             CameraUpdate.newCameraPosition(
//                                               CameraPosition(
//                                                 target: LatLng(
//                                                   item.supervisor.lat,
//                                                   item.supervisor.lng,
//                                                 ),
//                                                 zoom: 15.5,
//                                               ),
//                                             ),
//                                           );
//                                         },
//                                         onToggleVisited: () =>
//                                             _onToggleVisited(item),
//                                       );
//                                     },
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),

//           // ------------- FULL-SCREEN SPLASH OVERLAY -------------
//           if (_showSplash)
//             Positioned.fill(
//               child: Container(
//                 color: Colors.white,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: const [
//                     // put your logo here if you want
//                     Icon(
//                       Icons.map_rounded,
//                       size: 72,
//                       color: Color(0xFF7F53FD),
//                     ),
//                     SizedBox(height: 16),
//                     Text(
//                       'Loading map & outlets...',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: kText,
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     CircularProgressIndicator(),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }


// class _PrimaryGradientButton extends StatelessWidget {
//   const _PrimaryGradientButton({
//     Key? key,
//     required this.text,
//     required this.onPressed,
//     this.loading = false,
//   }) : super(key: key);

//   final String text;
//   final VoidCallback? onPressed;
//   final bool loading;

//   static const _grad = LinearGradient(
//     colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//     begin: Alignment.centerLeft,
//     end: Alignment.centerRight,
//   );

//   @override
//   Widget build(BuildContext context) {
//     final disabled = loading || onPressed == null;

//     return Opacity(
//       opacity: disabled ? 0.6 : 1.0,
//       child: Container(
//         height: 54,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(8),
//           gradient: _grad,
//           boxShadow: [
//             BoxShadow(
//               color: const Color(0xFF7F53FD).withOpacity(0.25),
//               blurRadius: 18,
//               offset: const Offset(0, 8),
//             ),
//           ],
//         ),
//         child: Material(
//           color: Colors.transparent,
//           child: InkWell(
//             borderRadius: BorderRadius.circular(28),
//             onTap: disabled ? null : onPressed,
//             child: Center(
//               child: loading
//                   ? const SizedBox(
//                       height: 20,
//                       width: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         valueColor:
//                             AlwaysStoppedAnimation<Color>(Colors.white),
//                       ),
//                     )
//                   : Text(
//                       text,
//                       style: const TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.white,
//                       ),
//                     ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }


// /* --------------------------- Glass Card Row --------------------------- */

// class _GlassJourneyCard extends StatelessWidget {
//   const _GlassJourneyCard({
//     required this.index,
//     required this.data,
//     required this.onTap,
//     required this.onToggleVisited,
//   });

//   final int index;
//   final _JourneyWithDistance data;
//   final VoidCallback onTap;
//   final VoidCallback onToggleVisited;

//   @override
//   Widget build(BuildContext context) {
//     final jp = data.supervisor;
//     final distText = '${data.distanceKm.toStringAsFixed(1)} km';

//     String? timeText;
//     if (jp.checkIn != null && jp.checkOut != null) {
//       final inStr = formatTimeHM(jp.checkIn!);
//       final outStr = formatTimeHM(jp.checkOut!);
//       if (jp.durationMinutes != null) {
//         timeText = '$inStr – $outStr • ${jp.durationMinutes} min';
//       } else {
//         timeText = '$inStr – $outStr';
//       }
//     } else if (jp.checkIn != null) {
//       timeText = 'Check-in: ${formatTimeHM(jp.checkIn!)}';
//     }

//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.18),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: Colors.black.withOpacity(0.5),
//             width: 0.9,
//           ),
//         ),
//         padding: const EdgeInsets.all(10),
//         child: Row(
//           children: [
//             Container(
//               width: 34,
//               height: 34,
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Colors.white, Color(0xFFECFEFF)],
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Center(
//                 child: Text(
//                   '$index',
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w800,
//                     fontFamily: 'ClashGrotesk',
//                     color: kText,
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     jp.name,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 14,
//                       fontWeight: FontWeight.w700,
//                       fontFamily: 'ClashGrotesk',
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Row(
//                     children: [
//                       const Icon(Icons.location_on_rounded,
//                           size: 14, color: Colors.white70),
//                       const SizedBox(width: 4),
//                       Text(
//                         distText,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           fontFamily: 'ClashGrotesk',
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (timeText != null) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       timeText,
//                       style: const TextStyle(
//                         color: Colors.white70,
//                         fontSize: 11,
//                         fontWeight: FontWeight.w500,
//                         fontFamily: 'ClashGrotesk',
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             const SizedBox(width: 8),
//             InkWell(
//               borderRadius: BorderRadius.circular(999),
//               onTap: onToggleVisited,
//               child: Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(999),
//                   color: jp.isVisited
//                       ? Colors.greenAccent.withOpacity(0.18)
//                       : Colors.orangeAccent.withOpacity(0.18),
//                   border: Border.all(
//                     color: jp.isVisited
//                         ? Colors.greenAccent
//                         : Colors.orangeAccent,
//                   ),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       jp.isVisited
//                           ? Icons.check_circle_rounded
//                           : Icons.radio_button_unchecked_rounded,
//                       size: 16,
//                       color: jp.isVisited
//                           ? Colors.greenAccent
//                           : Colors.orangeAccent,
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                       jp.isVisited ? 'Visited' : 'Pending',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 11,
//                         fontWeight: FontWeight.w700,
//                         fontFamily: 'ClashGrotesk',
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }