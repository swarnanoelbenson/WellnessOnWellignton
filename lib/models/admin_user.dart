import 'package:uuid/uuid.dart';

/// One of exactly two admin accounts in the system.
///
/// Admin credentials are set up during initial app configuration.
/// Passwords are stored as bcrypt hashes — never plain text.
/// Admin accounts live in both SQLite (for offline access) and Firestore.
class AdminUser {
  final String id;
  final String username;
  final String passwordHash; // bcrypt hash

  const AdminUser({
    required this.id,
    required this.username,
    required this.passwordHash,
  });

  factory AdminUser.create({
    required String username,
    required String passwordHash,
  }) {
    return AdminUser(
      id: const Uuid().v4(),
      username: username,
      passwordHash: passwordHash,
    );
  }

  AdminUser copyWith({String? passwordHash}) {
    return AdminUser(
      id: id,
      username: username,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  // ── SQLite serialisation ────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
    };
  }

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
    );
  }

  // ── Firestore serialisation ─────────────────────────────────────────────

  Map<String, dynamic> toFirestoreMap() => toMap();

  factory AdminUser.fromFirestoreMap(Map<String, dynamic> map) =>
      AdminUser.fromMap(map);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AdminUser && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AdminUser(id: $id, username: $username)';
}
