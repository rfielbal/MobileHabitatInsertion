import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/mobile_update.dart';
import 'api_client.dart';
import 'api_exception.dart';

class MobileUpdateDownloadProgress {
  const MobileUpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get ratio {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }

    return (receivedBytes / total).clamp(0, 1).toDouble();
  }
}

class MobileUpdateDownloadService {
  MobileUpdateDownloadService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  static const _apkPath = '/metier/mobile-update/apk';
  static const _apkMimeType = 'application/vnd.android.package-archive';

  final ApiClient _apiClient;

  Future<void> downloadVerifyAndOpen(
    MobileUpdateInfo update, {
    void Function(MobileUpdateDownloadProgress progress)? onProgress,
  }) async {
    final expectedSha256 = update.apkSha256;
    if (!update.updateAvailable) {
      throw const ApiException(message: 'Aucune mise à jour disponible.');
    }

    if (expectedSha256 == null) {
      throw const ApiException(
        message: 'Mise à jour indisponible : empreinte APK manquante.',
      );
    }

    final file = await _targetFile(update);
    await _deleteOldUpdateFiles(file);
    await _apiClient.downloadToFile(
      _apkPath,
      destinationPath: file.path,
      onProgress: (receivedBytes, totalBytes) {
        onProgress?.call(
          MobileUpdateDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes ?? update.apkSizeBytes,
          ),
        );
      },
    );

    await _assertSha256(file, expectedSha256);
    final result = await OpenFilex.open(file.path, type: _apkMimeType);
    if (result.type != ResultType.done) {
      throw ApiException(message: _installErrorMessage(result));
    }
  }

  Future<File> _targetFile(MobileUpdateInfo update) async {
    final directory = await getTemporaryDirectory();
    final versionCode = update.latestVersionCode ?? update.currentVersionCode;

    return File(p.join(directory.path, 'wheello-update-$versionCode.apk'));
  }

  Future<void> _deleteOldUpdateFiles(File targetFile) async {
    final directory = targetFile.parent;
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list()) {
      if (entity is! File || entity.path == targetFile.path) {
        continue;
      }

      final filename = p.basename(entity.path);
      if (!filename.startsWith('wheello-update-') ||
          !filename.endsWith('.apk')) {
        continue;
      }

      try {
        await entity.delete();
      } catch (_) {
        // Un ancien fichier bloqué sera ignoré puis remplacé au prochain passage.
      }
    }
  }

  Future<void> _assertSha256(File file, String expectedSha256) async {
    final digest = await sha256.bind(file.openRead()).first;
    final actualSha256 = digest.toString().toLowerCase();

    if (actualSha256 == expectedSha256.toLowerCase()) {
      return;
    }

    try {
      await file.delete();
    } catch (_) {
      // Le fichier ne doit pas être utilisé, mais sa suppression peut échouer.
    }

    throw const ApiException(
      message: 'Mise à jour refusée : le fichier téléchargé est invalide.',
    );
  }

  String _installErrorMessage(OpenResult result) {
    return switch (result.type) {
      ResultType.noAppToOpen =>
        'Installation impossible : aucun installateur APK disponible.',
      ResultType.permissionDenied =>
        'Installation bloquée : autorisez Wheello à installer des applications depuis cette source.',
      ResultType.fileNotFound =>
        'Installation impossible : le fichier APK téléchargé est introuvable.',
      _ =>
        result.message.isNotEmpty
            ? result.message
            : 'Installation impossible. Réessayez dans un instant.',
    };
  }
}
