import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/auth_providers.dart';
import 'admin_widgets.dart';
import 'attendance_log_section.dart';
import 'employees_section.dart';
import 'holidays_section.dart';
import 'reports_section.dart';

// ── Admin panel screen ────────────────────────────────────────────────────────

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  int _selectedIndex = 0;
  Timer? _inactivityTimer;

  static const _inactivityDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, _logOut);
  }

  void _logOut() {
    if (!mounted) return;
    ref.read(adminSessionProvider.notifier).state = null;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(adminSessionProvider);

    return Listener(
      onPointerDown: (_) => _resetTimer(),
      child: Scaffold(
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: _selectedIndex,
              adminName: admin?.username ?? 'Admin',
              onSelect: (i) => setState(() => _selectedIndex = i),
              onLogOut: _logOut,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  EmployeesSection(),
                  AttendanceLogSection(),
                  HolidaysSection(),
                  ReportsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.adminName,
    required this.onSelect,
    required this.onLogOut,
  });

  final int selectedIndex;
  final String adminName;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogOut;

  static const _items = [
    (icon: Icons.people_outline, label: 'Employees'),
    (icon: Icons.list_alt_outlined, label: 'Attendance Log'),
    (icon: Icons.beach_access_outlined, label: 'Public Holidays'),
    (icon: Icons.bar_chart_outlined, label: 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: adminCharcoal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header
          Container(
            color: adminCrimson,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    color: Colors.white, size: 26),
                const SizedBox(height: 8),
                Text(
                  'Admin Panel',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  adminName,
                  style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Navigation items
          for (var i = 0; i < _items.length; i++)
            _NavItem(
              icon: _items[i].icon,
              label: _items[i].label,
              isSelected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          // Log-out button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 16),
              label: Text(
                'Log Out',
                style:
                    GoogleFonts.nunito(fontWeight: FontWeight.w600),
              ),
              onPressed: onLogOut,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white.withValues(alpha: 0.85),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? adminCrimson : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
