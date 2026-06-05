import 'package:image_picker/image_picker.dart';

enum ReservationVideoKind {
  departure(apiValue: 'depart', label: 'début'),
  returnVehicle(apiValue: 'arrive', label: 'retour');

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
    this.description = '',
  });

  final String reservationId;
  final ReservationVideoKind kind;
  final XFile file;
  final DateTime capturedAt;
  final String description;

  ReservationVideoDraft copyWith({String? description}) {
    return ReservationVideoDraft(
      reservationId: reservationId,
      kind: kind,
      file: file,
      capturedAt: capturedAt,
      description: description ?? this.description,
    );
  }

  Map<String, String> get multipartFields {
    return {
      'reservationId': reservationId,
      'type': kind.apiValue,
      'description': description,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }
}

class ReservationVideoUpload {
  const ReservationVideoUpload({
    required this.kind,
    required this.type,
    required this.description,
    required this.nomFichier,
    required this.taille,
    this.id,
    this.chemin,
    this.url,
    this.capturedAt,
  });

  final ReservationVideoKind kind;
  final String type;
  final String description;
  final String nomFichier;
  final String taille;
  final String? id;
  final String? chemin;
  final String? url;
  final DateTime? capturedAt;

  Map<String, dynamic> toConstatPayload() {
    return {
      'nomFichier': nomFichier,
      'taille': taille,
      'type': type,
      'description': description,
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
    String description = '',
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
      description: description,
    );
  }
}
