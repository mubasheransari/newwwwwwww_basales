import 'package:flutter/material.dart';


class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.onPickGallery,
    required this.onCapture,
    required this.onPickDocs,
    required this.enabled,
    required this.galleryIconAsset,
    required this.captureIconAsset,
    required this.docsIconAsset,
    this.scaleFactor, // optional override if you want to tweak from outside
  });

  final VoidCallback onPickGallery;
  final VoidCallback onCapture;
  final VoidCallback onPickDocs;
  final bool enabled;

  final String galleryIconAsset; // e.g. 'assets/icons/gallery.png'
  final String captureIconAsset; // e.g. 'assets/icons/scan.png'
  final String docsIconAsset;    // e.g. 'assets/icons/docs.png'

  /// Set < 1.0 to shrink, > 1.0 to enlarge. Default makes it smaller already.
  final double? scaleFactor;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    const kCompact = 0.84; // <-- compactness factor (shrink everything)
    final s = (w / 390.0) * (scaleFactor ?? kCompact);

    return SizedBox(
      height: 148 * s,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // pill container
          Positioned.fill(
            top: 32 * s,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16 * s),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEAF2FF), Color(0xFFF5F6FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(28 * s),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140E1631),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE6EBF5)),
              ),
              padding: EdgeInsets.fromLTRB(22 * s, 1 * s, 22 * s, 8 * s),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _circleWithLabel(
                    s: s,
                    label: 'Images',
                    iconAsset: galleryIconAsset,
                    onTap: onPickGallery,
                  ),
                  SizedBox(width: 86 * s), // space for center button
                  _circleWithLabel(
                    s: s,
                    label: 'Documents',
                    iconAsset: docsIconAsset,
                    onTap: onPickDocs,
                  ),
                ],
              ),
            ),
          ),

          // center scan button
          Positioned(
            bottom: 32 * s,
            child: _CenterCaptureButton(
              s: s,
              enabled: enabled,
              iconAsset: captureIconAsset,
              onTap: enabled ? onCapture : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleWithLabel({
    required double s,
    required String label,
    required String iconAsset,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64 * s,
            height: 64 * s,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE6EBF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140E1631),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              iconAsset,
              width: 48 * s,
              height: 48 * s,
            ),
          ),
          SizedBox(height: 8 * s),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w800,
              fontSize: 14 * s,
              color: const Color(0xFF0E1631),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterCaptureButton extends StatelessWidget {
  const _CenterCaptureButton({
    required this.s,
    required this.enabled,
    required this.iconAsset,
    required this.onTap,
  });

  final double s;
  final bool enabled;
  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color a = const Color(0xFF4CA6FF);
    final Color b = const Color(0xFF6B8CFF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 86 * s,
        height: 86 * s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: enabled ? [a, b] : [Colors.grey.shade400, Colors.grey.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x330E1631), blurRadius: 20, offset: Offset(0, 12)),
          ],
        ),
        padding: EdgeInsets.all(14 * s),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Image.asset(
            iconAsset,
            width: 54 * s,
            height: 54 * s,
          ),
        ),
      ),
    );
  }
}
