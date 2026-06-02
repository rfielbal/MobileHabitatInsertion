import 'package:flutter/material.dart';

import '../../data/notification_store.dart';
import '../../navigation/app_routes.dart';
import '../../services/auth_session_service.dart';
import '../../widgets/fleet_bottom_navigation.dart';
import 'bookings_screen.dart';
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
  int _reservationRefreshVersion = 0;

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
          VehiclesScreen(onReservationChanged: _refreshReservationData),
          BookingsScreen(
            key: ValueKey('bookings-$_reservationRefreshVersion'),
            refreshVersion: _reservationRefreshVersion,
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
        },
      ),
    );
  }

  Future<void> _logout() async {
    await _authSessionService.clearSession();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _refreshReservationData() {
    setState(() {
      _reservationRefreshVersion++;
    });
  }
}
