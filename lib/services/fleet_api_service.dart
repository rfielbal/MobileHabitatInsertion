import 'package:path/path.dart' as p;

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

    reservations.sort((a, b) => a.startAt.compareTo(b.startAt));
    return reservations;
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

      final apiAvailability = _availabilityFromResponse(
        response,
        month,
        vehicleId: vehicle.id,
      );
      availabilityByDay.addAll(apiAvailability.availabilityByDay);
      return VehicleAvailabilityMonth(
        availabilityByDay: availabilityByDay,
        suggestionsByDay: apiAvailability.suggestionsByDay,
        hasEffectiveReturnAdjustments:
            apiAvailability.hasEffectiveReturnAdjustments,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    return VehicleAvailabilityMonth(availabilityByDay: availabilityByDay);
  }

  Future<List<DateTime>> fetchVehicleReservationStartTimesForMonth({
    required Vehicle vehicle,
    required DateTime month,
  }) async {
    final response = await _apiClient.getJson(
      '/metier/vehicules/${vehicle.id}/disponibilites',
      queryParameters: {
        'mois': _monthParameter(month),
        ..._refreshQueryParameters(),
      },
    );

    return _reservationStartTimesFromAvailabilityResponse(response);
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

    return _isVehicleAvailableForPeriodFromDetailedAvailability(
      vehicle: vehicle,
      startAt: startAt,
      endAt: endAt,
    );
  }

  Future<bool> _isVehicleAvailableForPeriodFromDetailedAvailability({
    required Vehicle vehicle,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
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

      if (_availabilityResponseHasActiveOverlap(
        response,
        startAt: startAt,
        endAt: endAt,
      )) {
        return false;
      }

      final apiAvailability = _availabilityFromResponse(
        response,
        month,
        vehicleId: vehicle.id,
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

  bool _availabilityResponseHasActiveOverlap(
    Object? value, {
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (value is List) {
      return value.any(
        (entry) => _availabilityResponseHasActiveOverlap(
          entry,
          startAt: startAt,
          endAt: endAt,
        ),
      );
    }

    if (value is! Map<String, dynamic>) {
      return false;
    }

    final nestedReservations = FleetApiMappers.itemsFromResponse({
      'items': value['reservations'],
    });
    if (nestedReservations.any(
      (reservation) => _availabilityRangeOverlapsPeriod(
        reservation,
        fallbackStatus: AvailabilityStatus.reserved,
        startAt: startAt,
        endAt: endAt,
      ),
    )) {
      return true;
    }

    if (_availabilityRangeOverlapsPeriod(
      value,
      fallbackStatus: _availabilityStatusFromApiValue(
        value['statut'] ??
            value['status'] ??
            value['etat'] ??
            value['availability'] ??
            value['disponibilite'] ??
            value['disponible'] ??
            value['estDisponible'] ??
            value['isAvailable'] ??
            value['type'],
      ),
      startAt: startAt,
      endAt: endAt,
    )) {
      return true;
    }

    return value.values.any(
      (entry) => _availabilityResponseHasActiveOverlap(
        entry,
        startAt: startAt,
        endAt: endAt,
      ),
    );
  }

  bool _availabilityRangeOverlapsPeriod(
    Map<String, dynamic> value, {
    required AvailabilityStatus? fallbackStatus,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final rangeStart = _dateFromApiValue(_rangeStartValue(value));
    final rangeEnd = _dateFromApiValue(_rangeEndValue(value));
    if (rangeStart == null ||
        rangeEnd == null ||
        !rangeStart.isBefore(rangeEnd)) {
      return false;
    }

    final status =
        _availabilityStatusFromApiValue(
          value['statut'] ??
              value['status'] ??
              value['etat'] ??
              value['availability'] ??
              value['disponibilite'] ??
              value['disponible'] ??
              value['estDisponible'] ??
              value['isAvailable'] ??
              value['type'],
        ) ??
        fallbackStatus;
    if (status == AvailabilityStatus.free || status == null) {
      return false;
    }

    final isOpenStartedReservation =
        FleetApiMappers.reservationIsStarted(value) &&
        !FleetApiMappers.reservationIsTerminated(value);
    final effectiveEnd = isOpenStartedReservation && rangeEnd.isBefore(endAt)
        ? endAt
        : _effectiveAvailabilityRangeEnd(
            startAt: rangeStart,
            endAt: rangeEnd,
            status: status,
            reservationValue: value,
          );
    if (!rangeStart.isBefore(effectiveEnd)) {
      return false;
    }

    return reservationPeriodsOverlap(
      firstStartAt: startAt,
      firstEndAt: endAt,
      secondStartAt: rangeStart,
      secondEndAt: effectiveEnd,
    );
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

  Future<FleetReservation> startImmediateDeparture({
    required Vehicle vehicle,
    required DateTime returnAt,
    DateTime? startedAt,
  }) async {
    final startAt = startedAt ?? DateTime.now();

    if (!startAt.isBefore(returnAt)) {
      throw const ApiException(
        message: 'L’heure de retour doit être après l’heure actuelle.',
      );
    }

    if (vehicle.status != VehicleStatus.available) {
      throw const ApiException(
        message: 'Ce véhicule n’est pas disponible pour un départ immédiat.',
      );
    }

    final available = await isVehicleAvailableForPeriod(
      vehicle: vehicle,
      startAt: startAt,
      endAt: returnAt,
    );

    if (!available) {
      throw const ApiException(
        message: 'Ce véhicule n’est plus disponible sur la période demandée.',
      );
    }

    final reservation = await createReservation(
      vehicle: vehicle,
      startAt: startAt,
      endAt: returnAt,
    );

    try {
      return await startConstat(reservation, confirmedAt: startAt);
    } catch (_) {
      try {
        await deleteReservation(reservation);
      } catch (_) {
        // Le départ immédiat doit rester cohérent côté mobile même si le
        // nettoyage de la réservation échoue côté API.
      }
      rethrow;
    }
  }

  Future<FleetReservation> startConstat(
    FleetReservation reservation, {
    DateTime? confirmedAt,
    ReservationVideoDraft? departureVideo,
  }) async {
    if (reservation.isStarted || reservation.isTerminated) {
      return reservation;
    }

    final datePrise = _pickupTimestampInsideReservation(
      reservation,
      confirmedAt ?? DateTime.now(),
    );

    final response = await _apiClient.postMap(
      '/metier/constats/demarrer',
      body: {
        'reservationId': int.tryParse(reservation.id) ?? reservation.id,
        'vehiculeId':
            int.tryParse(reservation.vehicle.id) ?? reservation.vehicle.id,
        'datePrise': FleetApiMappers.iso(datePrise),
        'kmDebut': reservation.expectedStartMileage,
      },
    );
    final constatId = _constatIdFromStartResponse(response);

    await _markReservationStarted(reservation);

    return reservation.copyWith(
      isStarted: true,
      isTerminated: false,
      constatId: constatId,
    );
  }

  Future<void> finishConstat({
    required FleetReservation reservation,
    required int mileage,
    DateTime? confirmedAt,
  }) async {
    final constatId = _constatIdForReturn(reservation);
    final dateRendu = _returnTimestampInsideReservation(
      reservation,
      confirmedAt ?? DateTime.now(),
    );

    await _apiClient.post(
      '/metier/constats/$constatId/terminer',
      body: {'dateRendu': FleetApiMappers.iso(dateRendu), 'kmFin': mileage},
    );

    await _markReservationTerminated(reservation);
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
    ReservationVideoUpload? video,
  }) async {
    await _apiClient.postMap(
      '/metier/signalements',
      body: {
        'reservationId': int.tryParse(reservation.id) ?? reservation.id,
        'vehiculeId':
            int.tryParse(reservation.vehicle.id) ?? reservation.vehicle.id,
        if (reservation.constatId != null &&
            reservation.constatId!.trim().isNotEmpty)
          'constatId':
              int.tryParse(reservation.constatId!) ?? reservation.constatId!,
        'type': type,
        'description': message,
        'message': message,
        if (video != null) 'video': video.toSignalementPayload(),
      },
    );
  }

  Future<ReservationVideoUpload> uploadReservationVideo(
    ReservationVideoDraft video,
  ) async {
    final fileSize = await video.file.length();
    if (fileSize > ReservationVideoService.maxUploadBytes) {
      throw ReservationVideoTooLargeException(
        actualBytes: fileSize,
        maxBytes: ReservationVideoService.maxUploadBytes,
      );
    }

    final response = await _apiClient.postMultipart(
      _reservationVideoUploadPath,
      fileField: _reservationVideoFileField,
      filePath: video.file.path,
      fields: video.multipartFields,
    );

    return _videoUploadFromResponse(response, video, fileSize: fileSize);
  }

  ReservationVideoUpload _videoUploadFromResponse(
    Object? response,
    ReservationVideoDraft video, {
    required int fileSize,
  }) {
    final json = _videoResponseMap(response);

    final id = _idFromNestedValue(json['id'] ?? json['videoId'] ?? json['@id']);
    final nomFichier = _textFromApiValue(
      json['nomFichier'] ??
          json['filename'] ??
          json['fileName'] ??
          json['name'] ??
          video.file.name,
    );
    final taille = _textFromApiValue(
      json['taille'] ?? json['size'] ?? json['fileSize'],
    );
    final mimeType = _textFromApiValue(
      json['mimeType'] ?? json['mime_type'] ?? json['contentType'],
    );
    final capturedAt =
        _dateFromApiValue(json['capturedAt'] ?? json['dateCapture']) ??
        video.capturedAt;

    return ReservationVideoUpload(
      kind: video.kind,
      type: _textFromApiValue(json['type']).isEmpty
          ? video.kind.apiValue
          : _textFromApiValue(json['type']),
      description: _textFromApiValue(json['description']).isEmpty
          ? video.description
          : _textFromApiValue(json['description']),
      nomFichier: nomFichier.isEmpty ? p.basename(video.file.path) : nomFichier,
      taille: taille.isEmpty ? fileSize.toString() : taille,
      mimeType: mimeType.isEmpty ? 'video/mp4' : mimeType,
      id: id,
      chemin: _nullableText(json['chemin'] ?? json['path']),
      url: _nullableText(json['url'] ?? json['publicUrl']),
      capturedAt: capturedAt,
    );
  }

  Map<String, dynamic> _videoResponseMap(Object? response) {
    if (response is! Map<String, dynamic>) {
      return const {};
    }

    for (final key in ['video', 'item', 'data', 'result']) {
      final nested = response[key];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
    }

    return response;
  }

  String? _nullableText(Object? value) {
    final text = _textFromApiValue(value);
    return text.isEmpty ? null : text;
  }

  Future<void> _markReservationTerminated(FleetReservation reservation) async {
    await _apiClient.patch(
      '/metier/reservations/${reservation.id}',
      body: {'termine': true, 'demarre': false},
    );
  }

  Future<void> _markReservationStarted(FleetReservation reservation) async {
    await _apiClient.patch(
      '/metier/reservations/${reservation.id}',
      body: {'demarre': true, 'termine': false},
    );
  }

  String _constatIdForReturn(FleetReservation reservation) {
    final constatId = reservation.constatId;
    if (constatId == null || constatId.trim().isEmpty) {
      throw const FormatException(
        'Identifiant du constat absent sur la réservation démarrée.',
      );
    }

    return constatId;
  }

  String? _constatIdFromStartResponse(Map<String, dynamic> response) {
    final directId = _idFromNestedValue(
      response['id'] ??
          response['constatId'] ??
          response['idConstat'] ??
          response['openConstatId'],
    );
    if (directId != null) {
      return directId;
    }

    for (final key in ['constat', 'item', 'data', 'result']) {
      final nested = response[key];
      if (nested is Map<String, dynamic>) {
        final nestedId = _idFromNestedValue(
          nested['id'] ??
              nested['@id'] ??
              nested['constatId'] ??
              nested['idConstat'],
        );
        if (nestedId != null) {
          return nestedId;
        }
      }
    }

    return null;
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

  List<DateTime> _reservationStartTimesFromAvailabilityResponse(
    Object? response,
  ) {
    final startsByTimestamp = <int, DateTime>{};

    void addStart(DateTime start) {
      startsByTimestamp[start.millisecondsSinceEpoch] = start;
    }

    bool isReservationLike(Map<String, dynamic> value) {
      return value.containsKey('id') ||
          value.containsKey('reservationId') ||
          value.containsKey('demarre') ||
          value.containsKey('démarre') ||
          value.containsKey('termine') ||
          value.containsKey('statut') ||
          value.containsKey('status') ||
          value.containsKey('type');
    }

    void collect(Object? value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }

      if (value is! Map<String, dynamic>) {
        return;
      }

      final start = _dateFromApiValue(_rangeStartValue(value));
      final end = _dateFromApiValue(_rangeEndValue(value));
      if (isReservationLike(value) &&
          start != null &&
          end != null &&
          start.isBefore(end) &&
          !FleetApiMappers.reservationIsTerminated(value)) {
        addStart(start);
      }

      for (final key in [
        'items',
        'hydra:member',
        'member',
        'data',
        'results',
        'jours',
        'reservations',
      ]) {
        collect(value[key]);
      }
    }

    collect(response);

    final starts = startsByTimestamp.values.toList()..sort();
    return starts;
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

  String _textFromApiValue(Object? value) {
    return value?.toString().trim() ?? '';
  }

  VehicleAvailabilityMonth _availabilityFromResponse(
    Object? response,
    DateTime month, {
    required String vehicleId,
  }) {
    final availabilityByDay = <int, AvailabilityStatus>{};
    final suggestionsByDay = <int, VehicleAvailabilitySuggestion>{};
    var hasEffectiveReturnAdjustments = false;

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
      );
      final rangeIsTerminated = _availabilityValueIsTerminated(
        reservationValue,
      );
      if (!start.isBefore(effectiveEnd)) {
        if (rangeIsTerminated) {
          hasEffectiveReturnAdjustments = true;
          return true;
        }
        return false;
      }
      if (effectiveEnd.isBefore(end)) {
        hasEffectiveReturnAdjustments = true;
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
            _rangeStartValue(entry) ??
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
                _rangeStartValue(reservation),
                _rangeEndValue(reservation),
                AvailabilityStatus.reserved.name,
                reservationValue: reservation,
              ) ||
              parsedNestedReservationRange;
        }
        if (parsedNestedReservationRange) {
          return;
        }

        if (_rangeStartValue(entry) != null && _rangeEndValue(entry) != null) {
          addRangeStatus(
            _rangeStartValue(entry),
            _rangeEndValue(entry),
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
                  _rangeStartValue(reservation),
                  _rangeEndValue(reservation),
                  AvailabilityStatus.reserved.name,
                  reservationValue: reservation,
                ) ||
                parsedNestedReservationRange;
          }
          if (parsedNestedReservationRange) {
            continue;
          }

          if (_rangeStartValue(value) != null &&
              _rangeEndValue(value) != null) {
            addRangeStatus(
              _rangeStartValue(value),
              _rangeEndValue(value),
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
        hasEffectiveReturnAdjustments: hasEffectiveReturnAdjustments,
      );
    }

    if (response is! Map<String, dynamic>) {
      return VehicleAvailabilityMonth(
        availabilityByDay: availabilityByDay,
        suggestionsByDay: suggestionsByDay,
        hasEffectiveReturnAdjustments: hasEffectiveReturnAdjustments,
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
      hasEffectiveReturnAdjustments: hasEffectiveReturnAdjustments,
    );
  }

  DateTime _effectiveAvailabilityRangeEnd({
    required DateTime startAt,
    required DateTime endAt,
    required AvailabilityStatus status,
    required Object? reservationValue,
  }) {
    if (status != AvailabilityStatus.reserved) {
      return endAt;
    }

    final returnedAt = _closedReturnedAtForAvailabilityRange(
      startAt: startAt,
      endAt: endAt,
      reservationValue: reservationValue,
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
  }) {
    return _returnedAtFromAvailabilityValue(
      reservationValue,
      startAt: startAt,
      endAt: endAt,
    );
  }

  DateTime? _returnedAtFromAvailabilityValue(
    Object? value, {
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    if (!FleetApiMappers.reservationIsTerminated(value)) {
      return null;
    }

    final returnedAt = FleetApiMappers.reservationReturnedAt(value);
    if (returnedAt != null) {
      return returnedAt;
    }

    return startAt;
  }

  bool _availabilityValueIsTerminated(Object? value) {
    return value is Map<String, dynamic> &&
        FleetApiMappers.reservationIsTerminated(value);
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
        if (reservation.isTerminated || !reservation.isStarted) {
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

  Object? _rangeStartValue(Map<String, dynamic> value) {
    return value['dateDebutPrevue'] ??
        value['date_debut_prevue'] ??
        value['dateDebut'] ??
        value['date_debut'] ??
        value['startAt'] ??
        value['start_at'];
  }

  Object? _rangeEndValue(Map<String, dynamic> value) {
    return value['dateFinPrevue'] ??
        value['date_fin_prevue'] ??
        value['dateFin'] ??
        value['date_fin'] ??
        value['endAt'] ??
        value['end_at'];
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

    if (status.contains('maintenance') ||
        status.contains('immobilisation') ||
        status.contains('garage')) {
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
