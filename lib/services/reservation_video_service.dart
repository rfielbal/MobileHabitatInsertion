import 'package:image_picker/image_picker.dart';

enum ReservationVideoKind {
  departure(apiValue: 'depart', label: 'début'),
  returnVehicle(apiValue: 'retour', label: 'fin');

  const ReservationVideoKind({required this.apiValue, required this.label});

  final String apiValue;
  final String label;
}

class ReservationVideoDraft {
  const ReservationVideoDraft({
    required this.reservationId,
    required this.kind,
    required this.file,
    required this.capturedAt,
  });

  final String reservationId;
  final ReservationVideoKind kind;
  final XFile file;
  final DateTime capturedAt;

  Map<String, String> get multipartFields {
    return {
      'reservationId': reservationId,
      'type': kind.apiValue,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}

class ReservationVideoService {
  ReservationVideoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<ReservationVideoDraft?> recordReservationVideo({
    required String reservationId,
    required ReservationVideoKind kind,
    Duration maxDuration = const Duration(minutes: 1),
  }) async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration,
    );

    if (file == null) {
      return null;
    }

    return ReservationVideoDraft(
      reservationId: reservationId,
      kind: kind,
      file: file,
      capturedAt: DateTime.now(),
    );
  }
}
