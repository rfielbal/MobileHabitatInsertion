import '../models/reservation.dart';
import '../models/vehicle.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'fleet_api_mappers.dart';

class FleetApiService {
  FleetApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Vehicle>> fetchVehicles() async {
    final sitesResponse = await _apiClient.getMap('/metier/mes-sites');
    final sites = FleetApiMappers.itemsFromResponse(sitesResponse);
    final vehiclesById = <String, Vehicle>{};

    for (final site in sites) {
      final siteId = site['id'];
      if (siteId == null) {
        continue;
      }

      final response = await _apiClient.getMap(
        '/metier/sites/$siteId/vehicules',
      );
      final vehicles = FleetApiMappers.itemsFromResponse(response);

      for (final item in vehicles) {
        final vehicle = FleetApiMappers.vehicleFromJson(item);
        vehiclesById[vehicle.id] = vehicle;
      }
    }

    if (vehiclesById.isEmpty) {
      final now = DateTime.now();
      final response = await _apiClient.getMap(
        '/metier/vehicules-disponibles',
        queryParameters: {
          'dateDebut': FleetApiMappers.iso(now),
          'dateFin': FleetApiMappers.iso(now.add(const Duration(days: 1))),
        },
      );

      for (final item in FleetApiMappers.itemsFromResponse(response)) {
        final vehicle = FleetApiMappers.vehicleFromJson(item);
        vehiclesById[vehicle.id] = vehicle;
      }
    }

    var vehicles = vehiclesById.values.toList();
    vehicles = await _withCurrentReservationState(vehicles);
    vehicles.sort((a, b) {
      final statusSort = a.status.sortRank.compareTo(b.status.sortRank);
      if (statusSort != 0) {
        return statusSort;
      }
      return a.name.compareTo(b.name);
    });
    return vehicles;
  }

  Future<List<String>> fetchUserSiteLabels() async {
    final response = await _apiClient.getJson(
      '/metier/mes-sites',
      queryParameters: _refreshQueryParameters(),
    );
    final sites = FleetApiMappers.itemsFromResponse(response)
        .map(FleetApiMappers.siteLabelFromJson)
        .where((site) => site.trim().isNotEmpty)
        .toSet()
        .toList();

    sites.sort();
    return sites;
  }

  Future<List<FleetReservation>> fetchReservations() async {
    final response = await _apiClient.getJson(
      '/metier/mes-reservations',
      queryParameters: _refreshQueryParameters(),
    );
    final reservations = FleetApiMappers.itemsFromResponse(
      response,
    ).map(FleetApiMappers.reservationFromJson).toList();

    reservations.sort((a, b) => a.startAt.compareTo(b.startAt));
    return reservations;
  }

  Future<Map<int, AvailabilityStatus>> fetchVehicleAvailabilityForMonth({
    required Vehicle vehicle,
    required DateTime month,
  }) async {
    final availabilityByDay = Map<int, AvailabilityStatus>.of(
      vehicle.availabilityByDay,
    );

    try {
      final response = await _apiClient.getJson(
        '/metier/vehicules/${vehicle.id}/disponibilites',
        queryParameters: {
          'mois': _monthParameter(month),
          ..._refreshQueryParameters(),
        },
      );

      final apiAvailabilityByDay = _availabilityByDayFromResponse(
        response,
        month,
      );
      if (apiAvailabilityByDay.isNotEmpty) {
        availabilityByDay.addAll(apiAvailabilityByDay);
        return availabilityByDay;
      }
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    return _fetchVehicleAvailabilityForMonthByDay(
      vehicle: vehicle,
      month: month,
      knownAvailabilityByDay: availabilityByDay,
    );
  }

  Future<Map<int, AvailabilityStatus>> _fetchVehicleAvailabilityForMonthByDay({
    required Vehicle vehicle,
    required DateTime month,
    required Map<int, AvailabilityStatus> knownAvailabilityByDay,
  }) async {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final availabilityByDay = Map<int, AvailabilityStatus>.of(
      knownAvailabilityByDay,
    );
    final results = await Future.wait([
      for (var day = 1; day <= daysInMonth; day++)
        _fetchVehicleAvailabilityForDay(
          vehicle: vehicle,
          month: month,
          day: day,
        ),
    ]);

    for (final result in results) {
      availabilityByDay[result.key] = result.value;
    }

    return availabilityByDay;
  }

  Future<FleetReservation> createReservation({
    required Vehicle vehicle,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _apiClient.postMap(
      '/metier/reservations',
      body: {
        'vehiculeId': int.tryParse(vehicle.id) ?? vehicle.id,
        'dateDebut': FleetApiMappers.iso(startAt),
        'dateFin': FleetApiMappers.iso(endAt),
        'type': 'reservation',
      },
    );

    return FleetApiMappers.reservationFromJson(response);
  }

  Future<FleetReservation> updateReservation({
    required FleetReservation reservation,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _apiClient.patchMap(
      '/metier/reservations/${reservation.id}',
      body: {
        'vehiculeId':
            int.tryParse(reservation.vehicle.id) ?? reservation.vehicle.id,
        'dateDebut': FleetApiMappers.iso(startAt),
        'dateFin': FleetApiMappers.iso(endAt),
        'type': 'reservation',
      },
    );

    return FleetApiMappers.reservationFromJson(response);
  }

  Future<void> deleteReservation(FleetReservation reservation) async {
    await _apiClient.delete('/reservations/${reservation.id}');
  }

  Future<void> startConstat(FleetReservation reservation) async {
    await _apiClient.postMap(
      '/metier/constats/demarrer',
      body: {
        'reservationId': int.tryParse(reservation.id) ?? reservation.id,
        'vehiculeId':
            int.tryParse(reservation.vehicle.id) ?? reservation.vehicle.id,
        'datePrise': FleetApiMappers.iso(DateTime.now()),
        'kmDebut': reservation.expectedStartMileage,
        'depart': const {'nomFichier': 'video-non-requise', 'taille': '0'},
      },
    );
  }

  Future<void> finishConstat({
    required FleetReservation reservation,
    required int mileage,
  }) async {
    final constatId = await _findOpenConstatId(reservation.vehicle.id);

    await _apiClient.postMap(
      '/metier/constats/$constatId/terminer',
      body: {
        'dateRendu': FleetApiMappers.iso(DateTime.now()),
        'kmFin': mileage,
        'arrive': const {'nomFichier': 'video-non-requise', 'taille': '0'},
      },
    );
  }

  Future<void> createSignalement({
    required FleetReservation reservation,
    required String type,
    required String message,
  }) async {
    await _apiClient.postMap(
      '/metier/signalements',
      body: {
        'vehiculeId':
            int.tryParse(reservation.vehicle.id) ?? reservation.vehicle.id,
        'type': type,
        'message': message,
      },
    );
  }

  Future<int> _findOpenConstatId(String vehicleId) async {
    final response = await _apiClient.getMap('/metier/mes-constats');
    final constats = FleetApiMappers.itemsFromResponse(response);

    for (final constat in constats) {
      final vehicle = constat['vehicule'];
      if (constat['estOuvert'] == true &&
          vehicle is Map<String, dynamic> &&
          vehicle['id'].toString() == vehicleId) {
        final constatId = int.tryParse('${constat['id']}');
        if (constatId != null) {
          return constatId;
        }
      }
    }

    throw const FormatException(
      'Aucun constat ouvert trouvé pour ce véhicule.',
    );
  }

  Future<MapEntry<int, AvailabilityStatus>> _fetchVehicleAvailabilityForDay({
    required Vehicle vehicle,
    required DateTime month,
    required int day,
  }) async {
    final startAt = DateTime(month.year, month.month, day);
    final endAt = startAt.add(const Duration(days: 1));
    final response = await _apiClient.getMap(
      '/metier/vehicules-disponibles',
      queryParameters: {
        'dateDebut': FleetApiMappers.iso(startAt),
        'dateFin': FleetApiMappers.iso(endAt),
        ..._refreshQueryParameters(),
      },
    );
    final availableVehicleIds = FleetApiMappers.itemsFromResponse(
      response,
    ).map((item) => '${item['id']}').toSet();

    if (availableVehicleIds.contains(vehicle.id)) {
      return MapEntry(day, AvailabilityStatus.free);
    }

    final status = vehicle.status == VehicleStatus.maintenance
        ? AvailabilityStatus.maintenance
        : AvailabilityStatus.reserved;
    return MapEntry(day, status);
  }

  Map<int, AvailabilityStatus> _availabilityByDayFromResponse(
    Object? response,
    DateTime month,
  ) {
    final availabilityByDay = <int, AvailabilityStatus>{};

    void addStatus(Object? dayValue, Object? statusValue) {
      final day = _dayFromApiValue(dayValue, month);
      final status = _availabilityStatusFromApiValue(statusValue);

      if (day != null && status != null) {
        availabilityByDay[day] = status;
      }
    }

    void addRangeStatus(
      Object? startValue,
      Object? endValue,
      Object? statusValue,
    ) {
      final start = _dateFromApiValue(startValue);
      final end = _dateFromApiValue(endValue);
      final status = _availabilityStatusFromApiValue(statusValue);

      if (start == null || end == null || status == null) {
        return;
      }

      var current = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);

      while (!current.isAfter(last)) {
        if (current.year == month.year && current.month == month.month) {
          availabilityByDay[current.day] = status;
        }
        current = current.add(const Duration(days: 1));
      }
    }

    void parseEntry(Object? entry) {
      if (entry is Map<String, dynamic>) {
        final dayValue =
            entry['jour'] ??
            entry['day'] ??
            entry['date'] ??
            entry['dateDebut'] ??
            entry['startAt'];
        final statusValue =
            entry['statut'] ??
            entry['status'] ??
            entry['etat'] ??
            entry['availability'] ??
            entry['disponibilite'] ??
            entry['disponible'] ??
            entry['estDisponible'] ??
            entry['isAvailable'] ??
            entry['type'];

        if (entry['dateDebut'] != null && entry['dateFin'] != null) {
          addRangeStatus(
            entry['dateDebut'],
            entry['dateFin'],
            statusValue ?? AvailabilityStatus.reserved.name,
          );
          return;
        }

        addStatus(dayValue, statusValue);
      }
    }

    void parseStatusMap(Map<String, dynamic> valuesByDay) {
      for (final entry in valuesByDay.entries) {
        if (int.tryParse(entry.key) == null &&
            DateTime.tryParse(entry.key) == null) {
          continue;
        }

        if (entry.value is Map<String, dynamic>) {
          final value = entry.value as Map<String, dynamic>;
          if (value['dateDebut'] != null && value['dateFin'] != null) {
            addRangeStatus(
              value['dateDebut'],
              value['dateFin'],
              value['statut'] ??
                  value['status'] ??
                  value['etat'] ??
                  value['availability'] ??
                  value['disponibilite'] ??
                  value['disponible'] ??
                  value['estDisponible'] ??
                  value['isAvailable'] ??
                  value['type'] ??
                  AvailabilityStatus.reserved.name,
            );
            continue;
          }

          addStatus(
            entry.key,
            value['statut'] ??
                value['status'] ??
                value['etat'] ??
                value['availability'] ??
                value['disponibilite'] ??
                value['disponible'] ??
                value['estDisponible'] ??
                value['isAvailable'] ??
                value['type'],
          );
        } else {
          addStatus(entry.key, entry.value);
        }
      }
    }

    if (response is List) {
      for (final entry in response) {
        parseEntry(entry);
      }
      return availabilityByDay;
    }

    if (response is! Map<String, dynamic>) {
      return availabilityByDay;
    }

    for (final key in [
      'items',
      'hydra:member',
      'disponibilites',
      'availability',
      'jours',
      'days',
      'reservations',
      'calendrier',
      'calendar',
      'availabilityByDay',
      'disponibilitesParJour',
    ]) {
      final value = response[key];
      if (value is List) {
        for (final entry in value) {
          parseEntry(entry);
        }
      } else if (value is Map<String, dynamic>) {
        parseStatusMap(value);
      }
    }

    parseStatusMap(response);

    return availabilityByDay;
  }

  String _monthParameter(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  Map<String, String> _refreshQueryParameters() {
    return {'_': DateTime.now().millisecondsSinceEpoch.toString()};
  }

  Future<List<Vehicle>> _withCurrentReservationState(
    List<Vehicle> vehicles,
  ) async {
    final now = DateTime.now();

    try {
      final reservations = await fetchReservations();
      final activeReservationsByVehicleId = <String, FleetReservation>{};

      for (final reservation in reservations) {
        if (reservation.startAt.isAfter(now) ||
            !reservation.endAt.isAfter(now)) {
          continue;
        }

        final vehicleId = reservation.vehicle.id;
        final existing = activeReservationsByVehicleId[vehicleId];
        if (existing == null || reservation.endAt.isAfter(existing.endAt)) {
          activeReservationsByVehicleId[vehicleId] = reservation;
        }
      }

      return [
        for (final vehicle in vehicles)
          if (activeReservationsByVehicleId.containsKey(vehicle.id))
            vehicle.copyWith(
              status: VehicleStatus.inUse,
              subtitle:
                  'En usage jusqu’au ${_dateTimeUntilLabel(activeReservationsByVehicleId[vehicle.id]!.endAt)}',
              nextAvailableAt: activeReservationsByVehicleId[vehicle.id]!.endAt,
              priorityRank: VehicleStatus.inUse.sortRank,
            )
          else
            vehicle,
      ];
    } catch (_) {
      return vehicles;
    }
  }

  String _dateTimeUntilLabel(DateTime date) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} à $hour:$minute';
  }

  int? _dayFromApiValue(Object? value, DateTime month) {
    if (value is int) {
      return _validDay(value, month);
    }

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final day = int.tryParse(text);
    if (day != null) {
      return _validDay(day, month);
    }

    final date = DateTime.tryParse(text)?.toLocal();
    if (date == null || date.year != month.year || date.month != month.month) {
      return null;
    }

    return _validDay(date.day, month);
  }

  DateTime? _dateFromApiValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text)?.toLocal();
  }

  int? _validDay(int day, DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (day < 1 || day > daysInMonth) {
      return null;
    }
    return day;
  }

  AvailabilityStatus? _availabilityStatusFromApiValue(Object? value) {
    if (value is bool) {
      return value ? AvailabilityStatus.free : AvailabilityStatus.reserved;
    }

    final status = value?.toString().toLowerCase().trim();
    if (status == null || status.isEmpty) {
      return null;
    }

    if (status.contains('maintenance') || status.contains('garage')) {
      return AvailabilityStatus.maintenance;
    }
    if (status.contains('partiel') || status.contains('partial')) {
      return AvailabilityStatus.free;
    }
    if (status.contains('reserve') ||
        status.contains('réserv') ||
        status.contains('reservation') ||
        status.contains('booked') ||
        status.contains('unavailable') ||
        status.contains('indisponible')) {
      return AvailabilityStatus.reserved;
    }
    if (status.contains('libre') ||
        status.contains('disponible') ||
        status.contains('available') ||
        status.contains('free')) {
      return AvailabilityStatus.free;
    }

    return null;
  }
}
