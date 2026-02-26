import 'package:uuid/uuid.dart';

/// A manually configured public holiday date.
///
/// When a date is marked as a public holiday, the workday schedule shifts:
///   Open: 9:00 am  |  Close: 1:00 pm  |  CSV email: 2:00 pm
///
/// Admin sets these via the Admin Panel. Stored in both SQLite and Firestore.
class PublicHoliday {
  final String id;
  final DateTime date; // only the date portion is meaningful (time is midnight)
  final String name;   // e.g. "ANZAC Day", "Christmas Day"

  const PublicHoliday({
    required this.id,
    required this.date,
    required this.name,
  });

  factory PublicHoliday.create({
    required DateTime date,
    required String name,
  }) {
    return PublicHoliday(
      id: const Uuid().v4(),
      // Normalise to midnight so date comparisons are reliable.
      date: DateTime(date.year, date.month, date.day),
      name: name,
    );
  }

  /// YYYY-MM-DD string — used as the storage key in both SQLite and Firestore.
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // ── SQLite serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': dateKey,
      'name': name,
    };
  }

  factory PublicHoliday.fromMap(Map<String, dynamic> map) {
    return PublicHoliday(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      name: map['name'] as String,
    );
  }

  // ── Firestore serialisation ─────────────────────────────────────────────

  Map<String, dynamic> toFirestoreMap() => toMap();

  factory PublicHoliday.fromFirestoreMap(Map<String, dynamic> map) =>
      PublicHoliday.fromMap(map);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PublicHoliday && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PublicHoliday(id: $id, date: $dateKey, name: $name)';
}
