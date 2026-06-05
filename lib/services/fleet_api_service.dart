import '../models/reservation.dart';
import '../models/vehicle.dart';
import '../utils/reservation_calendar_days.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'fleet_api_mappers.dart';
import 'reservation_video_service.dart';

class FleetApiService {
  FleetApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static const _reservationVideoUploadPath = '/metier/videos';
  static const _reservationVideoFileField = 'video';

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
    final constats = await _fetchConstatIndex();
    final reservationsWithConstats = [
      for (final reservation in reservations)
        _reservationWithConstatState(reservation, constats),
    ];

    reservationsWithConstats.sort((a, b) => a.startAt.compareTo(b.startAt));
    return reservationsWithConstats;
  }

  FleetReservation _reservationWithConstatState(
    FleetReservation reservation,
    _ConstatIndex constats,
  ) {
    final returnedAt =
        reservation.returnedAt ??
        _reservationReturnedAtFromConstats(reservation, constats);

    return reservation.copyWith(
      hasOpenConstat:
          reservation.hasOpenConstat ||
          constats.openReservationIds.contains(reservation.id) ||
          _reservationHasOpenConstatForVehicle(reservation, constats),
      hasClosedConstat:
          reservation.hasClosedConstat ||
          constats.closedReservationIds.containsKey(reservation.id) ||
          _reservationHasClosedConstatForVehicle(reservation, constats),
      returnedAt: returnedAt,
    );
  }

  Future<Map<int, AvailabilityStatus>> fetchVehicleAvailabilityForMonth({
    required Vehicle vehicle,
    required DateTime month,
  }) async {
    final availability = await fetchVehicleAvailabilityDetailsForMonth(
      vehicle: vehicle,
      month: month,
    );

    return availability.availabilityByDay;
  }

  Future<VehicleAvailabilityMonth> fetchVehicleAvailabilityDetailsForMonth({
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

      final constats = _availabilityResponseMayContainReservedRanges(response)
          ? await _fetchConstatIndex()
          : const _ConstatIndex();
      final apiAvailability = _availabilityFromResponse(
        response,
        month,
        vehicleId: vehicle.id,
        constats: constats,
      );
      availabilityByDay.addAll(apiAvailability.availabilityByDay);
      return VehicleAvailabilityMonth(
        availabilityByDay: availabilityByDay,
        suggestionsByDay: apiAvailability.suggestionsByDay,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    return VehicleAvailabilityMonth(availabilityByDay: availabilityByDay);
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

  Future<bool> isVehicleAvailableForPeriod({
    required Vehicle vehicle,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _apiClient.getMap(
      '/metier/vehicules-disponibles',
      queryParameters: {
        'dateDebut': FleetApiMappers.iso(startAt),
        'dateFin': FleetApiMappers.iso(endAt),
        ..._refreshQueryParameters(),
      },
    );
    final availableVehicleIds = _vehicleIdsFromAvailabilityResponse(response);

    if (_vehicleIdsMatch(availableVehicleIds, vehicle.id)) {
      return true;
    }

    return _isVehicleAvailableForPeriodFromClosedConstats(
      vehicle: vehicle,
      startAt: startAt,
      endAt: endAt,
    );
  }

  Future<bool> _isVehicleAvailableForPeriodFromClosedConstats({
    required Vehicle vehicle,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final constats = await _fetchConstatIndex();
    final hasClosedVehicleConstat = constats.closedVehicleConstats.any((
      constat,
    ) {
      final returnedAt = constat.returnedAt;
      return constat.vehicleId == vehicle.id &&
          returnedAt != null &&
          !returnedAt.isAfter(endAt);
    });
    if (!hasClosedVehicleConstat) {
      return false;
    }

    var month = DateTime(startAt.year, startAt.month);
    final lastMonth = DateTime(endAt.year, endAt.month);

    while (!month.isAfter(lastMonth)) {
      final Object? response;
      try {
        response = await _apiClient.getJson(
          '/metier/vehicules/${vehicle.id}/disponibilites',
          queryParameters: {
            'mois': _monthParameter(month),
            ..._refreshQueryParameters(),
          },
        );
      } on ApiException catch (error) {
        if (error.statusCode == 404) {
          return false;
        }
        rethrow;
      }

      final apiAvailability = _availabilityFromResponse(
        response,
        month,
        vehicleId: vehicle.id,
        constats: constats,
      );
      final availabilityByDay = Map<int, AvailabilityStatus>.of(
        vehicle.availabilityByDay,
      )..addAll(apiAvailability.availabilityByDay);

      if (reservationPeriodContainsUnavailableDayForMonth(
        startAt: startAt,
        endAt: endAt,
        month: month,
        availabilityByDay: availabilityByDay,
      )) {
        return false;
      }

      month = DateTime(month.year, month.month + 1);
    }

    return true;
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
    await _apiClient.delete('/metier/reservations/${reservation.id}');
  }

  Future<void> startConstat(
    FleetReservation reservation, {
    DateTime? confirmedAt,
  }) async {
    if (await _reservationAlreadyHasConstat(reservation)) {
      return;
    }

    final datePrise = _pickupTimestampInsideReservation(
      reservation,
      confirmedAt ?? DateTime.now(),
    );

    await _apiClient.post(
      '/metier/constats/demarrer',
      body: {
        'reservationId': int.tryParse(reservation.id) ?? reservation.id,
        'vehiculeId':
            int.tryParse(reservation.vehicle.id) ?? reservation.vehicle.id,
        'datePrise': FleetApiMappers.iso(datePrise),
        'kmDebut': reservation.expectedStartMileage,
        'depart': const {'nomFichier': 'video-non-requise', 'taille': '0'},
      },
    );
  }

  Future<void> finishConstat({
    required FleetReservation reservation,
    required int mileage,
    DateTime? confirmedAt,
  }) async {
    final constatId = await _findOpenConstatId(reservation.vehicle.id);
    final dateRendu = _returnTimestampInsideReservation(
      reservation,
      confirmedAt ?? DateTime.now(),
    );

    await _apiClient.post(
      '/metier/constats/$constatId/terminer',
      body: {
        'dateRendu': FleetApiMappers.iso(dateRendu),
        'kmFin': mileage,
        'arrive': const {'nomFichier': 'video-non-requise', 'taille': '0'},
      },
    );

    await _markReservationCompleted(reservation);
  }

  DateTime _pickupTimestampInsideReservation(
    FleetReservation reservation,
    DateTime confirmedAt,
  ) {
    if (confirmedAt.isBefore(reservation.startAt) ||
        !confirmedAt.isBefore(reservation.endAt)) {
      return reservation.startAt;
    }

    return confirmedAt;
  }

  DateTime _returnTimestampInsideReservation(
    FleetReservation reservation,
    DateTime confirmedAt,
  ) {
    if (confirmedAt.isBefore(reservation.startAt)) {
      return reservation.startAt;
    }
    if (!confirmedAt.isBefore(reservation.endAt)) {
      return _latestTimestampInsideReservation(reservation);
    }

    return confirmedAt;
  }

  DateTime _latestTimestampInsideReservation(FleetReservation reservation) {
    final latest = reservation.endAt.subtract(const Duration(seconds: 1));
    return latest.isBefore(reservation.startAt) ? reservation.startAt : latest;
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

  Future<void> uploadReservationVideo(ReservationVideoDraft video) async {
    await _apiClient.postMultipart(
      _reservationVideoUploadPath,
      fileField: _reservationVideoFileField,
      filePath: video.file.path,
      fields: video.multipartFields,
    );
  }

  Future<bool> _markReservationCompleted(FleetReservation reservation) async {
    final attempts = [
      {'statue': 'terminé'},
      {'statue': 'termine'},
      {'statut': 'terminé'},
      {'statut': 'termine'},
      {'statu': 'terminé'},
      {'statu': 'termine'},
    ];

    for (final body in attempts) {
      try {
        await _apiClient.patch(
          '/metier/reservations/${reservation.id}',
          body: body,
        );
        return true;
      } on ApiException {
        continue;
      }
    }

    return false;
  }

  Future<bool> _reservationAlreadyHasConstat(
    FleetReservation reservation,
  ) async {
    try {
      final response = await _apiClient.getJson('/metier/mes-constats');
      final constats = FleetApiMappers.itemsFromResponse(response);

      for (final constat in constats) {
        if (_constatMatchesReservation(constat, reservation)) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  Future<int> _findOpenConstatId(String vehicleId) async {
    final response = await _apiClient.getMap('/metier/mes-constats');
    final constats = FleetApiMappers.itemsFromResponse(response);

    for (final constat in constats) {
      final vehicle = constat['vehicule'];
      if (_constatIsOpen(constat) &&
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

  Future<_ConstatIndex> _fetchConstatIndex() async {
    try {
      final response = await _apiClient.getJson('/metier/mes-constats');
      final constats = FleetApiMappers.itemsFromResponse(response);
      final openReservationIds = <String>{};
      final openVehicleConstats = <_OpenVehicleConstat>[];
      final closedReservationIds = <String, DateTime?>{};
      final closedVehicleConstats = <_ClosedVehicleConstat>[];

      for (final constat in constats) {
        final reservationId = _idFromNestedValue(
          constat['reservation'] ??
              constat['reservationId'] ??
              constat['reservation_id'],
        );
        final vehicleId = _idFromNestedValue(
          constat['vehicule'] ?? constat['vehiculeId'] ?? constat['vehicleId'],
        );

        if (_constatIsOpen(constat)) {
          if (reservationId != null) {
            openReservationIds.add(reservationId);
          }
          if (vehicleId != null) {
            openVehicleConstats.add(
              _OpenVehicleConstat(
                vehicleId: vehicleId,
                pickedUpAt: _constatPickedUpAt(constat),
              ),
            );
          }
          continue;
        }

        if (_constatIsClosed(constat)) {
          final returnedAt = _constatReturnedAt(constat);
          if (reservationId != null) {
            closedReservationIds[reservationId] = returnedAt;
          }
          if (vehicleId != null) {
            closedVehicleConstats.add(
              _ClosedVehicleConstat(
                vehicleId: vehicleId,
                returnedAt: returnedAt,
                hasFinalMileage: _hasFinalMileage(constat),
              ),
            );
          }
        }
      }

      return _ConstatIndex(
        openReservationIds: openReservationIds,
        openVehicleConstats: openVehicleConstats,
        closedReservationIds: closedReservationIds,
        closedVehicleConstats: closedVehicleConstats,
      );
    } catch (_) {
      return const _ConstatIndex();
    }
  }

  bool _reservationMayHaveOpenConstat(FleetReservation reservation) {
    final now = DateTime.now();

    return !reservation.isInHistory &&
        !now.isBefore(
          reservation.startAt.subtract(FleetReservation.pickupFormLeadTime),
        );
  }

  bool _reservationHasOpenConstatForVehicle(
    FleetReservation reservation,
    _ConstatIndex constats,
  ) {
    for (final constat in constats.openVehicleConstats) {
      if (constat.vehicleId != reservation.vehicle.id) {
        continue;
      }

      final pickedUpAt = constat.pickedUpAt;
      if (pickedUpAt == null) {
        return _reservationMayHaveOpenConstat(reservation);
      }

      if (!pickedUpAt.isBefore(reservation.startAt) &&
          pickedUpAt.isBefore(reservation.endAt)) {
        return true;
      }
    }

    return false;
  }

  bool _reservationHasClosedConstatForVehicle(
    FleetReservation reservation,
    _ConstatIndex constats,
  ) {
    for (final constat in constats.closedVehicleConstats) {
      if (constat.vehicleId != reservation.vehicle.id) {
        continue;
      }

      final returnedAt = constat.returnedAt;
      if (returnedAt == null) {
        if (constat.hasFinalMileage &&
            reservation.endAt.isBefore(DateTime.now())) {
          return true;
        }
        continue;
      }

      if (!returnedAt.isBefore(reservation.startAt) &&
          !returnedAt.isAfter(reservation.endAt)) {
        return true;
      }
    }

    return false;
  }

  DateTime? _reservationReturnedAtFromConstats(
    FleetReservation reservation,
    _ConstatIndex constats,
  ) {
    if (constats.closedReservationIds.containsKey(reservation.id)) {
      return constats.closedReservationIds[reservation.id];
    }

    for (final constat in constats.closedVehicleConstats) {
      if (constat.vehicleId != reservation.vehicle.id) {
        continue;
      }

      final returnedAt = constat.returnedAt;
      if (returnedAt == null) {
        continue;
      }

      if (!returnedAt.isBefore(reservation.startAt) &&
          !returnedAt.isAfter(reservation.endAt)) {
        return returnedAt;
      }
    }

    return null;
  }

  bool _constatMatchesReservation(
    Map<String, dynamic> constat,
    FleetReservation reservation,
  ) {
    final reservationId = _idFromNestedValue(
      constat['reservation'] ??
          constat['reservationId'] ??
          constat['reservation_id'],
    );
    if (reservationId != null) {
      return reservationId == reservation.id;
    }

    final vehicleId = _idFromNestedValue(
      constat['vehicule'] ?? constat['vehiculeId'] ?? constat['vehicleId'],
    );
    if (vehicleId != reservation.vehicle.id) {
      return false;
    }

    final pickupAt = _constatPickedUpAt(constat);
    final returnedAt = _constatReturnedAt(constat);
    final referenceDate = returnedAt ?? pickupAt;

    if (referenceDate == null) {
      return _constatIsOpen(constat) &&
          _reservationMayHaveOpenConstat(reservation);
    }

    return !referenceDate.isBefore(reservation.startAt) &&
        !referenceDate.isAfter(reservation.endAt);
  }

  String? _idFromNestedValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return _idFromNestedValue(value['id'] ?? value['@id']);
    }

    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final pathSegments = text.split('/').where((segment) => segment.isNotEmpty);
    if (pathSegments.isNotEmpty && pathSegments.length > 1) {
      return pathSegments.last;
    }

    return text;
  }

  Set<String> _vehicleIdsFromAvailabilityResponse(Object? response) {
    final ids = <String>{};

    void addId(Object? value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) {
        return;
      }

      ids.add(text);
      final pathSegments = text
          .split('/')
          .where((segment) => segment.isNotEmpty);
      if (pathSegments.isNotEmpty) {
        ids.add(pathSegments.last);
      }
    }

    void addFromValue(Object? value) {
      if (value is Map<String, dynamic>) {
        addId(value['id']);
        addId(value['@id']);
        addFromValue(value['vehicule']);
        addFromValue(value['vehicle']);
        addFromValue(value['vehiculeId']);
        addFromValue(value['vehicleId']);
        return;
      }

      if (value is List) {
        for (final item in value) {
          addFromValue(item);
        }
        return;
      }

      addId(value);
    }

    for (final item in FleetApiMappers.itemsFromResponse(response)) {
      addFromValue(item);
    }

    if (response is Map<String, dynamic>) {
      addFromValue(response['ids']);
      addFromValue(response['vehicleIds']);
      addFromValue(response['vehiculeIds']);
      addFromValue(response['vehiculesDisponibles']);
      addFromValue(response['availableVehicleIds']);
    }

    return ids;
  }

  bool _vehicleIdsMatch(Set<String> candidateIds, String vehicleId) {
    final vehicleIdCandidates = <String>{vehicleId};
    final pathSegments = vehicleId
        .split('/')
        .where((segment) => segment.trim().isNotEmpty);
    if (pathSegments.isNotEmpty) {
      vehicleIdCandidates.add(pathSegments.last);
    }

    return candidateIds.any(vehicleIdCandidates.contains);
  }

  bool _constatIsClosed(Map<String, dynamic> constat) {
    return constat['estOuvert'] == false ||
        _hasFinalMileage(constat) ||
        _constatReturnedAt(constat) != null;
  }

  bool _constatIsOpen(Map<String, dynamic> constat) {
    final explicitOpen =
        constat['estOuvert'] ??
        constat['constatOuvert'] ??
        constat['open'] ??
        constat['isOpen'];

    if (explicitOpen is bool) {
      return explicitOpen;
    }

    final status = _textFromApiValue(
      constat['statut'] ??
          constat['statue'] ??
          constat['statu'] ??
          constat['status'] ??
          constat['state'] ??
          constat['etat'],
    ).toLowerCase();

    if (status.contains('term') ||
        status.contains('fini') ||
        status.contains('clos') ||
        status.contains('completed') ||
        status.contains('done')) {
      return false;
    }

    if (status.contains('ouvert') ||
        status.contains('open') ||
        status.contains('cours') ||
        status.contains('progress') ||
        status.contains('demarr') ||
        status.contains('démarr') ||
        status.contains('active')) {
      return true;
    }

    return _constatPickedUpAt(constat) != null &&
        _constatReturnedAt(constat) == null &&
        !_hasFinalMileage(constat);
  }

  bool _hasFinalMileage(Map<String, dynamic> constat) {
    return _textFromApiValue(
      constat['kmFin'] ??
          constat['kilometrageFin'] ??
          constat['kilometrageRetour'] ??
          constat['mileageEnd'],
    ).isNotEmpty;
  }

  DateTime? _constatPickedUpAt(Map<String, dynamic> constat) {
    return _dateFromApiValue(
      constat['datePrise'] ??
          constat['dateDepart'] ??
          constat['pickedUpAt'] ??
          constat['startedAt'] ??
          constat['demarreLe'],
    );
  }

  DateTime? _constatReturnedAt(Map<String, dynamic> constat) {
    return _dateFromApiValue(
      constat['dateRendu'] ??
          constat['dateRetour'] ??
          constat['returnedAt'] ??
          constat['closedAt'] ??
          constat['termineLe'],
    );
  }

  String _textFromApiValue(Object? value) {
    return value?.toString().trim() ?? '';
  }

  VehicleAvailabilityMonth _availabilityFromResponse(
    Object? response,
    DateTime month, {
    required String vehicleId,
    _ConstatIndex constats = const _ConstatIndex(),
  }) {
    final availabilityByDay = <int, AvailabilityStatus>{};
    final suggestionsByDay = <int, VehicleAvailabilitySuggestion>{};

    void setStatus(int day, AvailabilityStatus status) {
      final existing = availabilityByDay[day];
      availabilityByDay[day] = _dominantAvailabilityStatus(existing, status);
    }

    void setSuggestion({
      required DateTime dateTime,
      DateTime? earliestStartAt,
      DateTime? latestEndAt,
    }) {
      if (dateTime.year != month.year || dateTime.month != month.month) {
        return;
      }

      final existing = suggestionsByDay[dateTime.day];
      suggestionsByDay[dateTime.day] =
          existing?.merge(
            earliestStartAt: earliestStartAt,
            latestEndAt: latestEndAt,
          ) ??
          VehicleAvailabilitySuggestion(
            earliestStartAt: earliestStartAt,
            latestEndAt: latestEndAt,
          );
    }

    void addStatus(Object? dayValue, Object? statusValue) {
      final day = _dayFromApiValue(dayValue, month);
      final status = _availabilityStatusFromApiValue(statusValue);

      if (day != null && status != null) {
        setStatus(day, status);
      }
    }

    bool addRangeStatus(
      Object? startValue,
      Object? endValue,
      Object? statusValue, {
      Object? reservationValue,
    }) {
      final start = _dateFromApiValue(startValue);
      final end = _dateFromApiValue(endValue);
      final status = _availabilityStatusFromApiValue(statusValue);

      if (start == null ||
          end == null ||
          status == null ||
          !start.isBefore(end)) {
        return false;
      }

      final effectiveEnd = _effectiveAvailabilityRangeEnd(
        startAt: start,
        endAt: end,
        status: status,
        reservationValue: reservationValue,
        vehicleId: vehicleId,
        constats: constats,
      );
      if (!start.isBefore(effectiveEnd)) {
        return false;
      }

      var current = DateTime(start.year, start.month, start.day);
      final lastOccupiedInstant = effectiveEnd.subtract(
        const Duration(microseconds: 1),
      );
      final last = DateTime(
        lastOccupiedInstant.year,
        lastOccupiedInstant.month,
        lastOccupiedInstant.day,
      );

      while (!current.isAfter(last)) {
        if (current.year == month.year && current.month == month.month) {
          setStatus(
            current.day,
            _availabilityStatusForRangeDay(
              status: status,
              day: current,
              rangeStart: start,
              rangeEnd: effectiveEnd,
            ),
          );
        }
        current = current.add(const Duration(days: 1));
      }

      if (status == AvailabilityStatus.reserved) {
        setSuggestion(
          dateTime: start.subtract(reservationTurnaroundDuration),
          latestEndAt: start.subtract(reservationTurnaroundDuration),
        );
        setSuggestion(
          dateTime: effectiveEnd.add(reservationTurnaroundDuration),
          earliestStartAt: effectiveEnd.add(reservationTurnaroundDuration),
        );
      }

      return true;
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

        final nestedReservations = FleetApiMappers.itemsFromResponse({
          'items': entry['reservations'],
        });
        var parsedNestedReservationRange = false;
        for (final reservation in nestedReservations) {
          parsedNestedReservationRange =
              addRangeStatus(
                reservation['dateDebut'] ?? reservation['startAt'],
                reservation['dateFin'] ?? reservation['endAt'],
                AvailabilityStatus.reserved.name,
                reservationValue: reservation,
              ) ||
              parsedNestedReservationRange;
        }
        if (parsedNestedReservationRange) {
          return;
        }

        if (entry['dateDebut'] != null && entry['dateFin'] != null) {
          addRangeStatus(
            entry['dateDebut'],
            entry['dateFin'],
            statusValue ?? AvailabilityStatus.reserved.name,
            reservationValue: entry,
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
          final nestedReservations = FleetApiMappers.itemsFromResponse({
            'items': value['reservations'],
          });
          var parsedNestedReservationRange = false;
          for (final reservation in nestedReservations) {
            parsedNestedReservationRange =
                addRangeStatus(
                  reservation['dateDebut'] ?? reservation['startAt'],
                  reservation['dateFin'] ?? reservation['endAt'],
                  AvailabilityStatus.reserved.name,
                  reservationValue: reservation,
                ) ||
                parsedNestedReservationRange;
          }
          if (parsedNestedReservationRange) {
            continue;
          }

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
              reservationValue: value,
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
      return VehicleAvailabilityMonth(
        availabilityByDay: availabilityByDay,
        suggestionsByDay: suggestionsByDay,
      );
    }

    if (response is! Map<String, dynamic>) {
      return VehicleAvailabilityMonth(
        availabilityByDay: availabilityByDay,
        suggestionsByDay: suggestionsByDay,
      );
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

    return VehicleAvailabilityMonth(
      availabilityByDay: availabilityByDay,
      suggestionsByDay: suggestionsByDay,
    );
  }

  DateTime _effectiveAvailabilityRangeEnd({
    required DateTime startAt,
    required DateTime endAt,
    required AvailabilityStatus status,
    required Object? reservationValue,
    required String vehicleId,
    required _ConstatIndex constats,
  }) {
    if (status != AvailabilityStatus.reserved) {
      return endAt;
    }

    final returnedAt = _closedReturnedAtForAvailabilityRange(
      startAt: startAt,
      endAt: endAt,
      reservationValue: reservationValue,
      vehicleId: vehicleId,
      constats: constats,
    );
    if (returnedAt == null ||
        returnedAt.isBefore(startAt) ||
        returnedAt.isAfter(endAt)) {
      return endAt;
    }

    return returnedAt;
  }

  DateTime? _closedReturnedAtForAvailabilityRange({
    required DateTime startAt,
    required DateTime endAt,
    required Object? reservationValue,
    required String vehicleId,
    required _ConstatIndex constats,
  }) {
    final reservationId = _reservationIdFromAvailabilityValue(reservationValue);
    if (reservationId != null &&
        constats.closedReservationIds.containsKey(reservationId)) {
      return constats.closedReservationIds[reservationId];
    }

    final rangeVehicleId =
        _vehicleIdFromAvailabilityValue(reservationValue) ?? vehicleId;
    DateTime? returnedAt;
    for (final constat in constats.closedVehicleConstats) {
      if (constat.vehicleId != rangeVehicleId || constat.returnedAt == null) {
        continue;
      }

      final candidate = constat.returnedAt!;
      if (candidate.isBefore(startAt) || candidate.isAfter(endAt)) {
        continue;
      }

      if (returnedAt == null || candidate.isBefore(returnedAt)) {
        returnedAt = candidate;
      }
    }

    return returnedAt;
  }

  String? _reservationIdFromAvailabilityValue(Object? value) {
    if (value is! Map<String, dynamic>) {
      return _idFromNestedValue(value);
    }

    return _idFromNestedValue(
      value['id'] ??
          value['@id'] ??
          value['reservation'] ??
          value['reservationId'] ??
          value['reservation_id'],
    );
  }

  String? _vehicleIdFromAvailabilityValue(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return _idFromNestedValue(
      value['vehicule'] ?? value['vehiculeId'] ?? value['vehicleId'],
    );
  }

  bool _availabilityResponseMayContainReservedRanges(Object? value) {
    if (value is List) {
      return value.any(_availabilityResponseMayContainReservedRanges);
    }

    if (value is! Map<String, dynamic>) {
      return false;
    }

    final nestedReservations = FleetApiMappers.itemsFromResponse({
      'items': value['reservations'],
    });
    if (nestedReservations.isNotEmpty) {
      return true;
    }

    if (value['dateDebut'] != null && value['dateFin'] != null) {
      final status = _availabilityStatusFromApiValue(
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
      return status == AvailabilityStatus.reserved;
    }

    return value.values.any(_availabilityResponseMayContainReservedRanges);
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
    try {
      final reservations = await fetchReservations();
      final inUseReservationsByVehicleId = <String, FleetReservation>{};

      for (final reservation in reservations) {
        if (reservation.isInHistory ||
            !reservation.hasOpenConstat ||
            reservation.hasClosedConstat) {
          continue;
        }

        final vehicleId = reservation.vehicle.id;
        final existing = inUseReservationsByVehicleId[vehicleId];
        if (existing == null || reservation.endAt.isAfter(existing.endAt)) {
          inUseReservationsByVehicleId[vehicleId] = reservation;
        }
      }

      return [
        for (final vehicle in vehicles)
          if (inUseReservationsByVehicleId.containsKey(vehicle.id))
            vehicle.copyWith(
              status: VehicleStatus.inUse,
              subtitle:
                  'En usage jusqu’au ${_dateTimeUntilLabel(inUseReservationsByVehicleId[vehicle.id]!.endAt)}',
              nextAvailableAt: inUseReservationsByVehicleId[vehicle.id]!.endAt,
              priorityRank: VehicleStatus.inUse.sortRank,
            )
          else if (vehicle.status == VehicleStatus.inUse)
            vehicle.copyWith(
              status: VehicleStatus.available,
              subtitle: VehicleStatus.available.label,
              priorityRank: VehicleStatus.available.sortRank,
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
      return AvailabilityStatus.partial;
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

  AvailabilityStatus _availabilityStatusForRangeDay({
    required AvailabilityStatus status,
    required DateTime day,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (status != AvailabilityStatus.reserved) {
      return status;
    }

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final coversFullDay =
        !rangeStart.isAfter(dayStart) && !rangeEnd.isBefore(dayEnd);

    return coversFullDay
        ? AvailabilityStatus.reserved
        : AvailabilityStatus.partial;
  }

  AvailabilityStatus _dominantAvailabilityStatus(
    AvailabilityStatus? existing,
    AvailabilityStatus next,
  ) {
    if (existing == null) {
      return next;
    }

    return _availabilityStatusPriority(next) >
            _availabilityStatusPriority(existing)
        ? next
        : existing;
  }

  int _availabilityStatusPriority(AvailabilityStatus status) {
    return switch (status) {
      AvailabilityStatus.free => 0,
      AvailabilityStatus.partial => 1,
      AvailabilityStatus.reserved => 2,
      AvailabilityStatus.maintenance => 3,
    };
  }
}

class _ConstatIndex {
  const _ConstatIndex({
    this.openReservationIds = const {},
    this.openVehicleConstats = const [],
    this.closedReservationIds = const {},
    this.closedVehicleConstats = const [],
  });

  final Set<String> openReservationIds;
  final List<_OpenVehicleConstat> openVehicleConstats;
  final Map<String, DateTime?> closedReservationIds;
  final List<_ClosedVehicleConstat> closedVehicleConstats;
}

class _OpenVehicleConstat {
  const _OpenVehicleConstat({
    required this.vehicleId,
    required this.pickedUpAt,
  });

  final String vehicleId;
  final DateTime? pickedUpAt;
}

class _ClosedVehicleConstat {
  const _ClosedVehicleConstat({
    required this.vehicleId,
    required this.returnedAt,
    required this.hasFinalMileage,
  });

  final String vehicleId;
  final DateTime? returnedAt;
  final bool hasFinalMileage;
}
