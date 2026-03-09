import 'package:shared_preferences/shared_preferences.dart';

/// Tracks when the attendance board was last reset after a successful email send.
///
/// The reset timestamp is persisted in [SharedPreferences] so it survives app
/// restarts. Any attendance session that started before the reset cutoff is
/// treated as archived and excluded from the active board display.
class BoardResetService {
  static const _key = 'board_last_reset_ms';

  /// Writes the current moment as the board reset timestamp.
  static Future<void> markReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns the [DateTime] of the last board reset, or null if never reset.
  static Future<DateTime?> lastResetTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }
}
