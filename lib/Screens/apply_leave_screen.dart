import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_amst_flutter/Widgets/gradient_text.dart';
import 'dart:ui' as ui;

import 'package:new_amst_flutter/Widgets/watermarked_widget.dart';

class ApplyLeaveScreenNew extends StatefulWidget {
  const ApplyLeaveScreenNew({super.key});
  @override
  State<ApplyLeaveScreenNew> createState() => _ApplyLeaveScreenNewState();
}

class _ApplyLeaveScreenNewState extends State<ApplyLeaveScreenNew> {
  final _descCtrl = TextEditingController();

  String? _req(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  String _paymentType = 'full';

  final _selectHalfDayLeaveDate = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  static final _fmt = DateFormat('dd-MMM-yyyy');

  Future<void> _pickDate(TextEditingController target, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_fromDate ?? now) : (_toDate ?? _fromDate ?? now);
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: isFrom ? 'Select From Date' : 'Select To Date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7F53FD)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final s = _fmt.format(picked);
      setState(() {
        target.text = s;
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) {
            _toDate = picked;
            _toCtrl.text = s;
          }
        } else {
          _toDate = picked;
        }
      });
    }
  }

  int tab = 0;
  bool remember = true;

  final ScrollController _scrollCtrl = ScrollController();
  double _scrollY = 0.0;

  final _signupFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      if (tab != 1) return;
      final off = _scrollCtrl.offset;
      if (off != _scrollY) {
        setState(() => _scrollY = off);
      }
    });
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    //if (!_signupFormKey.currentState!.validate()) return;

    // Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (_) => const AppShell()),
    // );

    print("SELECTED OPTION $_paymentType");
    print("SELECTED OPTION $_paymentType");
    print("SELECTED OPTION $_paymentType");
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Stack(
        children: [
          WatermarkTiledSmall(tileScale: 25.0),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width < 380 ? 16 : 22,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: _scrollCtrl,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Form(
                              key: _signupFormKey,
                              autovalidateMode: AutovalidateMode.disabled,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Selection pills (Full / Half)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: PaymentChoiceTile(
                                          label: 'Full day',
                                          code: 'full',
                                          selected: _paymentType == 'full',
                                          onTap: () => setState(() {
                                            _paymentType = 'full';
                                          }),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: PaymentChoiceTile(
                                          label: 'Half day',
                                          code: 'half',
                                          selected: _paymentType == 'half',
                                          onTap: () => setState(() {
                                            _paymentType = 'half';
                                          }),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  _paymentType == "full"
                                      ? _DateCard(
                                          label: 'From Date',
                                          controller: _fromCtrl,
                                          onTap: () =>
                                              _pickDate(_fromCtrl, true),
                                          validator: _req,
                                        )
                                      : SizedBox(),

                                  _paymentType == "half"
                                      ? _DateCard(
                                          label: 'Select Date',
                                          controller: _selectHalfDayLeaveDate,
                                          onTap: () => _pickDate(
                                            _selectHalfDayLeaveDate,
                                            true,
                                          ),
                                          validator: _req,
                                        )
                                      : SizedBox(),
                                  const SizedBox(height: 12),

                                  _paymentType == "full"
                                      ? _DateCard(
                                          label: 'To Date',
                                          controller: _toCtrl,
                                          onTap: () =>
                                              _pickDate(_toCtrl, false),
                                          validator: _req,
                                        )
                                      : SizedBox(),
                                  _paymentType == "full"
                                      ? SizedBox(height: 12)
                                      : Container(),
                                  _DescriptionCard(controller: _descCtrl),
                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: 160,
                                    height: 44,
                                    child: _PrimaryGradientButton(
                                      text: 'SUBMIT',
                                      onPressed: _submit,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Title overlay
          Positioned(
            top: 100,
            left: 57,
            right: 0,
            child: IgnorePointer(
              child: GradientText(
                'LEAVE APPLICATION FORM',
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                style: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.59,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
    _PrimaryGradientButton({
    required this.text,
    required this.onPressed,
  this.loading = false
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
          borderRadius: BorderRadius.circular(28),
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
            child: SizedBox(
              height: 44,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _kCardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
  ],
);

/* ------------------------ Choice Tile ------------------------ */

class PaymentChoiceTile extends StatelessWidget {
  const PaymentChoiceTile({
    super.key,
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  static const _grad = LinearGradient(
    colors: [Color(0xFF00C6FF), Color(0xFF7F53FD)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    if (selected) {
      // Selected: gradient fill
      return InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            gradient: _grad,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7F53FD).withOpacity(.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Not selected: gradient outline + gradient icon/text
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: _grad, // border gradient
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7F53FD).withOpacity(.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.6), // outline thickness
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GradientIcon(
                icon: Icons.radio_button_unchecked,
                size: 18,
                gradient: _grad,
              ),
              const SizedBox(width: 8),
              _GradientText(
                label: label,
                gradient: _grad,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- Gradient Helpers -------------------- */

class _GradientText extends StatelessWidget {
  const _GradientText({
    required this.label,
    required this.gradient,
    this.style,
  });

  final String label;
  final Gradient gradient;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => gradient.createShader(r),
      blendMode: BlendMode.srcIn,
      child: Text(
        label,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon({
    required this.icon,
    required this.size,
    required this.gradient,
  });

  final IconData icon;
  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => gradient.createShader(r),
      blendMode: BlendMode.srcIn,
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({
    required this.controller,
    this.hint = 'Description',
    this.validator,
    this.minLines = 3,
    this.maxLines = 6,
  })  : assert(minLines > 0),
        assert(maxLines >= minLines);

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _kCardDeco,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, size: 18, color: Color(0xFF1B1B1B)),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: minLines,
              maxLines: maxLines,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: const TextStyle(
                  fontFamily: 'ClashGrotesk',
                  color: Colors.black54,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.controller,
    required this.onTap,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: _kCardDeco,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: Color(0xFF1B1B1B),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AbsorbPointer(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  decoration: InputDecoration(
                    hintText: label,
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintStyle: const TextStyle(
                      fontFamily: 'ClashGrotesk',
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'ClashGrotesk',
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              size: 18,
              color: Color(0xFF7F53FD),
            ),
          ],
        ),
      ),
    );
  }
}
