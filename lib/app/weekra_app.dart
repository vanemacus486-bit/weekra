import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/presentation/week_screen.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';
import 'package:weekra/features/updater/domain/update_service.dart';
import 'package:weekra/features/updater/presentation/update_coordinator.dart';
import 'package:weekra/l10n/app_localizations.dart';

const _localeOverride = String.fromEnvironment('WEEKRA_LOCALE');
const _updatesDisabled = bool.fromEnvironment('WEEKRA_DISABLE_UPDATES');

class WeekraApp extends StatelessWidget {
  const WeekraApp({
    super.key,
    this.eventStore = const JsonCalendarEventStore(),
    this.fontFamily,
    this.locale,
    this.textScaler,
    this.updateService,
    this.enableAutomaticUpdates = true,
  });

  final CalendarEventStore eventStore;
  final String? fontFamily;
  final Locale? locale;
  final TextScaler? textScaler;
  final UpdateService? updateService;
  final bool enableAutomaticUpdates;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6B5F);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale ?? _localeFromEnvironment(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF15171C),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: UpdateCoordinator(
        updateService: enableAutomaticUpdates
            ? updateService ?? _defaultUpdateService()
            : null,
        child: WeekScreen(eventStore: eventStore),
      ),
    );
  }
}

UpdateService? _defaultUpdateService() {
  if (_updatesDisabled || !Platform.isWindows) {
    return null;
  }
  return WindowsUpdateService();
}

Locale? _localeFromEnvironment() {
  return switch (_localeOverride) {
    'en' => const Locale('en'),
    'zh' => const Locale('zh'),
    'en_XA' => const Locale('en', 'XA'),
    _ => null,
  };
}
