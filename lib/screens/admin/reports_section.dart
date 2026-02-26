import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/admin_providers.dart';
import '../../services/admin_service.dart';
import 'admin_widgets.dart';

class ReportsSection extends ConsumerStatefulWidget {
  const ReportsSection({super.key});

  @override
  ConsumerState<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends ConsumerState<ReportsSection> {
  late DateTime _from;
  late DateTime _to;
  String? _csvData;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Default to the current month.
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, 1);
    _to = DateTime(today.year, today.month, today.day);
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
      _csvData = null;
    });
    try {
      final records = await ref
          .read(adminServiceProvider)
          .getAttendanceForDateRange(_from, _to);
      final csv = AdminService.generateCsv(records);
      if (mounted) {
        setState(() {
          _csvData = csv;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_csvData == null) return;
    await Clipboard.setData(ClipboardData(text: _csvData!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _emailReport() async {
    if (_csvData == null) return;
    final subject =
        'Wellness on Wellington — Attendance ${adminFmtDate(_from)} to ${adminFmtDate(_to)}';
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': subject,
        'body': _csvData!,
      },
    );
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open mail app.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSectionHeader(
          title: 'Reports',
          action: AdminDateRangeRow(
            from: _from,
            to: _to,
            onFromChanged: (d) => setState(() {
              _from = d;
              _csvData = null;
            }),
            onToChanged: (d) => setState(() {
              _to = d;
              _csvData = null;
            }),
          ),
        ),
        // Action bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border:
                Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              FilledButton.icon(
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.bar_chart, size: 18),
                label: Text(
                  'Generate Report',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                ),
                onPressed: _isGenerating ? null : _generateReport,
                style:
                    FilledButton.styleFrom(backgroundColor: adminCrimson),
              ),
              if (_csvData != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: Text(
                    'Copy CSV',
                    style:
                        GoogleFonts.nunito(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _copyToClipboard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adminCharcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: Text(
                    'Email Report',
                    style:
                        GoogleFonts.nunito(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _emailReport,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adminCrimson,
                    side: const BorderSide(color: adminCrimson),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isGenerating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_csvData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Select a date range and tap "Generate Report".',
              style: GoogleFonts.nunito(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _csvData!,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              color: adminCharcoal,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
