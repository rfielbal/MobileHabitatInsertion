import '../models/reservation.dart';
import '../models/vehicle.dart';
import 'reservation_calendar_days.dart';

DateTime suggestedReservationStartAt({
  required DateTime date,
  required Map<int, VehicleAvailabilitySuggestion> suggestionsByDay,
  List<FleetReservation> userReservations = const [],
  String? excludedReservationId,
  DateTime? now,
}) {
  final dayStart = _dayStart(date);
  final currentTime = now ?? DateTime.now();
  final nowPlusTurnaround = currentTime.add(reservationTurnaroundDuration);
  var suggestion = _latestDate(
    earliestReservationStartAt(date: date, suggestionsByDay: suggestionsByDay),
    earliestUserReservationStartAt(
      date: date,
      userReservations: userReservations,
      excludedReservationId: excludedReservationId,
    ),
  );

  suggestion ??= _sameDay(dayStart, currentTime) ? nowPlusTurnaround : dayStart;

  if (_sameDay(dayStart, currentTime) &&
      suggestion.isBefore(nowPlusTurnaround)) {
    return nowPlusTurnaround;
  }

  return suggestion;
}

DateTime suggestedReservationEndAt({
  required DateTime date,
  required Map<int, VehicleAvailabilitySuggestion> suggestionsByDay,
  DateTime? startAt,
  List<FleetReservation> userReservations = const [],
  String? excludedReservationId,
}) {
  final latestEndAt = latestReservationEndAt(
    date: date,
    suggestionsByDay: suggestionsByDay,
    userReservations: userReservations,
    excludedReservationId: excludedReservationId,
  );

  if (startAt != null && _sameDay(startAt, date)) {
    final sameDayEndAt = startAt.add(reservationTurnaroundDuration);
    if (latestEndAt != null && latestEndAt.isBefore(sameDayEndAt)) {
      return latestEndAt;
    }

    return sameDayEndAt;
  }

  return latestEndAt ?? _dayStart(date);
}

DateTime? earliestReservationStartAt({
  required DateTime date,
  required Map<int, VehicleAvailabilitySuggestion> suggestionsByDay,
}) {
  final suggestion = suggestionsByDay[date.day]?.earliestStartAt;
  if (suggestion == null || !_sameDay(suggestion, date)) {
    return null;
  }

  return suggestion;
}

DateTime? latestReservationEndAt({
  required DateTime date,
  required Map<int, VehicleAvailabilitySuggestion> suggestionsByDay,
  List<FleetReservation> userReservations = const [],
  String? excludedReservationId,
}) {
  DateTime? latestEndAt = suggestionsByDay[date.day]?.latestEndAt;
  if (latestEndAt != null && !_sameDay(latestEndAt, date)) {
    latestEndAt = null;
  }

  for (final reservation in userReservations) {
    if (reservation.id == excludedReservationId || reservation.isInHistory) {
      continue;
    }

    final latestUserEndAt = reservation.startAt.subtract(
      reservationTurnaroundDuration,
    );
    if (!_sameDay(latestUserEndAt, date)) {
      continue;
    }

    if (latestEndAt == null || latestUserEndAt.isBefore(latestEndAt)) {
      latestEndAt = latestUserEndAt;
    }
  }

  return latestEndAt;
}

bool reservationStartViolatesEarliestStart({
  required DateTime startAt,
  required Map<int, VehicleAvailabilitySuggestion> suggestionsByDay,
  List<FleetReservation> userReservations = const [],
  String? excludedReservationId,
}) {
  final earliestStartAt = _latestDate(
    earliestReservationStartAt(
      date: startAt,
      suggestionsByDay: suggestionsByDay,
    ),
    earliestUserReservationStartAt(
      date: startAt,
      userReservations: userReservations,
      excludedReservationId: excludedReservationId,
    ),
  );

  return earliestStartAt != null && startAt.isBefore(earliestStartAt);
}

bool reservationEndViolatesLatestEnd({
  required DateTime endAt,
  required Map<int, VehicleAvailabilitySuggestion> suggestionsByDay,
  List<FleetReservation> userReservations = const [],
  String? excludedReservationId,
}) {
  final latestEndAt = latestReservationEndAt(
    date: endAt,
    suggestionsByDay: suggestionsByDay,
    userReservations: userReservations,
    excludedReservationId: excludedReservationId,
  );

  return latestEndAt != null && endAt.isAfter(latestEndAt);
}

DateTime? earliestUserReservationStartAt({
  required DateTime date,
  List<FleetReservation> userReservations = const [],
  String? excludedReservationId,
}) {
  DateTime? earliestStartAt;

  for (final reservation in userReservations) {
    if (reservation.id == excludedReservationId || reservation.isInHistory) {
      continue;
    }

    final nextUserStartAt = reservation.effectiveEndAt.add(
      reservationTurnaroundDuration,
    );
    if (!_sameDay(nextUserStartAt, date)) {
      continue;
    }

    earliestStartAt = _latestDate(earliestStartAt, nextUserStartAt);
  }

  return earliestStartAt;
}

DateTime? _latestDate(DateTime? first, DateTime? second) {
  if (first == null) {
    return second;
  }
  if (second == null) {
    return first;
  }

  return second.isAfter(first) ? second : first;
}

DateTime _dayStart(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
