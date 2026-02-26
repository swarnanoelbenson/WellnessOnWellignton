/// Shared UI primitives used across admin panel sections.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colours ───────────────────────────────────────────────────────────────────

const Color adminCrimson = Color(0xFF8B0000);
const Color adminCharcoal = Color(0xFF2C2C2C);

// ── Time / date helpers ───────────────────────────────────────────────────────

/// Formats a [DateTime] as "H:MM AM/PM" (e.g. "8:02 AM", "12:45 PM").
String adminFmtTime(DateTime dt) {
  final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$h:$mm $period';
}

/// Formats a [DateTime] as "D/M/YYYY" (e.g. "26/2/2026").
String adminFmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

// ── AdminSectionHeader ────────────────────────────────────────────────────────

/// White header bar with a title and an optional trailing action widget.
/// Used consistently across all four admin sections.
class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: adminCharcoal,
            ),
          ),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

// ── AdminDateRangeRow ─────────────────────────────────────────────────────────

/// A compact "From → To" date-picker row used in the log and reports sections.
class AdminDateRangeRow extends StatelessWidget {
  const AdminDateRangeRow({
    super.key,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
  });

  final DateTime from;
  final DateTime to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DatePickerButton(
          label: 'From',
          date: from,
          onPick: onFromChanged,
          lastDate: to,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('→', style: GoogleFonts.nunito(fontSize: 16)),
        ),
        _DatePickerButton(
          label: 'To',
          date: to,
          onPick: onToChanged,
          firstDate: from,
        ),
      ],
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onPick,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: adminCharcoal,
      ),
      child: Text(
        '$label: ${adminFmtDate(date)}',
        style: GoogleFonts.nunito(fontSize: 13),
      ),
    );
  }
}

// ── AdminConfirmDialog ────────────────────────────────────────────────────────

/// Shows a Material confirmation dialog and returns [true] if confirmed.
Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  Color confirmColor = adminCrimson,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      content: Text(message, style: GoogleFonts.nunito()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: GoogleFonts.nunito()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(confirmLabel, style: GoogleFonts.nunito()),
        ),
      ],
    ),
  );
  return result ?? false;
}
