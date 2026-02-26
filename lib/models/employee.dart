import 'package:uuid/uuid.dart';

/// Represents a clinic employee in the Wellness on Wellington system.
///
/// The [isDefaultPassword] flag is critical — it is true when the employee
/// has never changed their password from the system default ("123456").
/// Every login attempt checks this flag to force the first-time setup flow.
class Employee {
  final String id;
  final String name;
  final String passwordHash; // bcrypt hash — never plain text
  final bool isDefaultPassword;
  final DateTime createdAt;

  const Employee({
    required this.id,
    required this.name,
    required this.passwordHash,
    required this.isDefaultPassword,
    required this.createdAt,
  });

  /// Creates a brand-new employee with a generated UUID and the default
  /// password flag set to true. The caller must supply a bcrypt hash of
  /// the default password "123456".
  factory Employee.create({
    required String name,
    required String defaultPasswordHash,
  }) {
    return Employee(
      id: const Uuid().v4(),
      name: name,
      passwordHash: defaultPasswordHash,
      isDefaultPassword: true,
      createdAt: DateTime.now(),
    );
  }

  Employee copyWith({
    String? name,
    String? passwordHash,
    bool? isDefaultPassword,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      passwordHash: passwordHash ?? this.passwordHash,
      isDefaultPassword: isDefaultPassword ?? this.isDefaultPassword,
      createdAt: createdAt,
    );
  }

  // ── SQLite serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'password_hash': passwordHash,
      'is_default_password': isDefaultPassword ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      name: map['name'] as String,
      passwordHash: map['password_hash'] as String,
      isDefaultPassword: (map['is_default_password'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ── Firestore serialisation ─────────────────────────────────────────────

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'name': name,
      'password_hash': passwordHash,
      'is_default_password': isDefaultPassword,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Employee.fromFirestoreMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      name: map['name'] as String,
      passwordHash: map['password_hash'] as String,
      isDefaultPassword: map['is_default_password'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Employee && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Employee(id: $id, name: $name, isDefault: $isDefaultPassword)';
}
