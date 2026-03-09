import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';

// ── Brand colours (mirrors main_screen.dart) ──────────────────────────────────

const Color _crimson = Color(0xFF8B0000);
const Color _charcoal = Color(0xFF2C2C2C);
const Color _green = Color(0xFF2E7D32);

// ── Time formatting helpers ───────────────────────────────────────────────────

/// 24-hour HH:mm format used on attendance board cards.
String _fmt24(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

// ── Desktop top navigation bar ────────────────────────────────────────────────

/// Persistent top bar for the Windows layout.
///
/// Shows the app logo and title on the left, a live clock in the centre,
/// and an always-visible [Admin] button on the right that replaces the
/// hidden 3-second long-press used on tablet.
class DesktopTopBar extends StatelessWidget {
  const DesktopTopBar({super.key, required this.onAdminTap});

  final VoidCallback onAdminTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: _crimson,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Left: clinic logo
          Image.asset(
            'assets/main_page_logo.jpg',
            height: 44,
            fit: BoxFit.contain,
          ),

          // Centre: live date/time
          const Spacer(),
          const _DesktopLiveClock(),
          const Spacer(),

          // Right: Admin button
          OutlinedButton.icon(
            onPressed: onAdminTap,
            icon: const Icon(Icons.lock_outline, size: 16, color: Colors.white),
            label: Text(
              'Admin',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop live clock (centred, full date) ───────────────────────────────────

class _DesktopLiveClock extends StatelessWidget {
  const _DesktopLiveClock();

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
      builder: (_, snap) {
        final now = snap.data ?? DateTime.now();
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

// ── Desktop board column ──────────────────────────────────────────────────────

/// A searchable, scrollable column for the Windows desktop board.
///
/// Each entry in [namedCards] is a `(name, card)` pair; the name string is
/// used for case-insensitive filtering when the user types in the search
/// field.  The count badge in the header always reflects the *total* number
/// of items, not the filtered count.
class DesktopBoardColumn extends StatefulWidget {
  const DesktopBoardColumn({
    super.key,
    required this.title,
    required this.accentColor,
    required this.emptyMessage,
    required this.namedCards,
  });

  final String title;
  final Color accentColor;
  final String emptyMessage;

  /// Each record is `(employeeName, card widget)`.
  /// The name is used for search filtering.
  final List<(String, Widget)> namedCards;

  @override
  State<DesktopBoardColumn> createState() => _DesktopBoardColumnState();
}

class _DesktopBoardColumnState extends State<DesktopBoardColumn> {
  final _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final text = _searchCtrl.text.toLowerCase();
    if (text != _filter) setState(() => _filter = text);
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? widget.namedCards
        : widget.namedCards
            .where((p) => p.$1.toLowerCase().contains(_filter))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Column header with count summary ────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: widget.accentColor.withValues(alpha: 0.08),
          child: Row(
            children: [
              Text(
                widget.title.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: widget.accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.namedCards.length}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Search / filter bar ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name…',
              hintStyle: GoogleFonts.nunito(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon:
                  Icon(Icons.search, size: 18, color: Colors.grey.shade400),
              suffixIcon: _filter.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.clear,
                          size: 16, color: Colors.grey.shade400),
                      onPressed: _searchCtrl.clear,
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: widget.accentColor.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),

        // ── Card list ────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filter.isEmpty
                        ? widget.emptyMessage
                        : 'No results for "$_filter"',
                    style: GoogleFonts.nunito(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => filtered[i].$2,
                ),
        ),
      ],
    );
  }
}

// ── Desktop employee cards ────────────────────────────────────────────────────

/// Not-clocked-in card.
///
/// Horizontal layout: avatar | name | ··· | [Clock In →]
class DesktopEmployeeCard extends StatelessWidget {
  const DesktopEmployeeCard({
    super.key,
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
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      shadowColor: Colors.black12,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: _crimson.withValues(alpha: 0.06),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _charcoal,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name
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
                const SizedBox(width: 12),
              ],
              // Clock-in action
              _ActionChip(
                label: 'Clock In',
                icon: Icons.arrow_forward,
                color: _crimson,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clocked-in card.
///
/// Horizontal layout: avatar | name + "In: HH:MM" | ··· | [Clock Out →]
class DesktopClockedInCard extends StatelessWidget {
  const DesktopClockedInCard({
    super.key,
    required this.record,
    required this.onTap,
  });

  final AttendanceRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.green.withValues(alpha: 0.06),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green.shade50,
                child: Icon(Icons.check, size: 18, color: _green),
              ),
              const SizedBox(width: 16),
              // Name + clock-in time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.employeeName,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'IN: ${_fmt24(record.clockInTime)}',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                ),
              ),
              // Clock-out action
              _ActionChip(
                label: 'Clock Out',
                icon: Icons.logout,
                color: _green,
                backgroundColor: Colors.green.shade50,
                borderColor: Colors.green.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared action chip ────────────────────────────────────────────────────────

/// Small pill-shaped action label with an icon, used in desktop cards.
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }
}
