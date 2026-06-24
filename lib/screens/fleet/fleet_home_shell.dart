import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/mobile_update_store.dart';
import '../../data/notification_store.dart';
import '../../models/reservation.dart';
import '../../navigation/app_routes.dart';
import '../../services/auth_api_service.dart';
import '../../services/auth_session_service.dart';
import '../../services/fleet_api_service.dart';
import '../../services/native_notification_service.dart';
import '../../services/session_invalidation_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/fleet_bottom_navigation.dart';
import 'bookings_screen.dart';
import 'home_screen.dart';
import 'immediate_departure_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'vehicles_screen.dart';

class FleetHomeShell extends StatefulWidget {
  const FleetHomeShell({super.key});

  @override
  State<FleetHomeShell> createState() => _FleetHomeShellState();
}

class _FleetHomeShellState extends State<FleetHomeShell>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _authApiService = AuthApiService();
  final _authSessionService = const AuthSessionService();
  final _fleetApiService = FleetApiService();
  Timer? _sessionGuardTimer;
  Timer? _mobileUpdateTimer;
  int _currentIndex = 0;
  int _vehicleRefreshVersion = 0;
  int _reservationRefreshVersion = 0;
  String? _focusedReservationId;
  bool _hasActiveDeparture = true;
  bool _isCheckingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeNotificationService.instance.tapIntent.addListener(
      _handleNativeNotificationTap,
    );
    SessionInvalidationNotifier.instance.addListener(_handleSessionInvalidated);
    _sessionGuardTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _verifyCurrentSession(),
    );
    _mobileUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => MobileUpdateStore.refresh(),
    );
    NotificationStore.refresh();
    MobileUpdateStore.refresh();
    _refreshActiveDepartureState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNativeNotificationTap();
    });
  }

  @override
  void dispose() {
    NativeNotificationService.instance.tapIntent.removeListener(
      _handleNativeNotificationTap,
    );
    SessionInvalidationNotifier.instance.removeListener(
      _handleSessionInvalidated,
    );
    _sessionGuardTimer?.cancel();
    _mobileUpdateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    _handleSystemBack();
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    NotificationStore.refresh();
    MobileUpdateStore.refresh();
    _verifyCurrentSession();
    _refreshActiveDepartureState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }

        _handleSystemBack();
      },
      child: Scaffold(
        body: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (_) => _routeForIndex(_currentIndex),
        ),
        bottomNavigationBar: FleetBottomNavigation(
          currentIndex: _currentIndex,
          onChanged: _selectTab,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _authApiService.signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Déconnexion impossible. Réessayez dans un instant.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    NotificationStore.resetReservationSyncState();
    MobileUpdateStore.reset();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Route<void> _routeForIndex(int index) {
    return MaterialPageRoute<void>(
      builder: (context) => _screenForIndex(index),
    );
  }

  Widget _screenForIndex(int index) {
    return switch (index) {
      0 => HomeScreen(
        onImmediateDeparture: _openImmediateDeparture,
        onPlanReservation: _openReservationPlanning,
        onOpenReservationFromNotification: _openReservationFromNotification,
        showImmediateDeparture: !_hasActiveDeparture,
      ),
      1 => BookingsScreen(
        key: ValueKey('bookings-$_reservationRefreshVersion'),
        refreshVersion: _reservationRefreshVersion,
        focusedReservationId: _focusedReservationId,
        onReservationChanged: _refreshVehicleData,
        onOpenReservationFromNotification: _openReservationFromNotification,
      ),
      _ => ProfileScreen(
        onLogout: _logout,
        onOpenReservationFromNotification: _openReservationFromNotification,
      ),
    };
  }

  void _selectTab(int index) {
    if (index == 1) {
      _reservationRefreshVersion++;
      _focusedReservationId = null;
    }

    setState(() {
      _currentIndex = index;
    });

    _navigatorKey.currentState?.pushAndRemoveUntil(
      _routeForIndex(index),
      (route) => false,
    );

    if (index == 0) {
      _refreshActiveDepartureState();
    }
  }

  void _handleSystemBack() {
    final navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }

    if (_currentIndex != 0) {
      _selectTab(0);
    }
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
      try {
        await NotificationStore.upsertDepartureReminders(
          reservations,
          DateTime.now(),
        );
      } catch (_) {
        // Les rappels locaux ne doivent pas fausser l'état de l'accueil.
      }
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
    _navigatorKey.currentState
        ?.push(
          MaterialPageRoute<FleetReservation>(
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

    _navigatorKey.currentState
        ?.push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => VehiclesScreen(
              refreshVersion: _vehicleRefreshVersion,
              showBackButton: true,
              closeAfterReservation: true,
              onReservationChanged: _refreshReservationData,
              onOpenReservationFromNotification:
                  _openReservationFromNotification,
            ),
          ),
        )
        .then((updated) {
          if ((updated ?? false) && mounted) {
            _refreshReservationData();
          }
        });
  }

  void _handleNativeNotificationTap() {
    final intent = NativeNotificationService.instance.tapIntent.value;
    if (intent == null || !mounted) {
      return;
    }

    NativeNotificationService.instance.consumeTapIntent(intent);
    setState(() {
      _currentIndex = 0;
    });
    _navigatorKey.currentState
        ?.push<String>(
          MaterialPageRoute<String>(
            builder: (context) => NotificationsScreen(
              initialNotificationId: intent.notificationId,
              initialReservationId: intent.reservationId,
              initialAction: intent.action,
            ),
          ),
        )
        .then((reservationId) {
          if (reservationId == null || reservationId.trim().isEmpty) {
            return;
          }

          _openReservationFromNotification(reservationId);
        });
  }

  void _openReservationFromNotification(String reservationId) {
    final normalizedId = reservationId.trim();
    if (normalizedId.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _currentIndex = 1;
      _reservationRefreshVersion++;
      _focusedReservationId = normalizedId;
    });

    _navigatorKey.currentState?.pushAndRemoveUntil(
      _routeForIndex(1),
      (route) => false,
    );
  }

  void _handleSessionInvalidated() {
    NotificationStore.resetReservationSyncState();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _verifyCurrentSession() async {
    if (_isCheckingSession) {
      return;
    }

    _isCheckingSession = true;
    try {
      final session = await _authSessionService.readSession();
      if (session == null || session.isMockSession) {
        return;
      }

      await _authApiService.refreshStoredSession(session);
    } catch (_) {
      // ApiClient handles invalid authenticated sessions globally.
    } finally {
      _isCheckingSession = false;
    }
  }
}
