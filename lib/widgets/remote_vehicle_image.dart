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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: width,
            color: AppColors.surfaceHigh,
            child: const Icon(
              Icons.directions_car,
              color: AppColors.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
