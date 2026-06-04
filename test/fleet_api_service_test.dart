import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/services/api_client.dart';
import 'package:mobile_habitat_insertion/services/fleet_api_mappers.dart';
import 'package:mobile_habitat_insertion/services/fleet_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startConstat sends reservation start when confirmed after end',
    () async {
      Map<String, dynamic>? sentBody;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return _emptyConstatsResponse();
        }

        expect(request.method, 'POST');
        expect(request.url.path, '/api/metier/constats/demarrer');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(sentBody?['datePrise'], FleetApiMappers.iso(reservation.startAt));
    },
  );

  test(
    'startConstat sends reservation start when confirmed too early',
    () async {
      Map<String, dynamic>? sentBody;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return _emptyConstatsResponse();
        }

        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8),
      );

      expect(sentBody?['datePrise'], FleetApiMappers.iso(reservation.startAt));
    },
  );

  test(
    'startConstat sends confirmation time when it is inside period',
    () async {
      Map<String, dynamic>? sentBody;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return _emptyConstatsResponse();
        }

        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );
      final confirmedAt = DateTime(2026, 6, 18, 8, 35);

      await service.startConstat(reservation, confirmedAt: confirmedAt);

      expect(sentBody?['datePrise'], FleetApiMappers.iso(confirmedAt));
    },
  );

  test(
    'startConstat does not create another constat when one already exists',
    () async {
      var startRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'estOuvert': true,
                  'reservation': {'id': 10},
                  'vehicule': {'id': 1},
                  'datePrise': '2026-06-18T08:30:00Z',
                },
              ],
            }),
            200,
          );
        }

        startRequests++;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(startRequests, 0);
    },
  );

  test(
    'startConstat does not create another constat after final mileage exists',
    () async {
      var startRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'reservation': {'id': 10},
                  'vehicule': {'id': 1},
                  'kmFin': 120,
                },
              ],
            }),
            200,
          );
        }

        startRequests++;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(startRequests, 0);
    },
  );

  test(
    'startConstat ignores unrelated closed vehicle constats without reservation id',
    () async {
      var startRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'vehicule': {'id': 1},
                  'kmFin': 120,
                },
              ],
            }),
            200,
          );
        }

        startRequests++;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(startRequests, 1);
    },
  );

  test(
    'finishConstat sends a return date inside period when confirmed late',
    () async {
      Map<String, dynamic>? sentBody;
      Map<String, dynamic>? statusBody;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'estOuvert': true,
                  'vehicule': {'id': 1},
                },
              ],
            }),
            200,
          );
        }

        if (request.method == 'POST') {
          expect(request.url.path, '/api/metier/constats/99/terminer');
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }

        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/metier/reservations/10');
        statusBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.finishConstat(
        reservation: reservation,
        mileage: 120,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(
        sentBody?['dateRendu'],
        FleetApiMappers.iso(DateTime(2026, 6, 18, 8, 39, 59)),
      );
      expect(statusBody, {'statue': 'terminé'});
    },
  );

  test(
    'finishConstat succeeds when status patch is rejected after return post',
    () async {
      var returnRequests = 0;
      var statusRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'estOuvert': true,
                  'vehicule': {'id': 1},
                },
              ],
            }),
            200,
          );
        }

        if (request.method == 'POST') {
          returnRequests++;
          return http.Response('', 204);
        }

        if (request.method == 'PATCH') {
          statusRequests++;
          return http.Response('{"detail":"Forbidden"}', 403);
        }

        return http.Response('{}', 404);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
      );

      await service.finishConstat(
        reservation: reservation,
        mileage: 120,
        confirmedAt: DateTime(2026, 6, 18, 8, 39),
      );

      expect(returnRequests, 1);
      expect(statusRequests, 6);
    },
  );

  test(
    'fetchReservations detects closed constat without moving reservation to history',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'reservee',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'estOuvert': false,
                  'reservation': {'id': 10},
                  'vehicule': {'id': 1},
                  'dateRendu': endAt
                      .subtract(const Duration(seconds: 1))
                      .toIso8601String(),
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.hasClosedConstat, isTrue);
      expect(reservations.single.isInHistory, isFalse);
    },
  );

  test(
    'fetchReservations moves reservation to history when status is termine',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'terminé',
                  statusField: 'statue',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return _emptyConstatsResponse();
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.status, ReservationStatus.completed);
      expect(reservations.single.isInHistory, isTrue);
      expect(
        reservations.single.shouldShowDepartureActionAt(DateTime.now()),
        isFalse,
      );
    },
  );

  test('fetchReservations detects open constat from constat status', () async {
    final startAt = DateTime.now().subtract(const Duration(minutes: 30));
    final endAt = DateTime.now().add(const Duration(minutes: 30));
    final service = _serviceWithMockClient((request) async {
      if (request.url.path == '/api/metier/mes-reservations') {
        return http.Response(
          jsonEncode({
            'items': [
              _reservationJson(
                id: 10,
                startAt: startAt,
                endAt: endAt,
                status: 'reservee',
              ),
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/mes-constats') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 99,
                'statut': 'en_cours',
                'reservation': {'id': 10},
                'vehicule': {'id': 1},
                'datePrise': startAt.toIso8601String(),
              },
            ],
          }),
          200,
        );
      }

      return http.Response('{}', 404);
    });

    final reservations = await service.fetchReservations();

    expect(reservations.single.hasOpenConstat, isTrue);
    expect(
      reservations.single.shouldShowReturnActionAt(DateTime.now()),
      isTrue,
    );
  });

  test(
    'fetchReservations keeps completed status in history with stale open constat',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'termine',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'estOuvert': true,
                  'reservation': {'id': 10},
                  'vehicule': {'id': 1},
                  'datePrise': startAt.toIso8601String(),
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.hasOpenConstat, isTrue);
      expect(reservations.single.isInHistory, isTrue);
      expect(
        reservations.single.shouldShowReturnActionAt(DateTime.now()),
        isFalse,
      );
    },
  );

  test(
    'fetchReservations moves reservation to history when statut is termine',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'termine',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return _emptyConstatsResponse();
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.status, ReservationStatus.completed);
      expect(reservations.single.isInHistory, isTrue);
    },
  );

  test(
    'fetchReservations detects final mileage without moving reservation to history',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'reservee',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'reservation': {'id': 10},
                  'vehicule': {'id': 1},
                  'kmFin': 120,
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.hasClosedConstat, isTrue);
      expect(reservations.single.isInHistory, isFalse);
    },
  );

  test(
    'fetchReservations matches vehicle final mileage when return date is missing',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'reservee',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'vehicule': {'id': 1},
                  'kmFin': 120,
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.hasClosedConstat, isTrue);
      expect(reservations.single.isInHistory, isFalse);
    },
  );

  test(
    'fetchReservations matches closed vehicle constat by return date when reservation id is missing',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'reservee',
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 99,
                  'estOuvert': false,
                  'vehicule': {'id': 1},
                  'dateRendu': endAt
                      .subtract(const Duration(seconds: 1))
                      .toIso8601String(),
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final reservations = await service.fetchReservations();

      expect(reservations.single.hasClosedConstat, isTrue);
      expect(reservations.single.isInHistory, isFalse);
    },
  );

  test('createReservation sends selected vehicle and period to API', () async {
    Map<String, dynamic>? sentBody;
    final startAt = DateTime(2026, 6, 18, 8, 30);
    final endAt = DateTime(2026, 6, 18, 17);
    final service = _serviceWithMockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/metier/reservations');
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(_reservationJson(id: 99, startAt: startAt, endAt: endAt)),
        200,
      );
    });

    final reservation = await service.createReservation(
      vehicle: _vehicle,
      startAt: startAt,
      endAt: endAt,
    );

    expect(sentBody, {
      'vehiculeId': 1,
      'dateDebut': FleetApiMappers.iso(startAt),
      'dateFin': FleetApiMappers.iso(endAt),
      'type': 'reservation',
    });
    expect(reservation.id, '99');
  });

  test('updateReservation patches the existing reservation period', () async {
    Map<String, dynamic>? sentBody;
    final startAt = DateTime(2026, 6, 19, 9);
    final endAt = DateTime(2026, 6, 19, 18);
    final service = _serviceWithMockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/metier/reservations/10');
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(_reservationJson(id: 10, startAt: startAt, endAt: endAt)),
        200,
      );
    });

    final reservation = await service.updateReservation(
      reservation: _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 17),
      ),
      startAt: startAt,
      endAt: endAt,
    );

    expect(sentBody?['vehiculeId'], 1);
    expect(sentBody?['dateDebut'], FleetApiMappers.iso(startAt));
    expect(sentBody?['dateFin'], FleetApiMappers.iso(endAt));
    expect(reservation.startAt, startAt);
  });

  test('deleteReservation calls the reservation endpoint', () async {
    var deleteRequests = 0;
    final service = _serviceWithMockClient((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/metier/reservations/10');
      deleteRequests++;
      return http.Response('', 204);
    });

    await service.deleteReservation(
      _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 17),
      ),
    );

    expect(deleteRequests, 1);
  });

  test(
    'isVehicleAvailableForPeriod allows a vehicle after a same-day return',
    () async {
      final startAt = DateTime(2026, 6, 4, 11);
      final endAt = DateTime(2026, 6, 4, 18);
      final service = _serviceWithMockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/metier/vehicules-disponibles');
        expect(
          DateTime.parse(request.url.queryParameters['dateDebut']!).toLocal(),
          startAt,
        );
        expect(
          DateTime.parse(request.url.queryParameters['dateFin']!).toLocal(),
          endAt,
        );
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 1, 'marque': 'Renault', 'modele': 'Clio'},
            ],
          }),
          200,
        );
      });

      expect(
        await service.isVehicleAvailableForPeriod(
          vehicle: _vehicle,
          startAt: startAt,
          endAt: endAt,
        ),
        isTrue,
      );
    },
  );

  test(
    'isVehicleAvailableForPeriod blocks exact unavailable periods',
    () async {
      final service = _serviceWithMockClient((request) async {
        expect(request.url.path, '/api/metier/vehicules-disponibles');
        return http.Response(jsonEncode({'items': []}), 200);
      });

      expect(
        await service.isVehicleAvailableForPeriod(
          vehicle: _vehicle,
          startAt: DateTime(2026, 6, 4, 8, 30),
          endAt: DateTime(2026, 6, 4, 12),
        ),
        isFalse,
      );
    },
  );

  test(
    'isVehicleAvailableForPeriod reads nested and IRI vehicle ids',
    () async {
      var requestCount = 0;
      final service = _serviceWithMockClient((request) async {
        requestCount++;
        expect(request.url.path, '/api/metier/vehicules-disponibles');
        return http.Response(
          jsonEncode({
            'items': [
              {
                '@id': '/api/metier/vehicules/99',
                'vehicule': {'@id': '/api/metier/vehicules/1'},
              },
            ],
          }),
          200,
        );
      });

      expect(
        await service.isVehicleAvailableForPeriod(
          vehicle: _vehicle,
          startAt: DateTime(2026, 6, 4, 11),
          endAt: DateTime(2026, 6, 4, 18),
        ),
        isTrue,
      );
      expect(requestCount, 1);
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth maps API statuses by day and range',
    () async {
      var fallbackRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          expect(request.url.queryParameters['mois'], '2026-06');
          return http.Response(
            jsonEncode({
              'items': [
                {'jour': 18, 'statut': 'libre'},
                {'jour': 19, 'statut': 'réservé'},
                {
                  'dateDebut': '2026-06-20T08:00:00Z',
                  'dateFin': '2026-06-22T18:00:00Z',
                  'statut': 'maintenance',
                },
                {'jour': 23, 'disponible': true},
                {'jour': 24, 'disponible': false},
              ],
            }),
            200,
          );
        }

        fallbackRequests++;
        return http.Response('{}', 404);
      });

      final availability = await service.fetchVehicleAvailabilityForMonth(
        vehicle: _vehicle,
        month: DateTime(2026, 6),
      );

      expect(availability[18], AvailabilityStatus.free);
      expect(availability[19], AvailabilityStatus.reserved);
      expect(availability[20], AvailabilityStatus.maintenance);
      expect(availability[21], AvailabilityStatus.maintenance);
      expect(availability[22], AvailabilityStatus.maintenance);
      expect(availability[23], AvailabilityStatus.free);
      expect(availability[24], AvailabilityStatus.reserved);
      expect(fallbackRequests, 0);
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth marks only one day for same-day reservations',
    () async {
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'dateDebut': '2026-06-04T08:30:00Z',
                  'dateFin': '2026-06-04T18:00:00Z',
                  'statut': 'réservé',
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final availability = await service.fetchVehicleAvailabilityForMonth(
        vehicle: _vehicle,
        month: DateTime(2026, 6),
      );

      expect(availability, hasLength(1));
      expect(availability[4], AvailabilityStatus.partial);
      expect(availability[5], isNull);
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth keeps full-day reservations as reserved',
    () async {
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'dateDebut': '2026-06-04T00:00:00',
                  'dateFin': '2026-06-05T00:00:00',
                  'statut': 'réservé',
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final availability = await service.fetchVehicleAvailabilityForMonth(
        vehicle: _vehicle,
        month: DateTime(2026, 6),
      );

      expect(availability[4], AvailabilityStatus.reserved);
      expect(availability[5], isNull);
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth reads nested reservation ranges as partial boundary days',
    () async {
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-04',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'dateDebut': '2026-06-04T18:00:00',
                      'dateFin': '2026-06-07T10:00:00',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final availability = await service.fetchVehicleAvailabilityForMonth(
        vehicle: _vehicle,
        month: DateTime(2026, 6),
      );

      expect(availability[4], AvailabilityStatus.partial);
      expect(availability[5], AvailabilityStatus.reserved);
      expect(availability[6], AvailabilityStatus.reserved);
      expect(availability[7], AvailabilityStatus.partial);
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth treats empty monthly response as free days',
    () async {
      var unexpectedFallbackRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(jsonEncode({'jours': []}), 200);
        }

        unexpectedFallbackRequests++;
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final availability = await service.fetchVehicleAvailabilityForMonth(
        vehicle: _vehicle,
        month: DateTime(2026, 6),
      );

      expect(unexpectedFallbackRequests, 0);
      expect(availability, isEmpty);
      expect(availability[18], isNull);
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth does not fall back to day checks on 404',
    () async {
      var unexpectedFallbackRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response('{"detail":"not found"}', 404);
        }

        unexpectedFallbackRequests++;
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final availability = await service.fetchVehicleAvailabilityForMonth(
        vehicle: _vehicle,
        month: DateTime(2026, 6),
      );

      expect(unexpectedFallbackRequests, 0);
      expect(availability, isEmpty);
    },
  );

  test('fetchVehicles marks active reservations as vehicles in use', () async {
    final now = DateTime.now();
    final service = _serviceWithMockClient((request) async {
      if (request.url.path == '/api/metier/mes-sites') {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 7, 'nom': 'Site'},
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/sites/7/vehicules') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 1,
                'marque': 'Renault',
                'modele': 'Clio',
                'immatriculation': 'AA-123-AA',
                'sites': [
                  {'nom': 'Site'},
                ],
              },
              {
                'id': 2,
                'marque': 'Peugeot',
                'modele': '208',
                'immatriculation': 'BB-123-BB',
                'sites': [
                  {'nom': 'Site'},
                ],
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/mes-reservations') {
        return http.Response(
          jsonEncode({
            'items': [
              _reservationJson(
                id: 12,
                startAt: now.subtract(const Duration(minutes: 30)),
                endAt: now.add(const Duration(hours: 2)),
                vehicleId: 2,
              ),
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/mes-constats') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 99,
                'estOuvert': true,
                'reservation': {'id': 12},
                'vehicule': {'id': 2},
                'datePrise': now
                    .subtract(const Duration(minutes: 20))
                    .toIso8601String(),
              },
            ],
          }),
          200,
        );
      }

      return http.Response('{}', 404);
    });

    final vehicles = await service.fetchVehicles();

    expect(vehicles.first.id, '2');
    expect(vehicles.first.status, VehicleStatus.inUse);
    expect(vehicles.first.subtitle, startsWith('En usage jusqu’au'));
    expect(vehicles.last.id, '1');
    expect(vehicles.last.status, VehicleStatus.available);
  });

  test('fetchVehicles frees a vehicle after a confirmed return', () async {
    final now = DateTime.now();
    final service = _serviceWithMockClient((request) async {
      if (request.url.path == '/api/metier/mes-sites') {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 7, 'nom': 'Site'},
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/sites/7/vehicules') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 1,
                'marque': 'Renault',
                'modele': 'Clio',
                'immatriculation': 'AA-123-AA',
                'status': 'en_utilisation',
                'sites': [
                  {'nom': 'Site'},
                ],
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/mes-reservations') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                ..._reservationJson(
                  id: 12,
                  startAt: now.subtract(const Duration(hours: 2)),
                  endAt: now.add(const Duration(hours: 2)),
                ),
                'constatFerme': true,
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/api/metier/mes-constats') {
        return _emptyConstatsResponse();
      }

      return http.Response('{}', 404);
    });

    final vehicles = await service.fetchVehicles();

    expect(vehicles.single.status, VehicleStatus.available);
    expect(vehicles.single.subtitle, 'Libre');
  });

  test(
    'fetchVehicles does not keep a vehicle in use when open and closed constats exist',
    () async {
      final now = DateTime.now();
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-sites') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 7, 'nom': 'Site'},
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/sites/7/vehicules') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'marque': 'Renault',
                  'modele': 'Clio',
                  'immatriculation': 'AA-123-AA',
                  'status': 'en_utilisation',
                  'sites': [
                    {'nom': 'Site'},
                  ],
                },
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                _reservationJson(
                  id: 12,
                  startAt: now.subtract(const Duration(hours: 2)),
                  endAt: now.add(const Duration(hours: 2)),
                ),
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 98,
                  'estOuvert': true,
                  'reservation': {'id': 12},
                  'vehicule': {'id': 1},
                  'datePrise': now
                      .subtract(const Duration(hours: 2))
                      .toIso8601String(),
                },
                {
                  'id': 99,
                  'estOuvert': false,
                  'reservation': {'id': 12},
                  'vehicule': {'id': 1},
                  'dateRendu': now.toIso8601String(),
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final vehicles = await service.fetchVehicles();

      expect(vehicles.single.status, VehicleStatus.available);
      expect(vehicles.single.subtitle, 'Libre');
    },
  );
}

http.Response _emptyConstatsResponse() {
  return http.Response(jsonEncode({'items': []}), 200);
}

FleetApiService _serviceWithMockClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return FleetApiService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      baseUri: Uri.parse('https://example.test/api'),
    ),
  );
}

FleetReservation _reservation({
  required DateTime startAt,
  required DateTime endAt,
}) {
  return FleetReservation(
    id: '10',
    vehicle: _vehicle,
    location: 'Site',
    startAt: startAt,
    endAt: endAt,
    startLabel: 'Départ',
    endLabel: 'Retour',
    status: ReservationStatus.upcoming,
    expectedStartMileage: 100,
  );
}

final _vehicle = Vehicle(
  id: '1',
  internalNumber: 'V-001',
  name: 'Renault Clio',
  brand: 'Renault',
  model: 'Clio',
  plateNumber: 'AA-123-AA',
  category: 'Flotte',
  status: VehicleStatus.available,
  subtitle: 'Libre',
  imageUrl: '',
  location: 'Site',
  site: 'Site',
  parkingDescription: 'Parking',
  seats: '5',
  transmission: 'Manuelle',
  energyType: VehicleEnergyType.thermal,
  energyInfo: 'Thermique',
  currentMileage: 100,
  fuelLevelLabel: '50%',
  priorityRank: 1,
  nextAvailableAt: DateTime(2026, 6, 18),
  availabilityByDay: const {},
);

Map<String, dynamic> _reservationJson({
  required int id,
  required DateTime startAt,
  required DateTime endAt,
  String status = 'reservee',
  String statusField = 'statut',
  int vehicleId = 1,
}) {
  return {
    'id': id,
    'dateDebut': startAt.toIso8601String(),
    'dateFin': endAt.toIso8601String(),
    statusField: status,
    'vehicule': {
      'id': vehicleId,
      'marque': 'Renault',
      'modele': 'Clio',
      'immatriculation': 'AA-123-AA',
    },
  };
}
