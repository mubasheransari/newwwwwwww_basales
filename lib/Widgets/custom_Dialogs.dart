import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

Future<void> showAccountCreatedDialog(BuildContext context) async {
  var box = GetStorage();
  final deviceId = (box.read('device_id') ?? '').toString();

  final size = MediaQuery.of(context).size;
  const baseW = 393.0;
  final s = size.width / baseW;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18 * s),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: 24 * s),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            margin: EdgeInsets.all(1.5 * s),
            padding: EdgeInsets.fromLTRB(18 * s, 20 * s, 18 * s, 16 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16 * s),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // check icon
                Container(
                  padding: EdgeInsets.all(10 * s),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFFBF7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 32,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(height: 12 * s),

                Text(
                  'Account Created',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 20 * s,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                SizedBox(height: 8 * s),

                Text(
                  'Your Account is created sucessfully please send this device id to your line manager to active your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A6F7B),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 14 * s),

                if (deviceId.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: deviceId));
                      Navigator.of(ctx).pop();
                   //   showToast(context, 'Device ID copied', success: true);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * s,
                        vertical: 8 * s,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10 * s),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.smartphone_rounded,
                            size: 16,
                            color: Color(0xFF6A6F7B),
                          ),
                          SizedBox(width: 8 * s),
                          Flexible(
                            child: Text(
                              deviceId,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'ClashGrotesk',
                                fontSize: 13 * s,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          SizedBox(width: 6 * s),
                          const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: Color(0xFF6A6F7B),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 16 * s),

                SizedBox(
                  width: double.infinity,
                  height: 40 * s,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12 * s),
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Center(
                        child: Text(
                          'Got it',
                          style: TextStyle(
                            fontFamily: 'ClashGrotesk',
                            fontSize: 16 * s,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
