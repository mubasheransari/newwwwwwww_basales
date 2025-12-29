import 'package:flutter/material.dart';

enum ToastType { success, error, info, dark }

void showAppToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.success,
  IconData? icon,
}) {
  Color bg;
  IconData ic;

  switch (type) {
    case ToastType.success:
      bg = const Color(0xFF16A34A); // green
      ic = Icons.check_circle_rounded;
      break;

    case ToastType.error:
      bg = const Color(0xFFDC2626); // red
      ic = Icons.error_outline_rounded;
      break;

    case ToastType.info:
      bg = const Color(0xFF6B7280); // grey
      ic = Icons.info_outline_rounded;
      break;

    case ToastType.dark:
      bg = const Color(0xFF111827); // black-ish
      ic = Icons.warning_amber_rounded;
      break;
  }

  final mq = MediaQuery.of(context);
  final keyboard = mq.viewInsets.bottom;
  final availableH = mq.size.height - keyboard;
  final bottomOffset = (availableH / 2) - 20;

  final safeBottom = bottomOffset.clamp(20.0, availableH - 100.0);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 12,
      margin: EdgeInsets.fromLTRB(16, 0, 16, safeBottom),
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon ?? ic,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
