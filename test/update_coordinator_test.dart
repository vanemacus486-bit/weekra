import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/updater/domain/app_update.dart';
import 'package:weekra/features/updater/domain/update_service.dart';
import 'package:weekra/features/updater/presentation/update_coordinator.dart';
import 'package:weekra/l10n/app_localizations.dart';

void main() {
  testWidgets('failed startup check is visible and manual retry recovers', (
    tester,
  ) async {
    final service = _UpdateService();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: UpdateCoordinator(
          updateService: service,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final state = tester.state<UpdateCoordinatorState>(
      find.byType(UpdateCoordinator),
    );
    expect(service.checks, 1);
    expect(state.status.value, contains('Could not reach'));
    service.fail = false;
    await state.checkForUpdates(userInitiated: true);
    await tester.pumpAndSettle();
    expect(service.checks, 2);
    expect(state.status.value, contains('latest version'));
    await tester.pumpWidget(const SizedBox());
  });
}

class _UpdateService implements UpdateService {
  bool fail = true;
  int checks = 0;
  @override
  Future<AppUpdate?> checkForUpdate() async {
    checks++;
    if (fail) throw Exception('offline');
    return null;
  }

  @override
  Future<void> downloadAndInstall(
    AppUpdate update, {
    UpdateProgressCallback? onProgress,
  }) async {}
}
