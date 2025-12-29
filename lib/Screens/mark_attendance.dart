import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart' as geol;
import 'package:new_amst_flutter/Firebase/firebase_services.dart';


const _kPrimaryGrad = LinearGradient(
  colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// Local storage key for attendance logs
const String _kAttendanceBoxKey = 'attendance_logs';

// -------------- GLASS WIDGETS --------------

class _GlassPanel extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _GlassPanel({
    required this.height,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const r = BorderRadius.vertical(top: Radius.circular(10));
    final onAndroid = Platform.isAndroid;

    final sigma = onAndroid ? 0.0 : 16.0;
    final tint = onAndroid
        ? Colors.white.withOpacity(0.80)
        : Colors.white.withOpacity(0.12);
    final scrimTop = Colors.black.withOpacity(onAndroid ? 0.20 : 0.06);
    final scrimBottom = Colors.black.withOpacity(onAndroid ? 0.26 : 0.03);

    return ClipRRect(
      borderRadius: r,
      child: Stack(
        children: [
          // Gradient border
          Container(
            decoration: const BoxDecoration(
              gradient: _kPrimaryGrad,
              borderRadius: r,
            ),
          ),
          // Glass body
          Padding(
            padding: const EdgeInsets.all(1.5),
            child: ClipRRect(
              borderRadius: r,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: Container(
                  height: height,
                  padding: padding,
                  decoration: BoxDecoration(
                    borderRadius: r,
                    color: tint,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [scrimTop, scrimBottom],
                    ),
                  ),
                  child: IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: DefaultTextStyle(
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: Colors.white),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassChip({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(12);
    final onAndroid = Platform.isAndroid;
    final sigma = onAndroid ? 0.0 : 12.0;
    final tint = onAndroid
        ? Colors.white.withOpacity(0.70)
        : Colors.white.withOpacity(0.14);

    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: r,
            color: tint,
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
              width: 1,
            ),
          ),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: DefaultTextStyle.merge(
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Colors.white),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// -------------- MAIN SCREEN --------------

class MarkAttendanceView extends StatefulWidget {
  final String code;

  const MarkAttendanceView({
    super.key,
    required this.code,
  });

  @override
  State<MarkAttendanceView> createState() => _MarkAttendanceViewState();
}

class _MarkAttendanceViewState extends State<MarkAttendanceView> {
  final loc.Location location = loc.Location();
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _currentMarkerIcon;
  LatLng? _currentLatLng;
  LatLng? _allowedLatLng;
  double _allowedRadiusMeters = 100;
  double? _distanceMeters;
  bool _withinAllowed = false;
  CameraPosition? _initialCameraPosition;
  String distanceInfo = "";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isMapReady = false;

  final _box = GetStorage();

  String _dateTime = "";

  // 🔹 Today’s in/out state
  bool _isCheckedInToday = false;
  String? _todayIn;
  String? _todayOut;

  String _currentAddress = "Fetching location...";
  String _deviceId = '';

  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;

  @override
  void initState() {
    super.initState();

    // Read stored device id: await box.write('device_id', id);
    _deviceId = _box.read('device_id') ?? '';

    _initMap();
    _loadAllowedLocation();
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _loadTodayAttendanceFromLocal();
  }

  Future<void> _loadAllowedLocation() async {
    try {
      final u = Fb.user;
      if (u == null) return;
      final profile = await FbUserRepo.getOrCreateProfile(user: u);

      if (!mounted) return;
      setState(() {
        _allowedLatLng = LatLng(profile.allowedLat, profile.allowedLng);
        _allowedRadiusMeters = profile.allowedRadiusMeters;
      });

      // Add marker for allowed location (if configured)
      if (_allowedLatLng != null &&
          _allowedLatLng!.latitude != 0 &&
          _allowedLatLng!.longitude != 0) {
        _markers.add(
          Marker(
            markerId: const MarkerId('allowed_location'),
            position: _allowedLatLng!,
            infoWindow: const InfoWindow(title: 'Allowed Attendance Location'),
          ),
        );
      }

      _recalcDistance();
    } catch (_) {
      // ignore (screen will behave as not configured)
    }
  }

  void _recalcDistance() {
    if (_currentLatLng == null || _allowedLatLng == null) return;
    if (_allowedLatLng!.latitude == 0 && _allowedLatLng!.longitude == 0) {
      setState(() {
        _distanceMeters = null;
        _withinAllowed = false;
        distanceInfo = 'Attendance location is not configured yet.';
      });
      return;
    }

    final d = geol.Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      _allowedLatLng!.latitude,
      _allowedLatLng!.longitude,
    );

    final within = d <= _allowedRadiusMeters;
    setState(() {
      _distanceMeters = d;
      _withinAllowed = within;
      distanceInfo = within
          ? '✅ You are within ${_allowedRadiusMeters.toStringAsFixed(0)}m. Distance: ${d.toStringAsFixed(1)}m'
          : '❌ Too far from allowed location. Distance: ${d.toStringAsFixed(1)}m (Allowed: ${_allowedRadiusMeters.toStringAsFixed(0)}m)';
    });
  }

  // -------------- TIME DISPLAY --------------

  void _updateTime() {
    final now = DateTime.now();
    final formatted = DateFormat("EEEE, dd-MMM-yyyy HH:mm:ss").format(now);
    setState(() => _dateTime = formatted);
  }

  // -------------- MAP & LOCATION --------------

  Future<void> _initMap() async {
    await _loadCustomMarkers();
    await _requestPermissionAndFetchLocation();
    setState(() => distanceInfo = '');
  }

  Future<BitmapDescriptor> _bitmapFromAsset(
    String path, {
    int width = 36,
  }) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _loadCustomMarkers() async {
    _currentMarkerIcon = await _bitmapFromAsset(
      'assets/marker.png',
      width: 88,
    );
    setState(() {});
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentAddress =
              "${place.thoroughfare}, ${place.subLocality}, ${place.locality},";
        });
      }
    } catch (_) {
      setState(() => _currentAddress = "Unable to fetch address");
    }
  }

  Future<void> _requestPermissionAndFetchLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    var permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    final currentLocation = await location.getLocation();
    _currentLatLng = LatLng(
      currentLocation.latitude ?? 24.8607,
      currentLocation.longitude ?? 67.0011,
    );

    _initialCameraPosition = CameraPosition(
      target: _currentLatLng!,
      zoom: 14,
    );

    if (_currentMarkerIcon != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLatLng!,
          icon: _currentMarkerIcon!,
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    await _getAddressFromLatLng(_currentLatLng!);
    _recalcDistance();
  }

  void _recenterToCurrentLocation() {
    if (_currentLatLng != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    LatLngBounds? visibleRegion;
    do {
      visibleRegion = await _mapController.getVisibleRegion();
    } while (visibleRegion.southwest.latitude == -90.0);
    setState(() => _isMapReady = true);
  }

  // -------------- LOCAL STORAGE: TODAY IN/OUT --------------

  void _loadTodayAttendanceFromLocal() {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final raw = _box.read(_kAttendanceBoxKey);

    String? inTime;
    String? outTime;
    bool checkedIn = false;

    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['date'] == todayKey) {
          inTime = item['in']?.toString();
          outTime = item['out']?.toString();
          if (inTime != null &&
              inTime.isNotEmpty &&
              (outTime == null || outTime.isEmpty)) {
            checkedIn = true;
          }
          break;
        }
      }
    }

    setState(() {
      _todayIn = inTime;
      _todayOut = outTime;
      _isCheckedInToday = checkedIn;
    });
  }

  Future<void> _saveTodayAttendance({
    required String inTime,
    String? outTime,
  }) async {
    final today = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(today);
    final dayName = DateFormat('EEEE').format(today);
    final displayDate = DateFormat('dd-MMM-yyyy').format(today);

    final raw = _box.read(_kAttendanceBoxKey);
    final List<Map<String, dynamic>> items = [];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final idx = items.indexWhere((e) => e['date'] == dateKey);

    if (idx >= 0) {
      final rec = items[idx];
      rec['in'] = inTime;
      rec['out'] = outTime ?? (rec['out'] ?? '');
      items[idx] = rec;
    } else {
      items.add({
        'date': dateKey,
        'displayDate': displayDate,
        'day': dayName,
        'in': inTime,
        'out': outTime ?? '',
      });
    }

    await _box.write(_kAttendanceBoxKey, items);
  }

  // -------------- IN / OUT TOGGLE HANDLER --------------

  Future<void> _handleAttendanceTap() async {
    // Re-check distance right before marking
    _recalcDistance();

    if (_allowedLatLng == null ||
        (_allowedLatLng!.latitude == 0 && _allowedLatLng!.longitude == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance location is not configured for this user.'),
        ),
      );
      return;
    }

    if (!_withinAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are not within ${_allowedRadiusMeters.toStringAsFixed(0)}m of the allowed location.',
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final dateStr = DateFormat('dd-MMM-yyyy').format(now);

    final latStr = (_currentLatLng?.latitude ?? 24.8871334).toString();
    final lngStr = (_currentLatLng?.longitude ?? 66.9788572).toString();

    //final repo = Repository();

    final uid = Fb.uid;

    if (!_isCheckedInToday) {
      // 👉 ATTENDANCE IN
      await _saveTodayAttendance(inTime: timeStr, outTime: null);

      if (uid != null) {
        await FbAttendanceRepo.addAttendance(
          uid: uid,
          action: 'IN',
          lat: _currentLatLng?.latitude ?? 0,
          lng: _currentLatLng?.longitude ?? 0,
          distanceMeters: _distanceMeters ?? 0,
          withinAllowed: true,
          deviceId: _deviceId.isEmpty ? 'unknown-device' : _deviceId,
        );
      }

      // await repo.submitAttendance(
      //   type: 1,
      //   code: widget.code,
      //   latitude: latStr,
      //   longitude: lngStr,
      //   deviceId: _deviceId.isEmpty ? 'unknown-device' : _deviceId,
      //   actType: "ATTENDANCE",
      //   action: "IN",
      //   attTime: timeStr,
      //   attDate: dateStr,
      // );

      setState(() {
        _isCheckedInToday = true;
        _todayIn = timeStr;
        _todayOut = null;
      });
    } else {
      // 👉 ATTENDANCE OUT
      final existingIn = _todayIn ?? timeStr;

      await _saveTodayAttendance(inTime: existingIn, outTime: timeStr);

      if (uid != null) {
        await FbAttendanceRepo.addAttendance(
          uid: uid,
          action: 'OUT',
          lat: _currentLatLng?.latitude ?? 0,
          lng: _currentLatLng?.longitude ?? 0,
          distanceMeters: _distanceMeters ?? 0,
          withinAllowed: true,
          deviceId: _deviceId.isEmpty ? 'unknown-device' : _deviceId,
        );
      }

      // await repo.submitAttendance(
      //   type: 1,
      //   code: widget.code,
      //   latitude: latStr,
      //   longitude: lngStr,
      //   deviceId: _deviceId.isEmpty ? 'unknown-device' : _deviceId,
      //   actType: "ATTENDANCE",
      //   action: "OUT",
      //   attTime: timeStr,
      //   attDate: dateStr,
      // );

      setState(() {
        _isCheckedInToday = false;
        _todayOut = timeStr;
      });
    }
  }

  // -------------- BUILD --------------

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          if (_initialCameraPosition != null)
            GoogleMap(
              padding: const EdgeInsets.only(bottom: 60),
              onMapCreated: _onMapCreated,
              initialCameraPosition: _initialCameraPosition!,
              mapType: MapType.normal,
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),

          if (distanceInfo.isNotEmpty)
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  distanceInfo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 60,
            left: 16,
            right: 16,
            child: _GlassPanel(
              height: 240,
              padding: const EdgeInsets.all(20),
              child: DefaultTextStyle.merge(
                style: t.bodyMedium!.copyWith(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Location",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'ClashGrotesk',
                      ),
                    ),
                    const SizedBox(height: 6),

                    _GlassChip(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentAddress,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontFamily: 'ClashGrotesk',
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          IconButton(
                            onPressed: _recenterToCurrentLocation,
                            icon: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) =>
                                  _kPrimaryGrad.createShader(bounds),
                              child: const Icon(
                                Icons.my_location,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //     _PunchCard(
                    //       title: 'Punch In',
                    //       time: _todayIn ?? '--:--',
                    //       lightOnGradient: true,
                    //     ),
                    //     _PunchCard(
                    //       title: 'Punch Out',
                    //       time: (_todayOut ?? '').isEmpty
                    //           ? '--:--'
                    //           : _todayOut!,
                    //       lightOnGradient: true,
                    //     ),
                    //   ],
                    // ),

                    // const SizedBox(height: 16),

                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.40,
                        height: 40,
                        child: _PrimaryGradientButton(
                          text: _isCheckedInToday
                              ? 'ATTENDANCE OUT'
                              : 'ATTENDANCE IN',
                          onPressed: _handleAttendanceTap,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: Text(
                        _dateTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'ClashGrotesk',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------- SMALL UI HELPERS --------------

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

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
      opacity: disabled ? 0.8 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
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
            borderRadius: BorderRadius.circular(12),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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

class _PunchCard extends StatelessWidget {
  final String title;
  final String time;
  final bool lightOnGradient;

  const _PunchCard({
    required this.title,
    required this.time,
    this.lightOnGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titleColor =
        lightOnGradient ? Colors.white : const Color(0xFF1E1E1E);
    final timeColor =
        lightOnGradient ? Colors.white : const Color(0xFFEA7A3B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: timeColor,
          ),
        ),
      ],
    );
  }
}


// const _kPrimaryGrad = LinearGradient(
//   colors: [Color(0xFF0ED2F7), Color(0xFF7F53FD)],
//   begin: Alignment.centerLeft,
//   end: Alignment.centerRight,
// );

// class _GlassPanel extends StatelessWidget {
//   final double height;
//   final EdgeInsetsGeometry padding;
//   final Widget child;
//   const _GlassPanel({
//     required this.height,
//     required this.padding,
//     required this.child,
//   });

//   @override
//   Widget build(BuildContext context) {
//     const r = BorderRadius.vertical(top: Radius.circular(10));
//     final onAndroid = Platform.isAndroid;

//     // On Android over GoogleMap: no actual blur → increase opacity + add scrim
//     final sigma = onAndroid ? 0.0 : 16.0;
//     final tint = onAndroid
//         ? Colors.white.withOpacity(0.80)
//         : Colors.white.withOpacity(0.12);
//     final scrimTop = Colors.black.withOpacity(onAndroid ? 0.20 : 0.06);
//     final scrimBottom = Colors.black.withOpacity(onAndroid ? 0.26 : 0.03);

//     return ClipRRect(
//       borderRadius: r,
//       child: Stack(
//         children: [
//           // Gradient border
//           Container(
//             decoration: const BoxDecoration(
//               gradient: _kPrimaryGrad,
//               borderRadius: r,
//             ),
//           ),
//           // Glass body
//           Padding(
//             padding: const EdgeInsets.all(1.5),
//             child: ClipRRect(
//               borderRadius: r,
//               child: BackdropFilter(
//                 filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
//                 child: Container(
//                   height: height,
//                   padding: padding,
//                   decoration: BoxDecoration(
//                     borderRadius: r,
//                     color: tint,
//                     border: Border.all(
//                       color: Colors.white.withOpacity(0.28),
//                       width: 1,
//                     ),
//                     // subtle dark scrim for contrast
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [scrimTop, scrimBottom],
//                     ),
//                   ),
//                   child: IconTheme(
//                     data: const IconThemeData(color: Colors.white),
//                     child: DefaultTextStyle(
//                       style: Theme.of(
//                         context,
//                       ).textTheme.bodyMedium!.copyWith(color: Colors.white),
//                       child: child,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _GlassChip extends StatelessWidget {
//   final Widget child;
//   final EdgeInsetsGeometry padding;
//   const _GlassChip({
//     required this.child,
//     this.padding = const EdgeInsets.all(12),
//   });

//   @override
//   Widget build(BuildContext context) {
//     final r = BorderRadius.circular(12);
//     final onAndroid = Platform.isAndroid;
//     final sigma = onAndroid ? 0.0 : 12.0;
//     final tint = onAndroid
//         ? Colors.white.withOpacity(0.70)
//         : Colors.white.withOpacity(0.14);

//     return ClipRRect(
//       borderRadius: r,
//       child: BackdropFilter(
//         filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
//         child: Container(
//           padding: padding,
//           decoration: BoxDecoration(
//             borderRadius: r,
//             color: tint,
//             border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
//           ),
//           child: IconTheme(
//             data: const IconThemeData(color: Colors.white),
//             child: DefaultTextStyle.merge(
//               style: Theme.of(
//                 context,
//               ).textTheme.bodyMedium!.copyWith(color: Colors.white),
//               child: child,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class MarkAttendanceView extends StatefulWidget {
//   String code;
//    MarkAttendanceView({super.key,required this.code});

//   @override
//   State<MarkAttendanceView> createState() => _MarkAttendanceViewState();
// }

// class _MarkAttendanceViewState extends State<MarkAttendanceView> {



//   final loc.Location location = loc.Location();
//   late GoogleMapController _mapController;
//   final Set<Marker> _markers = {};
//   BitmapDescriptor? _currentMarkerIcon;
//   LatLng? _currentLatLng;
//   CameraPosition? _initialCameraPosition;
//   String distanceInfo = "";
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   bool _isMapReady = false;

//   String _dateTime = "";
//   void _updateTime() {
//     final now = DateTime.now();
//     final formatted = DateFormat("EEEE, dd-MMM-yyyy HH:mm:ss").format(now);
//     setState(() => _dateTime = formatted);
//   }

//   @override
//   void initState() {
//     super.initState();
//     print("CODE ${widget.code}");
//         print("CODE ${widget.code}");
//             print("CODE ${widget.code}");
//     _initMap();
//     _updateTime();
//     Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
//   }

//   Future<void> _initMap() async {
//     await _loadCustomMarkers();
//     await _requestPermissionAndFetchLocation();
//     setState(() => distanceInfo = '');
//   }

//   Future<BitmapDescriptor> _bitmapFromAsset(
//     String path, {
//     int width = 36,
//   }) async {
//     final data = await rootBundle.load(path);
//     final codec = await ui.instantiateImageCodec(
//       data.buffer.asUint8List(),
//       targetWidth: width, 
//     );
//     final frame = await codec.getNextFrame();
//     final bytes = (await frame.image.toByteData(
//       format: ui.ImageByteFormat.png,
//     ))!.buffer.asUint8List();
//     return BitmapDescriptor.fromBytes(bytes);
//   }

//   // Future<void> _loadCustomMarkers() async {
//   //   _currentMarkerIcon = await BitmapDescriptor.fromAssetImage(
//   //      ImageConfiguration(devicePixelRatio: 2.5,size: Size(20, 20)),
//   //     'assets/marker.png',

//   //   );
//   // }

//   Future<void> _loadCustomMarkers() async {
//     _currentMarkerIcon = await _bitmapFromAsset(
//       'assets/marker.png',
//       width: 88,
//     ); // try 24–40
//     setState(() {}); // if needed
//   }

//   String _currentAddress = "Fetching location...";
//   Future<void> _getAddressFromLatLng(LatLng position) async {
//     try {
//       final placemarks = await geo.placemarkFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );
//       if (placemarks.isNotEmpty) {
//         final place = placemarks.first;
//         setState(() {
//           _currentAddress =
//               "${place.thoroughfare}, ${place.subLocality}, ${place.locality},";
//         });
//       }
//     } catch (_) {
//       setState(() => _currentAddress = "Unable to fetch address");
//     }
//   }

//   Future<void> _requestPermissionAndFetchLocation() async {
//     bool serviceEnabled = await location.serviceEnabled();
//     if (!serviceEnabled) {
//       serviceEnabled = await location.requestService();
//       if (!serviceEnabled) return;
//     }
//     var permissionGranted = await location.hasPermission();
//     if (permissionGranted == loc.PermissionStatus.denied) {
//       permissionGranted = await location.requestPermission();
//       if (permissionGranted != loc.PermissionStatus.granted) return;
//     }

//     final currentLocation = await location.getLocation();
//     _currentLatLng = LatLng(
//       currentLocation.latitude ?? 24.8607,
//       currentLocation.longitude ?? 67.0011,
//     );

//     _initialCameraPosition = CameraPosition(target: _currentLatLng!, zoom: 14);

//     if (_currentMarkerIcon != null) {
//       _markers.add(
//         Marker(
//           markerId: const MarkerId('current_location'),
//           position: _currentLatLng!,
//           icon: _currentMarkerIcon!,
//           infoWindow: const InfoWindow(title: 'Your Location'),
//         ),
//       );
//     }

//     await _getAddressFromLatLng(_currentLatLng!);
//   }

//   void _recenterToCurrentLocation() {
//     if (_currentLatLng != null) {
//       _mapController.animateCamera(
//         CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
//       );
//     }
//   }

//   void _onMapCreated(GoogleMapController controller) async {
//     _mapController = controller;
//     LatLngBounds? visibleRegion;
//     do {
//       visibleRegion = await _mapController.getVisibleRegion();
//     } while (visibleRegion.southwest.latitude == -90.0);
//     setState(() => _isMapReady = true);
//   }

//   final ImagePicker _picker = ImagePicker();
//   File? _capturedImage;

//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context).textTheme;

//     return Scaffold(
//       key: _scaffoldKey,
//       body: Stack(
//         children: [
//           if (_initialCameraPosition != null)
//             GoogleMap(
//               padding: const EdgeInsets.only(bottom: 60),
//               onMapCreated: _onMapCreated,
//               initialCameraPosition: _initialCameraPosition!,
//               mapType: MapType.normal,
//               markers: _markers,
//               myLocationButtonEnabled: false,
//               zoomControlsEnabled: false,
//             ),

//           // Distance pill (kept as-is)
//           if (distanceInfo.isNotEmpty)
//             Positioned(
//               bottom: 30,
//               left: 16,
//               right: 16,
//               child: Container(
//                 padding: const EdgeInsets.all(0),
//                 decoration: BoxDecoration(
//                   color: Colors.white70,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   distanceInfo,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ),
//           // ===== Glassy gradient bottom sheet =====
//           Positioned(
//             bottom: 60,
//             left: 16,
//             right: 16,
//             child: _GlassPanel(
//               height: 250,
//               padding: const EdgeInsets.all(20),
//               child: DefaultTextStyle.merge(
//                 style: Theme.of(
//                   context,
//                 ).textTheme.bodyMedium!.copyWith(color: Colors.white),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Location",
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                         fontFamily: 'ClashGrotesk',
//                       ),
//                     ),
//                     const SizedBox(height: 6),

//                     // glass address field
//                     _GlassChip(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 14,
//                       ),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               _currentAddress,
//                               style: Theme.of(context).textTheme.bodyMedium
//                                   ?.copyWith(
//                                     color: Colors.black,
//                                     fontFamily: 'ClashGrotesk',
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                             ),
//                           ),
//                           IconButton(
//                             onPressed: _recenterToCurrentLocation,
//                             icon: ShaderMask(
//                               blendMode: BlendMode.srcIn,
//                               shaderCallback: (bounds) =>
//                                   _kPrimaryGrad.createShader(bounds),
//                               child: const Icon(
//                                 Icons.my_location,
//                                 size: 24,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ),

                      
//                         ],
//                       ),
//                     ),

               
//                     const SizedBox(height: 18),

//                     Center(
//                       child: SizedBox(
//                         width: MediaQuery.of(context).size.width * 0.40,
//                         height: 40,
//                         child: _PrimaryGradientButton(
//                           text: 'ATTENDANCE IN',
//                           onPressed: () async {
//                             final now = DateTime.now();
//                             final attTime = DateFormat('HH:mm:ss').format(now);
//                             final attDate = DateFormat(
//                               'dd-MMM-yyyy',
//                             ).format(now);
//                             await Repository().submitAttendance(
//                               type: 1,
//                               code: "306232",
//                               latitude: "24.8871334",
//                               longitude: "66.9788572",
//                               deviceId: "3d61adab1be4b2f2",
//                               actType: "ATTENDANCE",
//                               action: "IN",
//                               attTime: attTime,
//                               attDate: attDate,
//                             );
//                           },
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 10),

//                     Center(
//                       child: Text(
//                         _dateTime,
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontFamily: 'ClashGrotesk',
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // ===== Gradient bottom sheet =====
//           /*  Positioned(
//             bottom: 60,
//             left: 16,
//             right: 16,
//             child: Container(
//               height: 310,
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//                 gradient: kPrimaryGrad,
//                 boxShadow: const [
//                   BoxShadow(
//                     color: _shadow,
//                     blurRadius: 10,
//                     offset: Offset(0, -2),
//                   ),
//                 ],
//               ),
//               padding: const EdgeInsets.all(20),
//               child: DefaultTextStyle(
//                 style: t.bodyMedium!.copyWith(color: Colors.white),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "Location",
//                       style: t.titleMedium?.copyWith(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 6),

//                     // Address field with translucent fill
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.18),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: Colors.white.withOpacity(0.35)),
//                       ),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 14,
//                       ),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               _currentAddress,
//                               style: t.bodyMedium?.copyWith(color: Colors.white),
//                             ),
//                           ),
//                           IconButton(
//                             onPressed: _recenterToCurrentLocation,
//                             icon: const Icon(Icons.my_location, color: Colors.white),
//                           ),
//                         ],
//                       ),
//                     ),

//                     const SizedBox(height: 20),

//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: const [
//                         _PunchCard(title: "Punch In", time: "--:--", lightOnGradient: true),
//                         _PunchCard(title: "Punch Out", time: "--:--", lightOnGradient: true),
//                       ],
//                     ),

//                     const SizedBox(height: 8),

//                     // Gradient button
//                     Center(
//                       child: SizedBox(
//                         width: MediaQuery.of(context).size.width * 0.50,
//                         height: 50,
//                         child: _PrimaryGradientButton(
//                           text: 'ATTENDANCE IN',
//                           onPressed: () async {
//                             // TODO: wire to your bloc if needed
//                           },
//                         ),
//                       ),
//                     ),

//                     const SizedBox(height: 10),

//                     Center(
//                       child: Text(
//                         _dateTime,
//                         style: t.bodySmall?.copyWith(color: Colors.white70),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),*/
//         ],
//       ),
//     );
//   }
// }

// /// Gradient CTA (matches your previous gradient style)
// class _PrimaryGradientButton extends StatelessWidget {
//   const _PrimaryGradientButton({
//     required this.text,
//     required this.onPressed,
//     this.loading = false,
//   });

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
//       opacity: disabled ? 0.8 : 1,
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(6),
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
//             borderRadius: BorderRadius.circular(12),
//             onTap: disabled ? null : onPressed,
//             child: Center(
//               child: loading
//                   ? const SizedBox(
//                       height: 20,
//                       width: 20,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                       ),
//                     )
//                   : const Text(
//                       'ATTENDANCE IN',
//                       style: TextStyle(
//                         fontFamily: 'ClashGrotesk',
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
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
