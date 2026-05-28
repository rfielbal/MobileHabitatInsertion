import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({
    super.key,
    required this.reservation,
    required this.phaseLabel,
  });

  final FleetReservation reservation;
  final String phaseLabel;

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _issueType = 'Problème véhicule';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _sendAlert() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signalement envoyé à l’administrateur')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: 'Envoyer le signalement',
              icon: Icons.report_problem_outlined,
              onPressed: _sendAlert,
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
              AppCard(
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber,
                        color: AppColors.error,
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
                          const SizedBox(height: 4),
                          Text(
                            '${widget.phaseLabel} • ${widget.reservation.vehicle.plateNumber}',
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
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _issueType,
                decoration: const InputDecoration(
                  labelText: 'Type de problème',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Problème véhicule',
                    child: Text('Problème véhicule'),
                  ),
                  DropdownMenuItem(
                    value: 'Clés indisponibles',
                    child: Text('Clés indisponibles'),
                  ),
                  DropdownMenuItem(
                    value: 'Kilométrage incohérent',
                    child: Text('Kilométrage incohérent'),
                  ),
                  DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _issueType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Décrivez le problème pour l’administrateur',
                ),
                minLines: 4,
                maxLines: 6,
                validator: (value) {
                  if ((value ?? '').trim().length < 10) {
                    return 'Décrivez le problème en quelques mots';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const AppCard(
                child: Text(
                  'Le signalement sera relié à la réservation et visible côté administration lorsque l’API sera branchée.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
