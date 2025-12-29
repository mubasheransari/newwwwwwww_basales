import 'package:flutter/material.dart';







class SponsoredVendorsScreen extends StatelessWidget {
  const SponsoredVendorsScreen({super.key});

  // Palette & gradients tuned to screenshot
  static const _bg = Color(0xFFF6F7FB);
  static const _title = Color(0xFF111111);
  static const _text = Color(0xFF7D8790);
  static const _closed = Color(0xFFE53935);
  static const _cardBorder = Color(0xFFE9ECF2);
  static const _star = Color(0xFFFFC107);
  static const _dark = Color(0xFF1F1F1F);

  static const _chipGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _circleGrad = LinearGradient(
    colors: [Color(0xFF73D1FF), Color(0xFF6A7CFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    // Reference width (iPhone 390pt). Everything scales from this.
    final s = MediaQuery.of(context).size.width / 390.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 24 * s),
          children: [
            // ===== Header (back + centered title)
            SizedBox(
              height: 44 * s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                
                  Text(
                    'Sponsored vendors list',
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 20 * s,
                      fontWeight: FontWeight.w700,
                      color: _title,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12 * s),

            // ===== Top stats row (exact three items)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatTile(
                  s: s,
                  number: '1,250+',
                  line1: 'Trusted',
                  line2: 'Vendors',
                ),
                _StatTile(
                  s: s,
                  number: '15k+',
                  line1: 'Happy',
                  line2: 'Customers',
                ),
                _StatTile(
                  s: s,
                  number: '50+',
                  line1: 'Service',
                  line2: 'Coverage',
                ),
              ],
            ),

            SizedBox(height: 14 * s),

            // ===== Vendor cards (repeat)
            ...List.generate(4, (_) => _VendorCard(scale: s)),
          ],
        ),
      ),
    );
  }

  // Small gradient circle action
  static Widget _gradCircle({
    required double s,
    required double size,
    required IconData icon,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: _chipGrad,
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/* ----------------------------- Stat Tile (exact) ----------------------------- */

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.s,
    required this.number,
    required this.line1,
    required this.line2,
  });

  final double s;
  final String number;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118 * s, // locks 3 across like screenshot
      child: Column(
        children: [
          // Gradient circle (number)
          Container(
            width: 88 * s,
            height: 88 * s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SponsoredVendorsScreen._circleGrad,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A7CFF).withOpacity(.28),
                  blurRadius: 18 * s,
                  offset: Offset(0, 10 * s),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.white,
                  fontSize: 18 * s,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: 8 * s),

          // White rounded label (very soft gradient like screenshot)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 9 * s),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF4F8FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16 * s),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 12 * s,
                  offset: Offset(0, 8 * s),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  line1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12.5 * s,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
                Text(
                  line2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 12.5 * s,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------- Vendor Card -------------------------------- */

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.scale});
  final double scale;

  static const _cardBorder = SponsoredVendorsScreen._cardBorder;
  static const _text = SponsoredVendorsScreen._text;
  static const _title = SponsoredVendorsScreen._title;
  static const _chipGrad = SponsoredVendorsScreen._chipGrad;
  static const _closed = SponsoredVendorsScreen._closed;
  static const _star = SponsoredVendorsScreen._star;
  static const _dark = SponsoredVendorsScreen._dark;

  @override
  Widget build(BuildContext context) {
    final s = scale;

    return Container(
      margin: EdgeInsets.only(bottom: 16 * s),
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: _cardBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16 * s,
            offset: Offset(0, 8 * s),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left image + overlays
          SizedBox(
            width: 128 * s,
            height: 86 * s,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12 * s),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?q=80&w=1400&auto=format&fit=crop',
                    width: 128 * s,
                    height: 120 * s,
                    fit: BoxFit.cover,
                  ),
                ),

                // Share gradient chip (top-right)
                Positioned(
                  top: 6 * s,
                  right: 6 * s,
                  child: Container(
                    width: 30 * s,
                    height: 30 * s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _chipGrad,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A7CFF).withOpacity(.24),
                          blurRadius: 8 * s,
                          offset: Offset(0, 3 * s),
                        ),
                      ],
                    ),
                    child: Icon(Icons.share_rounded,
                        color: Colors.white, size: 16 * s),
                  ),
                ),

                // Rating pill (bottom-left): ⭐ 4.8  ( 4k ) blue bubble
                Positioned(
                  left: 6 * s,
                  bottom: 6 * s,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5 * s, vertical: 2 * s),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10 * s),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16 * s, color: _star),
                        SizedBox(width: 4 * s),
                        Text(
                          '4.8',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 12 * s,
                            fontWeight: FontWeight.w800,
                            color: _title,
                          ),
                        ),
                        SizedBox(width: 6 * s),
                        Container(
                          width: 28 * s,
                          height: 22 * s,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(10 * s),
                            gradient: _chipGrad,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '4k',
                            style: TextStyle(
                              fontFamily: 'ClashGrotesk',
                              fontSize: 11 * s,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 12 * s),

          // Right side
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + call/chat gradient bubbles
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'U.S. Auto Inspection',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 16.5 * s,
                            fontWeight: FontWeight.w800,
                            color: _title,
                          ),
                        ),
                      ),
                      _gradAction(s, Icons.call_rounded),
                      SizedBox(width: 6 * s),
                      _gradAction(s, Icons.chat_rounded),
                    ],
                  ),
                  SizedBox(height: 4 * s),

                  Text(
                    'Vehicle inspection service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  SizedBox(height: 4 * s),

                  // Closed – Opens 08:00
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Closed ',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: _closed,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '– ',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: _dark,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: 'Opens 08:00',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            color: _dark,
                            fontSize: 13 * s,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6 * s),

                  // Quote line
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10 * s,
                        backgroundImage: const NetworkImage(
                          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?q=80&w=200',
                        ),
                      ),
                      SizedBox(width: 6 * s),
                      Expanded(
                        child: Text(
                          '“Fast car inspection service and excellent customer service.”',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 12.5 * s,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF808A93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _gradAction(double s, IconData icon) {
    return Container(
      width: 32 * s,
      height: 32 * s,
      margin: EdgeInsets.only(left: 6 * s),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _chipGrad,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A7CFF).withOpacity(.24),
            blurRadius: 8 * s,
            offset: Offset(0, 3 * s),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16 * s),
    );
  }
}
