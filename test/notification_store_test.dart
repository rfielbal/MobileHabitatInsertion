import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/data/notification_store.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    NotificationStore.items.value = [];
    NotificationStore.readIds.value = {};
    NotificationStore.resetReservationSyncState();
  });

  test(
    'creates a local notification when a reservation is deleted server-side',
    () async {
      await NotificationStore.upsertDeletedReservationNotifications([
        _reservation(id: 'deleted-admin-reservation'),
      ]);

      expect(NotificationStore.items.value, hasLength(1));
      expect(
        NotificationStore.items.value.single.title,
        'Réservation supprimée',
      );
      expect(
        NotificationStore.items.value.single.body,
        contains('Renault Clio'),
      );
      expect(NotificationStore.unreadCount, 1);
    },
  );

  test(
    'sync creates a notification only after a known reservation disappears',
    () async {
      final reservation = _reservation(id: 'server-sync-deleted-reservation');

      await NotificationStore.syncServerReservations([reservation]);
      expect(NotificationStore.items.value, isEmpty);

      await NotificationStore.syncServerReservations(const []);
      expect(NotificationStore.items.value, hasLength(1));
      expect(
        NotificationStore.items.value.single.title,
        'Réservation supprimée',
      );
    },
  );

  test('sync ignores reservations deleted locally from the app', () async {
    final reservation = _reservation(id: 'locally-deleted-reservation');

    await NotificationStore.syncServerReservations([reservation]);
    await NotificationStore.syncServerReservations(
      const [],
      locallyDeletedReservationIds: {reservation.id},
    );

    expect(NotificationStore.items.value, isEmpty);
  });
}

FleetReservation _reservation({required String id}) {
  return FleetReservation(
    id: id,
    vehicle: _vehicle,
    location: 'Site',
    startAt: DateTime(2026, 6, 18, 8),
    endAt: DateTime(2026, 6, 18, 17),
    startLabel: 'Jeu 18 Juin, 08:00',
    endLabel: 'Jeu 18 Juin, 17:00',
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
