import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/vehicle_sort.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_usage_help_dialog.dart';
import '../../widgets/brand_top_bar.dart';
import '../../widgets/vehicle_card.dart';
import 'notifications_screen.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    super.key,
    this.refreshVersion = 0,
    this.filterCommandVersion = 0,
    this.statusFilter,
    this.onReservationChanged,
    this.onOpenReservationFromNotification,
    this.showBackButton = false,
    this.closeAfterReservation = false,
  });

  final int refreshVersion;
  final int filterCommandVersion;
  final VehicleStatus? statusFilter;
  final VoidCallback? onReservationChanged;
  final ValueChanged<String>? onOpenReservationFromNotification;
  final bool showBackButton;
  final bool closeAfterReservation;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchController = TextEditingController();
  final _fleetApiService = FleetApiService();
  late Future<_VehiclesData> _vehiclesFuture;
  String? _selectedSite;
  String? _selectedBrand;
  VehicleStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _applyExternalFilter(widget.statusFilter);
    _vehiclesFuture = _loadVehicles();
  }

  @override
  void didUpdateWidget(covariant VehiclesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _vehiclesFuture = _loadVehicles();
    }

    if (oldWidget.filterCommandVersion != widget.filterCommandVersion) {
      _applyExternalFilter(widget.statusFilter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vehicle> _filteredVehicles(
    List<Vehicle> allVehicles,
    List<String> sitePriority,
    String selectedSite,
    String? selectedBrand,
    VehicleStatus? selectedStatus,
  ) {
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
      final matchesSite = vehicle.site == selectedSite;
      final matchesBrand =
          selectedBrand == null || vehicle.brand == selectedBrand;
      final matchesStatus =
          selectedStatus == null || vehicle.status == selectedStatus;

      return matchesQuery && matchesSite && matchesBrand && matchesStatus;
    }).toList();

    sortVehiclesByRecommendation(vehicles, sitePriority: sitePriority);

    return vehicles;
  }

  Future<_VehiclesData> _loadVehicles() async {
    final vehicles = await _fleetApiService.fetchVehicles();
    final siteLabels = await _loadAccessibleSitesFallback(vehicles);

    return _VehiclesData(vehicles: vehicles, sites: siteLabels);
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
      // Les véhicules restent affichables si la récupération dédiée des sites
      // échoue ; on retombe alors sur les affectations présentes dans la liste.
    }

    return _sitesFromVehicles(vehicles);
  }

  List<String> _sitesFromVehicles(List<Vehicle> vehicles) {
    final sites = <String>[];
    final seen = <String>{};

    for (final vehicle in vehicles) {
      final site = vehicle.site.trim();
      if (site.isEmpty || !seen.add(site.toLowerCase())) {
        continue;
      }
      sites.add(site);
    }

    return sites;
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
        onHelpPressed: () =>
            showAppUsageHelp(context, AppUsageHelpTopic.vehicles),
        showBackButton: widget.showBackButton,
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
            FutureBuilder<_VehiclesData>(
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

                final data = snapshot.data ?? const _VehiclesData.empty();
                final brands = _brands(data.vehicles);
                final selectedSite = data.sites.contains(_selectedSite)
                    ? _selectedSite
                    : null;
                final selectedBrand = brands.contains(_selectedBrand)
                    ? _selectedBrand
                    : null;
                final selectedStatus =
                    _selectedStatus != null &&
                        _selectedStatus!.canBeUsedAsFilter
                    ? _selectedStatus
                    : null;

                return _VehiclesContent(
                  vehicles: data.vehicles,
                  filteredVehicles: selectedSite == null
                      ? const []
                      : _filteredVehicles(
                          data.vehicles,
                          data.sites,
                          selectedSite,
                          selectedBrand,
                          selectedStatus,
                        ),
                  sites: data.sites,
                  brands: brands,
                  selectedSite: selectedSite,
                  selectedBrand: selectedBrand,
                  selectedStatus: selectedStatus,
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
      _vehiclesFuture = _loadVehicles();
    });
  }

  void _resetFilters() {
    setState(() {
      _applyExternalFilter(null);
    });
  }

  void _applyExternalFilter(VehicleStatus? statusFilter) {
    _searchController.clear();
    _selectedSite = null;
    _selectedBrand = null;
    _selectedStatus = statusFilter;
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
            widget.onReservationChanged?.call();

            if (widget.closeAfterReservation && mounted) {
              Navigator.of(context).pop(true);
              return;
            }

            _reloadVehicles();
          }
        });
  }

  Future<void> _openNotifications(BuildContext context) async {
    final reservationId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => const NotificationsScreen(),
      ),
    );

    if (!context.mounted ||
        reservationId == null ||
        reservationId.trim().isEmpty) {
      return;
    }

    widget.onOpenReservationFromNotification?.call(reservationId);
  }
}

class _VehiclesData {
  const _VehiclesData({required this.vehicles, required this.sites});

  const _VehiclesData.empty() : vehicles = const [], sites = const [];

  final List<Vehicle> vehicles;
  final List<String> sites;
}

class _VehiclesContent extends StatelessWidget {
  const _VehiclesContent({
    required this.vehicles,
    required this.filteredVehicles,
    required this.sites,
    required this.brands,
    required this.selectedSite,
    required this.selectedBrand,
    required this.selectedStatus,
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
  final String? selectedSite;
  final String? selectedBrand;
  final VehicleStatus? selectedStatus;
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
        if (selectedSite == null)
          const _SelectDepartureSitePrompt()
        else if (filteredVehicles.isEmpty)
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

class _SelectDepartureSitePrompt extends StatelessWidget {
  const _SelectDepartureSitePrompt();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        children: [
          Icon(Icons.location_on_outlined, color: AppColors.primary, size: 34),
          SizedBox(height: 12),
          Text(
            'Sélectionnez un site de départ pour afficher les véhicules disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
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
                decoration: const InputDecoration(labelText: 'Site de départ'),
                hint: const Text('Sélectionner'),
                items: [
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
