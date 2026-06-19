import '../models/vehicle.dart';

int compareVehiclesByRecommendation(
  Vehicle first,
  Vehicle second, {
  List<String> sitePriority = const [],
}) {
  final siteRanks = _siteRanks(sitePriority);
  final siteRankComparison = _siteRank(
    first,
    siteRanks,
  ).compareTo(_siteRank(second, siteRanks));
  if (siteRankComparison != 0) {
    return siteRankComparison;
  }

  final mileageComparison = first.currentMileage.compareTo(
    second.currentMileage,
  );
  if (mileageComparison != 0) {
    return mileageComparison;
  }

  final statusComparison = first.status.sortRank.compareTo(
    second.status.sortRank,
  );
  if (statusComparison != 0) {
    return statusComparison;
  }

  final siteComparison = first.site.compareTo(second.site);
  if (siteComparison != 0) {
    return siteComparison;
  }

  final nameComparison = first.name.compareTo(second.name);
  if (nameComparison != 0) {
    return nameComparison;
  }

  return first.id.compareTo(second.id);
}

void sortVehiclesByRecommendation(
  List<Vehicle> vehicles, {
  List<String> sitePriority = const [],
}) {
  vehicles.sort(
    (first, second) => compareVehiclesByRecommendation(
      first,
      second,
      sitePriority: sitePriority,
    ),
  );
}

Map<String, int> _siteRanks(List<String> sitePriority) {
  final ranks = <String, int>{};

  for (final site in sitePriority) {
    final normalized = _normalizeSite(site);
    if (normalized.isEmpty || ranks.containsKey(normalized)) {
      continue;
    }
    ranks[normalized] = ranks.length;
  }

  return ranks;
}

int _siteRank(Vehicle vehicle, Map<String, int> siteRanks) {
  if (siteRanks.isEmpty) {
    return 0;
  }

  return siteRanks[_normalizeSite(vehicle.site)] ?? siteRanks.length;
}

String _normalizeSite(String value) {
  return value.trim().toLowerCase();
}
