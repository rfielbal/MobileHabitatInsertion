import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/reservation.dart';
import '../models/vehicle.dart';
import '../theme/app_colors.dart';

class ApiNotificationPayload {
  const ApiNotificationPayload({
    required this.notification,
    required this.read,
  });

  final AppNotification notification;
  final bool read;
}

class FleetApiMappers {
  const FleetApiMappers._();

  static const _peugeotImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCxpRQJXrqL-wN7xx1p1bkH1cNCYmWMRVsYSo-19HMwsjfzN3l1ASoOmMoBGheYEb4pYB7v6bLzPE0Khw6Sp9lIWDJgzo4xhnVDxekG-s69GoIMlTA_fevIFbqutRwpZ1reWtBzup3XE_oBY6kUqZAM-rYYBBvtM3ZMPUV4YIT7GdQlfIKjITFV7ZMlsR3WeD8C1o_Z6eN6_I7MCVLDV8RFzr_Tu-e-5vSKSbvs2qCBnCc9WSrc_fQS2Ag1XbFBeLGltLq4BSpq5SA';
  static const _renaultImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBiyM9r4xFyExLo0IIX3GlqmuTF0PnSgWaJt0ryFZ-P4Ih9uQRXQErs8ma7f4humcwYlfsI0ei3ca95sXj3bCagMQuH0O3U_E6YtDx13pxuPcWelzASUonT_JzZmTpCIdlPVlToKTAmLVp0nWI1lHddO6WEt4-y0lemSZezL9IjCaGOorvjyXJ7_xh5ft8D7G0xmd8F2Dez6G8LqwfQVI9wgRwpgNuhyvnkabFWnNDrdIaLJNimSNxBjMvftejZzksHyPvBuhjbLa4';
  static const _defaultImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA6ikFZGTeJ3t9WXCFzs7QwE5RmxmwhmMrds9cT1VeSWC3GFSzCBROKnxFnyM1LRabjlF6lJtD9ucTNVdDwCdI7OETAE5V7knOoGDxZGbOPbZDWiablFhqNU86OjVAxbgut_wOybL7J2XHHLPKryrp8ZuP9riYBpAx7lxTmF9UU0QqsmPHpV288g8AiZbGp14UQh-Q61-qCzGqoSywRIadaNzwYEBHSMPlkEnCPE2Nu2IcOAFVK07ZTkxL2Wf9xpDtxQnHAj3tarac';

  static Vehicle vehicleFromJson(Map<String, dynamic> json) {
    final id = _text(json['id'], fallback: '0');
    final brand = _text(json['marque'], fallback: 'Véhicule');
    final model = _text(json['modele'], fallback: 'Non renseigné');
    final plateNumber = _text(json['immatriculation'], fallback: 'N/A');
    final status = _vehicleStatus(json['status']);
    final sites = _listOfMaps(json['sites']);
    final firstSite = sites.isEmpty ? null : sites.first;
    final siteName = _siteLabel(firstSite);
    final internalNumber = _internalNumber(json['numVehicule'], id);
    final description = _text(
      json['descriptif'],
      fallback: 'Stationnement non renseigné',
    );
    final energyType = _energyType('$brand $model $description');

    return Vehicle(
      id: id,
      internalNumber: internalNumber,
      name: '$brand $model',
      brand: brand,
      model: model,
      plateNumber: plateNumber,
      category: 'Flotte',
      status: status,
      subtitle: status.label,
      imageUrl: _imageForBrand(brand),
      location: siteName,
      site: siteName,
      parkingDescription: description,
      seats: 'Non renseigné',
      transmission: 'Non renseignée',
      energyType: energyType,
      energyInfo: energyType.label,
      currentMileage: 0,
      fuelLevelLabel: energyType == VehicleEnergyType.electric
          ? 'Batterie non renseignée'
          : 'Non renseigné',
      priorityRank: status.sortRank,
      nextAvailableAt: DateTime.now(),
      availabilityByDay: const {},
      knownIssues: status == VehicleStatus.maintenance
          ? const [
              VehicleIssue(
                title: 'Véhicule en maintenance',
                description: 'Indisponibilité définie depuis l’administration.',
                reportedAtLabel: 'Donnée API',
                requiresAttention: true,
              ),
            ]
          : const [],
    );
  }

  static FleetReservation reservationFromJson(Map<String, dynamic> json) {
    final vehicleJson = json['vehicule'];
    final vehicle = vehicleJson is Map<String, dynamic>
        ? vehicleFromJson(vehicleJson)
        : vehicleFromJson(const {});
    final startAt = _date(json['dateDebut']) ?? DateTime.now();
    final endAt =
        _date(json['dateFin']) ?? startAt.add(const Duration(hours: 1));
    final returnedAt = reservationReturnedAt(json);
    final createdAt =
        _date(json['createdAt']) ??
        _date(json['created_at']) ??
        _date(json['dateCreation']) ??
        _date(json['dateReservation']) ??
        _date(json['creeLe']);

    return FleetReservation(
      id: _text(json['id'], fallback: '0'),
      vehicle: vehicle,
      location: vehicle.location,
      startAt: startAt,
      endAt: endAt,
      startLabel: _reservationDateLabel(startAt),
      endLabel: _reservationDateLabel(endAt),
      status: _reservationStatus(startAt, endAt, _reservationStatusValue(json)),
      expectedStartMileage: vehicle.currentMileage,
      createdAt: createdAt,
      hasOpenConstat: reservationHasOpenConstat(json),
      hasClosedConstat: reservationHasClosedConstat(json),
      returnedAt: returnedAt,
    );
  }

  static DateTime? reservationReturnedAt(Map<String, dynamic> json) {
    final directReturn =
        _date(json['dateRendu']) ??
        _date(json['dateRetour']) ??
        _date(json['dateFinReelle']) ??
        _date(json['dateFinEffective']) ??
        _date(json['finEffective']) ??
        _date(json['returned_at']) ??
        _date(json['returnedAt']) ??
        _date(json['closedAt']) ??
        _date(json['termineLe']);
    if (directReturn != null) {
      return directReturn;
    }

    final constat = json['constat'];
    if (constat is Map<String, dynamic> && _constatIsClosed(constat)) {
      return _constatReturnedAt(constat);
    }

    for (final constat in _listOfMaps(json['constats'])) {
      if (_constatIsClosed(constat)) {
        final returnedAt = _constatReturnedAt(constat);
        if (returnedAt != null) {
          return returnedAt;
        }
      }
    }

    return null;
  }

  static bool reservationHasOpenConstat(Map<String, dynamic> json) {
    final directValue =
        json['constatOuvert'] ??
        json['hasOpenConstat'] ??
        json['estOuvert'] ??
        json['openConstat'];

    if (directValue is bool) {
      return directValue;
    }

    final constat = json['constat'];
    if (constat is Map<String, dynamic> && _constatIsOpen(constat)) {
      return true;
    }

    for (final constat in _listOfMaps(json['constats'])) {
      if (_constatIsOpen(constat)) {
        return true;
      }
    }

    return false;
  }

  static bool reservationHasClosedConstat(Map<String, dynamic> json) {
    final directValue =
        json['constatFerme'] ??
        json['hasClosedConstat'] ??
        json['retourConfirme'] ??
        json['returnConfirmed'] ??
        json['constatTermine'];

    if (directValue is bool) {
      return directValue;
    }

    final constat = json['constat'];
    if (constat is Map<String, dynamic> && _constatIsClosed(constat)) {
      return true;
    }

    for (final constat in _listOfMaps(json['constats'])) {
      if (_constatIsClosed(constat)) {
        return true;
      }
    }

    return false;
  }

  static ApiNotificationPayload notificationFromJson(
    Map<String, dynamic> json,
  ) {
    final type = _text(json['type'], fallback: 'notification');

    return ApiNotificationPayload(
      read: json['lu'] == true,
      notification: AppNotification(
        id: int.tryParse(_text(json['id'], fallback: '0')) ?? 0,
        title: _text(json['objet'], fallback: 'Notification'),
        body: _text(json['message'], fallback: ''),
        timeLabel: _relativeDateLabel(_date(json['date'])),
        icon: _notificationIcon(type),
        color: _notificationColor(type),
      ),
    );
  }

  static String siteLabelFromJson(Map<String, dynamic> json) {
    return _siteLabel(json);
  }

  static List<Map<String, dynamic>> itemsFromResponse(Object? response) {
    if (response is List) {
      return _listOfMaps(response);
    }

    if (response is! Map<String, dynamic>) {
      return const [];
    }

    return _listOfMaps(
      response['items'] ??
          response['hydra:member'] ??
          response['member'] ??
          response['data'] ??
          response['results'] ??
          response['reservations'] ??
          response['vehicules'] ??
          response['sites'] ??
          response['notifications'] ??
          response['constats'],
    );
  }

  static String iso(DateTime date) => date.toUtc().toIso8601String();

  static String _internalNumber(Object? value, String id) {
    final parsed = int.tryParse(_text(value));
    if (parsed != null && parsed > 0) {
      return 'V-${parsed.toString().padLeft(3, '0')}';
    }
    return 'V-$id';
  }

  static VehicleStatus _vehicleStatus(Object? value) {
    return switch (_text(value).toLowerCase()) {
      'en_utilisation' || 'en usage' || 'usage' => VehicleStatus.inUse,
      'maintenance' || 'en_maintenance' => VehicleStatus.maintenance,
      'partiel' ||
      'partiellement_disponible' ||
      'partial' => VehicleStatus.available,
      _ => VehicleStatus.available,
    };
  }

  static VehicleEnergyType _energyType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('hybrid') || lower.contains('hybride')) {
      return VehicleEnergyType.hybrid;
    }
    if (lower.contains('diesel') ||
        lower.contains('essence') ||
        lower.contains('thermique')) {
      return VehicleEnergyType.thermal;
    }
    return VehicleEnergyType.electric;
  }

  static ReservationStatus _reservationStatus(
    DateTime startAt,
    DateTime endAt,
    Object? apiStatus,
  ) {
    final status = _text(apiStatus).toLowerCase();
    final now = DateTime.now();

    if (status.contains('term') ||
        status.contains('fini') ||
        status.contains('clos') ||
        status.contains('completed') ||
        status.contains('done')) {
      return ReservationStatus.completed;
    }
    if (_sameDay(startAt, now)) {
      return ReservationStatus.pickupToday;
    }
    if (_sameDay(endAt, now) ||
        endAt.isBefore(now) ||
        (startAt.isBefore(now) && endAt.isAfter(now))) {
      return ReservationStatus.returnToday;
    }
    return ReservationStatus.upcoming;
  }

  static Object? _reservationStatusValue(Map<String, dynamic> json) {
    return json['statue'] ??
        json['statut'] ??
        json['statu'] ??
        json['status'] ??
        json['state'] ??
        json['etat'];
  }

  static String _reservationDateLabel(DateTime date) {
    final day = _weekDays[date.weekday - 1];
    final month = _months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day ${date.day.toString().padLeft(2, '0')} $month, $hour:$minute';
  }

  static String _relativeDateLabel(DateTime? date) {
    if (date == null) {
      return 'Date inconnue';
    }

    final now = DateTime.now();
    if (_sameDay(date, now)) {
      return 'Aujourd’hui';
    }
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Hier';
    }
    return '${_weekDays[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]}';
  }

  static IconData _notificationIcon(String type) {
    return switch (type) {
      'reservation' => Icons.event_available,
      'constat' => Icons.assignment_turned_in_outlined,
      'signalement' => Icons.warning_amber,
      'mdp' => Icons.lock_reset,
      _ => Icons.notifications_none,
    };
  }

  static Color _notificationColor(String type) {
    return switch (type) {
      'signalement' => AppColors.maintenance,
      'constat' => AppColors.available,
      _ => AppColors.primary,
    };
  }

  static String _imageForBrand(String brand) {
    final lower = brand.toLowerCase();
    if (lower.contains('peugeot')) {
      return _peugeotImage;
    }
    if (lower.contains('renault')) {
      return _renaultImage;
    }
    return _defaultImage;
  }

  static String _siteLabel(Map<String, dynamic>? site) {
    if (site == null) {
      return 'Affectation non renseignée';
    }

    final nom = _text(site['nom']);
    final ville = _text(site['ville']);

    if (nom.isEmpty && ville.isEmpty) {
      return 'Affectation non renseignée';
    }
    if (nom.isEmpty) {
      return ville;
    }
    if (ville.isEmpty || nom == ville) {
      return nom;
    }
    return '$nom - $ville';
  }

  static List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const [];
    }

    return [
      for (final item in value)
        if (item is Map<String, dynamic>) item,
    ];
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _constatIsClosed(Map<String, dynamic> constat) {
    if (constat['estOuvert'] == false) {
      return true;
    }
    if (_hasFinalMileage(constat)) {
      return true;
    }

    return _date(
          constat['dateRendu'] ??
              constat['dateRetour'] ??
              constat['returnedAt'] ??
              constat['closedAt'] ??
              constat['termineLe'],
        ) !=
        null;
  }

  static bool _constatIsOpen(Map<String, dynamic> constat) {
    final explicitOpen =
        constat['estOuvert'] ??
        constat['constatOuvert'] ??
        constat['open'] ??
        constat['isOpen'];

    if (explicitOpen is bool) {
      return explicitOpen;
    }

    final status = _text(
      constat['statut'] ??
          constat['statue'] ??
          constat['statu'] ??
          constat['status'] ??
          constat['state'] ??
          constat['etat'],
    ).toLowerCase();

    if (status.contains('term') ||
        status.contains('fini') ||
        status.contains('clos') ||
        status.contains('completed') ||
        status.contains('done')) {
      return false;
    }

    if (status.contains('ouvert') ||
        status.contains('open') ||
        status.contains('cours') ||
        status.contains('progress') ||
        status.contains('demarr') ||
        status.contains('démarr') ||
        status.contains('active')) {
      return true;
    }

    final pickedUpAt =
        _date(
          constat['datePrise'] ??
              constat['dateDepart'] ??
              constat['pickedUpAt'] ??
              constat['startedAt'] ??
              constat['demarreLe'],
        ) !=
        null;

    return pickedUpAt && !_constatIsClosed(constat);
  }

  static bool _hasFinalMileage(Map<String, dynamic> constat) {
    return _text(
      constat['kmFin'] ??
          constat['kilometrageFin'] ??
          constat['kilometrageRetour'] ??
          constat['mileageEnd'],
    ).isNotEmpty;
  }

  static DateTime? _constatReturnedAt(Map<String, dynamic> constat) {
    return _date(
      constat['dateRendu'] ??
          constat['dateRetour'] ??
          constat['returnedAt'] ??
          constat['closedAt'] ??
          constat['termineLe'],
    );
  }

  static const _weekDays = [
    'Lun.',
    'Mar.',
    'Mer.',
    'Jeu.',
    'Ven.',
    'Sam.',
    'Dim.',
  ];
  static const _months = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Août',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];
}
