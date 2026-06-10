import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

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

class ReservationVideoTooLargeException implements Exception {
  const ReservationVideoTooLargeException({
    required this.actualBytes,
    required this.maxBytes,
  });

  final int actualBytes;
  final int maxBytes;

  String get message {
    return 'La vidéo est trop lourde (${_formatBytes(actualBytes)}). '
        'La limite mobile est de ${_formatBytes(maxBytes)} pour rester sous la limite serveur. '
        'Réduisez la durée de la vidéo puis réessayez.';
  }

  @override
  String toString() => message;

  static String _formatBytes(int bytes) {
    final megaBytes = bytes / (1024 * 1024);
    return '${megaBytes.toStringAsFixed(1)} Mo';
  }
}

class ReservationVideoUpload {
  const ReservationVideoUpload({
    required this.kind,
    required this.type,
    required this.description,
    required this.nomFichier,
    required this.taille,
    required this.mimeType,
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
  final String mimeType;
  final String? id;
  final String? chemin;
  final String? url;
  final DateTime? capturedAt;

  Map<String, dynamic> toConstatPayload() {
    return {
      'nomFichier': nomFichier,
      'taille': taille,
      'mimeType': mimeType,
      'type': type,
      'description': description,
    };
  }

  Map<String, dynamic> toSignalementPayload() {
    return {
      'nomFichier': nomFichier,
      'taille': taille,
      'mimeType': mimeType,
      'type': type,
      'description': description,
      'context': kind.apiValue,
    };
  }
}

class ReservationVideoService {
  ReservationVideoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  // The production PHP server currently rejects multipart bodies above 8 MB.
  // Keep 1 MB of headroom for fields and multipart boundaries.
  static const serverPostLimitBytes = 8 * 1024 * 1024;
  static const uploadSafetyMarginBytes = 1 * 1024 * 1024;
  static const maxUploadBytes = serverPostLimitBytes - uploadSafetyMarginBytes;
  static const compressionThresholdBytes = maxUploadBytes;
  static const defaultMaxDuration = Duration(seconds: 30);

  final ImagePicker _picker;

  Future<ReservationVideoDraft?> recordReservationVideo({
    required String reservationId,
    required ReservationVideoKind kind,
    String description = '',
    Duration maxDuration = defaultMaxDuration,
    void Function(double progress)? onCompressionProgress,
  }) async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: maxDuration,
    );

    if (file == null) {
      return null;
    }

    final preparedFile = await _prepareVideoForUpload(
      file,
      onCompressionProgress: onCompressionProgress,
    );

    return ReservationVideoDraft(
      reservationId: reservationId,
      kind: kind,
      file: preparedFile,
      capturedAt: DateTime.now(),
      description: description,
    );
  }

  Future<XFile> _prepareVideoForUpload(
    XFile file, {
    void Function(double progress)? onCompressionProgress,
  }) async {
    final originalSize = await file.length();
    var uploadFile = file;

    if (originalSize > compressionThresholdBytes) {
      uploadFile =
          await _compressedVideo(file, onCompressionProgress) ?? uploadFile;
    }

    final uploadSize = await uploadFile.length();
    if (uploadSize > maxUploadBytes) {
      throw ReservationVideoTooLargeException(
        actualBytes: uploadSize,
        maxBytes: maxUploadBytes,
      );
    }

    return uploadFile;
  }

  Future<XFile?> _compressedVideo(
    XFile file,
    void Function(double progress)? onCompressionProgress,
  ) async {
    Subscription? subscription;
    if (onCompressionProgress != null) {
      subscription = VideoCompress.compressProgress$.subscribe((progress) {
        onCompressionProgress((progress / 100).clamp(0, 1).toDouble());
      });
    }

    try {
      final compressed = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24,
      );
      final compressedPath = compressed?.path;
      if (compressedPath == null || compressedPath.trim().isEmpty) {
        return null;
      }

      final compressedFile = File(compressedPath);
      if (!await compressedFile.exists()) {
        return null;
      }

      final compressedSize = await compressedFile.length();
      final originalSize = await file.length();
      if (compressedSize <= 0 || compressedSize >= originalSize) {
        return null;
      }

      return XFile(compressedPath);
    } finally {
      subscription?.unsubscribe();
    }
  }
}
