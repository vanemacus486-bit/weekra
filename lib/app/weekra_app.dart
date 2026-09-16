import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:weekra/app/weekra_design.dart';
import 'package:weekra/app/glass_surface.dart';
import 'package:weekra/app/weekra_theme.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/presentation/week_screen.dart';
import 'package:weekra/features/settings/data/app_settings_store.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';
import 'package:weekra/features/settings/presentation/settings_panel.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';
import 'package:weekra/features/updater/domain/update_service.dart';
import 'package:weekra/features/updater/presentation/update_coordinator.dart';
import 'package:weekra/l10n/app_localizations.dart';

const _localeOverride = String.fromEnvironment('WEEKRA_LOCALE');
const _updatesDisabled = bool.fromEnvironment('WEEKRA_DISABLE_UPDATES');

class WeekraApp extends StatefulWidget {
  const WeekraApp({
    super.key,
    this.eventStore = const JsonCalendarEventStore(),
    this.fontFamily,
    this.locale,
    this.textScaler,
    this.updateService,
    this.enableAutomaticUpdates = true,
    this.settingsStore = const JsonAppSettingsStore(),
    this.clock,
  });

  final CalendarEventStore eventStore;
  final String? fontFamily;
  final Locale? locale;
  final TextScaler? textScaler;
  final UpdateService? updateService;
  final bool enableAutomaticUpdates;
  final AppSettingsStore settingsStore;
  final DateTime Function()? clock;

  @override
  State<WeekraApp> createState() => _WeekraAppState();
}

class _WeekraAppState extends State<WeekraApp> {
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    widget.settingsStore.load().then((value) {
      if (mounted) setState(() => _settings = value);
    });
  }

  Future<void> _changeSettings(AppSettings value) async {
    setState(() => _settings = value);
    await widget.settingsStore.save(value);
  }

  void _openSettings(BuildContext context) {
    final updater = context.findAncestorStateOfType<UpdateCoordinatorState>();
    showGlassDialog<void>(
      context,
      maxWidth: 900,
      maxHeight: 680,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setPanelState) => SettingsPanel(
          settings: _settings,
          updateStatus: updater?.status,
          onChanged: (settings) {
            _changeSettings(settings);
            setPanelState(() {});
          },
          onCheckUpdates: updater?.canCheck == true
              ? () => updater!.checkForUpdates(userInitiated: true)
              : null,
          onClose: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _settings.theme.accent;

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: widget.locale ?? _settings.locale ?? _localeFromEnvironment(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: widget.textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: widget.textScaler),
              child: child!,
            ),
      theme: WeekraDesign.dark(fontFamily: widget.fontFamily, accent: accent),
      home: UpdateCoordinator(
        updateService: widget.enableAutomaticUpdates
            ? widget.updateService ?? _defaultUpdateService()
            : null,
        child: Builder(
          builder: (context) => WeekScreen(
            eventStore: widget.eventStore,
            theme: _settings.theme,
            calendarSettings: _settings.calendar,
            categorySettings: _settings.categories,
            clock: widget.clock,
            onOpenSettings: () => _openSettings(context),
          ),
        ),
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
