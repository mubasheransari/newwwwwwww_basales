import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';

class LocationManagementTab extends StatelessWidget {
  const LocationManagementTab({super.key});

  Future<void> _openEditDialog(BuildContext context, {String? id, Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: (existing?['name'] ?? '').toString());
    final radiusController = TextEditingController(
      text: (existing?['allowedRadiusMeters'] ?? 100).toString(),
    );

    GeoPoint? gp;
    final exLoc = existing?['allowedLocation'];
    if (exLoc is GeoPoint) gp = exLoc;

    final latController = TextEditingController(text: gp?.latitude.toString() ?? '');
    final lngController = TextEditingController(text: gp?.longitude.toString() ?? '');

    await showDialog(
      context: context,
      builder: (_) {
        bool saving = false;

        Future<void> save() async {
          final name = nameController.text.trim();
          final lat = double.tryParse(latController.text.trim());
          final lng = double.tryParse(lngController.text.trim());
          final radius = double.tryParse(radiusController.text.trim());

          if (name.isEmpty || lat == null || lng == null || radius == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fill all fields with valid numbers')),
            );
            return;
          }

          saving = true;
          (context as Element).markNeedsBuild();

          try {
            await FbLocationRepo.upsertLocation(
              id: id,
              name: name,
              lat: lat,
              lng: lng,
              radiusMeters: radius,
            );
            Navigator.of(context).pop();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Save failed: $e')),
            );
          }
        }

        return AlertDialog(
          title: Text(id == null ? 'Add Location' : 'Edit Location'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: latController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lngController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Radius (meters)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FbLocationRepo.streamLocations(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No locations yet. Tap + to add.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final data = d.data();
              final name = (data['name'] ?? d.id).toString();
              final gp = data['allowedLocation'] is GeoPoint ? data['allowedLocation'] as GeoPoint : null;
              final rad = (data['allowedRadiusMeters'] ?? '').toString();
              return ListTile(
                title: Text(name),
                subtitle: Text(
                  gp == null ? 'Radius: $rad m' : '(${gp.latitude}, ${gp.longitude}) • Radius: $rad m',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openEditDialog(context, id: d.id, existing: data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete location?'),
                            content: Text('Delete "$name"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await FbLocationRepo.deleteLocation(d.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
