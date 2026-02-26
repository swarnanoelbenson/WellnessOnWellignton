import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/attendance_record.dart';
import '../../providers/admin_providers.dart';
import 'admin_widgets.dart';

class AttendanceLogSection extends ConsumerStatefulWidget {
  const AttendanceLogSection({super.key});

  @override
  ConsumerState<AttendanceLogSection> createState() =>
      _AttendanceLogSectionState();
}

class _AttendanceLogSectionState extends ConsumerState<AttendanceLogSection> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    // Default to today.
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = DateTime(today.year, today.month, today.day);
  }

  @override
  Widget build(BuildContext context) {
    final range = (from: _from, to: _to);
    final recordsAsync = ref.watch(attendanceForRangeProvider(range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Attendance Log',
          action: AdminDateRangeRow(
            from: _from,
            to: _to,
            onFromChanged: (d) => setState(() => _from = d),
            onToChanged: (d) => setState(() => _to = d),
          ),
        ),
        Expanded(
          child: recordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Error loading records: $e')),
            data: (records) => records.isEmpty
                ? Center(
                    child: Text(
                      'No records for this date range.',
                      style: GoogleFonts.nunito(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : _RecordsTable(records: records),
          ),
        ),
      ],
    );
  }
}

// ── Records data table ────────────────────────────────────────────────────────

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({required this.records});

  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columnSpacing: 28,
          columns: [
            DataColumn(label: _col('Employee')),
            DataColumn(label: _col('Date')),
            DataColumn(label: _col('Clock In')),
            DataColumn(label: _col('Clock Out')),
            DataColumn(label: _col('Hours'), numeric: true),
            DataColumn(label: _col('Status')),
          ],
          rows: [
            for (final r in records)
              DataRow(cells: [
                DataCell(Text(r.employeeName, style: _cell())),
                DataCell(Text(r.dateKey, style: _cell())),
                DataCell(Text(adminFmtTime(r.clockInTime), style: _cell())),
                DataCell(Text(
                  r.clockOutTime != null
                      ? adminFmtTime(r.clockOutTime!)
                      : '—',
                  style: _cell(),
                )),
                DataCell(Text(
                  r.totalHours != null
                      ? r.totalHours!.toStringAsFixed(2)
                      : '—',
                  style: _cell(),
                )),
                DataCell(_StatusBadge(status: r.status)),
              ]),
          ],
        ),
      ),
    );
  }

  TextStyle _cell() => GoogleFonts.nunito(fontSize: 13);

  Widget _col(String text) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      AttendanceStatus.complete => (Colors.green.shade700, 'Complete'),
      AttendanceStatus.absent => (Colors.red.shade700, 'Absent'),
      AttendanceStatus.missingClockOut => (
          Colors.orange.shade700,
          'Missing Clock-Out'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
