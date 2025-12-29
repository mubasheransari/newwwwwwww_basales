import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Firebase/firebase_services.dart';

// ✅ FIX: import the journey plan repo where FbJourneyPlanRepo + FbLocation are defined
import 'package:new_amst_flutter/Firebase/fb_journey_plan_repo.dart' as jrepo;
class JourneyPlansManagementTab extends StatefulWidget {
  const JourneyPlansManagementTab({super.key});

  @override
  State<JourneyPlansManagementTab> createState() =>
      _JourneyPlansManagementTabState();
}

/// Backwards-compatible alias.
///
/// Some parts of the app refer to `JourneyPlansTab`.
/// Keep this wrapper so those imports don't break.
class JourneyPlansTab extends StatelessWidget {
  const JourneyPlansTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const JourneyPlansManagementTab();
  }
}

class _JourneyPlansManagementTabState extends State<JourneyPlansManagementTab> {
  String? _selectedSupervisorId;
  String _periodType = 'weekly';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 6));

  final Set<String> _selectedLocationIds = {};
  bool _saving = false;
  String? _error;

  void _recalcEndDate() {
    if (_periodType == 'weekly') {
      _endDate = DateTime(_startDate.year, _startDate.month, _startDate.day)
          .add(const Duration(days: 6));
    } else {
      // monthly: end at last day of month
      final firstNextMonth =
          DateTime(_startDate.year, _startDate.month + 1, 1);
      _endDate = firstNextMonth.subtract(const Duration(days: 1));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      _recalcEndDate();
    });
  }

  Future<void> _createPlan(List<FbLocation> allLocations) async {
    setState(() => _error = null);

    if (_selectedSupervisorId == null) {
      setState(() => _error = 'Please select a supervisor');
      return;
    }
    if (_selectedLocationIds.isEmpty) {
      setState(() => _error = 'Please select at least 1 location');
      return;
    }

    final stops = allLocations
        .where((l) => _selectedLocationIds.contains(l.id))
        .toList(growable: false);

    setState(() => _saving = true);
    try {
      await jrepo.FbJourneyPlanRepo.createJourneyPlan(
        supervisorId: _selectedSupervisorId!,
        periodType: _periodType,
        startDate: _startDate,
        endDate: _endDate,
        stops: stops,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey plan created')),
      );

      setState(() => _selectedLocationIds.clear());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeletePlan(String planId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete plan?',
          style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will delete the plan, its stops and visits. Continue?',
          style: TextStyle(fontFamily: 'ClashGrotesk'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'ClashGrotesk')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(fontFamily: 'ClashGrotesk')),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await jrepo.FbJourneyPlanRepo.deletePlan(planId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journey Plans',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),

          // Supervisor dropdown
          StreamBuilder<List<FbSupervisorProfile>>(
            stream: FbSupervisorRepo.watchSupervisors(),
            builder: (context, snap) {
              final items = snap.data ?? const <FbSupervisorProfile>[];
              return DropdownButtonFormField<String>(
                value: _selectedSupervisorId,
                decoration: const InputDecoration(
                  labelText: 'Supervisor',
                  border: OutlineInputBorder(),
                ),
                items: items
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.uid,
                        child: Text('${s.name} (${s.city})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedSupervisorId = v),
              );
            },
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _periodType,
                  decoration: const InputDecoration(
                    labelText: 'Plan type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _periodType = v;
                      _recalcEndDate();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStartDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    'Start: ${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'End date auto: ${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'ClashGrotesk',
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Select locations for this plan',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<FbLocation>>(
              stream: FbLocationRepo.watchLocations(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final locs = snap.data ?? const <FbLocation>[];

                if (locs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No locations found.',
                      style: TextStyle(fontFamily: 'ClashGrotesk'),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: locs.length,
                  itemBuilder: (_, i) {
                    final l = locs[i];
                    final checked = _selectedLocationIds.contains(l.id);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(
                        l.name,
                        style: const TextStyle(fontFamily: 'ClashGrotesk'),
                      ),
                      subtitle: Text(
                        'Lat: ${l.lat.toStringAsFixed(4)}, Lng: ${l.lng.toStringAsFixed(4)} • Radius: ${l.radiusMeters.toStringAsFixed(0)} m',
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedLocationIds.add(l.id);
                          } else {
                            _selectedLocationIds.remove(l.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 10),

          StreamBuilder<List<FbLocation>>(
            stream: FbLocationRepo.watchLocations(),
            builder: (context, snap) {
              final locs = snap.data ?? const <FbLocation>[];
              return SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _createPlan(locs),
                  icon: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    _saving ? 'Creating...' : 'Create Journey Plan',
                    style: const TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Existing plans (latest 30)',
            style: TextStyle(
              fontFamily: 'ClashGrotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 220,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: Fb.db
                  .collection('journeyPlans')
                  .orderBy('createdAt', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No plans found.',
                      style: TextStyle(fontFamily: 'ClashGrotesk'),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final data = d.data();

                    final supId = (data['supervisorId'] ?? '').toString();
                    final type = (data['periodType'] ?? '').toString();

                    // Support both keys: startDate/endDate OR startAt/endAt
                    final start = (data['startDate'] as Timestamp?)?.toDate() ??
                        (data['startAt'] as Timestamp?)?.toDate();
                    final end = (data['endDate'] as Timestamp?)?.toDate() ??
                        (data['endAt'] as Timestamp?)?.toDate();

                    String _short(DateTime? dt) =>
                        dt == null ? '--' : dt.toIso8601String().substring(0, 10);

                    return ListTile(
                      title: Text(
                        'Supervisor: $supId',
                        style: const TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${type.toUpperCase()} • ${_short(start)} → ${_short(end)}',
                        style: const TextStyle(fontFamily: 'ClashGrotesk'),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDeletePlan(d.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../Firebase/firebase_services.dart';


// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../Firebase/firebase_services.dart';

// // ✅ FIX: import the journey plan repo where FbJourneyPlanRepo is defined
// import 'package:new_amst_flutter/Firebase/fb_journey_plan_repo.dart';

// /// Admin screen tab to create Weekly / Monthly Journey Plans for supervisors.
// ///
// /// Data model (Firestore):
// /// - journeyPlans/{planId}
// ///     supervisorId, periodType("weekly"|"monthly"), startDate(Timestamp), endDate(Timestamp), createdAt, createdBy
// ///     stops: (subcollection) stops/{stopId} => locationId, name, allowedLocation(GeoPoint), allowedRadiusMeters
// class JourneyPlansManagementTab extends StatefulWidget {
//   const JourneyPlansManagementTab({super.key});

//   @override
//   State<JourneyPlansManagementTab> createState() =>
//       _JourneyPlansManagementTabState();
// }

// class _JourneyPlansManagementTabState extends State<JourneyPlansManagementTab> {
//   String? _selectedSupervisorId;
//   String _periodType = 'weekly';
//   DateTime _startDate = DateTime.now();
//   DateTime _endDate = DateTime.now().add(const Duration(days: 6));

//   final Set<String> _selectedLocationIds = {};
//   bool _saving = false;
//   String? _error;

//   void _recalcEndDate() {
//     if (_periodType == 'weekly') {
//       _endDate = DateTime(_startDate.year, _startDate.month, _startDate.day)
//           .add(const Duration(days: 6));
//     } else {
//       final firstNextMonth =
//           DateTime(_startDate.year, _startDate.month + 1, 1);
//       _endDate = firstNextMonth.subtract(const Duration(days: 1));
//     }
//   }

//   Future<void> _pickStartDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: _startDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2100),
//     );
//     if (picked == null) return;
//     setState(() {
//       _startDate = picked;
//       _recalcEndDate();
//     });
//   }

//   Future<void> _createPlan(List<FbLocation> allLocations) async {
//     setState(() => _error = null);

//     if (_selectedSupervisorId == null) {
//       setState(() => _error = 'Please select a supervisor');
//       return;
//     }
//     if (_selectedLocationIds.isEmpty) {
//       setState(() => _error = 'Please select at least 1 location');
//       return;
//     }

//     final stops = allLocations
//         .where((l) => _selectedLocationIds.contains(l.id))
//         .toList(growable: false);

//     setState(() => _saving = true);
//     try {
//       await FbJourneyPlanRepo.createJourneyPlan(
//         supervisorId: _selectedSupervisorId!,
//         periodType: _periodType,
//         startDate: _startDate,
//         endDate: _endDate,
//         stops: stops,
//       );

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Journey plan created')),
//       );

//       setState(() => _selectedLocationIds.clear());
//     } catch (e) {
//       setState(() => _error = e.toString());
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Journey Plans',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           const SizedBox(height: 10),

//           // Supervisor dropdown
//           StreamBuilder<List<FbSupervisorProfile>>(
//             stream: FbSupervisorRepo.watchSupervisors(),
//             builder: (context, snap) {
//               final items = snap.data ?? const <FbSupervisorProfile>[];
//               return DropdownButtonFormField<String>(
//                 value: _selectedSupervisorId,
//                 decoration: const InputDecoration(
//                   labelText: 'Supervisor',
//                   border: OutlineInputBorder(),
//                 ),
//                 items: items
//                     .map(
//                       (s) => DropdownMenuItem(
//                         value: s.uid,
//                         child: Text('${s.name} (${s.city})'),
//                       ),
//                     )
//                     .toList(),
//                 onChanged: (v) => setState(() => _selectedSupervisorId = v),
//               );
//             },
//           ),

//           const SizedBox(height: 12),

//           Row(
//             children: [
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: _periodType,
//                   decoration: const InputDecoration(
//                     labelText: 'Plan type',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: const [
//                     DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
//                     DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
//                   ],
//                   onChanged: (v) {
//                     if (v == null) return;
//                     setState(() {
//                       _periodType = v;
//                       _recalcEndDate();
//                     });
//                   },
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: _pickStartDate,
//                   icon: const Icon(Icons.date_range),
//                   label: Text(
//                     'Start: ${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'End date auto: ${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
//             style: const TextStyle(
//               fontFamily: 'ClashGrotesk',
//               color: Colors.black54,
//             ),
//           ),

//           const SizedBox(height: 14),

//           const Text(
//             'Select locations for this plan',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           const SizedBox(height: 8),

//           Expanded(
//             child: StreamBuilder<List<FbLocation>>(
//               stream: FbLocationRepo.watchLocations(),
//               builder: (context, snap) {
//                 if (snap.hasError) {
//                   return Center(child: Text('Error: ${snap.error}'));
//                 }
//                 if (!snap.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }

//                 final locs = snap.data ?? const <FbLocation>[];

//                 return ListView.builder(
//                   itemCount: locs.length,
//                   itemBuilder: (_, i) {
//                     final l = locs[i];
//                     final checked = _selectedLocationIds.contains(l.id);
//                     return CheckboxListTile(
//                       value: checked,
//                       title: Text(
//                         l.name,
//                         style: const TextStyle(fontFamily: 'ClashGrotesk'),
//                       ),
//                       subtitle: Text(
//                         'Lat: ${l.lat.toStringAsFixed(4)}, Lng: ${l.lng.toStringAsFixed(4)} • Radius: ${l.radiusMeters.toStringAsFixed(0)} m',
//                         style: const TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontSize: 12,
//                         ),
//                       ),
//                       onChanged: (v) {
//                         setState(() {
//                           if (v == true) {
//                             _selectedLocationIds.add(l.id);
//                           } else {
//                             _selectedLocationIds.remove(l.id);
//                           }
//                         });
//                       },
//                     );
//                   },
//                 );
//               },
//             ),
//           ),

//           if (_error != null) ...[
//             const SizedBox(height: 8),
//             Text(_error!, style: const TextStyle(color: Colors.red)),
//           ],

//           const SizedBox(height: 10),

//           StreamBuilder<List<FbLocation>>(
//             stream: FbLocationRepo.watchLocations(),
//             builder: (context, snap) {
//               final locs = snap.data ?? const <FbLocation>[];
//               return SizedBox(
//                 width: double.infinity,
//                 height: 48,
//                 child: ElevatedButton.icon(
//                   onPressed: _saving ? null : () => _createPlan(locs),
//                   icon: _saving
//                       ? const SizedBox(
//                           height: 18,
//                           width: 18,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         )
//                       : const Icon(Icons.add),
//                   label: Text(
//                     _saving ? 'Creating...' : 'Create Journey Plan',
//                     style: const TextStyle(
//                       fontFamily: 'ClashGrotesk',
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),

//           const SizedBox(height: 18),
//           const Divider(),
//           const SizedBox(height: 8),
//           const Text(
//             'Existing plans (latest 30)',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontWeight: FontWeight.w700,
//             ),
//           ),
//           const SizedBox(height: 8),

//           SizedBox(
//             height: 220,
//             child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//               stream: Fb.db
//                   .collection('journeyPlans')
//                   .orderBy('createdAt', descending: true)
//                   .limit(30)
//                   .snapshots(),
//               builder: (context, snap) {
//                 if (!snap.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 final docs = snap.data!.docs;

//                 return ListView.separated(
//                   itemCount: docs.length,
//                   separatorBuilder: (_, __) => const Divider(height: 1),
//                   itemBuilder: (_, i) {
//                     final d = docs[i];
//                     final data = d.data();
//                     final supId = (data['supervisorId'] ?? '').toString();
//                     final type = (data['periodType'] ?? '').toString();
//                     final start = (data['startDate'] as Timestamp?)?.toDate();
//                     final end = (data['endDate'] as Timestamp?)?.toDate();

//                     return ListTile(
//                       title: Text(
//                         'Supervisor: $supId',
//                         style: const TextStyle(
//                           fontFamily: 'ClashGrotesk',
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                       subtitle: Text(
//                         '${type.toUpperCase()} • ${start?.toIso8601String().substring(0, 10) ?? '--'} → ${end?.toIso8601String().substring(0, 10) ?? '--'}',
//                         style: const TextStyle(fontFamily: 'ClashGrotesk'),
//                       ),
//                       trailing: IconButton(
//                         icon: const Icon(Icons.delete_outline),
//                         onPressed: () async {
//                           await FbJourneyPlanRepo.deletePlan(d.id);
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


// /// Admin screen tab to create Weekly / Monthly Journey Plans for supervisors.
// ///
// /// Data model (Firestore):
// /// - journeyPlans/{planId}
// ///     supervisorId, periodType("weekly"|"monthly"), startDate(Timestamp), endDate(Timestamp), createdAt, createdBy
// ///     stops: (subcollection) stops/{stopId} => locationId, name, allowedLocation(GeoPoint), allowedRadiusMeters
// class JourneyPlansManagementTab extends StatefulWidget {
//   const JourneyPlansManagementTab({super.key});

//   @override
//   State<JourneyPlansManagementTab> createState() => _JourneyPlansManagementTabState();
// }

// class _JourneyPlansManagementTabState extends State<JourneyPlansManagementTab> {
//   String? _selectedSupervisorId;
//   String _periodType = 'weekly';
//   DateTime _startDate = DateTime.now();
//   DateTime _endDate = DateTime.now().add(const Duration(days: 6));

//   final Set<String> _selectedLocationIds = {};
//   bool _saving = false;
//   String? _error;

//   void _recalcEndDate() {
//     if (_periodType == 'weekly') {
//       _endDate = DateTime(_startDate.year, _startDate.month, _startDate.day)
//           .add(const Duration(days: 6));
//     } else {
//       // monthly: end at last day of the month
//       final firstNextMonth = DateTime(_startDate.year, _startDate.month + 1, 1);
//       _endDate = firstNextMonth.subtract(const Duration(days: 1));
//     }
//   }

//   Future<void> _pickStartDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: _startDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime(2100),
//     );
//     if (picked == null) return;
//     setState(() {
//       _startDate = picked;
//       _recalcEndDate();
//     });
//   }

//   Future<void> _createPlan(List<FbLocation> allLocations) async {
//     setState(() {
//       _error = null;
//     });

//     if (_selectedSupervisorId == null) {
//       setState(() => _error = 'Please select a supervisor');
//       return;
//     }
//     if (_selectedLocationIds.isEmpty) {
//       setState(() => _error = 'Please select at least 1 location');
//       return;
//     }

//     final stops = allLocations
//         .where((l) => _selectedLocationIds.contains(l.id))
//         .toList(growable: false);

//     setState(() => _saving = true);
//     try {
//       await FbJourneyPlanRepo.createJourneyPlan(
//         supervisorId: _selectedSupervisorId!,
//         periodType: _periodType,
//         startDate: _startDate,
//         endDate: _endDate,
//         stops: stops,
//       );

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Journey plan created')),
//       );

//       setState(() {
//         _selectedLocationIds.clear();
//       });
//     } catch (e) {
//       setState(() => _error = e.toString());
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Journey Plans',
//             style: TextStyle(
//               fontFamily: 'ClashGrotesk',
//               fontSize: 18,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           const SizedBox(height: 10),

//           // Supervisor dropdown
//           StreamBuilder<List<FbSupervisorProfile>>(
//             stream: FbSupervisorRepo.watchSupervisors(),
//             builder: (context, snap) {
//               final items = snap.data ?? const <FbSupervisorProfile>[];
//               return DropdownButtonFormField<String>(
//                 value: _selectedSupervisorId,
//                 decoration: const InputDecoration(
//                   labelText: 'Supervisor',
//                   border: OutlineInputBorder(),
//                 ),
//                 items: items
//                     .map(
//                       (s) => DropdownMenuItem(
//                         value: s.uid,
//                         child: Text('${s.name} (${s.city})'),
//                       ),
//                     )
//                     .toList(),
//                 onChanged: (v) => setState(() => _selectedSupervisorId = v),
//               );
//             },
//           ),

//           const SizedBox(height: 12),

//           Row(
//             children: [
//               Expanded(
//                 child: DropdownButtonFormField<String>(
//                   value: _periodType,
//                   decoration: const InputDecoration(
//                     labelText: 'Plan type',
//                     border: OutlineInputBorder(),
//                   ),
//                   items: const [
//                     DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
//                     DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
//                   ],
//                   onChanged: (v) {
//                     if (v == null) return;
//                     setState(() {
//                       _periodType = v;
//                       _recalcEndDate();
//                     });
//                   },
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: _pickStartDate,
//                   icon: const Icon(Icons.date_range),
//                   label: Text(
//                     'Start: ${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'End date auto: ${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
//             style: const TextStyle(fontFamily: 'ClashGrotesk', color: Colors.black54),
//           ),

//           const SizedBox(height: 14),

//           const Text(
//             'Select locations for this plan',
//             style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w700),
//           ),
//           const SizedBox(height: 8),

//           Expanded(
//             child: StreamBuilder<List<FbLocation>>(
//               stream: FbLocationRepo.watchLocations(),
//               builder: (context, snap) {
//                 final locs = snap.data ?? const <FbLocation>[];
//                 if (snap.hasError) {
//                   return Center(child: Text('Error: ${snap.error}'));
//                 }
//                 if (!snap.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }

//                 return ListView.builder(
//                   itemCount: locs.length,
//                   itemBuilder: (_, i) {
//                     final l = locs[i];
//                     final checked = _selectedLocationIds.contains(l.id);
//                     return CheckboxListTile(
//                       value: checked,
//                       title: Text(l.name, style: const TextStyle(fontFamily: 'ClashGrotesk')),
//                       subtitle: Text(
//                         'Lat: ${l.lat.toStringAsFixed(4)}, Lng: ${l.lng.toStringAsFixed(4)} • Radius: ${l.radiusMeters.toStringAsFixed(0)} m',
//                         style: const TextStyle(fontFamily: 'ClashGrotesk', fontSize: 12),
//                       ),
//                       onChanged: (v) {
//                         setState(() {
//                           if (v == true) {
//                             _selectedLocationIds.add(l.id);
//                           } else {
//                             _selectedLocationIds.remove(l.id);
//                           }
//                         });
//                       },
//                     );
//                   },
//                 );
//               },
//             ),
//           ),

//           if (_error != null) ...[
//             const SizedBox(height: 8),
//             Text(_error!, style: const TextStyle(color: Colors.red)),
//           ],

//           const SizedBox(height: 10),

//           StreamBuilder<List<FbLocation>>(
//             stream: FbLocationRepo.watchLocations(),
//             builder: (context, snap) {
//               final locs = snap.data ?? const <FbLocation>[];
//               return SizedBox(
//                 width: double.infinity,
//                 height: 48,
//                 child: ElevatedButton.icon(
//                   onPressed: _saving ? null : () => _createPlan(locs),
//                   icon: _saving
//                       ? const SizedBox(
//                           height: 18,
//                           width: 18,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         )
//                       : const Icon(Icons.add),
//                   label: Text(
//                     _saving ? 'Creating...' : 'Create Journey Plan',
//                     style: const TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w700),
//                   ),
//                 ),
//               );
//             },
//           ),

//           const SizedBox(height: 18),

//           const Divider(),
//           const SizedBox(height: 8),
//           const Text(
//             'Existing plans (latest 30)',
//             style: TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w700),
//           ),
//           const SizedBox(height: 8),

//           SizedBox(
//             height: 220,
//             child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
//               stream: Fb.db
//                   .collection('journeyPlans')
//                   .orderBy('createdAt', descending: true)
//                   .limit(30)
//                   .snapshots(),
//               builder: (context, snap) {
//                 final docs = snap.data?.docs ?? const [];
//                 if (!snap.hasData) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//                 return ListView.separated(
//                   itemCount: docs.length,
//                   separatorBuilder: (_, __) => const Divider(height: 1),
//                   itemBuilder: (_, i) {
//                     final d = docs[i];
//                     final data = d.data();
//                     final supId = (data['supervisorId'] ?? '').toString();
//                     final type = (data['periodType'] ?? '').toString();
//                     final start = (data['startDate'] as Timestamp?)?.toDate();
//                     final end = (data['endDate'] as Timestamp?)?.toDate();
//                     return ListTile(
//                       title: Text(
//                         'Supervisor: $supId',
//                         style: const TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w700),
//                       ),
//                       subtitle: Text(
//                         '${type.toUpperCase()} • ${start?.toIso8601String().substring(0, 10) ?? '--'} → ${end?.toIso8601String().substring(0, 10) ?? '--'}',
//                         style: const TextStyle(fontFamily: 'ClashGrotesk'),
//                       ),
//                       trailing: IconButton(
//                         icon: const Icon(Icons.delete_outline),
//                         onPressed: () async {
//                           await FbJourneyPlanRepo.deletePlan(d.id);
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
