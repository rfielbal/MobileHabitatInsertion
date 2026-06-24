import 'package:flutter/material.dart';

import '../data/mobile_update_store.dart';
import '../data/notification_store.dart';
import '../models/mobile_update.dart';
import '../services/mobile_update_download_service.dart';
import '../theme/app_assets.dart';
import '../theme/app_brand.dart';
import '../theme/app_colors.dart';

class BrandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandTopBar({
    super.key,
    required this.onNotificationsPressed,
    this.showBackButton = false,
    this.onHelpPressed,
  });

  final VoidCallback onNotificationsPressed;
  final bool showBackButton;
  final VoidCallback? onHelpPressed;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: showBackButton,
      toolbarHeight: 68,
      backgroundColor: AppColors.surface,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHighest,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Image.asset(
                AppAssets.homeLogo,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.directions_car,
                    color: AppColors.primary,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              AppBrand.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (onHelpPressed != null) ...[
          IconButton(
            tooltip: 'Guide d’utilisation',
            onPressed: onHelpPressed,
            icon: const Icon(Icons.help_outline),
          ),
          const SizedBox(width: 2),
        ],
        AnimatedBuilder(
          animation: Listenable.merge([
            MobileUpdateStore.info,
            MobileUpdateStore.loading,
          ]),
          builder: (context, _) {
            return IconButton(
              tooltip: 'Mises à jour',
              onPressed: () => _showMobileUpdateSheet(context),
              icon: _UpdateIcon(count: MobileUpdateStore.pendingCount),
            );
          },
        ),
        const SizedBox(width: 2),
        AnimatedBuilder(
          animation: Listenable.merge([
            NotificationStore.items,
            NotificationStore.readIds,
          ]),
          builder: (context, _) {
            final notificationCount = NotificationStore.unreadCount;

            return IconButton(
              tooltip: 'Notifications',
              onPressed: onNotificationsPressed,
              icon: _NotificationIcon(count: notificationCount),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

void _showMobileUpdateSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surfaceLowest,
    builder: (context) => const _MobileUpdateSheet(),
  );
}

class _UpdateIcon extends StatelessWidget {
  const _UpdateIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const Icon(Icons.system_update_alt);
    }

    return Badge(
      label: Text(count > 9 ? '9+' : '$count'),
      backgroundColor: AppColors.error,
      textColor: AppColors.onPrimary,
      child: const Icon(Icons.system_update_alt),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const Icon(Icons.notifications_none);
    }

    return Badge(
      label: Text(count > 9 ? '9+' : '$count'),
      backgroundColor: AppColors.error,
      textColor: AppColors.onPrimary,
      child: const Icon(Icons.notifications_none),
    );
  }
}

class _MobileUpdateSheet extends StatefulWidget {
  const _MobileUpdateSheet();

  @override
  State<_MobileUpdateSheet> createState() => _MobileUpdateSheetState();
}

class _MobileUpdateSheetState extends State<_MobileUpdateSheet> {
  final _downloadService = MobileUpdateDownloadService();
  bool _installing = false;
  double? _downloadProgress;
  String? _installError;

  @override
  void initState() {
    super.initState();
    MobileUpdateStore.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        MobileUpdateStore.info,
        MobileUpdateStore.loading,
        MobileUpdateStore.error,
      ]),
      builder: (context, _) {
        final info = MobileUpdateStore.info.value;
        final loading = MobileUpdateStore.loading.value;
        final error = MobileUpdateStore.error.value;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MobileUpdateHeader(
                  info: info,
                  loading: loading,
                  installing: _installing,
                  error: error,
                ),
                const SizedBox(height: 18),
                if (loading && info == null)
                  const LinearProgressIndicator(minHeight: 3)
                else if (_installing)
                  _MobileUpdateProgress(progress: _downloadProgress)
                else
                  _MobileUpdateDetails(
                    info: info,
                    error: _installError ?? error,
                  ),
                const SizedBox(height: 18),
                _MobileUpdateActions(
                  info: info,
                  loading: loading,
                  installing: _installing,
                  onInstall: _installUpdate,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _installUpdate(MobileUpdateInfo info) async {
    if (_installing) {
      return;
    }

    setState(() {
      _installing = true;
      _downloadProgress = null;
      _installError = null;
    });

    try {
      await _downloadService.downloadVerifyAndOpen(
        info,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          setState(() {
            _downloadProgress = progress.ratio;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _installing = false;
        _downloadProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Téléchargement terminé. Validez l’installation Android.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _installing = false;
        _downloadProgress = null;
        _installError = error.toString();
      });
    }
  }
}

class _MobileUpdateHeader extends StatelessWidget {
  const _MobileUpdateHeader({
    required this.info,
    required this.loading,
    required this.installing,
    required this.error,
  });

  final MobileUpdateInfo? info;
  final bool loading;
  final bool installing;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(status.icon, color: status.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.title,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.subtitle,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _MobileUpdateStatus get _status {
    if (installing) {
      return const _MobileUpdateStatus(
        icon: Icons.download,
        color: AppColors.primary,
        title: 'Téléchargement sécurisé',
        subtitle:
            'L’APK est récupéré depuis l’API, puis vérifié avant installation.',
      );
    }

    if (loading && info == null) {
      return const _MobileUpdateStatus(
        icon: Icons.sync,
        color: AppColors.primary,
        title: 'Vérification en cours',
        subtitle: 'Recherche de la dernière version disponible.',
      );
    }

    if (error != null && info == null) {
      return const _MobileUpdateStatus(
        icon: Icons.cloud_off_outlined,
        color: AppColors.maintenance,
        title: 'Vérification indisponible',
        subtitle: 'Nous sommes en maintenance, veuillez nous excuser',
      );
    }

    if (info?.updateAvailable == true) {
      return const _MobileUpdateStatus(
        icon: Icons.system_update_alt,
        color: AppColors.error,
        title: 'Mise à jour disponible',
        subtitle: 'Une nouvelle version de Wheello peut être téléchargée.',
      );
    }

    if (info?.apkAvailable == true) {
      return const _MobileUpdateStatus(
        icon: Icons.check_circle_outline,
        color: AppColors.available,
        title: 'Application à jour',
        subtitle: 'La version installée correspond à la version publiée.',
      );
    }

    return const _MobileUpdateStatus(
      icon: Icons.info_outline,
      color: AppColors.outline,
      title: 'Aucune version publiée',
      subtitle: 'Le téléchargement sera disponible après dépôt de l’APK.',
    );
  }
}

class _MobileUpdateDetails extends StatelessWidget {
  const _MobileUpdateDetails({required this.info, required this.error});

  final MobileUpdateInfo? info;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final updateInfo = info;
    if (updateInfo == null) {
      return Text(
        error ?? 'Statut de mise à jour indisponible.',
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      );
    }

    final rows = <String>[
      if (updateInfo.currentVersionName != null)
        'Version installée : ${updateInfo.currentVersionName}+${updateInfo.currentVersionCode}'
      else
        'Code installé : ${updateInfo.currentVersionCode}',
      if (updateInfo.latestVersionName != null)
        'Version publiée : ${updateInfo.latestVersionName}${updateInfo.latestVersionCode != null ? '+${updateInfo.latestVersionCode}' : ''}',
      if (updateInfo.apkSizeLabel != null)
        'Taille : ${updateInfo.apkSizeLabel}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows) ...[
            Text(
              row,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
            ),
            const SizedBox(height: 6),
          ],
          if (updateInfo.releaseNotes != null) ...[
            const SizedBox(height: 4),
            Text(
              updateInfo.releaseNotes!,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (updateInfo.updateAvailable && updateInfo.apkSha256 == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Téléchargement direct indisponible : empreinte de sécurité manquante.',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileUpdateProgress extends StatelessWidget {
  const _MobileUpdateProgress({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final value = progress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: value),
          const SizedBox(height: 10),
          Text(
            value == null
                ? 'Préparation du téléchargement sécurisé'
                : 'Téléchargement ${(value * 100).clamp(0, 100).toStringAsFixed(0)} %',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileUpdateActions extends StatelessWidget {
  const _MobileUpdateActions({
    required this.info,
    required this.loading,
    required this.installing,
    required this.onInstall,
  });

  final MobileUpdateInfo? info;
  final bool loading;
  final bool installing;
  final ValueChanged<MobileUpdateInfo> onInstall;

  @override
  Widget build(BuildContext context) {
    final canInstall =
        info?.updateAvailable == true && info?.apkSha256 != null && !installing;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: loading || installing ? null : MobileUpdateStore.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Vérifier'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: canInstall ? () => onInstall(info!) : null,
            icon: installing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt),
            label: Text(installing ? 'Téléchargement' : 'Installer'),
          ),
        ),
      ],
    );
  }
}

class _MobileUpdateStatus {
  const _MobileUpdateStatus({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}
