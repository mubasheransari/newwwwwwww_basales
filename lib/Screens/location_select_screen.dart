import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';
import 'package:new_amst_flutter/Screens/app_shell.dart';

class LocationSelectScreen extends StatefulWidget {
  const LocationSelectScreen({super.key});

  @override
  State<LocationSelectScreen> createState() => _LocationSelectScreenState();
}

class _LocationSelectScreenState extends State<LocationSelectScreen> {
  String? _selectedId;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_selectedId == null) {
      setState(() => _error = 'Please select a location');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
            final uid = Fb.uid;
      if (uid == null) throw Exception('Not signed in');
      final all = await FbLocationRepo.fetchLocationsOnce();
      final selected = all.firstWhere((x) => x.id == _selectedId);
      await FbLocationRepo.applyLocationToUser(uid: uid, location: selected);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your working location to lock attendance coordinates.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<FbLocation>>(
              stream: FbLocationRepo.watchLocations(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final locations = snap.data ?? const <FbLocation>[];
                if (locations.isEmpty) {
                  return const Text('No locations found. Ask admin to add locations.');
                }

                                final items = locations
                    .map((l) => DropdownMenuItem<String>(
                          value: l.id,
                          child: Text(l.name.isEmpty ? l.id : l.name),
                        ))
                    .toList();

                return DropdownButtonFormField<String>(
                  value: _selectedId,
                  items: items,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _saving ? null : (v) => setState(() => _selectedId = v),
                );
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
