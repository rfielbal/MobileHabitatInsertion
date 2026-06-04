import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum VehicleStatus { inUse, available, maintenance }

extension VehicleStatusX on VehicleStatus {
  String get label {
    return switch (this) {
      VehicleStatus.inUse => 'En usage',
      VehicleStatus.available => 'Libre',
      VehicleStatus.maintenance => 'En maintenance',
    };
  }

  Color get color {
    return switch (this) {
      VehicleStatus.inUse => AppColors.error,
      VehicleStatus.available => AppColors.available,
      VehicleStatus.maintenance => AppColors.maintenance,
    };
  }

  IconData get icon {
    return switch (this) {
      VehicleStatus.inUse => Icons.directions_car,
      VehicleStatus.available => Icons.electric_car,
      VehicleStatus.maintenance => Icons.build,
    };
  }

  int get sortRank {
    return switch (this) {
      VehicleStatus.inUse => 1,
      VehicleStatus.available => 3,
      VehicleStatus.maintenance => 4,
    };
  }

  bool get canBeUsedAsFilter {
    return switch (this) {
      VehicleStatus.inUse || VehicleStatus.available => true,
      VehicleStatus.maintenance => false,
    };
  }
}

enum AvailabilityStatus { free, partial, reserved, maintenance }

extension AvailabilityStatusX on AvailabilityStatus {
  String get label {
    return switch (this) {
      AvailabilityStatus.free => 'Libre',
      AvailabilityStatus.partial => 'Partiel',
      AvailabilityStatus.reserved => 'Réservé',
      AvailabilityStatus.maintenance => 'Maintenance',
    };
  }

  Color get color {
    return switch (this) {
      AvailabilityStatus.free => AppColors.available,
      AvailabilityStatus.partial => AppColors.partial,
      AvailabilityStatus.reserved => AppColors.error,
      AvailabilityStatus.maintenance => AppColors.maintenance,
    };
  }

  bool get canStartReservation {
    return switch (this) {
      AvailabilityStatus.free || AvailabilityStatus.partial => true,
      AvailabilityStatus.reserved || AvailabilityStatus.maintenance => false,
    };
  }
}

class VehicleAvailabilityMonth {
  const VehicleAvailabilityMonth({
    required this.availabilityByDay,
    this.suggestionsByDay = const {},
  });

  final Map<int, AvailabilityStatus> availabilityByDay;
  final Map<int, VehicleAvailabilitySuggestion> suggestionsByDay;
}

class VehicleAvailabilitySuggestion {
  const VehicleAvailabilitySuggestion({this.earliestStartAt, this.latestEndAt});

  final DateTime? earliestStartAt;
  final DateTime? latestEndAt;

  VehicleAvailabilitySuggestion merge({
    DateTime? earliestStartAt,
    DateTime? latestEndAt,
  }) {
    final currentEarliestStartAt = this.earliestStartAt;
    final nextEarliestStartAt =
        currentEarliestStartAt == null ||
            (earliestStartAt != null &&
                earliestStartAt.isAfter(currentEarliestStartAt))
        ? earliestStartAt
        : currentEarliestStartAt;

    final currentLatestEndAt = this.latestEndAt;
    final nextLatestEndAt =
        currentLatestEndAt == null ||
            (latestEndAt != null && latestEndAt.isBefore(currentLatestEndAt))
        ? latestEndAt
        : currentLatestEndAt;

    return VehicleAvailabilitySuggestion(
      earliestStartAt: nextEarliestStartAt,
      latestEndAt: nextLatestEndAt,
    );
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

  Vehicle copyWith({
    VehicleStatus? status,
    String? subtitle,
    DateTime? nextAvailableAt,
    int? priorityRank,
  }) {
    return Vehicle(
      id: id,
      internalNumber: internalNumber,
      name: name,
      brand: brand,
      model: model,
      plateNumber: plateNumber,
      category: category,
      status: status ?? this.status,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl,
      location: location,
      site: site,
      parkingDescription: parkingDescription,
      seats: seats,
      transmission: transmission,
      energyType: energyType,
      energyInfo: energyInfo,
      currentMileage: currentMileage,
      fuelLevelLabel: fuelLevelLabel,
      priorityRank: priorityRank ?? this.priorityRank,
      nextAvailableAt: nextAvailableAt ?? this.nextAvailableAt,
      availabilityByDay: availabilityByDay,
      knownIssues: knownIssues,
    );
  }
}
