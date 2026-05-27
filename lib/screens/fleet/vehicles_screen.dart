import 'package:flutter/material.dart';

import '../../data/mock_fleet_data.dart';
import '../../models/vehicle.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_top_bar.dart';
import '../../widgets/vehicle_card.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Tous';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vehicle> get _filteredVehicles {
    final query = _searchController.text.trim().toLowerCase();
    return MockFleetData.sortedVehicles.where((vehicle) {
      final matchesQuery =
          query.isEmpty ||
          vehicle.name.toLowerCase().contains(query) ||
          vehicle.plateNumber.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'Tous' || vehicle.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandTopBar(),
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
                hintText: 'Rechercher un modèle, plaque...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _CategoryChip(
                  label: 'Tous',
                  selected: _selectedCategory == 'Tous',
                  onSelected: _selectCategory,
                ),
                _CategoryChip(
                  label: 'Utilitaires',
                  selected: _selectedCategory == 'Utilitaires',
                  onSelected: _selectCategory,
                ),
                _CategoryChip(
                  label: 'Berline',
                  selected: _selectedCategory == 'Berline',
                  onSelected: _selectCategory,
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

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(label),
      selectedColor: AppColors.surfaceContainer,
      backgroundColor: AppColors.surfaceLowest,
      side: BorderSide(
        color: selected ? AppColors.surfaceContainer : AppColors.outlineVariant,
      ),
      shape: const StadiumBorder(),
    );
  }
}
