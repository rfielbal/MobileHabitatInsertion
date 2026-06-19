import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_habitat_insertion/data/notification_store.dart';
import 'package:mobile_habitat_insertion/models/app_notification.dart';
import 'package:mobile_habitat_insertion/models/reservation.dart';
import 'package:mobile_habitat_insertion/models/vehicle.dart';
import 'package:mobile_habitat_insertion/services/native_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNativeNotificationSink nativeNotifications;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    nativeNotifications = _FakeNativeNotificationSink();
    NotificationStore.debugSetNativeNotificationSink(nativeNotifications);
    NotificationStore.items.value = [];
    NotificationStore.readIds.value = {};
    NotificationStore.resetReservationSyncState();
  });

  tearDown(NotificationStore.debugResetNativeNotificationSink);

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
      expect(nativeNotifications.shown, hasLength(1));
      expect(nativeNotifications.shown.single.title, 'Réservation supprimée');
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

  test(
    'local cancellation clears reservation reminders and suppresses delete sync',
    () async {
      final reservation = _reservation(
        id: 'locally-cancelled-started-reservation',
        isStarted: true,
      );

      await NotificationStore.syncServerReservations([reservation]);
      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 17, 30));

      expect(NotificationStore.items.value, hasLength(1));
      expect(NotificationStore.items.value.single.title, 'Retour à confirmer');

      await NotificationStore.clearReservationReminders(reservation.id);
      expect(NotificationStore.items.value, isEmpty);
      expect(nativeNotifications.cancelled, isNotEmpty);

      await NotificationStore.syncServerReservations(const []);
      expect(NotificationStore.items.value, isEmpty);
    },
  );

  test(
    'creates an actionable notification fifteen minutes after unstarted departure',
    () async {
      final reservation = _reservation(
        id: 'unstarted-reservation',
        startAt: DateTime(2026, 6, 18, 8),
      );

      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 8, 14));
      expect(NotificationStore.items.value, isEmpty);
      expect(nativeNotifications.scheduled, hasLength(1));
      expect(
        nativeNotifications.scheduled.single.scheduledAt,
        DateTime(2026, 6, 18, 8, 15),
      );

      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 8, 15));

      expect(NotificationStore.items.value, hasLength(1));
      expect(NotificationStore.items.value.single.title, 'Départ non confirmé');
      expect(
        NotificationStore.items.value.single.action,
        AppNotificationAction.resolveUnstartedReservation,
      );
      expect(
        NotificationStore.items.value.single.reservationId,
        reservation.id,
      );
      expect(nativeNotifications.shown, isEmpty);
    },
  );

  test(
    'retries native scheduling when notifications become enabled later',
    () async {
      final reservation = _reservation(
        id: 'native-permission-retry-reservation',
        startAt: DateTime(2026, 6, 18, 8),
      );
      nativeNotifications.enabled = false;

      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 8, 10));
      expect(nativeNotifications.scheduled, isEmpty);

      nativeNotifications.enabled = true;
      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 8, 11));

      expect(nativeNotifications.scheduled, hasLength(1));
      expect(
        nativeNotifications.scheduled.single.scheduledAt,
        DateTime(2026, 6, 18, 8, 15),
      );
    },
  );

  test('parses native notification tap payloads', () {
    final intent = NativeNotificationTapIntent.fromPayload(
      'notification:-123:reservation:42',
    );

    expect(intent?.notificationId, -123);
    expect(intent?.reservationId, '42');
  });

  test('parses native notification tap payload without reservation', () {
    final intent = NativeNotificationTapIntent.fromPayload(
      'notification:-456',
      fallbackNotificationId: 1,
    );

    expect(intent?.notificationId, -456);
    expect(intent?.reservationId, isNull);
  });

  test(
    'maintained unstarted reservations do not recreate the local reminder',
    () async {
      final reservation = _reservation(
        id: 'maintained-unstarted-reservation',
        startAt: DateTime(2026, 6, 18, 8),
      );

      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 8, 15));
      expect(NotificationStore.items.value, hasLength(1));

      await NotificationStore.maintainUnstartedReservation(reservation.id);
      expect(NotificationStore.items.value, isEmpty);

      await NotificationStore.upsertDepartureReminders([
        reservation,
      ], DateTime(2026, 6, 18, 8, 45));
      expect(NotificationStore.items.value, isEmpty);
    },
  );
}

class _FakeNativeNotificationSink implements NativeNotificationSink {
  final List<AppNotification> shown = [];
  final List<_ScheduledNativeNotification> scheduled = [];
  final List<int> cancelled = [];
  var enabled = true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> show(
    AppNotification notification, {
    required int badgeCount,
  }) async {
    if (!enabled) {
      return false;
    }

    shown.add(notification);
    return true;
  }

  @override
  Future<bool> schedule(
    AppNotification notification, {
    required DateTime scheduledAt,
    required int badgeCount,
  }) async {
    if (!enabled) {
      return false;
    }

    scheduled.add(
      _ScheduledNativeNotification(
        notification: notification,
        scheduledAt: scheduledAt,
      ),
    );
    return true;
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }
}

class _ScheduledNativeNotification {
  const _ScheduledNativeNotification({
    required this.notification,
    required this.scheduledAt,
  });

  final AppNotification notification;
  final DateTime scheduledAt;
}

FleetReservation _reservation({
  required String id,
  DateTime? startAt,
  bool isStarted = false,
}) {
  return FleetReservation(
    id: id,
    vehicle: _vehicle,
    location: 'Site',
    startAt: startAt ?? DateTime(2026, 6, 18, 8),
    endAt: DateTime(2026, 6, 18, 17),
    startLabel: 'Jeu 18 Juin, 08:00',
    endLabel: 'Jeu 18 Juin, 17:00',
    status: ReservationStatus.upcoming,
    expectedStartMileage: 100,
    isStarted: isStarted,
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
