import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RemoteVehicleImage extends StatelessWidget {
  const RemoteVehicleImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: _VehicleImagePlaceholder(height: height, width: width),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _VehicleImagePlaceholder(height: height, width: width);
        },
      ),
    );
  }
}

class _VehicleImagePlaceholder extends StatelessWidget {
  const _VehicleImagePlaceholder({this.height, this.width});

  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: AppColors.surfaceHigh,
      child: const Icon(
        Icons.directions_car,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}
