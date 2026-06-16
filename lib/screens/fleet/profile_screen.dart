import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/auth_session_service.dart';
import '../../services/fleet_api_service.dart';
import '../../services/native_notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_top_bar.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authSessionService = const AuthSessionService();
  final _fleetApiService = FleetApiService();

  AccountSession? _session;
  List<String> _sites = const [];
  bool _sitesLoading = true;
  bool _notificationsEnabled = false;
  bool _notificationsLoading = true;
  bool _permissionPluginAvailable = true;
  PermissionStatus? _notificationPermissionStatus;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadSites();
    _loadNotificationStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandTopBar(
        onNotificationsPressed: () => _openNotifications(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Profil',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryFixed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _session?.fullName ?? 'Utilisateur mobile',
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _ProfileRow(
                    icon: Icons.mail_outline,
                    label: 'Adresse e-mail',
                    value: _session?.email ?? 'Non connecté',
                  ),
                  const Divider(height: 24),
                  _ProfileRow(
                    icon: Icons.groups_outlined,
                    label: 'Pôle',
                    value: _session?.pole ?? 'Non défini',
                  ),
                  const Divider(height: 24),
                  _ProfileRow(
                    icon: Icons.location_city_outlined,
                    label: 'Site(s)',
                    value: _sitesLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.notifications_none,
                      color: AppColors.onSurfaceVariant,
                    ),
                    title: const Text('Notifications'),
                    subtitle: Text(_notificationSubtitle),
                    trailing: _notificationsLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: _notificationsEnabled,
                            onChanged: _permissionPluginAvailable
                                ? _setNotificationsEnabled
                                : null,
                          ),
                    onTap: _notificationsLoading || !_permissionPluginAvailable
                        ? null
                        : () =>
                              _setNotificationsEnabled(!_notificationsEnabled),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text('Se déconnecter'),
                    onTap: widget.onLogout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _notificationSubtitle {
    if (!_permissionPluginAvailable) {
      return 'Autorisation indisponible : relance complète nécessaire';
    }
    if (_notificationsLoading) {
      return 'Vérification de l’autorisation';
    }
    if (_notificationsEnabled) {
      return 'Alertes de réservation et de retour activées';
    }
    if (_notificationPermissionStatus?.isPermanentlyDenied ?? false) {
      return 'Autorisation bloquée dans les réglages du téléphone';
    }
    return 'Alertes de réservation et de retour désactivées';
  }

  String get _sitesLabel {
    if (_sitesLoading) {
      return 'Chargement des sites';
    }
    if (_sites.isEmpty) {
      return 'Aucun site rattaché';
    }
    return _sites.join('\n');
  }

  Future<void> _loadSession() async {
    final session = await _authSessionService.readSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
    });
  }

  Future<void> _loadSites() async {
    try {
      final sites = await _fleetApiService.fetchUserSiteLabels();
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = sites;
        _sitesLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sites = const [];
        _sitesLoading = false;
      });
    }
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final status = await Permission.notification.status;
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationPermissionStatus = status;
        _notificationsEnabled = status.isGranted;
        _notificationsLoading = false;
        _permissionPluginAvailable = true;
      });
    } on MissingPluginException {
      _handleMissingPermissionPlugin();
    }
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    if (!enabled) {
      setState(() {
        _notificationsEnabled = false;
      });
      return;
    }

    setState(() {
      _notificationsLoading = true;
    });

    PermissionStatus status;
    try {
      status = await Permission.notification.request();
      if (status.isGranted) {
        final nativeGranted = await NativeNotificationService.instance
            .requestPermissions();
        if (!nativeGranted) {
          status = PermissionStatus.denied;
        }
      }
    } on MissingPluginException {
      _handleMissingPermissionPlugin();
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _notificationPermissionStatus = status;
      _notificationsEnabled = status.isGranted;
      _notificationsLoading = false;
    });

    if (status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifications activées')));
      return;
    }

    final snackBar = SnackBar(
      content: const Text('Autorisation de notification refusée'),
      action: status.isPermanentlyDenied
          ? SnackBarAction(label: 'Réglages', onPressed: openAppSettings)
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _handleMissingPermissionPlugin() {
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionPluginAvailable = false;
      _notificationsEnabled = false;
      _notificationsLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Relancez complètement l’application pour activer ce plugin natif',
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.outline,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
