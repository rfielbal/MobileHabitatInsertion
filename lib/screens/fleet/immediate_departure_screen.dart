import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/vehicle_sort.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_usage_help_dialog.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/status_chip.dart';

class ImmediateDepartureScreen extends StatefulWidget {
  const ImmediateDepartureScreen({
    super.key,
    FleetApiService? fleetApiService,
    DateTime Function()? now,
  }) : _fleetApiService = fleetApiService,
       _now = now;

  final FleetApiService? _fleetApiService;
  final DateTime Function()? _now;

  @override
  State<ImmediateDepartureScreen> createState() =>
      _ImmediateDepartureScreenState();
}

class _ImmediateDepartureScreenState extends State<ImmediateDepartureScreen> {
  late final FleetApiService _fleetApiService;
  late final DateTime Function() _now;
  late Future<_ImmediateDepartureData> _departureDataFuture;
  late DateTime _returnAt;

  String? _selectedSite;
  Vehicle? _selectedVehicle;
  String? _error;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fleetApiService = widget._fleetApiService ?? FleetApiService();
    _now = widget._now ?? DateTime.now;
    _returnAt = _defaultReturnAt(_now());
    _departureDataFuture = _loadDepartureData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Départ immédiat'),
        actions: [
          IconButton(
            tooltip: 'Guide d’utilisation',
            onPressed: () =>
                showAppUsageHelp(context, AppUsageHelpTopic.immediateDeparture),
            icon: const Icon(Icons.help_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: _isSubmitting ? 'Validation...' : 'Valider le départ',
              icon: Icons.play_circle,
              onPressed: _isSubmitting ? null : _startImmediateDeparture,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_ImmediateDepartureData>(
          future: _departureDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ImmediateDepartureError(onRetry: _reloadVehicles);
            }

            final data = snapshot.data ?? const _ImmediateDepartureData.empty();
            final vehicles = data.availableVehicles;
            final sites = data.sites;
            final vehiclesForSite = _selectedSite == null
                ? const <Vehicle>[]
                : vehicles
                      .where((vehicle) => vehicle.site == _selectedSite)
                      .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Text(
                  'Départ maintenant',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choisissez le site de départ, le véhicule disponible, puis indiquez la date et l’heure de retour prévues.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  _InlineError(message: _error!),
                  const SizedBox(height: 14),
                ],
                _StepSection(
                  number: 1,
                  title: 'Site de départ',
                  child: sites.isEmpty
                      ? const _EmptyState(
                          icon: Icons.location_off_outlined,
                          title: 'Aucun site disponible',
                          message:
                              'Aucun site n’est rattaché à votre compte pour le moment.',
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final site in sites)
                              ChoiceChip(
                                label: Text(site),
                                selected: _selectedSite == site,
                                onSelected: (_) => _selectSite(site),
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _selectedSite == site
                                      ? AppColors.onPrimary
                                      : AppColors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _StepSection(
                  number: 2,
                  title: 'Véhicule disponible',
                  child: _selectedSite == null
                      ? const _PendingChoice(
                          message: 'Sélectionnez d’abord un site de départ.',
                        )
                      : vehiclesForSite.isEmpty
                      ? const _EmptyState(
                          icon: Icons.directions_car_filled_outlined,
                          title: 'Aucun véhicule libre',
                          message:
                              'Essayez un autre site ou faites une réservation classique.',
                        )
                      : Column(
                          children: [
                            for (final vehicle in vehiclesForSite) ...[
                              _SelectableVehicle(
                                vehicle: vehicle,
                                selected: _selectedVehicle?.id == vehicle.id,
                                onTap: () => _selectVehicle(vehicle),
                              ),
                              if (vehicle != vehiclesForSite.last)
                                const SizedBox(height: 10),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _StepSection(
                  number: 3,
                  title: 'Retour prévu',
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 46,
                              width: 46,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.event_available_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _returnDateLabel(_returnAt),
                                    style: const TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _returnTimeLabel(context, _returnAt),
                                    style: const TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickReturnDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: const Text('Date'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickReturnTime,
                              icon: const Icon(Icons.schedule),
                              label: const Text('Heure'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_ImmediateDepartureData> _loadDepartureData() async {
    final vehicles = await _fleetApiService.fetchVehicles();
    final availableVehicles = vehicles
        .where((vehicle) => vehicle.status == VehicleStatus.available)
        .toList();

    final sites = await _loadAccessibleSitesFallback(availableVehicles);
    sortVehiclesByRecommendation(availableVehicles, sitePriority: sites);
    if (mounted && _selectedSite == null && sites.length == 1) {
      setState(() {
        _selectedSite = sites.single;
      });
    }

    return _ImmediateDepartureData(
      sites: sites,
      availableVehicles: availableVehicles,
    );
  }

  Future<List<String>> _loadAccessibleSitesFallback(
    List<Vehicle> vehicles,
  ) async {
    try {
      final sites = await _fleetApiService.fetchUserSiteLabels();
      if (sites.isNotEmpty) {
        return sites;
      }
    } catch (_) {
      // Le parcours reste utilisable même si l'endpoint des sites échoue :
      // on retombe sur les sites portés par les véhicules disponibles.
    }

    return _sites(vehicles);
  }

  List<String> _sites(List<Vehicle> vehicles) {
    final sites = vehicles
        .map((vehicle) => vehicle.site.trim())
        .where((site) => site.isNotEmpty)
        .toList();

    final seen = <String>{};
    sites.retainWhere((site) => seen.add(site.toLowerCase()));
    return sites;
  }

  void _selectSite(String site) {
    setState(() {
      _selectedSite = site;
      if (_selectedVehicle?.site != site) {
        _selectedVehicle = null;
      }
      _error = null;
    });
  }

  void _selectVehicle(Vehicle vehicle) {
    setState(() {
      _selectedVehicle = vehicle;
      _error = null;
    });
    _adjustReturnAtBeforeNextDeparture(vehicle);
  }

  Future<void> _adjustReturnAtBeforeNextDeparture(Vehicle vehicle) async {
    final selectedVehicleId = vehicle.id;
    final now = _now();

    try {
      final startTimes = await _fleetApiService
          .fetchVehicleReservationStartTimesForMonth(
            vehicle: vehicle,
            month: now,
          );
      DateTime? nextDeparture;
      for (final startAt in startTimes) {
        if (startAt.isAfter(now)) {
          nextDeparture = startAt;
          break;
        }
      }

      if (nextDeparture == null) {
        return;
      }

      final suggestedReturn = nextDeparture.subtract(const Duration(hours: 1));
      if (!suggestedReturn.isAfter(now) ||
          !suggestedReturn.isBefore(_returnAt)) {
        return;
      }

      if (!mounted || _selectedVehicle?.id != selectedVehicleId) {
        return;
      }

      setState(() {
        _returnAt = suggestedReturn;
      });
    } catch (_) {
      // Le retour prévu par défaut reste valable ; la validation API protège le créneau.
    }
  }

  Future<void> _pickReturnDate() async {
    final now = _now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOnly(_returnAt),
      firstDate: _dateOnly(now),
      lastDate: _dateOnly(now).add(const Duration(days: 90)),
    );

    if (picked == null || !mounted) {
      return;
    }

    final nextReturnAt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _returnAt.hour,
      _returnAt.minute,
    );

    setState(() {
      _returnAt = nextReturnAt.isAfter(now)
          ? nextReturnAt
          : _defaultReturnAt(now);
      _error = null;
    });
  }

  Future<void> _pickReturnTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_returnAt),
    );

    if (picked == null || !mounted) {
      return;
    }

    final nextReturnAt = DateTime(
      _returnAt.year,
      _returnAt.month,
      _returnAt.day,
      picked.hour,
      picked.minute,
    );

    if (!nextReturnAt.isAfter(_now())) {
      setState(() {
        _error = 'Le retour prévu doit être après l’heure actuelle.';
      });
      return;
    }

    setState(() {
      _returnAt = nextReturnAt;
      _error = null;
    });
  }

  Future<void> _startImmediateDeparture() async {
    final vehicle = _selectedVehicle;
    if (_selectedSite == null) {
      setState(() {
        _error = 'Sélectionnez un site de départ.';
      });
      return;
    }
    if (vehicle == null) {
      setState(() {
        _error = 'Sélectionnez un véhicule disponible.';
      });
      return;
    }

    final startAt = _now();
    final returnAt = _returnAt;
    if (!startAt.isBefore(returnAt)) {
      setState(() {
        _error = 'Le retour prévu doit être après l’heure actuelle.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final startedReservation = await _fleetApiService.startImmediateDeparture(
        vehicle: vehicle,
        startedAt: startAt,
        returnAt: returnAt,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${vehicle.name} réservé et démarré')),
      );
      Navigator.of(context).pop(startedReservation);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = 'Départ immédiat impossible : $error';
      });
    }
  }

  DateTime _defaultReturnAt(DateTime now) {
    if (now.hour < 16) {
      final todayAtSix = DateTime(now.year, now.month, now.day, 18);
      if (todayAtSix.isAfter(now)) {
        return todayAtSix;
      }
    }

    return _roundUpToNextHalfHour(now.add(const Duration(hours: 2)));
  }

  DateTime _roundUpToNextHalfHour(DateTime value) {
    final base = DateTime(value.year, value.month, value.day, value.hour);
    final hasSubMinute =
        value.second != 0 || value.millisecond != 0 || value.microsecond != 0;
    if (value.minute == 0 && !hasSubMinute) {
      return base;
    }
    if (value.minute < 30 || (value.minute == 30 && !hasSubMinute)) {
      return base.add(const Duration(minutes: 30));
    }
    return base.add(const Duration(hours: 1));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _returnDateLabel(DateTime date) {
    final today = _dateOnly(_now());
    final target = _dateOnly(date);
    if (target == today) {
      return 'Aujourd’hui';
    }
    if (target == today.add(const Duration(days: 1))) {
      return 'Demain';
    }

    const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
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

    return '${weekDays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }

  String _returnTimeLabel(BuildContext context, DateTime date) {
    return TimeOfDay.fromDateTime(date).format(context);
  }

  void _reloadVehicles() {
    setState(() {
      _selectedSite = null;
      _selectedVehicle = null;
      _error = null;
      _departureDataFuture = _loadDepartureData();
    });
  }
}

class _ImmediateDepartureData {
  const _ImmediateDepartureData({
    required this.sites,
    required this.availableVehicles,
  });

  const _ImmediateDepartureData.empty()
    : sites = const [],
      availableVehicles = const [];

  final List<String> sites;
  final List<Vehicle> availableVehicles;
}

class _StepSection extends StatelessWidget {
  const _StepSection({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 28,
              width: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SelectableVehicle extends StatelessWidget {
  const _SelectableVehicle({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? Icons.check : Icons.directions_car_outlined,
              color: selected ? AppColors.onPrimary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle.internalNumber} • ${vehicle.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vehicle.plateNumber} • ${vehicle.currentMileage} km',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusChip(
            label: vehicle.status.label,
            color: vehicle.status.color,
            icon: vehicle.status.icon,
          ),
        ],
      ),
    );
  }
}

class _PendingChoice extends StatelessWidget {
  const _PendingChoice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.onErrorContainer,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmediateDepartureError extends StatelessWidget {
  const _ImmediateDepartureError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.error, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Impossible de charger les véhicules disponibles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
