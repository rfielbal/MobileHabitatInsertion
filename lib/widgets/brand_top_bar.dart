import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BrandTopBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandTopBar({super.key});

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
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBV1bjdeU_1MjpHJsXfGufZfwqMPmtDadnWLRkMUcfmUvhKUGoXs_t9wMfSVICI1mKiI781VcIJ_5_wkyBpfrjEBzZP1GorL6pMzjuxTidNmXaI-dzAKuadPD37MwPoRyaRyq05H_GA8mMykDYz7avF91-awbroBeEBVwDO35EFOPky3j4X3J0BEPvdYb0Wht2R1c7rBOtWo0XKaqun3Gr8-shgF-tBVE5Nrlt7OI6EMfCg3t46PgF4zauLTx0VdtKAYlDW45Pe-no',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.person, color: AppColors.primary);
              },
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'FlotteManager',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
