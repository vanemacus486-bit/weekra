import 'package:flutter/material.dart';
import 'package:weekra/app/weekra_theme.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';
import 'package:weekra/l10n/app_localizations.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.settings, required this.onChanged, required this.onClose});

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: const Color(0xFF15171C),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 24, 28),
          child: ListView(
            children: [
              Row(children: [
                Expanded(child: Text(l10n.settingsTitle, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, letterSpacing: -1))),
                IconButton(tooltip: l10n.closeTooltip, onPressed: onClose, icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 30),
              _SectionLabel(l10n.settingsAppearance),
              const SizedBox(height: 14),
              Row(children: [
                _ThemeChoice(label: l10n.themeEmber, value: WeekraTheme.ember, selected: settings.theme, onTap: _setTheme),
                const SizedBox(width: 10),
                _ThemeChoice(label: l10n.themeLagoon, value: WeekraTheme.lagoon, selected: settings.theme, onTap: _setTheme),
                const SizedBox(width: 10),
                _ThemeChoice(label: l10n.themeGraphite, value: WeekraTheme.graphite, selected: settings.theme, onTap: _setTheme),
              ]),
              const SizedBox(height: 34),
              _SectionLabel(l10n.settingsLanguage),
              const SizedBox(height: 10),
              _LanguageChoice(label: l10n.languageSystem, value: WeekraLanguage.system, settings: settings, onChanged: _setLanguage),
              _LanguageChoice(label: 'English', value: WeekraLanguage.english, settings: settings, onChanged: _setLanguage),
              _LanguageChoice(label: '简体中文', value: WeekraLanguage.chinese, settings: settings, onChanged: _setLanguage),
              const SizedBox(height: 28),
              Text(l10n.settingsSavedAutomatically, style: const TextStyle(color: Color(0xFFA9A6A3), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  void _setTheme(WeekraTheme value) => onChanged(settings.copyWith(theme: value));
  void _setLanguage(WeekraLanguage value) => onChanged(settings.copyWith(language: value));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label); final String label;
  @override Widget build(BuildContext context) => Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFFA9A6A3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.7));
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.label, required this.value, required this.selected, required this.onTap});
  final String label; final WeekraTheme value; final WeekraTheme selected; final ValueChanged<WeekraTheme> onTap;
  @override Widget build(BuildContext context) {
    final active = value == selected;
    return Expanded(child: InkWell(onTap: () => onTap(value), borderRadius: BorderRadius.circular(18), child: AnimatedContainer(
      duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? value.accent : Colors.white.withValues(alpha: .1))),
      child: Column(children: [Container(height: 54, decoration: BoxDecoration(gradient: LinearGradient(colors: value.background), borderRadius: BorderRadius.circular(12))), const SizedBox(height: 9), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : const Color(0xFFA9A6A3), fontSize: 12))]),
    )));
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({required this.label, required this.value, required this.settings, required this.onChanged});
  final String label; final WeekraLanguage value; final AppSettings settings; final ValueChanged<WeekraLanguage> onChanged;
  @override Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero, title: Text(label), onTap: () => onChanged(value),
    trailing: value == settings.language ? Icon(Icons.check_rounded, color: settings.theme.accent) : null,
  );
}
