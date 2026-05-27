/// Modèle pour un compte utilisateur
class Account {
  final String id;
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String role; // 'admin', 'manager', 'driver', 'user'
  final String avatar;
  final bool isActive;
  final String phone;
  final String company;

  const Account({
    required this.id,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.avatar,
    required this.isActive,
    required this.phone,
    required this.company,
  });
}

/// Données mockées pour les comptes de connexion
class MockAccountData {
  const MockAccountData._();

  static final accounts = <Account>[
    Account(
      id: 'user-001',
      email: 'sean.thompson@habitat.fr',
      password: '123456',
      firstName: 'Sean',
      lastName: 'Thompson',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=1',
      isActive: true,
      phone: '+33 6 12 34 56 78',
      company: 'Habitat Insertion Paris',
    ),
    Account(
      id: 'user-002',
      email: 'raphaël.coursier@habitat.fr',
      password: '123456',
      firstName: 'Raphaël',
      lastName: 'Coursier',
      role: 'manager',
      avatar: 'https://i.pravatar.cc/150?img=2',
      isActive: true,
      phone: '+33 6 23 45 67 89',
      company: 'Habitat Insertion Lille',
    ),
    Account(
      id: 'user-003',
      email: 'thomas.dominois@habitat.fr',
      password: '123456',
      firstName: 'Thomas',
      lastName: 'Dominois',
      role: 'admin',
      avatar: 'https://i.pravatar.cc/150?img=3',
      isActive: true,
      phone: '+33 6 34 56 78 90',
      company: 'Habitat Insertion',
    ),
    Account(
      id: 'user-004',
      email: 'sophie.durand@habitat.fr',
      password: '123456',
      firstName: 'Sophie',
      lastName: 'Durand',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=4',
      isActive: true,
      phone: '+33 6 45 67 89 01',
      company: 'Habitat Insertion Lyon',
    ),
    Account(
      id: 'user-005',
      email: 'saphia.touier@habitat.fr',
      password: '123456',
      firstName: 'Saphia',
      lastName: 'Touier',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=5',
      isActive: true,
      phone: '+33 6 56 78 90 12',
      company: 'Habitat Insertion Marseille',
    ),
    Account(
      id: 'user-006',
      email: 'vincent.rouget@habitat.fr',
      password: '123456',
      firstName: 'Vincent',
      lastName: 'Rouget',
      role: 'user',
      avatar: 'https://i.pravatar.cc/150?img=6',
      isActive: false,
      phone: '+33 6 67 89 01 23',
      company: 'Habitat Insertion Toulouse',
    ),
    Account(
      id: 'user-007',
      email: 'test@habitat.fr',
      password: '123456',
      firstName: 'Test',
      lastName: 'User',
      role: 'driver',
      avatar: 'https://i.pravatar.cc/150?img=7',
      isActive: true,
      phone: '+33 6 78 90 12 34',
      company: 'Habitat Insertion Nice',
    ),
  ];

  /// Méthode pour trouver un compte par email et vérifier le mot de passe
  static Account? authenticate(String email, String password) {
    try {
      return accounts.firstWhere(
        (account) =>
            account.email == email &&
            account.password == password &&
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
