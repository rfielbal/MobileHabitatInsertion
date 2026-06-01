/// Modèle pour un compte utilisateur
class Account {
  final String id;
  final String identifier;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'admin', 'manager', 'driver', 'user'
  final String avatar;
  final bool isActive;
  final String phone;
  final String company;
  final String pole;

  const Account({
    required this.id,
    required this.identifier,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.avatar,
    required this.isActive,
    required this.phone,
    required this.company,
    required this.pole,
  });
}

/// Données mockées pour les comptes de connexion
class MockAccountData {
  const MockAccountData._();

  static final accounts = <Account>[
    Account(
      id: 'user-001',
      identifier: 'sean.thompson',
      email: 'sean.thompson@habitat.fr',
      firstName: 'Sean',
      lastName: 'Thompson',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=1',
      isActive: true,
      phone: '+33 6 12 34 56 78',
      company: 'Habitat Insertion Paris',
      pole: 'Insertion',
    ),
    Account(
      id: 'user-002',
      identifier: 'raphael.coursier',
      email: 'raphaël.coursier@habitat.fr',
      firstName: 'Raphaël',
      lastName: 'Coursier',
      role: 'manager',
      avatar: 'https://i.pravatar.cc/150?img=2',
      isActive: true,
      phone: '+33 6 23 45 67 89',
      company: 'Habitat Insertion Lille',
      pole: 'Logistique',
    ),
    Account(
      id: 'user-003',
      identifier: 'thomas.dominois',
      email: 'thomas.dominois@habitat.fr',
      firstName: 'Thomas',
      lastName: 'Dominois',
      role: 'admin',
      avatar: 'https://i.pravatar.cc/150?img=3',
      isActive: true,
      phone: '+33 6 34 56 78 90',
      company: 'Habitat Insertion',
      pole: 'Administration',
    ),
    Account(
      id: 'user-004',
      identifier: 'sophie.durand',
      email: 'sophie.durand@habitat.fr',
      firstName: 'Sophie',
      lastName: 'Durand',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=4',
      isActive: true,
      phone: '+33 6 45 67 89 01',
      company: 'Habitat Insertion Lyon',
      pole: 'Accompagnement',
    ),
    Account(
      id: 'user-005',
      identifier: 'saphia.touier',
      email: 'saphia.touier@habitat.fr',
      firstName: 'Saphia',
      lastName: 'Touier',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=5',
      isActive: true,
      phone: '+33 6 56 78 90 12',
      company: 'Habitat Insertion Marseille',
      pole: 'Insertion',
    ),
    Account(
      id: 'user-006',
      identifier: 'vincent.rouget',
      email: 'vincent.rouget@habitat.fr',
      firstName: 'Vincent',
      lastName: 'Rouget',
      role: 'user',
      avatar: 'https://i.pravatar.cc/150?img=6',
      isActive: false,
      phone: '+33 6 67 89 01 23',
      company: 'Habitat Insertion Toulouse',
      pole: 'Technique',
    ),
    Account(
      id: 'user-007',
      identifier: 'test',
      email: 'test@habitat.fr',
      firstName: 'Test',
      lastName: 'User',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=7',
      isActive: true,
      phone: '+33 6 78 90 12 34',
      company: 'Habitat Insertion Nice',
      pole: 'Insertion',
    ),
  ];

  /// Méthode pour trouver un compte actif par e-mail ou identifiant interne.
  static Account? authenticate(String identifier) {
    final normalizedIdentifier = identifier.trim().toLowerCase();
    try {
      return accounts.firstWhere(
        (account) =>
            (account.email.toLowerCase() == normalizedIdentifier ||
                account.identifier.toLowerCase() == normalizedIdentifier) &&
            account.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  /// Méthode pour récupérer un compte par ID
  static Account? getAccountById(String id) {
    try {
      return accounts.firstWhere((account) => account.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Méthode pour lister tous les comptes actifs
  static List<Account> getActiveAccounts() {
    return accounts.where((account) => account.isActive).toList();
  }

  /// Méthode pour lister les comptes par rôle
  static List<Account> getAccountsByRole(String role) {
    return accounts.where((account) => account.role == role).toList();
  }
}
