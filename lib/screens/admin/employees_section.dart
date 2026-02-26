import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/employee.dart';
import '../../providers/admin_providers.dart';
import 'admin_widgets.dart';

class EmployeesSection extends ConsumerWidget {
  const EmployeesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(adminEmployeesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Employees',
          action: FilledButton.icon(
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text('Add Employee', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            onPressed: () => _showAddDialog(context, ref),
            style: FilledButton.styleFrom(backgroundColor: adminCrimson),
          ),
        ),
        Expanded(
          child: employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading employees: $e')),
            data: (employees) => employees.isEmpty
                ? Center(
                    child: Text(
                      'No employees yet. Tap "Add Employee" to get started.',
                      style: GoogleFonts.nunito(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: employees.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) =>
                        _EmployeeTile(employee: employees[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Employee',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, true),
          decoration: InputDecoration(
            labelText: 'Full Name',
            hintText: 'e.g. Jane Smith',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.nunito()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: adminCrimson),
            child: Text('Add', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await ref.read(adminServiceProvider).addEmployee(controller.text);
      ref.invalidate(adminEmployeesProvider);
    }
    controller.dispose();
  }
}

// ── Employee tile ─────────────────────────────────────────────────────────────

class _EmployeeTile extends ConsumerWidget {
  const _EmployeeTile({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: adminCharcoal,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + password status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (employee.isDefaultPassword)
                    Text(
                      'Password not yet changed',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                ],
              ),
            ),

            // Reset password
            IconButton(
              icon: const Icon(Icons.lock_reset_outlined),
              tooltip: 'Reset to default password',
              color: Colors.blueGrey.shade600,
              onPressed: () => _confirmReset(context, ref),
            ),

            // Remove employee
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove employee',
              color: Colors.red.shade700,
              onPressed: () => _confirmRemove(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await adminConfirm(
      context,
      title: 'Reset Password',
      message:
          "Reset ${employee.name}'s password? "
          'They will be required to set a new personal password on their '
          'next clock-in.',
      confirmLabel: 'Reset',
      confirmColor: Colors.blueGrey.shade700,
    );
    if (ok) {
      await ref.read(adminServiceProvider).resetEmployeePassword(employee);
      ref.invalidate(adminEmployeesProvider);
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await adminConfirm(
      context,
      title: 'Remove Employee',
      message:
          'Remove ${employee.name}? All their attendance records will also '
          'be deleted. This cannot be undone.',
      confirmLabel: 'Remove',
    );
    if (ok) {
      await ref.read(adminServiceProvider).removeEmployee(employee.id);
      ref.invalidate(adminEmployeesProvider);
    }
  }
}
