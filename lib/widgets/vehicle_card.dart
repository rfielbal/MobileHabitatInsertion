import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';
import 'remote_vehicle_image.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = vehicle.status == VehicleStatus.maintenance;

    return AppCard(
      onTap: onTap,
      opacity: disabled ? 0.78 : 1,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VehicleThumbnail(vehicle: vehicle),
            const SizedBox(width: 12),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                vehicle.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                            Icon(
                              vehicle.status.icon,
                              size: 22,
                              color: AppColors.outlineVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MetadataPill(label: vehicle.internalNumber),
                            _MetadataPill(label: vehicle.plateNumber),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_city_outlined,
                              size: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${vehicle.site} • ${vehicle.parkingDescription}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _metadataIcon(vehicle.status),
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            vehicle.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _metadataIcon(VehicleStatus status) {
    return switch (status) {
      VehicleStatus.inUse => Icons.person_outline,
      VehicleStatus.partiallyAvailable => Icons.schedule,
      VehicleStatus.available => Icons.battery_charging_full,
      VehicleStatus.maintenance => Icons.garage_outlined,
    };
  }
}

class _VehicleThumbnail extends StatelessWidget {
  const _VehicleThumbnail({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RemoteVehicleImage(
          imageUrl: vehicle.imageUrl,
          height: 110,
          width: 96,
          borderRadius: 10,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: vehicle.status.color.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(10),
              ),
            ),
            child: Text(
              vehicle.status.label.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                height: 1.15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 11,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
