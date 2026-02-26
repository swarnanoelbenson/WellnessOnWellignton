import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/public_holiday.dart';
import '../../providers/admin_providers.dart';
import 'admin_widgets.dart';

class HolidaysSection extends ConsumerWidget {
  const HolidaysSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidaysAsync = ref.watch(adminHolidaysProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Public Holidays',
          action: FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add Holiday',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            onPressed: () => _showAddDialog(context, ref),
            style: FilledButton.styleFrom(backgroundColor: adminCrimson),
          ),
        ),
        Expanded(
          child: holidaysAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error loading holidays: $e')),
            data: (holidays) => holidays.isEmpty
                ? Center(
                    child: Text(
                      'No public holidays configured.',
                      style: GoogleFonts.nunito(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: holidays.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) =>
                        _HolidayTile(holiday: holidays[i]),
                  ),
          ),
        ),
      ],
    );
  }

  // Shows a date picker, then a name input dialog.
  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year),
      lastDate: DateTime(today.year + 3),
      helpText: 'Select Holiday Date',
    );
    if (pickedDate == null || !context.mounted) return;

    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Public Holiday',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${adminFmtDate(pickedDate)}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: adminCharcoal.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.pop(ctx, true),
              decoration: InputDecoration(
                labelText: 'Holiday Name',
                hintText: 'e.g. ANZAC Day',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: GoogleFonts.nunito(),
            ),
          ],
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

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      await ref.read(adminServiceProvider).addPublicHoliday(
            pickedDate,
            nameController.text,
          );
      ref.invalidate(adminHolidaysProvider);
    }
    nameController.dispose();
  }
}

// ── Holiday tile ──────────────────────────────────────────────────────────────

class _HolidayTile extends ConsumerWidget {
  const _HolidayTile({required this.holiday});

  final PublicHoliday holiday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: adminCrimson.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.beach_access_outlined,
              color: adminCrimson, size: 20),
        ),
        title: Text(
          holiday.name,
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          holiday.dateKey,
          style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red.shade700,
          tooltip: 'Remove holiday',
          onPressed: () => _confirmRemove(context, ref),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await adminConfirm(
      context,
      title: 'Remove Holiday',
      message: 'Remove "${holiday.name}" (${holiday.dateKey})?',
      confirmLabel: 'Remove',
    );
    if (ok) {
      await ref.read(adminServiceProvider).removePublicHoliday(holiday.id);
      ref.invalidate(adminHolidaysProvider);
    }
  }
}
