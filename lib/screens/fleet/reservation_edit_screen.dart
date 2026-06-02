import 'package:flutter/material.dart';

import '../../models/reservation.dart';
import '../../services/api_exception.dart';
import '../../services/fleet_api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bottom_action_bar.dart';

class ReservationEditScreen extends StatefulWidget {
  const ReservationEditScreen({super.key, required this.reservation});

  final FleetReservation reservation;

  @override
  State<ReservationEditScreen> createState() => _ReservationEditScreenState();
}

class _ReservationEditScreenState extends State<ReservationEditScreen> {
  final _fleetApiService = FleetApiService();
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = _dateOnly(widget.reservation.startAt);
    _endDate = _dateOnly(widget.reservation.endAt);
    _startTime = TimeOfDay.fromDateTime(widget.reservation.startAt);
    _endTime = TimeOfDay.fromDateTime(widget.reservation.endAt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la réservation')),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: BottomActionButton(
              label: 'Annuler',
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              outlined: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BottomActionButton(
              label: _isSubmitting ? 'Enregistrement...' : 'Enregistrer',
              onPressed: _isSubmitting ? null : _save,
            ),
          ),
        ],
      ),
      body: SafeArea(
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
                      color: AppColors.primaryFixed,
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
                        const SizedBox(height: 4),
                        Text(
                          '${widget.reservation.vehicle.plateNumber} • ${widget.reservation.location}',
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
            const Text(
              'Nouvelle période',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _EditableRow(
                    icon: Icons.event_outlined,
                    label: 'Date de départ',
                    value: _formatDate(_startDate),
                    onTap: () => _pickDate(isStart: true),
                  ),
                  const Divider(height: 24),
                  _EditableRow(
                    icon: Icons.schedule,
                    label: 'Heure de départ',
                    value: _startTime.format(context),
                    onTap: () => _pickTime(isStart: true),
                  ),
                  const Divider(height: 24),
                  _EditableRow(
                    icon: Icons.event_available_outlined,
                    label: 'Date de retour',
                    value: _formatDate(_endDate),
                    onTap: () => _pickDate(isStart: false),
                  ),
                  const Divider(height: 24),
                  _EditableRow(
                    icon: Icons.schedule,
                    label: 'Heure de retour',
                    value: _endTime.format(context),
                    onTap: () => _pickTime(isStart: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Cette modification sera reliée à l’API métier pour vérifier les conflits de réservation.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) {
          final oldStart = _startDate;
          _startDate = _endDate;
          _endDate = oldStart;
        }
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final startAt = _mergeDateAndTime(_startDate, _startTime);
    final endAt = _mergeDateAndTime(_endDate, _endTime);

    if (!startAt.isBefore(endAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La date de départ doit être avant la date de retour'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _fleetApiService.updateReservation(
        reservation: widget.reservation,
        startAt: startAt,
        endAt: endAt,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Réservation modifiée')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
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
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Modification impossible : $e')));
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _mergeDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
