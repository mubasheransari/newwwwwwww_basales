
import 'package:flutter/material.dart';
import 'package:new_amst_flutter/Firebase/firebase_services.dart';

class SupervisorManagementTab extends StatelessWidget {
  const SupervisorManagementTab({super.key});

  Future<void> _openAddDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cnicCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    bool saving = false;
    String? error;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        Future<void> save() async {
          final name = nameCtrl.text.trim();
          final email = emailCtrl.text.trim();
          final cnic = cnicCtrl.text.trim();
          final city = cityCtrl.text.trim();
          final pass = passCtrl.text;
          final conf = confirmCtrl.text;

          if (name.isEmpty || email.isEmpty || cnic.isEmpty || city.isEmpty || pass.isEmpty) {
            error = 'Please fill all fields';
            (dialogCtx as Element).markNeedsBuild();
            return;
          }
          if (pass != conf) {
            error = 'Password and confirm password must match';
            (dialogCtx as Element).markNeedsBuild();
            return;
          }

          saving = true;
          error = null;
          (dialogCtx as Element).markNeedsBuild();

          try {
            await FbSupervisorRepo.createSupervisor(
              name: name,
              email: email,
              cnic: cnic,
              city: city,
              password: pass,
            );
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          } catch (e) {
            error = e.toString();
            saving = false;
            if (dialogCtx is Element) {
              // ignore: invalid_use_of_protected_member
              dialogCtx.markNeedsBuild();
            }
          }
        }

        return AlertDialog(
          title: const Text('Add Supervisor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(decoration: const InputDecoration(labelText: 'Name'), controller: nameCtrl),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(decoration: const InputDecoration(labelText: 'CNIC'), controller: cnicCtrl),
                const SizedBox(height: 10),
                TextField(decoration: const InputDecoration(labelText: 'City'), controller: cityCtrl),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'Password'),
                  controller: passCtrl,
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  controller: confirmCtrl,
                  obscureText: true,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<FbSupervisorProfile>>(
        stream: FbSupervisorRepo.watchSupervisors(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final list = snap.data ?? const <FbSupervisorProfile>[];
          if (list.isEmpty) {
            return const Center(child: Text('No supervisors yet. Tap + to add.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = list[i];
              return ListTile(
                title: Text(s.name.isEmpty ? s.email : s.name),
                subtitle: Text('${s.email}\nCNIC: ${s.cnic} • City: ${s.city}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete supervisor?'),
                        content: Text('Delete "${s.name}"?\n\nNote: This deletes only Firestore profile.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await FbSupervisorRepo.deleteSupervisor(s.uid);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
