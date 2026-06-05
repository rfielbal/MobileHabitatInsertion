import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../services/reservation_video_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';
import '../../widgets/upload_tile.dart';

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
  final _videoService = ReservationVideoService();
  final _fleetApiService = FleetApiService();

  ReservationVideoDraft? _issueVideo;
  bool _isPreparingVideo = false;
  bool _isUploadingVideo = false;
  bool _isSubmitting = false;
  String _issueType = 'Problème véhicule';

  bool get _hasVideo => _issueVideo != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final video = _issueVideo;

    setState(() {
      _isSubmitting = true;
      _isUploadingVideo = video != null;
    });

    try {
      final message = _descriptionController.text.trim();

      if (video != null) {
        await _fleetApiService.uploadReservationVideo(
          video.copyWith(description: message),
        );
        if (mounted) {
          setState(() {
            _isUploadingVideo = false;
          });
        }
      }

      await _fleetApiService.createSignalement(
        reservation: widget.reservation,
        type: _issueType,
        message: video != null
            ? '$message\n\nVidéo transmise depuis l’application mobile.'
            : message,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signalement envoyé à l’administrateur')),
      );
      Navigator.of(context).pop();
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
      ).showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
    }
  }

  Future<void> _recordIssueVideo() async {
    try {
      setState(() {
        _isPreparingVideo = true;
      });

      final video = await _videoService.recordReservationVideo(
        reservationId: widget.reservation.id,
        kind: _videoKind,
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
        _issueVideo = video;
        _isPreparingVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vidéo ajoutée au signalement')),
      );
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

  ReservationVideoKind get _videoKind {
    return widget.phaseLabel.toLowerCase().contains('retour')
        ? ReservationVideoKind.returnVehicle
        : ReservationVideoKind.departure;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: _isSubmitting ? 'Envoi...' : 'Envoyer le signalement',
              icon: Icons.report_problem_outlined,
              onPressed: _isSubmitting ? null : _sendAlert,
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
                            '${widget.reservation.vehicle.internalNumber} • ${widget.reservation.vehicle.name}',
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
              UploadTile(
                label: 'Ajouter une vidéo si nécessaire',
                selected: _hasVideo,
                processing: _isPreparingVideo || _isUploadingVideo,
                statusText: _isUploadingVideo
                    ? 'Envoi de la vidéo'
                    : 'Préparation de la vidéo',
                onTap: _isSubmitting ? null : _recordIssueVideo,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ajoutez une vidéo uniquement si le problème n’est pas déjà connu ou visible dans les anomalies signalées.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.35,
                ),
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
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _hasVideo
                            ? 'La vidéo est enregistrée avec ce signalement et pourra être transmise à l’administrateur.'
                            : 'Le signalement déclenchera une alerte administrateur. La vidéo reste optionnelle.',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
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
}
