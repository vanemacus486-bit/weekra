import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:weekra/app/app_version.dart';
import 'package:weekra/app/glass_surface.dart';
import 'package:weekra/app/weekra_design.dart';
import 'package:weekra/app/weekra_theme.dart';
import 'package:weekra/features/calendar/domain/event_category.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';
import 'package:weekra/l10n/app_localizations.dart';

enum _SettingsSection { calendar, categories, appearance, language, about }

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
    this.onCheckUpdates,
    this.updateStatus,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback onClose;
  final Future<void> Function()? onCheckUpdates;
  final ValueListenable<String?>? updateStatus;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  _SettingsSection _section = _SettingsSection.calendar;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('settings-card'),
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            return SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: wide ? _wideLayout(context) : _compactLayout(context),
            );
          },
        ),
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 236,
          padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
          decoration: const BoxDecoration(
            color: Color(0x8A131518),
            border: Border(right: BorderSide(color: WeekraColors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 4, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.settingsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      key: const Key('close-settings'),
                      tooltip: l10n.closeTooltip,
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _NavigationItem(
                      icon: Icons.calendar_view_week_outlined,
                      label: l10n.settingsCalendar,
                      subtitle: l10n.settingsCalendarDescription,
                      selected: _section == _SettingsSection.calendar,
                      accent: widget.settings.theme.accent,
                      onTap: () => _select(_SettingsSection.calendar),
                    ),
                    const SizedBox(height: 6),
                    _NavigationItem(
                      icon: Icons.label_outline_rounded,
                      label: l10n.settingsCategories,
                      subtitle: l10n.settingsCategoriesDescription,
                      selected: _section == _SettingsSection.categories,
                      accent: widget.settings.theme.accent,
                      onTap: () => _select(_SettingsSection.categories),
                    ),
                    const SizedBox(height: 6),
                    _NavigationItem(
                      icon: Icons.palette_outlined,
                      label: l10n.settingsAppearance,
                      subtitle: l10n.settingsAppearanceDescription,
                      selected: _section == _SettingsSection.appearance,
                      accent: widget.settings.theme.accent,
                      onTap: () => _select(_SettingsSection.appearance),
                    ),
                    const SizedBox(height: 6),
                    _NavigationItem(
                      icon: Icons.translate_rounded,
                      label: l10n.settingsLanguage,
                      subtitle: l10n.settingsLanguageDescription,
                      selected: _section == _SettingsSection.language,
                      accent: widget.settings.theme.accent,
                      onTap: () => _select(_SettingsSection.language),
                    ),
                    const SizedBox(height: 6),
                    _NavigationItem(
                      icon: Icons.info_outline_rounded,
                      label: l10n.settingsAbout,
                      subtitle: l10n.settingsAboutDescription,
                      selected: _section == _SettingsSection.about,
                      accent: widget.settings.theme.accent,
                      onTap: () => _select(_SettingsSection.about),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        l10n.settingsSavedAutomatically,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _SectionContent(section: _section, panel: widget),
        ),
      ],
    );
  }

  Widget _compactLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                key: const Key('close-settings'),
                tooltip: l10n.closeTooltip,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _CompactNavigationItem(
                icon: Icons.calendar_view_week_outlined,
                label: l10n.settingsCalendar,
                selected: _section == _SettingsSection.calendar,
                accent: widget.settings.theme.accent,
                onTap: () => _select(_SettingsSection.calendar),
              ),
              const SizedBox(width: 8),
              _CompactNavigationItem(
                icon: Icons.label_outline_rounded,
                label: l10n.settingsCategories,
                selected: _section == _SettingsSection.categories,
                accent: widget.settings.theme.accent,
                onTap: () => _select(_SettingsSection.categories),
              ),
              const SizedBox(width: 8),
              _CompactNavigationItem(
                icon: Icons.palette_outlined,
                label: l10n.settingsAppearance,
                selected: _section == _SettingsSection.appearance,
                accent: widget.settings.theme.accent,
                onTap: () => _select(_SettingsSection.appearance),
              ),
              const SizedBox(width: 8),
              _CompactNavigationItem(
                icon: Icons.translate_rounded,
                label: l10n.settingsLanguage,
                selected: _section == _SettingsSection.language,
                accent: widget.settings.theme.accent,
                onTap: () => _select(_SettingsSection.language),
              ),
              const SizedBox(width: 8),
              _CompactNavigationItem(
                icon: Icons.info_outline_rounded,
                label: l10n.settingsAbout,
                selected: _section == _SettingsSection.about,
                accent: widget.settings.theme.accent,
                onTap: () => _select(_SettingsSection.about),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: _SectionContent(section: _section, panel: widget),
        ),
      ],
    );
  }

  void _select(_SettingsSection section) {
    if (_section != section) setState(() => _section = section);
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({required this.section, required this.panel});

  final _SettingsSection section;
  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: WeekraMotion.resolve(context, WeekraMotion.content),
      switchInCurve: WeekraMotion.emphasized,
      switchOutCurve: WeekraMotion.standard,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: ListView(
        key: ValueKey(section),
        padding: const EdgeInsets.fromLTRB(36, 34, 36, 36),
        children: [
          _SectionHeader(section: section),
          const SizedBox(height: 26),
          if (section == _SettingsSection.calendar)
            _CalendarCard(panel: panel)
          else if (section == _SettingsSection.categories)
            _CategoriesCard(panel: panel)
          else if (section == _SettingsSection.appearance)
            _AppearanceCard(panel: panel)
          else if (section == _SettingsSection.language)
            _LanguageCard(panel: panel)
          else
            _AboutCards(panel: panel),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final _SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (title, description) = switch (section) {
      _SettingsSection.calendar => (
        l10n.settingsCalendar,
        l10n.settingsCalendarDescription,
      ),
      _SettingsSection.categories => (
        l10n.settingsCategories,
        l10n.settingsCategoriesDescription,
      ),
      _SettingsSection.appearance => (
        l10n.settingsAppearance,
        l10n.settingsAppearanceDescription,
      ),
      _SettingsSection.language => (
        l10n.settingsLanguage,
        l10n.settingsLanguageDescription,
      ),
      _SettingsSection.about => (
        l10n.settingsAbout,
        l10n.settingsAboutDescription,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 7),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.panel});

  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = panel.settings.calendar;
    return _SettingsCard(
      title: l10n.settingsCalendarArrangement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsCalendarArrangementDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('calendar-anchor-today'),
                label: Text(l10n.settingsAnchorToday),
                selected: settings.anchorMode == CalendarAnchorMode.today,
                onSelected: (_) => _setCalendar(
                  settings.copyWith(anchorMode: CalendarAnchorMode.today),
                ),
              ),
              ChoiceChip(
                key: const Key('calendar-anchor-week-start'),
                label: Text(l10n.settingsAnchorWeekStart),
                selected: settings.anchorMode == CalendarAnchorMode.weekStart,
                onSelected: (_) => _setCalendar(
                  settings.copyWith(anchorMode: CalendarAnchorMode.weekStart),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: WeekraMotion.resolve(context, WeekraMotion.content),
            child: settings.anchorMode == CalendarAnchorMode.today
                ? _CalendarChoiceGroup(
                    key: const ValueKey('today-position'),
                    title: l10n.settingsTodayPosition,
                    description: l10n.settingsTodayPositionDescription,
                    children: [
                      for (var index = 0; index < 7; index++)
                        ChoiceChip(
                          key: Key('calendar-today-column-$index'),
                          label: Text(l10n.settingsColumnNumber(index + 1)),
                          selected: settings.todayColumn == index,
                          onSelected: (_) => _setCalendar(
                            settings.copyWith(todayColumn: index),
                          ),
                        ),
                    ],
                  )
                : _CalendarChoiceGroup(
                    key: const ValueKey('week-start'),
                    title: l10n.settingsWeekStartsOn,
                    description: l10n.settingsWeekStartsOnDescription,
                    children: [
                      for (
                        var weekday = DateTime.monday;
                        weekday <= DateTime.sunday;
                        weekday++
                      )
                        ChoiceChip(
                          key: Key('calendar-week-start-$weekday'),
                          label: Text(_weekdayName(context, weekday)),
                          selected: settings.weekStartsOn == weekday,
                          onSelected: (_) => _setCalendar(
                            settings.copyWith(weekStartsOn: weekday),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _setCalendar(CalendarViewSettings value) {
    panel.onChanged(panel.settings.copyWith(calendar: value));
  }
}

class _CalendarChoiceGroup extends StatelessWidget {
  const _CalendarChoiceGroup({
    super.key,
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 5),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({required this.panel});

  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsCard(
      title: l10n.settingsCategories,
      child: Column(
        children: [
          for (
            var index = 0;
            index < EventCategories.values.length;
            index++
          ) ...[
            _CategorySettingsRow(
              category: EventCategories.values[index],
              panel: panel,
            ),
            if (index < EventCategories.values.length - 1)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _CategorySettingsRow extends StatelessWidget {
  const _CategorySettingsRow({required this.category, required this.panel});

  final EventCategory category;
  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = panel.settings.categories;
    final fallbackName = _defaultCategoryName(l10n, category.id);
    final name = settings.nameFor(category.id, fallbackName);
    final color = settings.colorFor(category.id, category.color);
    return InkWell(
      key: Key('settings-category-${category.id}'),
      onTap: () => _edit(context, name: name, color: color),
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Container(
              key: Key('settings-category-color-${category.id}'),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                name,
                key: Key('settings-category-name-${category.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(l10n.edit, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: WeekraColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context, {
    required String name,
    required Color color,
  }) async {
    final result = await _showCategoryEditor(
      context,
      categoryId: category.id,
      initialName: name,
      initialColor: color,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final categories = panel.settings.categories.customize(
      category.id,
      name: result.name,
      color: result.color,
    );
    panel.onChanged(panel.settings.copyWith(categories: categories));
  }
}

typedef _CategoryEditorResult = ({String name, Color color});

const _categoryPalette = <Color>[
  Color(0xFFF1776C),
  Color(0xFFFF967A),
  Color(0xFFC6A15B),
  Color(0xFFE1C45A),
  Color(0xFF72A57C),
  Color(0xFF70B8AF),
  Color(0xFF5BB7D2),
  Color(0xFF7F9DD4),
  Color(0xFF8E82D8),
  Color(0xFFB7799E),
  Color(0xFFD878A2),
  Color(0xFF9A9FA7),
];

Future<_CategoryEditorResult?> _showCategoryEditor(
  BuildContext context, {
  required String categoryId,
  required String initialName,
  required Color initialColor,
}) async {
  final controller = TextEditingController(text: initialName);
  var selectedColor = initialColor;
  final result = await showGlassDialog<_CategoryEditorResult>(
    context,
    maxWidth: 420,
    maxHeight: 520,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final l10n = AppLocalizations.of(context);
        final canSave = controller.text.trim().isNotEmpty;
        return Material(
          color: Colors.transparent,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.settingsEditCategory,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.closeTooltip,
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    key: Key('category-name-field-$categoryId'),
                    controller: controller,
                    autofocus: true,
                    maxLength: 18,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.settingsCategoryName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.settingsCategoryColor,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (
                        var index = 0;
                        index < _categoryPalette.length;
                        index++
                      )
                        _CategoryColorChoice(
                          key: Key('category-color-choice-$index'),
                          color: _categoryPalette[index],
                          selected:
                              _categoryPalette[index].toARGB32() ==
                              selectedColor.toARGB32(),
                          onTap: () => setDialogState(
                            () => selectedColor = _categoryPalette[index],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        key: const Key('save-category-settings'),
                        onPressed: canSave
                            ? () => Navigator.pop(dialogContext, (
                                name: controller.text.trim(),
                                color: selectedColor,
                              ))
                            : null,
                        child: Text(l10n.saveChanges),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  controller.dispose();
  return result;
}

class _CategoryColorChoice extends StatelessWidget {
  const _CategoryColorChoice({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: WeekraMotion.resolve(context, WeekraMotion.quick),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 3 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .42),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.panel});

  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsCard(
      title: l10n.settingsAppearance,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 430;
          final choices = [
            _ThemeChoice(
              label: l10n.themeEmber,
              value: WeekraTheme.ember,
              selected: panel.settings.theme,
              onTap: _setTheme,
            ),
            _ThemeChoice(
              label: l10n.themeLagoon,
              value: WeekraTheme.lagoon,
              selected: panel.settings.theme,
              onTap: _setTheme,
            ),
            _ThemeChoice(
              label: l10n.themeGraphite,
              value: WeekraTheme.graphite,
              selected: panel.settings.theme,
              onTap: _setTheme,
            ),
          ];
          if (vertical) {
            return Column(
              children: [
                for (var index = 0; index < choices.length; index++) ...[
                  choices[index],
                  if (index < choices.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < choices.length; index++) ...[
                Expanded(child: choices[index]),
                if (index < choices.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  void _setTheme(WeekraTheme value) =>
      panel.onChanged(panel.settings.copyWith(theme: value));
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.panel});

  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsCard(
      title: l10n.settingsLanguage,
      child: Column(
        children: [
          _LanguageChoice(
            label: l10n.languageSystem,
            value: WeekraLanguage.system,
            panel: panel,
          ),
          const Divider(height: 1),
          _LanguageChoice(
            label: 'English',
            value: WeekraLanguage.english,
            panel: panel,
          ),
          const Divider(height: 1),
          _LanguageChoice(
            label: '简体中文',
            value: WeekraLanguage.chinese,
            panel: panel,
          ),
        ],
      ),
    );
  }
}

class _AboutCards extends StatelessWidget {
  const _AboutCards({required this.panel});

  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _SettingsCard(
          title: l10n.settingsVersion,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: panel.settings.theme.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_view_week_rounded,
                  color: panel.settings.theme.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Weekra',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                'v$appVersion',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          title: l10n.checkForUpdates,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.settingsUpdateDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('check-for-updates'),
                  onPressed: panel.onCheckUpdates,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.checkForUpdates),
                ),
              ),
              if (panel.updateStatus != null)
                ValueListenableBuilder<String?>(
                  valueListenable: panel.updateStatus!,
                  builder: (context, message, _) => message == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.settingsSavedAutomatically,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WeekraColors.surfaceRaised.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: WeekraColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: WeekraMotion.resolve(context, WeekraMotion.control),
        curve: WeekraMotion.standard,
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: selected ? WeekraColors.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? WeekraColors.outline : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? accent : WeekraColors.textSecondary,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? WeekraColors.textPrimary
                          : WeekraColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WeekraColors.textTertiary,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactNavigationItem extends StatelessWidget {
  const _CompactNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? WeekraColors.onAccent : WeekraColors.textSecondary,
      ),
      label: Text(label),
      selectedColor: accent,
      backgroundColor: WeekraColors.surfaceRaised,
      side: BorderSide(color: selected ? accent : WeekraColors.outline),
      onSelected: (_) => onTap(),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final WeekraTheme value;
  final WeekraTheme selected;
  final ValueChanged<WeekraTheme> onTap;

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: WeekraMotion.resolve(context, WeekraMotion.control),
        curve: WeekraMotion.standard,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active
              ? value.accent.withValues(alpha: .10)
              : WeekraColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? value.accent : WeekraColors.outline,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: value.background,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: AnimatedOpacity(
                  opacity: active ? 1 : 0,
                  duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: value.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? WeekraColors.textPrimary
                    : WeekraColors.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.value,
    required this.panel,
  });

  final String label;
  final WeekraLanguage value;
  final SettingsPanel panel;

  @override
  Widget build(BuildContext context) {
    final active = value == panel.settings.language;
    return InkWell(
      onTap: () => panel.onChanged(panel.settings.copyWith(language: value)),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            AnimatedSwitcher(
              duration: WeekraMotion.resolve(context, WeekraMotion.quick),
              child: active
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey(true),
                      size: 20,
                      color: panel.settings.theme.accent,
                    )
                  : const SizedBox(key: ValueKey(false), width: 20, height: 20),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekdayName(BuildContext context, int weekday) {
  final names = MaterialLocalizations.of(context).narrowWeekdays;
  return names[weekday % DateTime.daysPerWeek];
}

String _defaultCategoryName(AppLocalizations l10n, String categoryId) {
  return switch (categoryId) {
    'category-1' => l10n.categoryOne,
    'category-2' => l10n.categoryTwo,
    'category-3' => l10n.categoryThree,
    'category-4' => l10n.categoryFour,
    'category-5' => l10n.categoryFive,
    'category-6' => l10n.categorySix,
    _ => l10n.uncategorized,
  };
}
