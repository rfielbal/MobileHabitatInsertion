import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UploadTile extends StatelessWidget {
  const UploadTile({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.large = false,
    this.processing = false,
    this.progress,
    this.statusText,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool large;
  final bool processing;
  final double? progress;
  final String? statusText;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: processing ? null : onTap,
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
              processing
                  ? Icons.hourglass_top
                  : selected
                  ? Icons.check
                  : Icons.videocam,
              color: selected ? Colors.white : AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            processing
                ? statusText ?? 'Traitement en cours'
                : selected
                ? 'Vidéo ajoutée'
                : label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (processing || progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress?.clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: AppColors.outlineVariant.withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress == null
                  ? 'Préparation de la vidéo'
                  : '${(progress!.clamp(0, 1).toDouble() * 100).round()}%',
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
