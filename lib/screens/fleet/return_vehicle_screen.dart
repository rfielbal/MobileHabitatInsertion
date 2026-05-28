import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../services/reservation_video_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';
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
  final _videoService = ReservationVideoService();

  ReservationVideoDraft? _returnVideo;
  bool _isPreparingVideo = false;
  bool _keysReturned = false;
  bool _vehicleClean = false;

  bool get _hasVideo => _returnVideo != null;

  @override
  void dispose() {
    _mileageController.dispose();

    super.dispose();
  }

  void _finishTrip() {
    if (!_formKey.currentState!.validate() || !_hasVideo) {
      if (!_hasVideo) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoutez une vidéo de fin')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trajet terminé')));

    Navigator.of(context).pop();
  }

  Future<void> _recordVideo() async {
    try {
      setState(() {
        _isPreparingVideo = true;
      });

      final video = await _videoService.recordReservationVideo(
        reservationId: widget.reservation.id,
        kind: ReservationVideoKind.returnVehicle,
      );

      if (video == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPreparingVideo = false;
        });
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _returnVideo = video;
        _isPreparingVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vidéo ajoutée avec succès')),
      );

      debugPrint('Vidéo de retour prête pour upload API : ${video.file.path}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPreparingVideo = false;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur vidéo : $e')));
      }
    }
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
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openReportIssue(),
                icon: const Icon(Icons.report_problem_outlined),
                label: const Text('Signaler un problème à l’administrateur'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Informations de retour',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mileageController,
                decoration: const InputDecoration(
                  labelText: 'Kilométrage de retour (km)',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final number = int.tryParse(value?.trim() ?? '');
                  if (number == null || number <= 0) {
                    return 'Kilométrage obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'État du véhicule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                "Veuillez filmer l'extérieur et l'intérieur du véhicule pour valider son état.",
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              UploadTile(
                label: 'Ajouter vidéo de fin',
                selected: _hasVideo,
                processing: _isPreparingVideo,
                statusText: 'Préparation de la vidéo de fin',
                large: true,
                onTap: _recordVideo,
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
