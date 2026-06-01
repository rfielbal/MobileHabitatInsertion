import 'package:flutter/material.dart';

import '../../data/mock_fleet_data.dart';
import '../../models/vehicle.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_top_bar.dart';
import '../../widgets/vehicle_card.dart';
import 'notifications_screen.dart';
import 'vehicle_detail_screen.dart';

enum VehicleSortMode { priority, status, date }

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchController = TextEditingController();
  VehicleSortMode _sortMode = VehicleSortMode.priority;
  String? _selectedSite;
  String? _selectedBrand;
  VehicleStatus? _selectedStatus;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vehicle> get _filteredVehicles {
    final query = _searchController.text.trim().toLowerCase();
    final vehicles = MockFleetData.vehicles.where((vehicle) {
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

  List<String> get _sites {
    final values = MockFleetData.vehicles
        .map((vehicle) => vehicle.site)
        .toSet();
    return values.toList()..sort();
  }

  List<String> get _brands {
    final values = MockFleetData.vehicles
        .map((vehicle) => vehicle.brand)
        .toSet();
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
                  ButtonSegment(
                    value: VehicleSortMode.date,
                    label: Text('Date'),
                  ),
                ],
                selected: {_sortMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    _sortMode = selection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            _VehicleFilters(
              sites: _sites,
              brands: _brands,
              selectedSite: _selectedSite,
              selectedBrand: _selectedBrand,
              selectedStatus: _selectedStatus,
              onSiteChanged: (value) => setState(() => _selectedSite = value),
              onBrandChanged: (value) => setState(() => _selectedBrand = value),
              onStatusChanged: (value) =>
                  setState(() => _selectedStatus = value),
              onReset: () {
                setState(() {
                  _selectedSite = null;
                  _selectedBrand = null;
                  _selectedStatus = null;
                });
              },
            ),
            const SizedBox(height: 18),
            if (_filteredVehicles.isEmpty)
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
              for (final vehicle in _filteredVehicles) ...[
                VehicleCard(
                  vehicle: vehicle,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => VehicleDetailScreen(
                          vehicle: vehicle.id == 'peugeot-3008'
                              ? MockFleetData.detailVehicle
                              : vehicle,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const NotificationsScreen(),
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
