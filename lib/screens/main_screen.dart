import 'dart:async';
import 'dart:io';

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
import 'windows/windows_board.dart';

// ── Shared constants ──────────────────────────────────────────────────────────

const Color _crimson = Color(0xFF8B0000);
const Color _charcoal = Color(0xFF2C2C2C);
const Color _green = Color(0xFF2E7D32);

// ── Time / date helpers ───────────────────────────────────────────────────────

/// 24-hour HH:mm format used on attendance board cards.
String _fmt24(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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
      if (Platform.isWindows) {
        // On Windows the admin panel slides in as a full-screen modal overlay
        // so the attendance board stays in the widget tree behind it.
        // AdminPanelScreen._logOut calls Navigator.pop() which closes the
        // dialog route correctly, just as it does for the push route below.
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierLabel: '',
          barrierColor: Colors.black45,
          transitionDuration: const Duration(milliseconds: 180),
          transitionBuilder: (_, animation, _, child) => FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
          pageBuilder: (_, _, _) => const AdminPanelScreen(),
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
      }
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

    // Windows gets the desktop layout; Android / iOS keep the tablet layout.
    if (Platform.isWindows) {
      return _buildWindowsScaffold(boardAsync);
    }

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

  // ── Windows desktop layout ────────────────────────────────────────────────

  Scaffold _buildWindowsScaffold(AsyncValue<AttendanceBoardState> boardAsync) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Persistent top nav bar with logo, clock, and Admin button.
          DesktopTopBar(onAdminTap: _openAdminAccess),
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
              data: _buildDesktopBoard,
            ),
          ),
        ],
      ),
    );
  }

  /// Three-column desktop attendance board (Not Clocked In | Clocked In |
  /// Completed), each with a count summary header and a search/filter bar.
  Widget _buildDesktopBoard(AttendanceBoardState board) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Not Clocked In ──────────────────────────────────────────────
        Expanded(
          child: DesktopBoardColumn(
            title: 'Not Clocked In',
            accentColor: _charcoal,
            emptyMessage: 'Everyone is accounted for!',
            namedCards: [
              for (final emp in board.notClockedIn)
                (
                  emp.name,
                  DesktopEmployeeCard(
                    key: ValueKey(emp.id),
                    name: emp.name,
                    onTap: () => _onEmployeeTap(emp),
                    lastClockOut: board.lastClockOutTimes[emp.id],
                  ),
                ),
            ],
          ),
        ),

        Container(width: 1, color: Colors.grey.shade300),

        // ── Clocked In ──────────────────────────────────────────────────
        Expanded(
          child: DesktopBoardColumn(
            title: 'Clocked In',
            accentColor: _green,
            emptyMessage: 'No one is clocked in yet.',
            namedCards: [
              for (final rec in board.clockedIn)
                (
                  rec.employeeName,
                  DesktopClockedInCard(
                    key: ValueKey(rec.id),
                    record: rec,
                    onTap: () => _onClockedInCardTap(rec),
                  ),
                ),
            ],
          ),
        ),

      ],
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
          // Clinic logo — hold 3 s to reveal admin login.
          GestureDetector(
            onTapDown: _onLogoTapDown,
            onTapUp: _onLogoTapUp,
            onTapCancel: _onLogoTapCancel,
            child: AnimatedOpacity(
              opacity: _isHoldingLogo ? 0.35 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Image.asset(
                'assets/main_page_logo.jpg',
                height: 44,
                fit: BoxFit.contain,
              ),
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
                  lastClockOut: board.lastClockOutTimes[emp.id],
                ),
            ],
          ),
        ),

        // Thin vertical divider
        Container(width: 1, color: Colors.grey.shade300),

        // ── Right: Clocked In ─────────────────────────────────────────────
        Expanded(
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
      ],
    );
  }
}

// ── Live clock ────────────────────────────────────────────────────────────────

class _LiveClock extends StatelessWidget {
  const _LiveClock();

  static const _days = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY',
    'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];
  static const _months = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(minutes: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        final label =
            '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}   $hh:$mm';
        return Text(
          label,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
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
  const _EmployeeCard({
    required this.name,
    required this.onTap,
    this.lastClockOut,
  });

  final String name;
  final VoidCallback onTap;

  /// Most recent clock-out time today, shown as "OUT: HH:mm" when non-null.
  final DateTime? lastClockOut;

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
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF212121),
                  ),
                ),
              ),
              if (lastClockOut != null) ...[
                Text(
                  'OUT: ${_fmt24(lastClockOut!)}',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF212121),
                      ),
                    ),
                    Text(
                      'IN: ${_fmt24(record.clockInTime)}',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
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

