import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../navigation/app_routes.dart';
import '../../services/auth_session_service.dart';
import '../../services/fleet_api_service.dart';
import '../../widgets/fleet_bottom_navigation.dart';
import 'bookings_screen.dart';
import 'home_screen.dart';
import 'immediate_departure_screen.dart';
import 'profile_screen.dart';
import 'vehicles_screen.dart';

class FleetHomeShell extends StatefulWidget {
  const FleetHomeShell({super.key});

  @override
  State<FleetHomeShell> createState() => _FleetHomeShellState();
}

class _FleetHomeShellState extends State<FleetHomeShell> {
  final _authSessionService = const AuthSessionService();
  final _fleetApiService = FleetApiService();
  int _currentIndex = 0;
  int _vehicleRefreshVersion = 0;
  int _reservationRefreshVersion = 0;
  bool _hasActiveDeparture = true;

  @override
  void initState() {
    super.initState();
    NotificationStore.refresh();
    _refreshActiveDepartureState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            onImmediateDeparture: _openImmediateDeparture,
            onPlanReservation: _openReservationPlanning,
            showImmediateDeparture: !_hasActiveDeparture,
          ),
          BookingsScreen(
            key: ValueKey('bookings-$_reservationRefreshVersion'),
            refreshVersion: _reservationRefreshVersion,
            onReservationChanged: _refreshVehicleData,
          ),
          ProfileScreen(onLogout: _logout),
        ],
      ),
      bottomNavigationBar: FleetBottomNavigation(
        currentIndex: _currentIndex,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 1) {
              _reservationRefreshVersion++;
            }
          });
          if (index == 0) {
            _refreshActiveDepartureState();
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    NotificationStore.resetReservationSyncState();
    await _authSessionService.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _refreshVehicleData() {
    setState(() {
      _vehicleRefreshVersion++;
    });
    _refreshActiveDepartureState();
  }

  void _refreshReservationData() {
    setState(() {
      _reservationRefreshVersion++;
    });
    _refreshActiveDepartureState();
  }

  Future<void> _refreshActiveDepartureState() async {
    try {
      final reservations = await _fleetApiService.fetchReservations();
      final hasActiveDeparture = reservations.any(
        (reservation) => reservation.isStarted && !reservation.isTerminated,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasActiveDeparture = hasActiveDeparture;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasActiveDeparture = false;
      });
    }
  }

  void _openImmediateDeparture() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const ImmediateDepartureScreen(),
          ),
        )
        .then((startedReservation) {
          if (startedReservation == null || !mounted) {
            return;
          }

          setState(() {
            _currentIndex = 0;
            _vehicleRefreshVersion++;
            _reservationRefreshVersion++;
            _hasActiveDeparture = true;
          });
        });
  }

  void _openReservationPlanning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choisissez un véhicule pour planifier la réservation.'),
      ),
    );

    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => VehiclesScreen(
              refreshVersion: _vehicleRefreshVersion,
              showBackButton: true,
              onReservationChanged: _refreshReservationData,
            ),
          ),
        )
        .then((updated) {
          if ((updated ?? false) && mounted) {
            _refreshReservationData();
          }
        });
  }
}
