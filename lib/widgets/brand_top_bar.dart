import 'package:flutter/material.dart';

import '../data/notification_store.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';

class BrandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandTopBar({super.key, required this.onNotificationsPressed});

  final VoidCallback onNotificationsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      backgroundColor: AppColors.surface,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHighest,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(3),
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
              'Wheello',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<Set<int>>(
          valueListenable: NotificationStore.readIds,
          builder: (context, readIds, _) {
            final notificationCount = NotificationStore.items
                .where((item) => !readIds.contains(item.id))
                .length;

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
      textColor: Colors.white,
      child: const Icon(Icons.notifications_none),
    );
  }
}
