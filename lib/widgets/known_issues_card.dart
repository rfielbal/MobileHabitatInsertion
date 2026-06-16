import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

class KnownIssuesCard extends StatelessWidget {
  const KnownIssuesCard({super.key, required this.issues});

  final List<VehicleIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const AppCard(
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.available),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune anomalie connue sur ce véhicule',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anomalies déjà signalées',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final issue in issues) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  issue.requiresAttention
                      ? Icons.warning_amber_outlined
                      : Icons.info_outline,
                  color: issue.requiresAttention
                      ? AppColors.maintenance
                      : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        issue.description,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      if ((issue.reportedAtLabel ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          issue.reportedAtLabel!.trim(),
                          style: const TextStyle(
                            color: AppColors.outline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (issue != issues.last) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}
