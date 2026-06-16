import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../navigation/app_routes.dart';
import '../../services/auth_session_service.dart';
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
  int _currentIndex = 0;
  int _vehicleRefreshVersion = 0;
  int _reservationRefreshVersion = 0;
  int _vehicleFilterCommandVersion = 0;

  @override
  void initState() {
    super.initState();
    NotificationStore.refresh();
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
          ),
          VehiclesScreen(
            refreshVersion: _vehicleRefreshVersion,
            filterCommandVersion: _vehicleFilterCommandVersion,
            onReservationChanged: _refreshReservationData,
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
            if (index == 2) {
              _reservationRefreshVersion++;
            }
          });
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
  }

  void _refreshReservationData() {
    setState(() {
      _reservationRefreshVersion++;
    });
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
          });
        });
  }

  void _openReservationPlanning() {
    setState(() {
      _currentIndex = 1;
      _vehicleFilterCommandVersion++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Choisissez un véhicule pour planifier la réservation.'),
      ),
    );
  }
}
