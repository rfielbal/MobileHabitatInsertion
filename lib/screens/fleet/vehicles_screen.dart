import 'package:flutter/material.dart';

import '../../data/mock_fleet_data.dart';
import '../../models/vehicle.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_top_bar.dart';
import '../../widgets/vehicle_card.dart';
import 'notifications_screen.dart';
import 'vehicle_detail_screen.dart';

enum VehicleSortMode { status, date }

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchController = TextEditingController();
  VehicleSortMode _sortMode = VehicleSortMode.status;

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
          vehicle.name.toLowerCase().contains(query) ||
          vehicle.plateNumber.toLowerCase().contains(query);
      return matchesQuery;
    }).toList();

    vehicles.sort((a, b) {
      return switch (_sortMode) {
        VehicleSortMode.status => a.status.sortRank.compareTo(
          b.status.sortRank,
        ),
        VehicleSortMode.date => a.nextAvailableAt.compareTo(b.nextAvailableAt),
      };
    });

    return vehicles;
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
                hintText: 'Rechercher une plaque...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Trier par',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<VehicleSortMode>(
                    segments: const [
                      ButtonSegment(
                        value: VehicleSortMode.status,
                        label: Text('Statut'),
                        icon: Icon(Icons.sort),
                      ),
                      ButtonSegment(
                        value: VehicleSortMode.date,
                        label: Text('Date'),
                        icon: Icon(Icons.event),
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
              ],
            ),
            const SizedBox(height: 18),
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
