import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_top_bar.dart';
import '../../widgets/vehicle_card.dart';
import 'notifications_screen.dart';
import 'vehicle_detail_screen.dart';

enum VehicleSortMode { priority, status, date }

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, this.onReservationChanged});

  final VoidCallback? onReservationChanged;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchController = TextEditingController();
  final _fleetApiService = FleetApiService();
  late Future<List<Vehicle>> _vehiclesFuture;
  VehicleSortMode _sortMode = VehicleSortMode.priority;
  String? _selectedSite;
  String? _selectedBrand;
  VehicleStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _vehiclesFuture = _fleetApiService.fetchVehicles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vehicle> _filteredVehicles(List<Vehicle> allVehicles) {
    final query = _searchController.text.trim().toLowerCase();
    final vehicles = allVehicles.where((vehicle) {
      final matchesQuery =
          query.isEmpty ||
          vehicle.internalNumber.toLowerCase().contains(query) ||
          vehicle.name.toLowerCase().contains(query) ||
          vehicle.brand.toLowerCase().contains(query) ||
          vehicle.model.toLowerCase().contains(query) ||
          vehicle.site.toLowerCase().contains(query) ||
          vehicle.plateNumber.toLowerCase().contains(query);
      final matchesSite =
          _selectedSite == null || vehicle.site == _selectedSite;
      final matchesBrand =
          _selectedBrand == null || vehicle.brand == _selectedBrand;
      final matchesStatus =
          _selectedStatus == null || vehicle.status == _selectedStatus;

      return matchesQuery && matchesSite && matchesBrand && matchesStatus;
    }).toList();

    vehicles.sort((a, b) {
      return switch (_sortMode) {
        VehicleSortMode.priority => a.priorityRank.compareTo(b.priorityRank),
        VehicleSortMode.status => a.status.sortRank.compareTo(
          b.status.sortRank,
        ),
        VehicleSortMode.date => a.nextAvailableAt.compareTo(b.nextAvailableAt),
      };
    });

    return vehicles;
  }

  List<String> _sites(List<Vehicle> vehicles) {
    final values = vehicles.map((vehicle) => vehicle.site).toSet();
    return values.toList()..sort();
  }

  List<String> _brands(List<Vehicle> vehicles) {
    final values = vehicles.map((vehicle) => vehicle.brand).toSet();
    return values.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandTopBar(
        onNotificationsPressed: () => _openNotifications(context),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Véhicules',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Rechercher numéro, modèle, plaque...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Vehicle>>(
              future: _vehiclesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return _VehiclesError(
                    message:
                        'Impossible de charger les véhicules depuis l’API.',
                    onRetry: _reloadVehicles,
                  );
                }

                return _VehiclesContent(
                  vehicles: snapshot.data ?? const [],
                  filteredVehicles: _filteredVehicles(
                    snapshot.data ?? const [],
                  ),
                  sites: _sites(snapshot.data ?? const []),
                  brands: _brands(snapshot.data ?? const []),
                  sortMode: _sortMode,
                  selectedSite: _selectedSite,
                  selectedBrand: _selectedBrand,
                  selectedStatus: _selectedStatus,
                  onSortModeChanged: (value) =>
                      setState(() => _sortMode = value),
                  onSiteChanged: (value) =>
                      setState(() => _selectedSite = value),
                  onBrandChanged: (value) =>
                      setState(() => _selectedBrand = value),
                  onStatusChanged: (value) =>
                      setState(() => _selectedStatus = value),
                  onReset: _resetFilters,
                  onVehicleTap: _openVehicle,
                  onRefresh: _reloadVehicles,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _reloadVehicles() {
    setState(() {
      _vehiclesFuture = _fleetApiService.fetchVehicles();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedSite = null;
      _selectedBrand = null;
      _selectedStatus = null;
    });
  }

  void _openVehicle(Vehicle vehicle) {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => VehicleDetailScreen(vehicle: vehicle),
          ),
        )
        .then((updated) {
          if (updated ?? false) {
            _reloadVehicles();
            widget.onReservationChanged?.call();
          }
        });
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const NotificationsScreen(),
      ),
    );
  }
}

class _VehiclesContent extends StatelessWidget {
  const _VehiclesContent({
    required this.vehicles,
    required this.filteredVehicles,
    required this.sites,
    required this.brands,
    required this.sortMode,
    required this.selectedSite,
    required this.selectedBrand,
    required this.selectedStatus,
    required this.onSortModeChanged,
    required this.onSiteChanged,
    required this.onBrandChanged,
    required this.onStatusChanged,
    required this.onReset,
    required this.onVehicleTap,
    required this.onRefresh,
  });

  final List<Vehicle> vehicles;
  final List<Vehicle> filteredVehicles;
  final List<String> sites;
  final List<String> brands;
  final VehicleSortMode sortMode;
  final String? selectedSite;
  final String? selectedBrand;
  final VehicleStatus? selectedStatus;
  final ValueChanged<VehicleSortMode> onSortModeChanged;
  final ValueChanged<String?> onSiteChanged;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<VehicleStatus?> onStatusChanged;
  final VoidCallback onReset;
  final ValueChanged<Vehicle> onVehicleTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return _VehiclesError(
        message:
            'Aucun véhicule n’est disponible pour ce compte. Vérifiez les affectations côté administration.',
        onRetry: onRefresh,
      );
    }

    return Column(
      children: [
        const Text(
          'Trier par',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<VehicleSortMode>(
            segments: const [
              ButtonSegment(
                value: VehicleSortMode.priority,
                label: Text('Priorité'),
              ),
              ButtonSegment(
                value: VehicleSortMode.status,
                label: Text('Statut'),
              ),
              ButtonSegment(value: VehicleSortMode.date, label: Text('Date')),
            ],
            selected: {sortMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              onSortModeChanged(selection.first);
            },
          ),
        ),
        const SizedBox(height: 14),
        _VehicleFilters(
          sites: sites,
          brands: brands,
          selectedSite: selectedSite,
          selectedBrand: selectedBrand,
          selectedStatus: selectedStatus,
          onSiteChanged: onSiteChanged,
          onBrandChanged: onBrandChanged,
          onStatusChanged: onStatusChanged,
          onReset: onReset,
        ),
        const SizedBox(height: 18),
        if (filteredVehicles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Aucun véhicule ne correspond aux filtres',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          for (final vehicle in filteredVehicles) ...[
            VehicleCard(vehicle: vehicle, onTap: () => onVehicleTap(vehicle)),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _VehiclesError extends StatelessWidget {
  const _VehiclesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.onSurfaceVariant,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _VehicleFilters extends StatelessWidget {
  const _VehicleFilters({
    required this.sites,
    required this.brands,
    required this.selectedSite,
    required this.selectedBrand,
    required this.selectedStatus,
    required this.onSiteChanged,
    required this.onBrandChanged,
    required this.onStatusChanged,
    required this.onReset,
  });

  final List<String> sites;
  final List<String> brands;
  final String? selectedSite;
  final String? selectedBrand;
  final VehicleStatus? selectedStatus;
  final ValueChanged<String?> onSiteChanged;
  final ValueChanged<String?> onBrandChanged;
  final ValueChanged<VehicleStatus?> onStatusChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        selectedSite != null || selectedBrand != null || selectedStatus != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedSite,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Site'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tous'),
                  ),
                  for (final site in sites)
                    DropdownMenuItem(value: site, child: Text(site)),
                ],
                onChanged: onSiteChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<VehicleStatus>(
                initialValue: selectedStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: [
                  const DropdownMenuItem<VehicleStatus>(
                    value: null,
                    child: Text('Tous'),
                  ),
                  for (final status in VehicleStatus.values.where(
                    (status) => status.canBeUsedAsFilter,
                  ))
                    DropdownMenuItem(value: status, child: Text(status.label)),
                ],
                onChanged: onStatusChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedBrand,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Marque'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Toutes'),
                  ),
                  for (final brand in brands)
                    DropdownMenuItem(value: brand, child: Text(brand)),
                ],
                onChanged: onBrandChanged,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.outlined(
              tooltip: 'Réinitialiser les filtres',
              onPressed: hasFilters ? onReset : null,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
