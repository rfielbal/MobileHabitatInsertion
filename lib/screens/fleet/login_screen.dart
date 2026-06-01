import 'package:flutter/material.dart';

import '../../data/mock_account_data.dart';
import '../../navigation/app_routes.dart';
import '../../services/auth_session_service.dart';
import '../../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _authSessionService = const AuthSessionService();

  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final identifier = _identifierController.text.trim();

      final account = MockAccountData.authenticate(identifier);

      if (account == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Identifiant inconnu ou compte désactivé'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      await _authSessionService.saveMockAccountSession(account);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion : ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'FlotteManager',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connexion interne à la flotte',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _identifierController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'E-mail ou identifiant',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _login(),
                      validator: (value) {
                        final identifier = value?.trim() ?? '';
                        if (identifier.isEmpty) {
                          return 'E-mail ou identifiant obligatoire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : FilledButton.icon(
                            onPressed: _login,
                            icon: const Icon(Icons.login),
                            label: const Text('Se connecter'),
                          ),

                    const SizedBox(height: 48),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Connexion sécurisée SSL',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
