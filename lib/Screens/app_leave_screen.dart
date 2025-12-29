import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:new_amst_flutter/Widgets/watermarked_widget.dart';


class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();

  final _userIdCtrl   = TextEditingController();
  String? _leaveTypeId; // from dropdown
  String? _fullHalf;    // "Full"/"Half"
  DateTime? _fromDate;
  DateTime? _toDate;
  final _fromCtrl     = TextEditingController();
  final _toCtrl       = TextEditingController();
  final _descCtrl     = TextEditingController();

  final bool _submitting = false;

  static final _fmt = DateFormat('dd-MMM-yyyy'); // 01-Feb-2025

  @override
  void initState() {
    super.initState();
    final box = GetStorage();
    final uid = (box.read('user_id') ?? '5902').toString();
    _userIdCtrl.text = uid;

    // Ensure leave types are loaded
    // final bloc = context.read<AuthBloc>();
    // if (bloc.state.getLeavesTypeStatus == GetLeavesTypeStatus.initial ||
    //     bloc.state.getLeavesTypeStatus == GetLeavesTypeStatus.failure) {
    //   bloc.add(GetLeavesTypeEvent(uid));
    // }
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  Future<void> _pickDate(TextEditingController target, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_fromDate ?? now) : (_toDate ?? _fromDate ?? now);
    final first = DateTime(now.year - 1);
    final last  = DateTime(now.year + 2);

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


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF2F3F5),
        title: const Text(
          'Apply Leave',
          style: TextStyle(
            fontFamily: 'ClashGrotesk',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
           WatermarkTiledSmall(tileScale: 25.0),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width < 380 ? 16 : 22),
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
                        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 6),

                              // USER ID (prefilled, editable)
                              // _InputCardModern(
                              //   hint: 'User ID',
                              //   iconAsset: 'assets/name_icon.png',
                              //   controller: _userIdCtrl,
                              //   keyboardType: TextInputType.number,
                              //   validator: _req,
                              // ),
                              // const SizedBox(height: 12),

                              // LEAVE TYPE (from AuthBloc)
                             /* BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final items = state.getLeaveTypeModel?.items ?? const [];
                                  final loading = state.getLeavesTypeStatus == GetLeavesTypeStatus.loading;

                                  return _DropdownModern(
                                    hint: 'Leave Type',
                                    value: _leaveTypeId,
                                    items: items
                                        .map((e) => DropdownMenuItem<String>(
                                              value: e.id,
                                              child: Text(e.name,
                                                  style: const TextStyle(
                                                    fontFamily: 'ClashGrotesk',
                                                    fontWeight: FontWeight.w600,
                                                  )),
                                            ))
                                        .toList(),
                                    onChanged: loading ? null : (v) => setState(() => _leaveTypeId = v),
                                    disabledHint: loading ? const Text('Loading...') : null,
                                    validator: (v) => v == null ? 'Required' : null,
                                  );
                                },
                              ),
                              const SizedBox(height: 12),*/

                              // FULL / HALF
                              _DropdownModern(
                                hint: 'Full or Half',
                                value: _fullHalf,
                                items: const ['Full', 'Half']
                                    .map((e) => DropdownMenuItem<String>(
                                          value: e,
                                          child: Text(e,
                                              style: const TextStyle(
                                                fontFamily: 'ClashGrotesk',
                                                fontWeight: FontWeight.w600,
                                              )),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _fullHalf = v),
                                validator: (v) => v == null ? 'Required' : null,
                              ),
                              const SizedBox(height: 12),

                              // FROM DATE
                              _DateCard(
                                label: 'From Date',
                                controller: _fromCtrl,
                                onTap: () => _pickDate(_fromCtrl, true),
                                validator: _req,
                              ),
                              const SizedBox(height: 12),

                              // TO DATE
                              _DateCard(
                                label: 'To Date',
                                controller: _toCtrl,
                                onTap: () => _pickDate(_toCtrl, false),
                                validator: _req,
                              ),
                              const SizedBox(height: 12),

                              // DESC
                              _InputCardModern(
                                hint: 'Description',
                                iconAsset: 'assets/name_icon.png',
                                controller: _descCtrl,
                                maxLines: 3,
                                validator: _req,
                              ),
                              const SizedBox(height: 20),

                              SizedBox(
                                width: 180,
                                height: 44,
                                child: _PrimaryGradientButton(
                                  text: _submitting ? 'Submitting...' : 'APPLY LEAVE',
                                 onPressed: (){},// onPressed: _submitting ? null : _submit,
                                  loading: _submitting,
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
          ),
        ],
      ),
    );
  }
}


class _InputCardModern extends StatelessWidget {
  const _InputCardModern({
    required this.hint,
    required this.iconAsset,
    this.controller,
    this.validator,
    this.maxLines = 1,
    this.keyboardType, // <-- added
  });

  final String hint;
  final String iconAsset;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType; // <-- now initialized via ctor

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _kCardDeco,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment:
            maxLines == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Image.asset(iconAsset, height: 17, width: 17, color: const Color(0xFF1B1B1B)),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType ??
                  (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
              validator: validator,
              maxLines: maxLines,
              textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.done,
              style: const TextStyle(
                fontFamily: 'ClashGrotesk',
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
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

class _DropdownModern extends StatelessWidget {
  const _DropdownModern({
    required this.hint,
    required this.items,
    required this.onChanged,
    this.value,
    this.validator,
    this.disabledHint, // <-- added
  });

  final String hint;
  final List<DropdownMenuItem<String>> items;
  final String? value;
  final String? Function(String?)? validator;
  final void Function(String?)? onChanged;
  final Widget? disabledHint; // <-- now initialized via ctor

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: _kCardDeco,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: value, // (use `value`; `initialValue` can be problematic)
        items: items,
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        hint: Text(
          hint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'ClashGrotesk',
            color: Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        disabledHint: disabledHint,
        icon: Container(
          height: 36,
          width: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.expand_more_rounded, size: 20, color: Color(0xFF7F53FD)),
        ),
        borderRadius: BorderRadius.circular(14),
        dropdownColor: Colors.white,
        menuMaxHeight: 300,
        style: const TextStyle(
          fontFamily: 'ClashGrotesk',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
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
            const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF1B1B1B)),
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
            const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF7F53FD)),
          ],
        ),
      ),
    );
  }
}

const _kCardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ],
);

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
              height: 48,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
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
