import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class LocationVendorsMapScreen extends StatefulWidget {
  const LocationVendorsMapScreen({super.key, this.showFirstTooltipOnLoad = true});
  final bool showFirstTooltipOnLoad;

  @override
  State<LocationVendorsMapScreen> createState() => _LocationVendorsMapScreenState();
}

class _LocationVendorsMapScreenState extends State<LocationVendorsMapScreen> {
  GoogleMapController? _gm;

  // Camera
  static const _usaCenter = LatLng(39.8283, -98.5795);
  static const _initialZoom = 4.6;

  // Data
  final Map<MarkerId, VendorLite> _vendorByMarker = {};
  final Set<Marker> _markers = {};
  MarkerId? _selected;
  Offset? _selectedScreenPx; // map px for tooltip anchor

  // Marker art cache
  BitmapDescriptor? _markerIcon;

  Future<BitmapDescriptor> _loadMarkerFromAsset(String asset, {Size? logicalSize}) {
    final cfg = createLocalImageConfiguration(context, size: logicalSize);
    return BitmapDescriptor.fromAssetImage(cfg, asset);
  }

  @override
  void initState() {
    super.initState();
    _seedRandomMarkers(8);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _markerIcon ??= await markerFromAssetAtDp(context, 'assets/marker_icon.png', 62);
      _refreshMarkersIcon();

      // ⛔️ Do not auto-select a marker on load (prevents auto popup)
      // if (widget.showFirstTooltipOnLoad && _markers.isNotEmpty) {
      //   setState(() => _selected = _markers.first.markerId);
      //   await _updateAnchor();
      // }
    });
  }

  // ------------------------ Map style ------------------------
  static const _mapStyleJson = '''
  [
    {"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},
    {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
    {"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},
    {"featureType":"administrative.land_parcel","stylers":[{"visibility":"off"}]},
    {"featureType":"poi","stylers":[{"visibility":"off"}]},
    {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
    {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
    {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
    {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},
    {"featureType":"transit","stylers":[{"visibility":"off"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#e9f2ff"}]}
  ]
  ''';

  // ------------------------ Seed data ------------------------
  static const _minLat = 24.7433195;
  static const _maxLat = 49.3457868;
  static const _minLng = -124.7844079;
  static const _maxLng = -66.9513812;

  LatLng _randomUsaLatLng(math.Random r) {
    final lat = _minLat + r.nextDouble() * (_maxLat - _minLat);
    final lng = _minLng + r.nextDouble() * (_maxLng - _minLng);
    return LatLng(lat, lng);
  }

  void _seedRandomMarkers(int count) {
    final r = math.Random(42);
    for (var i = 0; i < count; i++) {
      final pos = _randomUsaLatLng(r);
      final id = MarkerId('m$i');
      final rating = (3.2 + r.nextDouble() * 1.6); // 3.2..4.8
      final v = VendorLite(
        i.isEven ? 'National Tyres And Autocare' : 'U.S. Auto Inspection',
        i.isEven ? 'Braconash Road, Leyland PR25 3ZE' : 'Service • USA',
        double.parse(rating.toStringAsFixed(1)),
        _sampleImages[i % _sampleImages.length],
      );
      _vendorByMarker[id] = v;

      _markers.add(Marker(
        markerId: id,
        position: pos,
        icon: _markerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),

        // ✅ No popup on marker tap: never set _selected here.
        onTap: () async {
          if (_selected != null || _selectedScreenPx != null) {
            setState(() {
              _selected = null;
              _selectedScreenPx = null;
            });
          }
          // Optionally center the map without showing a popup:
          // await _gm?.animateCamera(CameraUpdate.newLatLng(pos));
        },

        anchor: const Offset(.5, .5), // center since our art is circular
      ));
    }
  }

  void _refreshMarkersIcon() {
    if (_markerIcon == null) return;
    final updated = <Marker>{};
    for (final m in _markers) {
      updated.add(m.copyWith(iconParam: _markerIcon));
    }
    setState(() => _markers
      ..clear()
      ..addAll(updated));
  }

  Future<void> _updateAnchor() async {
    if (_gm == null || _selected == null) return;
    final latLng = _markers.firstWhere((m) => m.markerId == _selected).position;
    final sc = await _gm!.getScreenCoordinate(latLng);
    setState(() => _selectedScreenPx = Offset(sc.x.toDouble(), sc.y.toDouble()));
  }

  // ------------------------ Custom marker (kept, bug fixed) ------------------------
  Future<Uint8List> _buildMarkerArt({required double diameter}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(diameter, diameter);

    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final midR = outerR * .74;
    final innerR = outerR * .56;

    // soft glow
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        outerR,
        [const Color(0x3300B2FF), const Color(0x0000B2FF)],
      );
    canvas.drawCircle(center, outerR, glowPaint);

    // outer ring
    final outerPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, size.height),
        [const Color(0xFF9BE7FF), const Color(0xFF7CC5FF)],
      );
    canvas.drawCircle(center, midR + 6, outerPaint);

    // middle ring  ✅ FIXED: radius is a double (midR), not a Paint
    final midPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, size.height),
        [const Color(0xFF5CC7FF), const Color(0xFF35A9FF)],
      );
    canvas.drawCircle(center, midR, midPaint);

    // inner circle
    final innerPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(center, innerR, innerPaint);

    // wheel-like glyph substitute (4 small arcs)
    final stroke = Paint()
      ..color = const Color(0xFF2E84FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    for (var i = 0; i < 4; i++) {
      final start = i * math.pi / 2 + .35;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerR - 6),
        start,
        math.pi / 3,
        false,
        stroke,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
        final s = MediaQuery.of(context).size.width / 390.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // --------------- MAP ---------------
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(
                  builder: (ctx, c) {
                    final mapW = c.maxWidth;
                    final mapH = c.maxHeight;
                    return Stack(children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(target: _usaCenter, zoom: _initialZoom),
                        onMapCreated: (ctrl) async {
                          _gm = ctrl;
                          await _gm?.setMapStyle(_mapStyleJson);
                          await _updateAnchor();
                        },
                        onCameraIdle: _updateAnchor,
                        onTap: (_) => setState(() {
                          _selected = null;
                          _selectedScreenPx = null;
                        }),
                        markers: _markers,
                        zoomControlsEnabled: false,
                        compassEnabled: false,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        buildingsEnabled: false,
                        trafficEnabled: false,
                      ),

                      // Tooltip shows only if _selected is set elsewhere (e.g., from a card tap).
                      if (_selected != null && _selectedScreenPx != null)
                        _TooltipPositioner(
                          mapSize: Size(mapW, mapH),
                          anchor: _selectedScreenPx!,
                          child: _VendorTooltipCard(vendor: _vendorByMarker[_selected]!),
                        ),
                    ]);
                  },
                ),
              ),
            ),

            // --------------- HEADER (same UI) ---------------
            Positioned(
              top: pad.top + 1,
              left: 6,
              right: 6,
           //   bottom: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
               
                  // IconButton(
                  //   onPressed: () => Navigator.pop(context),
                  //   icon: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 32),
                  // ),
                   Padding(
                     padding: const EdgeInsets.only(left:30.0),
                     child: Text(
                     'Sponsored vendors list',
                     style: TextStyle(
                       fontFamily: 'ClashGrotesk',
                       fontSize: 20 * s,
                       fontWeight: FontWeight.w700,
                       color: Color(0xFF111111),
                     ),
                                       ),
                   ),
                  const SizedBox(width: 46),
                ],
              ),
            ),

            // --------------- SPONSORED LABEL + CARDS (same UI; no Positioned inside Column) ---------------
            Positioned(
              left: 4,
              right: 0,
              bottom: 18 + pad.bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Replace bad Positioned-in-Column with padding (visually identical)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6D63FF), Color(0xFF2DA3FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                          topRight: Radius.circular(999),
                          bottomRight: Radius.circular(999),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Sponsored vendors :',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 13),
                  SizedBox(
                    height: 216,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(left: 14),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (_, i) {
                        final v = _vendorByMarker.values.elementAt(i);
                        return GestureDetector(
                          onTap: () async {
                            // Camera -> vendor (keep same UI behavior)
                            final entry = _vendorByMarker.entries.elementAt(i);
                            final pos = _markers.firstWhere((m) => m.markerId == entry.key).position;
                            await _gm?.animateCamera(
                              CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 10.8)),
                            );

                            // Keep tooltip behavior on card taps (same UI).
                            setState(() => _selected = entry.key);
                            await _updateAnchor();
                          },
                          child: _VendorCard(v: v),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemCount: _vendorByMarker.length,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorLite {
  final String title;
  final String address;
  final double rating;
  final String imageUrl;
  const VendorLite(this.title, this.address, this.rating, this.imageUrl);
}

const _sampleImages = [
  'https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?q=80&w=1400&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?q=80&w=1400&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1517048676732-d65bc937f952?q=80&w=1400&auto=format&fit=crop',
  'https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?q=80&w=1400&auto=format&fit=crop',
];

class _VendorTooltipCard extends StatelessWidget {
  const _VendorTooltipCard({required this.vendor});
  final VendorLite vendor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 250,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9ECF2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // image
            SizedBox(
              width: 96,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _netImg(vendor.imageUrl),
                  Positioned(left: 6, top: 6, child: _ratingPill(vendor.rating)),
                ],
              ),
            ),
            // details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Row(children: const [
                      Icon(Icons.build_circle_rounded, size: 14, color: Color(0xFF6C7A91)),
                      SizedBox(width: 4),
                      Expanded(child: Text('Vehicle inspection service', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.2, color: Color(0xFF6C7A91)))),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: const [
                      Icon(Icons.access_time_rounded, size: 14, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Expanded(child: Text('Closed • Opens 9:00', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.2, color: Color(0xFF6C7A91)))),
                    ]),
                    const Spacer(),
                    Row(children: [
                      _circleIcon(Icons.call_rounded),
                      const SizedBox(width: 6),
                      _circleIcon(Icons.chat_bubble_rounded),
                      const SizedBox(width: 6),
                      _circleIcon(Icons.navigation_rounded),
                      const Spacer(),
                      const Icon(Icons.more_horiz_rounded, size: 22, color: Color(0xFF9AA1AE)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _circleIcon(IconData icon) => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: Color(0xFFF0F3F9), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: Color(0xFF5F6C86)),
      );
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.v});
  final VendorLite v;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 122,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                  child: _netImg(v.imageUrl),
                ),
                Positioned(left: 10, top: 10, child: _ratingPill(v.rating)),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.bookmark_border_rounded, size: 18, color: Color(0xFF6C7A91)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'ClashGrotesk')),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 3), decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(v.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF6C7A91), fontFamily: 'ClashGrotesk'))),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _netImg(String url) {
  return Image.network(
    url,
    fit: BoxFit.cover,
    loadingBuilder: (c, w, p) => p == null
        ? w
        : Container(color: const Color(0xFFF2F4F7), child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
    errorBuilder: (c, e, s) => Container(
      color: const Color(0xFFF2F4F7),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9AA1AE)),
    ),
  );
}

Widget _ratingPill(double rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
    child: Row(children: [
      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
      const SizedBox(width: 2),
      Text('$rating', style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'ClashGrotesk', letterSpacing: 1.0)),
    ]),
  );
}

// ----------------------------- Tooltip anchor positioning -------------------
class _TooltipPositioner extends StatelessWidget {
  const _TooltipPositioner({required this.mapSize, required this.anchor, required this.child});
  final Size mapSize;
  final Offset anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const cardW = 250.0;
    const cardH = 140.0;

    final left = (anchor.dx - cardW * .65).clamp(12.0, mapSize.width - cardW - 12.0);
    final top = (anchor.dy - cardH - 22).clamp(80.0, mapSize.height - cardH - 12.0);

    return Positioned(left: left, top: top, child: child);
  }
}

// ----------------------------- Utilities -------------------
Future<BitmapDescriptor> markerFromAssetAtDp(
  BuildContext context,
  String assetPath,
  double logicalDp,
) async {
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final targetWidthPx = (logicalDp * dpr).round();

  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: targetWidthPx,
  );
  final frame = await codec.getNextFrame();
  final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

