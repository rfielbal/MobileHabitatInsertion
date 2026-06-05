import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../models/vehicle.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../services/reservation_video_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/known_issues_card.dart';
import '../../widgets/upload_tile.dart';
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
  final _fleetApiService = FleetApiService();
  final _videoService = ReservationVideoService();

  ReservationVideoDraft? _returnVideo;
  bool _keysReturned = false;
  bool _vehicleClean = false;
  bool _isPreparingVideo = false;
  bool _isUploadingVideo = false;
  bool _isSubmitting = false;

  bool get _hasReturnVideo => _returnVideo != null;

  @override
  void dispose() {
    _mileageController.dispose();
    _fuelController.dispose();

    super.dispose();
  }

  Future<void> _finishTrip() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_returnVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez une vidéo de retour')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isUploadingVideo = true;
    });

    try {
      await _fleetApiService.finishConstat(
        reservation: widget.reservation,
        mileage: int.parse(_mileageController.text.trim()),
        returnVideo: _returnVideo,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trajet terminé')));

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _isUploadingVideo = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _isUploadingVideo = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retour impossible : $e')));
    }
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

  Future<void> _recordReturnVideo() async {
    try {
      setState(() {
        _isPreparingVideo = true;
      });

      final video = await _videoService.recordReservationVideo(
        reservationId: widget.reservation.id,
        kind: ReservationVideoKind.returnVehicle,
        description: _returnVideoDescription,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _returnVideo = video ?? _returnVideo;
        _isPreparingVideo = false;
      });

      if (video != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vidéo de retour ajoutée')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingVideo = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur vidéo : $e')));
    }
  }

  String get _returnVideoDescription {
    return 'Vidéo de retour du véhicule ${widget.reservation.vehicle.internalNumber} pour la réservation ${widget.reservation.id}.';
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
              label: _isSubmitting ? 'Finalisation...' : 'Terminer le trajet',
              onPressed: _isSubmitting ? null : _finishTrip,
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
              UploadTile(
                label: 'Filmer l’état au retour',
                selected: _hasReturnVideo,
                processing: _isPreparingVideo || _isUploadingVideo,
                statusText: _isUploadingVideo
                    ? 'Envoi de la vidéo'
                    : 'Préparation de la vidéo',
                onTap: _isSubmitting ? null : _recordReturnVideo,
              ),
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
