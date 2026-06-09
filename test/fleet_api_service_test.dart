import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/services/api_client.dart';
import 'package:mobile_habitat_insertion/services/api_exception.dart';
import 'package:mobile_habitat_insertion/services/auth_session_service.dart';
import 'package:mobile_habitat_insertion/services/fleet_api_mappers.dart';
import 'package:mobile_habitat_insertion/services/fleet_api_service.dart';
import 'package:mobile_habitat_insertion/services/reservation_video_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startConstat sends reservation start when confirmed after end',
    () async {
      Map<String, dynamic>? sentBody;
      Map<String, dynamic>? statusBody;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return _emptyConstatsResponse();
        }

        if (request.method == 'PATCH') {
          expect(request.url.path, '/api/metier/reservations/10');
          statusBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
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
      expect(statusBody, {'demarre': true, 'termine': false});
    },
  );

  test('startConstat keeps the created constat id for return', () async {
    final service = _serviceWithMockClient((request) async {
      if (request.method == 'PATCH') {
        return http.Response('{}', 200);
      }

      expect(request.method, 'POST');
      expect(request.url.path, '/api/metier/constats/demarrer');
      return http.Response(jsonEncode({'id': 99, 'reservationId': 10}), 201);
    });
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 8, 30),
      endAt: DateTime(2026, 6, 18, 8, 40),
    );

    final startedReservation = await service.startConstat(reservation);

    expect(startedReservation.isStarted, isTrue);
    expect(startedReservation.constatId, '99');
  });

  test(
    'startConstat sends reservation start when confirmed too early',
    () async {
      Map<String, dynamic>? sentBody;
      final service = _serviceWithMockClient((request) async {
        if (request.method == 'GET') {
          return _emptyConstatsResponse();
        }

        if (request.method == 'PATCH') {
          return http.Response('{}', 200);
        }

        expect(request.method, 'POST');
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

        if (request.method == 'PATCH') {
          return http.Response('{}', 200);
        }

        expect(request.method, 'POST');
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
    'startConstat does not create another constat when demarre is true',
    () async {
      var startRequests = 0;
      final service = _serviceWithMockClient((request) async {
        startRequests++;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
        isStarted: true,
        constatId: '99',
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(startRequests, 0);
    },
  );

  test(
    'startConstat does not create another constat when termine is true',
    () async {
      var startRequests = 0;
      final service = _serviceWithMockClient((request) async {
        startRequests++;
        return http.Response('{}', 200);
      });
      final reservation = _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 8, 40),
        isTerminated: true,
      );

      await service.startConstat(
        reservation,
        confirmedAt: DateTime(2026, 6, 18, 8, 47),
      );

      expect(startRequests, 0);
    },
  );

  test(
    'startConstat starts an unstarted reservation without constat lookup',
    () async {
      var startRequests = 0;
      var statusRequests = 0;
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

        if (request.method == 'POST') {
          startRequests++;
        }
        if (request.method == 'PATCH') {
          statusRequests++;
        }
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
      expect(statusRequests, 1);
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
        isStarted: true,
        constatId: '99',
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
      expect(statusBody, {'termine': true, 'demarre': false});
    },
  );

  test(
    'finishConstat fails when the termine patch is rejected after return post',
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
        isStarted: true,
        constatId: '99',
      );

      await expectLater(
        service.finishConstat(
          reservation: reservation,
          mileage: 120,
          confirmedAt: DateTime(2026, 6, 18, 8, 39),
        ),
        throwsA(isA<ApiException>()),
      );

      expect(returnRequests, 1);
      expect(statusRequests, 1);
    },
  );

  test('uploadReservationVideo sends a multipart video request', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'wheello_video_upload_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final videoFile = File('${tempDir.path}/depart.mp4');
    await videoFile.writeAsBytes([0, 1, 2, 3, 4]);

    String? sentBody;
    final service = _serviceWithMockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/metier/videos');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      sentBody = request.body;
      return http.Response(
        jsonEncode({
          'id': 45,
          'nomFichier': 'depart-stocke.mp4',
          'taille': '5',
          'mimeType': 'video/mp4',
          'type': 'depart',
          'description': 'Vidéo de départ',
        }),
        201,
      );
    });
    final capturedAt = DateTime(2026, 6, 18, 8, 35);

    final upload = await service.uploadReservationVideo(
      ReservationVideoDraft(
        reservationId: '10',
        kind: ReservationVideoKind.departure,
        file: XFile(videoFile.path),
        capturedAt: capturedAt,
        description: 'Vidéo de départ',
      ),
    );

    expect(sentBody, contains('name="reservationId"'));
    expect(sentBody, contains('10'));
    expect(sentBody, contains('name="type"'));
    expect(sentBody, contains('depart'));
    expect(sentBody, contains('name="description"'));
    expect(sentBody, contains('Vidéo de départ'));
    expect(sentBody, contains('name="capturedAt"'));
    expect(sentBody, contains(capturedAt.toIso8601String()));
    expect(sentBody, contains('name="video"; filename="depart.mp4"'));
    expect(upload.toConstatPayload(), {
      'nomFichier': 'depart-stocke.mp4',
      'taille': '5',
      'mimeType': 'video/mp4',
      'type': 'depart',
      'description': 'Vidéo de départ',
    });
  });

  test(
    'uploadReservationVideo rejects oversized videos before request',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'wheello_large_video_upload_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final videoFile = File('${tempDir.path}/large.mp4');
      final largeVideo = await videoFile.open(mode: FileMode.write);
      await largeVideo.truncate(ReservationVideoService.maxUploadBytes + 1);
      await largeVideo.close();

      var requests = 0;
      final service = _serviceWithMockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      });

      await expectLater(
        service.uploadReservationVideo(
          ReservationVideoDraft(
            reservationId: '10',
            kind: ReservationVideoKind.departure,
            file: XFile(videoFile.path),
            capturedAt: DateTime(2026, 6, 18, 8, 35),
            description: 'Vidéo trop lourde',
          ),
        ),
        throwsA(isA<ReservationVideoTooLargeException>()),
      );
      expect(requests, 0);
    },
  );

  test('createSignalement sends uploaded video metadata', () async {
    Map<String, dynamic>? sentBody;
    final service = _serviceWithMockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/metier/signalements');
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 201);
    });

    await service.createSignalement(
      reservation: _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 17),
      ),
      type: 'Problème véhicule',
      message: 'Rayure sur la porte.',
      video: const ReservationVideoUpload(
        kind: ReservationVideoKind.departure,
        type: 'depart',
        description: 'Rayure sur la porte.',
        nomFichier: 'signalement.mp4',
        taille: '2048',
        mimeType: 'video/mp4',
      ),
    );

    expect(sentBody, {
      'vehiculeId': 1,
      'type': 'Problème véhicule',
      'message': 'Rayure sur la porte.',
      'video': {
        'nomFichier': 'signalement.mp4',
        'taille': '2048',
        'mimeType': 'video/mp4',
        'type': 'depart',
        'description': 'Rayure sur la porte.',
        'context': 'depart',
      },
    });
  });

  test('createSignalement refreshes expired JWT and retries once', () async {
    FlutterSecureStorage.setMockInitialValues({
      AuthSessionService.tokenKey: 'expired-token',
      AuthSessionService.userIdKey: '10',
      AuthSessionService.userEmailKey: 'g@g.c',
      AuthSessionService.firstNameKey: 'G',
      AuthSessionService.lastNameKey: 'C',
      AuthSessionService.roleKey: 'user',
      AuthSessionService.poleKey: 'Site',
    });

    final calls = <String>[];
    Map<String, dynamic>? sentBody;
    final service = _serviceWithMockClient((request) async {
      calls.add('${request.method} ${request.url.path}');

      if (request.url.path == '/api/metier/signalements' && calls.length == 1) {
        expect(request.headers['authorization'], 'Bearer expired-token');
        return http.Response(jsonEncode({'message': 'Expired JWT Token'}), 401);
      }

      if (request.url.path == '/api/mobile/session') {
        expect(jsonDecode(request.body), {'identifier': 'g@g.c'});
        return http.Response(
          jsonEncode({
            'token': 'fresh-token',
            'user': {
              'id': 10,
              'email': 'g@g.c',
              'prenom': 'G',
              'nom': 'C',
              'roles': ['ROLE_USER'],
              'pole': 'Site',
            },
          }),
          200,
        );
      }

      expect(request.url.path, '/api/metier/signalements');
      expect(request.headers['authorization'], 'Bearer fresh-token');
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 201);
    });

    await service.createSignalement(
      reservation: _reservation(
        startAt: DateTime(2026, 6, 18, 8, 30),
        endAt: DateTime(2026, 6, 18, 17),
      ),
      type: 'Problème véhicule',
      message: 'Voyant moteur allumé.',
    );

    expect(calls, [
      'POST /api/metier/signalements',
      'POST /api/mobile/session',
      'POST /api/metier/signalements',
    ]);
    expect(sentBody?['message'], 'Voyant moteur allumé.');
  });

  test('startConstat uploads departure video into depart payload', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'wheello_departure_video_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final videoFile = File('${tempDir.path}/depart.mp4');
    await videoFile.writeAsBytes([0, 1, 2, 3, 4]);

    String? uploadBody;
    Map<String, dynamic>? startBody;
    Map<String, dynamic>? statusBody;
    final service = _serviceWithMockClient((request) async {
      if (request.method == 'GET') {
        return _emptyConstatsResponse();
      }

      if (request.url.path == '/api/metier/videos') {
        uploadBody = request.body;
        return http.Response(
          jsonEncode({
            'id': 33,
            'nomFichier': 'depart-stocke.mp4',
            'taille': '5',
            'type': 'depart',
            'description': 'État départ OK',
          }),
          201,
        );
      }

      if (request.method == 'PATCH') {
        expect(request.url.path, '/api/metier/reservations/10');
        statusBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }

      expect(request.method, 'POST');
      expect(request.url.path, '/api/metier/constats/demarrer');
      startBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 8, 30),
      endAt: DateTime(2026, 6, 18, 17),
    );

    await service.startConstat(
      reservation,
      departureVideo: ReservationVideoDraft(
        reservationId: reservation.id,
        kind: ReservationVideoKind.departure,
        file: XFile(videoFile.path),
        capturedAt: DateTime(2026, 6, 18, 8, 25),
        description: 'État départ OK',
      ),
    );

    expect(uploadBody, contains('name="type"'));
    expect(uploadBody, contains('depart'));
    expect(uploadBody, contains('État départ OK'));
    expect(startBody?['depart'], {
      'nomFichier': 'depart-stocke.mp4',
      'taille': '5',
      'mimeType': 'video/mp4',
      'type': 'depart',
      'description': 'État départ OK',
    });
    expect(statusBody, {'demarre': true, 'termine': false});
  });

  test('finishConstat sends return without uploading video', () async {
    Map<String, dynamic>? returnBody;
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

      if (request.url.path == '/api/metier/videos') {
        fail('A return should not upload a video.');
      }

      if (request.url.path == '/api/metier/constats/99/terminer') {
        returnBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      }

      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/metier/reservations/10');
      statusBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });
    final reservation = _reservation(
      startAt: DateTime(2026, 6, 18, 8, 30),
      endAt: DateTime(2026, 6, 18, 17),
      isStarted: true,
      constatId: '99',
    );

    await service.finishConstat(
      reservation: reservation,
      mileage: 120,
      confirmedAt: DateTime(2026, 6, 18, 16, 30),
    );

    expect(returnBody?['arrive'], {
      'nomFichier': 'video-non-requise',
      'taille': '0',
      'type': 'arrive',
      'description': 'Aucune vidéo transmise depuis l’application mobile.',
    });
    expect(statusBody, {'termine': true, 'demarre': false});
  });

  test(
    'fetchReservations uses termine and dateRendu from reservation',
    () async {
      final startAt = DateTime.now().subtract(const Duration(hours: 2));
      final endAt = DateTime.now().subtract(const Duration(hours: 1));
      final returnedAt = endAt.subtract(const Duration(seconds: 1));
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/mes-reservations') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  ..._reservationJson(
                    id: 10,
                    startAt: startAt,
                    endAt: endAt,
                    status: 'reservee',
                  ),
                  'termine': true,
                  'dateRendu': returnedAt.toIso8601String(),
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
      expect(reservations.single.isInHistory, isTrue);
      expect(reservations.single.returnedAt, returnedAt);
      expect(reservations.single.effectiveEndAt, returnedAt);
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

  test('fetchReservations detects started reservation from demarre', () async {
    final startAt = DateTime.now().subtract(const Duration(minutes: 30));
    final endAt = DateTime.now().add(const Duration(minutes: 30));
    final service = _serviceWithMockClient((request) async {
      if (request.url.path == '/api/metier/mes-reservations') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                ..._reservationJson(
                  id: 10,
                  startAt: startAt,
                  endAt: endAt,
                  status: 'reservee',
                ),
                'demarre': true,
                'constatId': 99,
              },
            ],
          }),
          200,
        );
      }

      return http.Response('{}', 404);
    });

    final reservations = await service.fetchReservations();

    expect(reservations.single.isStarted, isTrue);
    expect(reservations.single.constatId, '99');
    expect(reservations.single.hasOpenConstat, isTrue);
    expect(
      reservations.single.shouldShowReturnActionAt(DateTime.now()),
      isTrue,
    );
  });

  test('fetchReservations lets termine win over stale open constat', () async {
    final startAt = DateTime.now().subtract(const Duration(hours: 2));
    final endAt = DateTime.now().subtract(const Duration(hours: 1));
    final service = _serviceWithMockClient((request) async {
      if (request.url.path == '/api/metier/mes-reservations') {
        return http.Response(
          jsonEncode({
            'items': [
              {
                ..._reservationJson(id: 10, startAt: startAt, endAt: endAt),
                'termine': true,
              },
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

    expect(reservations.single.hasOpenConstat, isFalse);
    expect(reservations.single.hasClosedConstat, isTrue);
    expect(reservations.single.isInHistory, isTrue);
    expect(
      reservations.single.shouldShowReturnActionAt(DateTime.now()),
      isFalse,
    );
  });

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

  test('fetchReservations ignores final mileage constats', () async {
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

    expect(reservations.single.hasClosedConstat, isFalse);
    expect(reservations.single.isInHistory, isFalse);
  });

  test(
    'fetchReservations ignores vehicle final mileage without termine',
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

      expect(reservations.single.hasClosedConstat, isFalse);
      expect(reservations.single.isInHistory, isFalse);
    },
  );

  test(
    'fetchReservations ignores closed vehicle constat when reservation has no termine',
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

      expect(reservations.single.hasClosedConstat, isFalse);
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
        if (request.url.path == '/api/metier/vehicules-disponibles') {
          return http.Response(jsonEncode({'items': []}), 200);
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return _emptyConstatsResponse();
        }

        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-04',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'id': 10,
                      'dateDebut': '2026-06-04T08:30:00',
                      'dateFin': '2026-06-04T12:00:00',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }

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

      final availability = await service
          .fetchVehicleAvailabilityDetailsForMonth(
            vehicle: _vehicle,
            month: DateTime(2026, 6),
          );

      expect(availability.availabilityByDay[4], AvailabilityStatus.partial);
      expect(availability.availabilityByDay[5], AvailabilityStatus.reserved);
      expect(availability.availabilityByDay[6], AvailabilityStatus.reserved);
      expect(availability.availabilityByDay[7], AvailabilityStatus.partial);
      expect(
        availability.suggestionsByDay[4]?.latestEndAt,
        DateTime(2026, 6, 4, 17),
      );
      expect(
        availability.suggestionsByDay[7]?.earliestStartAt,
        DateTime(2026, 6, 7, 11),
      );
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth truncates a closed reservation at actual return',
    () async {
      final returnedAt = DateTime(2026, 6, 5, 10, 30);
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-05',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'id': 10,
                      'dateDebut': '2026-06-05T10:00:00',
                      'dateFin': '2026-06-07T10:00:00',
                      'termine': true,
                      'dateRendu': returnedAt.toIso8601String(),
                    },
                  ],
                },
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
                  'dateRendu': returnedAt.toIso8601String(),
                },
              ],
            }),
            200,
          );
        }

        return http.Response('{}', 404);
      });

      final availability = await service
          .fetchVehicleAvailabilityDetailsForMonth(
            vehicle: _vehicle,
            month: DateTime(2026, 6),
          );

      expect(availability.availabilityByDay[5], AvailabilityStatus.partial);
      expect(availability.availabilityByDay[6], isNull);
      expect(availability.availabilityByDay[7], isNull);
      expect(
        availability.suggestionsByDay[5]?.earliestStartAt,
        DateTime(2026, 6, 5, 11, 30),
      );
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth truncates reservation using direct return date',
    () async {
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-06',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'id': 10,
                      'dateDebut': '2026-06-06T10:00:00',
                      'dateFin': '2026-06-11T10:00:00',
                      'termine': true,
                      'dateRendu': '2026-06-07T10:30:00',
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

      final availability = await service
          .fetchVehicleAvailabilityDetailsForMonth(
            vehicle: _vehicle,
            month: DateTime(2026, 6),
          );

      expect(availability.availabilityByDay[6], AvailabilityStatus.partial);
      expect(availability.availabilityByDay[7], AvailabilityStatus.partial);
      expect(availability.availabilityByDay[8], isNull);
      expect(availability.availabilityByDay[9], isNull);
      expect(availability.availabilityByDay[10], isNull);
      expect(availability.availabilityByDay[11], isNull);
      expect(availability.hasEffectiveReturnAdjustments, isTrue);
      expect(
        availability.suggestionsByDay[7]?.earliestStartAt,
        DateTime(2026, 6, 7, 11, 30),
      );
    },
  );

  test(
    'fetchVehicleAvailabilityForMonth frees a termine reservation without constat lookup',
    () async {
      var constatsRequests = 0;
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-06',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'id': 10,
                      'dateDebut': '2026-06-06T10:00:00',
                      'dateFin': '2026-06-11T10:00:00',
                      'termine': true,
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/mes-constats') {
          constatsRequests++;
          return _emptyConstatsResponse();
        }

        return http.Response('{}', 404);
      });

      final availability = await service
          .fetchVehicleAvailabilityDetailsForMonth(
            vehicle: _vehicle,
            month: DateTime(2026, 6),
          );

      expect(constatsRequests, 0);
      expect(availability.availabilityByDay[6], isNull);
      expect(availability.availabilityByDay[7], isNull);
      expect(availability.availabilityByDay[8], isNull);
      expect(availability.availabilityByDay[9], isNull);
      expect(availability.availabilityByDay[10], isNull);
      expect(availability.availabilityByDay[11], isNull);
      expect(availability.hasEffectiveReturnAdjustments, isTrue);
    },
  );

  test(
    'isVehicleAvailableForPeriod allows a period after direct early return',
    () async {
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules-disponibles') {
          return http.Response(jsonEncode({'items': []}), 200);
        }

        if (request.url.path == '/api/metier/mes-constats') {
          return _emptyConstatsResponse();
        }

        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-06',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'id': 10,
                      'dateDebut': '2026-06-06T10:00:00',
                      'dateFin': '2026-06-11T10:00:00',
                      'termine': true,
                      'dateRendu': '2026-06-07T10:30:00',
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

      expect(
        await service.isVehicleAvailableForPeriod(
          vehicle: _vehicle,
          startAt: DateTime(2026, 6, 8, 9),
          endAt: DateTime(2026, 6, 8, 18),
        ),
        isTrue,
      );
    },
  );

  test(
    'isVehicleAvailableForPeriod allows a period after an early confirmed return',
    () async {
      final returnedAt = DateTime(2026, 6, 5, 10, 30);
      final service = _serviceWithMockClient((request) async {
        if (request.url.path == '/api/metier/vehicules-disponibles') {
          return http.Response(jsonEncode({'items': []}), 200);
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
                  'dateRendu': returnedAt.toIso8601String(),
                },
              ],
            }),
            200,
          );
        }

        if (request.url.path == '/api/metier/vehicules/1/disponibilites') {
          return http.Response(
            jsonEncode({
              'jours': [
                {
                  'date': '2026-06-05',
                  'statut': 'réservé',
                  'reservations': [
                    {
                      'id': 10,
                      'dateDebut': '2026-06-05T10:00:00',
                      'dateFin': '2026-06-07T10:00:00',
                      'termine': true,
                      'dateRendu': returnedAt.toIso8601String(),
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

      expect(
        await service.isVehicleAvailableForPeriod(
          vehicle: _vehicle,
          startAt: DateTime(2026, 6, 6, 9),
          endAt: DateTime(2026, 6, 6, 18),
        ),
        isTrue,
      );
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
              {
                ..._reservationJson(
                  id: 12,
                  startAt: now.subtract(const Duration(minutes: 30)),
                  endAt: now.add(const Duration(hours: 2)),
                  vehicleId: 2,
                ),
                'demarre': true,
                'constatId': 99,
              },
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
                'termine': true,
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
                {
                  ..._reservationJson(
                    id: 12,
                    startAt: now.subtract(const Duration(hours: 2)),
                    endAt: now.add(const Duration(hours: 2)),
                  ),
                  'termine': true,
                },
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
  Future<http.Response> Function(http.Request request) handler, {
  AuthSessionService sessionService = const AuthSessionService(),
}) {
  return FleetApiService(
    apiClient: ApiClient(
      httpClient: MockClient(handler),
      sessionService: sessionService,
      baseUri: Uri.parse('https://example.test/api'),
    ),
  );
}

FleetReservation _reservation({
  required DateTime startAt,
  required DateTime endAt,
  bool isStarted = false,
  bool isTerminated = false,
  String? constatId,
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
    isStarted: isStarted,
    isTerminated: isTerminated,
    constatId: constatId,
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
