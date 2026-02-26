import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/auth_result.dart';
import '../models/models.dart';
import '../providers/attendance_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/email_providers.dart';
import 'admin/admin_panel_screen.dart';
import '../widgets/admin_login_modal.dart';
import '../widgets/password_entry_modal.dart';
import '../widgets/set_password_modal.dart';

// ── Shared constants ──────────────────────────────────────────────────────────

const Color _crimson = Color(0xFF8B0000);
const Color _charcoal = Color(0xFF2C2C2C);
const Color _green = Color(0xFF2E7D32);

// ── Time / date helpers ───────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$h:$mm $period';
}

String _formatDate(DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${days[dt.weekday - 1]}  ${dt.day} ${months[dt.month - 1]}';
}

// ── Main screen ───────────────────────────────────────────────────────────────

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  Timer? _adminHoldTimer;
  bool _isHoldingLogo = false;

  @override
  void initState() {
    super.initState();
    // Start the daily email scheduler once the widget is in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(emailServiceProvider).startScheduler();
    });
  }

  @override
  void dispose() {
    _adminHoldTimer?.cancel();
    super.dispose();
  }

  // ── Admin long-press (3 seconds) ──────────────────────────────────────────

  void _onLogoTapDown(TapDownDetails _) {
    _adminHoldTimer =
        Timer(const Duration(seconds: 3), _openAdminAccess);
    setState(() => _isHoldingLogo = true);
  }

  void _onLogoTapUp(TapUpDetails _) {
    _adminHoldTimer?.cancel();
    if (mounted) setState(() => _isHoldingLogo = false);
  }

  void _onLogoTapCancel() {
    _adminHoldTimer?.cancel();
    if (mounted) setState(() => _isHoldingLogo = false);
  }

  Future<void> _openAdminAccess() async {
    if (!mounted) return;
    setState(() => _isHoldingLogo = false);
    final authService = ref.read(authServiceProvider);
    final loggedIn = await showAdminLoginModal(
      context: context,
      onSubmit: (username, password) async {
        final result = await authService.loginAdmin(username, password);
        if (result is AdminLoginSuccess) {
          ref.read(adminSessionProvider.notifier).state = result.admin;
          return true;
        }
        return false;
      },
    );
    if (loggedIn && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      );
      // Clear the session and refresh the board in case admin made changes.
      if (mounted) {
        ref.read(adminSessionProvider.notifier).state = null;
        _refreshBoard();
      }
    }
  }

  // ── Clock-in flow ─────────────────────────────────────────────────────────

  Future<void> _onEmployeeTap(Employee employee) async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    ClockInResult? clockInResult;

    final didComplete = await showPasswordEntryModal(
      context: context,
      employeeName: employee.name,
      action: PasswordAction.clockIn,
      onSubmit: (password) async {
        clockInResult = await authService.clockIn(employee.id, password);
        return switch (clockInResult) {
          ClockInSuccess() => true,
          ClockInRequiresPasswordSetup() => true, // close modal; setup follows
          ClockInWrongPassword() => false,
          ClockInAlreadyClockedIn() => true,
          null => false,
        };
      },
    );

    if (!didComplete || !mounted) return;

    switch (clockInResult) {
      case ClockInSuccess():
        _refreshBoard();

      case ClockInRequiresPasswordSetup(
        employee: final setupEmployee,
        pendingRecord: final pending,
      ):
        if (!mounted) return;
        final newPassword = await showSetPasswordModal(
          context: context,
          employeeName: setupEmployee.name,
        );
        if (!mounted) return;
        await authService.completeClockInWithSetup(
          employee: setupEmployee,
          pendingRecord: pending,
          newPassword: newPassword,
        );
        _refreshBoard();

      default:
        break;
    }
  }

  // ── Clock-out flow ────────────────────────────────────────────────────────

  Future<void> _onClockedInCardTap(AttendanceRecord record) async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);

    final success = await showPasswordEntryModal(
      context: context,
      employeeName: record.employeeName,
      action: PasswordAction.clockOut,
      onSubmit: (password) async {
        final result =
            await authService.clockOut(record.employeeId, password);
        return result is ClockOutSuccess;
      },
    );

    if (success && mounted) _refreshBoard();
  }

  void _refreshBoard() {
    ref.invalidate(employeesProvider);
    ref.invalidate(todayAttendanceProvider);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(attendanceBoardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: boardAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _crimson),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load data.\n$e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(color: Colors.red.shade700),
                ),
              ),
              data: (board) => _buildBoard(board),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 68,
      color: _crimson,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Heart logo — hold 3 s to reveal admin login.
          GestureDetector(
            onTapDown: _onLogoTapDown,
            onTapUp: _onLogoTapUp,
            onTapCancel: _onLogoTapCancel,
            child: AnimatedOpacity(
              opacity: _isHoldingLogo ? 0.35 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Wellness on Wellington',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          const _LiveClock(),
        ],
      ),
    );
  }

  // ── Two-column board ──────────────────────────────────────────────────────

  Widget _buildBoard(AttendanceBoardState board) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left: Not Clocked In ──────────────────────────────────────────
        Expanded(
          child: _BoardColumn(
            title: 'Not Clocked In',
            count: board.notClockedIn.length,
            accentColor: _charcoal,
            emptyMessage: 'Everyone is accounted for!',
            children: [
              for (final emp in board.notClockedIn)
                _EmployeeCard(
                  name: emp.name,
                  onTap: () => _onEmployeeTap(emp),
                ),
            ],
          ),
        ),

        // Thin vertical divider
        Container(width: 1, color: Colors.grey.shade300),

        // ── Right: Clocked In + Completed (stacked) ───────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clocked In (takes more vertical space)
              Expanded(
                flex: 3,
                child: _BoardColumn(
                  title: 'Clocked In',
                  count: board.clockedIn.length,
                  accentColor: _green,
                  emptyMessage: 'No one is clocked in yet.',
                  children: [
                    for (final rec in board.clockedIn)
                      _ClockedInCard(
                        record: rec,
                        onTap: () => _onClockedInCardTap(rec),
                      ),
                  ],
                ),
              ),

              Container(height: 1, color: Colors.grey.shade300),

              // Completed
              Expanded(
                flex: 2,
                child: _BoardColumn(
                  title: 'Completed',
                  count: board.completed.length,
                  accentColor: _charcoal.withValues(alpha: 0.45),
                  emptyMessage: 'No completed shifts yet.',
                  children: [
                    for (final rec in board.completed)
                      _CompletedCard(record: rec),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Live clock ────────────────────────────────────────────────────────────────

class _LiveClock extends StatelessWidget {
  const _LiveClock();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(now),
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _formatDate(now),
              style: GoogleFonts.nunito(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Board column ──────────────────────────────────────────────────────────────

/// A labelled, scrollable column used for each attendance section.
class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.title,
    required this.count,
    required this.accentColor,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final int count;
  final Color accentColor;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          color: accentColor.withValues(alpha: 0.08),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Card list
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: GoogleFonts.nunito(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  children: children,
                ),
        ),
      ],
    );
  }
}

// ── Employee card — not clocked in ────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _crimson.withValues(alpha: 0.07),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _charcoal,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Clocked-in card ───────────────────────────────────────────────────────────

class _ClockedInCard extends StatelessWidget {
  const _ClockedInCard({required this.record, required this.onTap});

  final AttendanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1.5,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.green.withValues(alpha: 0.07),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.green.shade50,
                child: Icon(Icons.check, size: 18, color: _green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employeeName,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _charcoal,
                      ),
                    ),
                    Text(
                      'In since ${_formatTime(record.clockInTime)}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.logout, color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Completed card ────────────────────────────────────────────────────────────

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final hours = record.totalHours;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade100,
              child: const Icon(Icons.done_all, size: 18, color: Colors.grey),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.employeeName,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _charcoal.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    '${_formatTime(record.clockInTime)} → '
                    '${_formatTime(record.clockOutTime!)}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (hours != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${hours}h',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
