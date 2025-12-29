import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:new_amst_flutter/Bloc/auth_bloc.dart';
import 'package:new_amst_flutter/Bloc/auth_event.dart';
import 'package:new_amst_flutter/Bloc/auth_state.dart';
 

class LeaveTypeDebugPage extends StatelessWidget {
  const LeaveTypeDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = GetStorage();
    final userId = (box.read('user_id') ?? '3839').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Types Debug')),
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (p, c) => p.getLeavesTypeStatus != c.getLeavesTypeStatus,
        listener: (context, state) {
          if (state.getLeavesTypeStatus == GetLeavesTypeStatus.failure) {
            final msg = state.error ?? 'unknown_error';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Leave types failed: $msg')),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${state.getLeavesTypeStatus}'),
                  if (state.error != null) Text('Error: ${state.error}'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.getLeaveTypeModel?.items.length ?? 0,
                      itemBuilder: (_, i) {
                        final item = state.getLeaveTypeModel!.items[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text('id: ${item.id}'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context
                        .read<AuthBloc>()
                        .add(GetLeavesTypeEvent(userId)),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
