import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UploadTile extends StatelessWidget {
  const UploadTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.large = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(large ? 128 : 88),
        backgroundColor: selected
            ? AppColors.primaryFixed
            : AppColors.surfaceLow,
        foregroundColor: selected
            ? AppColors.primary
            : AppColors.onSurfaceVariant,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outlineVariant,
          style: BorderStyle.solid,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? Icons.check : Icons.videocam,
              color: selected ? Colors.white : AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            selected ? 'Vidéo ajoutée' : label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
