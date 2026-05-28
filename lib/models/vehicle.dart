import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum VehicleStatus { inUse, partiallyAvailable, available, maintenance }

extension VehicleStatusX on VehicleStatus {
  String get label {
    return switch (this) {
      VehicleStatus.inUse => 'En usage',
      VehicleStatus.partiallyAvailable => 'Disponible partiellement',
      VehicleStatus.available => 'Libre',
      VehicleStatus.maintenance => 'En maintenance',
    };
  }

  Color get color {
    return switch (this) {
      VehicleStatus.inUse => AppColors.error,
      VehicleStatus.partiallyAvailable => AppColors.primary,
      VehicleStatus.available => AppColors.available,
      VehicleStatus.maintenance => AppColors.maintenance,
    };
  }

  IconData get icon {
    return switch (this) {
      VehicleStatus.inUse => Icons.directions_car,
      VehicleStatus.partiallyAvailable => Icons.local_shipping,
      VehicleStatus.available => Icons.electric_car,
      VehicleStatus.maintenance => Icons.build,
    };
  }

  int get sortRank {
    return switch (this) {
      VehicleStatus.inUse => 1,
      VehicleStatus.partiallyAvailable => 2,
      VehicleStatus.available => 3,
      VehicleStatus.maintenance => 4,
    };
  }
}

enum AvailabilityStatus { free, reserved, maintenance, partial }

extension AvailabilityStatusX on AvailabilityStatus {
  String get label {
    return switch (this) {
      AvailabilityStatus.free => 'Libre',
      AvailabilityStatus.reserved => 'Réservé',
      AvailabilityStatus.maintenance => 'Maintenance',
      AvailabilityStatus.partial => 'Disponible partiellement',
    };
  }

  Color get color {
    return switch (this) {
      AvailabilityStatus.free => AppColors.outlineVariant,
      AvailabilityStatus.reserved => AppColors.error,
      AvailabilityStatus.maintenance => AppColors.maintenance,
      AvailabilityStatus.partial => AppColors.primary,
    };
  }

  bool get canStartReservation {
    return switch (this) {
      AvailabilityStatus.free || AvailabilityStatus.partial => true,
      AvailabilityStatus.reserved || AvailabilityStatus.maintenance => false,
    };
  }
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.category,
    required this.status,
    required this.subtitle,
    required this.imageUrl,
    required this.location,
    required this.seats,
    required this.transmission,
    required this.energyInfo,
    required this.nextAvailableAt,
    required this.availabilityByDay,
  });

  final String id;
  final String name;
  final String plateNumber;
  final String category;
  final VehicleStatus status;
  final String subtitle;
  final String imageUrl;
  final String location;
  final String seats;
  final String transmission;
  final String energyInfo;
  final DateTime nextAvailableAt;
  final Map<int, AvailabilityStatus> availabilityByDay;
}
