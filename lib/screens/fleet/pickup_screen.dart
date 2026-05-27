import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/upload_tile.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key, required this.reservation});

  final FleetReservation reservation;

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mileageController = TextEditingController();
  final _fuelController = TextEditingController();
  bool _hasVideo = false;

  @override
  void dispose() {
    _mileageController.dispose();
    _fuelController.dispose();
    super.dispose();
  }

  void _startTrip() {
    if (!_formKey.currentState!.validate() || !_hasVideo) {
      if (!_hasVideo) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoutez une vidéo de début')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trajet démarré')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Center(child: Text('Prise en charge')),
        actions: const [SizedBox(width: 48)],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _startTrip,
          icon: const Icon(Icons.play_circle),
          label: const Text('Démarrer le trajet'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning, color: AppColors.onErrorContainer),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attention requise',
                            style: TextStyle(
                              color: AppColors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Assurez-vous de bien vérifier l'état des pneus avant le départ. Une intervention est prévue demain.",
                            style: TextStyle(
                              color: AppColors.onErrorContainer,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.reservation.vehicle.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.reservation.vehicle.plateNumber} • ${widget.reservation.vehicle.category}',
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
              ),
              const SizedBox(height: 24),
              const Text(
                'État du véhicule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              UploadTile(
                label: 'Ajouter vidéo de début',
                selected: _hasVideo,
                onTap: () => setState(() => _hasVideo = true),
              ),
              const SizedBox(height: 8),
              const Text(
                'Faites le tour du véhicule pour documenter tout dommage existant.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _mileageController,
                decoration: const InputDecoration(
                  labelText: 'Kilométrage de départ (km)',
                  hintText: 'ex: 45000',
                ),
                keyboardType: TextInputType.number,
                validator: _requiredNumber,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _fuelController,
                decoration: const InputDecoration(
                  labelText: 'Niveau de carburant (litres ou %)',
                  hintText: 'ex: 85',
                ),
                keyboardType: TextInputType.number,
                validator: _requiredNumber,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredNumber(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) {
      return 'Valeur obligatoire';
    }
    return null;
  }
}
