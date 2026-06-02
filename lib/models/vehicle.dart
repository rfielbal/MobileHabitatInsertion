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
      VehicleStatus.partiallyAvailable => AppColors.partialAvailability,
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

  bool get canBeUsedAsFilter {
    return switch (this) {
      VehicleStatus.inUse || VehicleStatus.available => true,
      VehicleStatus.partiallyAvailable || VehicleStatus.maintenance => false,
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
      AvailabilityStatus.free => AppColors.available,
      AvailabilityStatus.reserved => AppColors.error,
      AvailabilityStatus.maintenance => AppColors.maintenance,
      AvailabilityStatus.partial => AppColors.partialAvailability,
    };
  }

  bool get canStartReservation {
    return switch (this) {
      AvailabilityStatus.free || AvailabilityStatus.partial => true,
      AvailabilityStatus.reserved || AvailabilityStatus.maintenance => false,
    };
  }
}

enum VehicleEnergyType { electric, hybrid, thermal }

extension VehicleEnergyTypeX on VehicleEnergyType {
  String get label {
    return switch (this) {
      VehicleEnergyType.electric => 'Électrique',
      VehicleEnergyType.hybrid => 'Hybride',
      VehicleEnergyType.thermal => 'Thermique',
    };
  }

  bool get usesFuelLevel {
    return switch (this) {
      VehicleEnergyType.electric => false,
      VehicleEnergyType.hybrid || VehicleEnergyType.thermal => true,
    };
  }
}

class VehicleIssue {
  const VehicleIssue({
    required this.title,
    required this.description,
    required this.reportedAtLabel,
    this.requiresAttention = false,
  });

  final String title;
  final String description;
  final String reportedAtLabel;
  final bool requiresAttention;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.internalNumber,
    required this.name,
    required this.brand,
    required this.model,
    required this.plateNumber,
    required this.category,
    required this.status,
    required this.subtitle,
    required this.imageUrl,
    required this.location,
    required this.site,
    required this.parkingDescription,
    required this.seats,
    required this.transmission,
    required this.energyType,
    required this.energyInfo,
    required this.currentMileage,
    required this.fuelLevelLabel,
    required this.priorityRank,
    required this.nextAvailableAt,
    required this.availabilityByDay,
    this.knownIssues = const [],
  });

  final String id;
  final String internalNumber;
  final String name;
  final String brand;
  final String model;
  final String plateNumber;
  final String category;
  final VehicleStatus status;
  final String subtitle;
  final String imageUrl;
  final String location;
  final String site;
  final String parkingDescription;
  final String seats;
  final String transmission;
  final VehicleEnergyType energyType;
  final String energyInfo;
  final int currentMileage;
  final String fuelLevelLabel;
  final int priorityRank;
  final DateTime nextAvailableAt;
  final Map<int, AvailabilityStatus> availabilityByDay;
  final List<VehicleIssue> knownIssues;
}
