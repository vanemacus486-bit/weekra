import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  });

  final CalendarEventStore eventStore;
  final String? fontFamily;
  final Locale? locale;
  final TextScaler? textScaler;
  final UpdateService? updateService;
  final bool enableAutomaticUpdates;
  final AppSettingsStore settingsStore;

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
    final wide = MediaQuery.sizeOf(context).width >= 760;
    if (wide) {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogContext, _, _) => Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(width: 430, height: double.infinity, child: SettingsPanel(settings: _settings, onChanged: _changeSettings, onClose: () => Navigator.pop(dialogContext))),
        ),
        transitionBuilder: (_, animation, _, child) => SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => FractionallySizedBox(heightFactor: .82, child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), child: SettingsPanel(settings: _settings, onChanged: _changeSettings, onClose: () => Navigator.pop(sheetContext)))),
      );
    }
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
              data: MediaQuery.of(context).copyWith(textScaler: widget.textScaler),
              child: child!,
            ),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: widget.fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF15171C),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: UpdateCoordinator(
        updateService: widget.enableAutomaticUpdates
            ? widget.updateService ?? _defaultUpdateService()
            : null,
        child: Builder(builder: (context) => WeekScreen(eventStore: widget.eventStore, theme: _settings.theme, onOpenSettings: () => _openSettings(context))),
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
