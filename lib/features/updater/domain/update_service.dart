import 'package:weekra/features/updater/domain/app_update.dart';

typedef UpdateProgressCallback = void Function(double? progress);

abstract interface class UpdateService {
  Future<AppUpdate?> checkForUpdate();

  Future<void> downloadAndInstall(
    AppUpdate update, {
    UpdateProgressCallback? onProgress,
  });
}
