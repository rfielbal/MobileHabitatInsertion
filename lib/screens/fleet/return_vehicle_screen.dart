import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../models/vehicle.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/known_issues_card.dart';
import 'report_issue_screen.dart';

class ReturnVehicleScreen extends StatefulWidget {
  const ReturnVehicleScreen({super.key, required this.reservation});

  final FleetReservation reservation;

  @override
  State<ReturnVehicleScreen> createState() => _ReturnVehicleScreenState();
}

class _ReturnVehicleScreenState extends State<ReturnVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mileageController = TextEditingController();
  final _fuelController = TextEditingController();

  bool _keysReturned = false;
  bool _vehicleClean = false;

  @override
  void dispose() {
    _mileageController.dispose();
    _fuelController.dispose();

    super.dispose();
  }

  void _finishTrip() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trajet terminé')));

    Navigator.of(context).pop();
  }

  String? _validateReturnMileage(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) {
      return 'Kilométrage obligatoire';
    }
    if (number < widget.reservation.expectedStartMileage) {
      return 'Le kilométrage ne peut pas être inférieur au départ';
    }
    return null;
  }

  String? _requiredFuelLevel(String? value) {
    if (!widget.reservation.vehicle.energyType.usesFuelLevel) {
      return null;
    }
    if ((value ?? '').trim().isEmpty) {
      return 'Niveau obligatoire';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retour du véhicule')),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: 'Terminer le trajet',
              onPressed: _finishTrip,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.reservation.vehicle.internalNumber} • ${widget.reservation.vehicle.name}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.reservation.vehicle.site} • ${widget.reservation.vehicle.plateNumber}',
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
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openReportIssue(),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Signaler une anomalie à l’administrateur'),
              ),
              const SizedBox(height: 16),
              KnownIssuesCard(issues: widget.reservation.vehicle.knownIssues),
              const SizedBox(height: 24),
              const Text(
                'Informations de retour',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mileageController,
                decoration: InputDecoration(
                  labelText: 'Kilométrage de retour (km)',
                  hintText:
                      'Départ confirmé : ${widget.reservation.expectedStartMileage} km',
                ),
                keyboardType: TextInputType.number,
                validator: _validateReturnMileage,
              ),
              if (widget.reservation.vehicle.energyType.usesFuelLevel) ...[
                const SizedBox(height: 18),
                TextFormField(
                  controller: _fuelController,
                  decoration: InputDecoration(
                    labelText: 'Niveau de carburant au retour',
                    hintText:
                        'Dernier niveau connu : ${widget.reservation.vehicle.fuelLevelLabel}',
                  ),
                  validator: _requiredFuelLevel,
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'État du véhicule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                "La vidéo est nécessaire uniquement si une anomalie est constatée. Utilisez le bouton de signalement dans ce cas.",
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _keysReturned,
                      onChanged: (value) {
                        setState(() {
                          _keysReturned = value ?? false;
                        });
                      },
                      title: const Text(
                        'Les clés ont été remises à leur place',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: _vehicleClean,
                      onChanged: (value) {
                        setState(() {
                          _vehicleClean = value ?? false;
                        });
                      },
                      title: const Text('Le véhicule est propre et branché'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReportIssue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReportIssueScreen(
          reservation: widget.reservation,
          phaseLabel: 'Retour véhicule',
        ),
      ),
    );
  }
}
