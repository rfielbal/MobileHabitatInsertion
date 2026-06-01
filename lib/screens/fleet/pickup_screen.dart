import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../models/vehicle.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/known_issues_card.dart';
import 'report_issue_screen.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key, required this.reservation});

  final FleetReservation reservation;

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fuelController = TextEditingController();
  bool _mileageConfirmed = false;

  @override
  void dispose() {
    _fuelController.dispose();

    super.dispose();
  }

  void _startTrip() {
    if (!_formKey.currentState!.validate() || !_mileageConfirmed) {
      if (!_mileageConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirmez le kilométrage affiché')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trajet démarré')));

    Navigator.of(context).pop();
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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Center(child: Text('Prise en charge')),
        actions: const [SizedBox(width: 48)],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: 'Démarrer le trajet',
              icon: Icons.play_circle,
              onPressed: _startTrip,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              OutlinedButton.icon(
                onPressed: () => _openReportIssue(),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Signaler une anomalie à l’administrateur'),
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
              const SizedBox(height: 24),
              KnownIssuesCard(issues: widget.reservation.vehicle.knownIssues),
              const SizedBox(height: 24),
              const Text(
                'Kilométrage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dernier kilométrage connu',
                      style: TextStyle(
                        color: AppColors.outline,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.reservation.expectedStartMileage} km',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _mileageConfirmed,
                      onChanged: (value) {
                        setState(() {
                          _mileageConfirmed = value ?? false;
                        });
                      },
                      title: const Text('Je confirme ce kilométrage'),
                      subtitle: const Text(
                        'En cas d’écart, signalez une anomalie à l’administrateur.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La vidéo n’est demandée que si une anomalie est constatée.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              if (widget.reservation.vehicle.energyType.usesFuelLevel) ...[
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fuelController,
                  decoration: InputDecoration(
                    labelText: 'Niveau de carburant',
                    hintText:
                        'Dernier niveau connu : ${widget.reservation.vehicle.fuelLevelLabel}',
                  ),
                  keyboardType: TextInputType.text,
                  validator: _requiredFuelLevel,
                ),
              ],
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
          phaseLabel: 'Prise en charge',
        ),
      ),
    );
  }
}
