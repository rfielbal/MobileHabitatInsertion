import '../models/reservation.dart';
import '../models/vehicle.dart';
import 'api_client.dart';
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

    final vehicles = vehiclesById.values.toList();
    vehicles.sort((a, b) {
      final statusSort = a.status.sortRank.compareTo(b.status.sortRank);
      if (statusSort != 0) {
        return statusSort;
      }
      return a.name.compareTo(b.name);
    });
    return vehicles;
  }

  Future<List<FleetReservation>> fetchReservations() async {
    final response = await _apiClient.getMap('/metier/mes-reservations');
    final reservations = FleetApiMappers.itemsFromResponse(
      response,
    ).map(FleetApiMappers.reservationFromJson).toList();

    reservations.sort((a, b) => b.startAt.compareTo(a.startAt));
    return reservations;
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
}
