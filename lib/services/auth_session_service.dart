import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/mock_account_data.dart';

class AccountSession {
  const AccountSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.pole,
  });

  final String token;
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String pole;

  String get fullName => '$firstName $lastName';
  bool get isMockSession => token.contains('.mock_token_');

  String get roleLabel {
    return switch (role) {
      'admin' => 'Administrateur',
      'manager' => 'Responsable',
      'driver' || 'user' => 'Utilisateur mobile',
      _ => 'Utilisateur mobile',
    };
  }
}

class AuthSessionService {
  const AuthSessionService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const tokenKey = 'jwt_token';
  static const userIdKey = 'user_id';
  static const userEmailKey = 'user_email';
  static const firstNameKey = 'user_first_name';
  static const lastNameKey = 'user_last_name';
  static const roleKey = 'user_role';
  static const poleKey = 'user_pole';

  final FlutterSecureStorage _storage;

  Future<void> saveMockAccountSession(Account account) async {
    final token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock_token_${account.id}';

    await saveSession(
      AccountSession(
        token: token,
        userId: account.id,
        email: account.email,
        firstName: account.firstName,
        lastName: account.lastName,
        role: account.role,
        pole: account.pole,
      ),
    );
  }

  Future<void> saveSession(AccountSession session) async {
    await _storage.write(key: tokenKey, value: session.token);
    await _storage.write(key: userIdKey, value: session.userId);
    await _storage.write(key: userEmailKey, value: session.email);
    await _storage.write(key: firstNameKey, value: session.firstName);
    await _storage.write(key: lastNameKey, value: session.lastName);
    await _storage.write(key: roleKey, value: session.role);
    await _storage.write(key: poleKey, value: session.pole);
  }

  Future<String?> readToken() async {
    try {
      return _storage.read(key: tokenKey);
    } on MissingPluginException {
      return null;
    }
  }

  Future<AccountSession?> readSession() async {
    try {
      final token = await _storage.read(key: tokenKey);
      final userId = await _storage.read(key: userIdKey);
      final email = await _storage.read(key: userEmailKey);

      if (token == null || userId == null || email == null) {
        return null;
      }

      final account = MockAccountData.getAccountById(userId);

      return AccountSession(
        token: token,
        userId: userId,
        email: email,
        firstName:
            await _storage.read(key: firstNameKey) ??
            account?.firstName ??
            'Utilisateur',
        lastName:
            await _storage.read(key: lastNameKey) ?? account?.lastName ?? '',
        role: await _storage.read(key: roleKey) ?? account?.role ?? 'user',
        pole:
            await _storage.read(key: poleKey) ?? account?.pole ?? 'Non défini',
      );
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: userIdKey);
    await _storage.delete(key: userEmailKey);
    await _storage.delete(key: firstNameKey);
    await _storage.delete(key: lastNameKey);
    await _storage.delete(key: roleKey);
    await _storage.delete(key: poleKey);
  }
}
