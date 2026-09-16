part of '../week_screen.dart';

class _WeekToolbar extends StatelessWidget {
  const _WeekToolbar({
    required this.weekStart,
    required this.layout,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onLayoutChanged,
    required this.onSettings,
  });

  final DateTime weekStart;
  final _WeekLayout layout;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<_WeekLayout> onLayoutChanged;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.weekToolbarEyebrow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _tertiaryInk,
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _weekLabel(materialL10n, weekStart),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.7,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        WeekraMetrics.pageGutter,
        14,
        18,
        12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final shouldStack =
              constraints.maxWidth < 680 || textScaler.scale(14) > 18;
          final showSwitcherLabels =
              constraints.maxWidth >= 900 && textScaler.scale(12) <= 15;
          final todayLabelWidth = _singleLineTextWidth(
            context,
            l10n.today,
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          );
          final navigation = _WeekNavigation(
            compact: todayLabelWidth > (constraints.maxWidth < 420 ? 76 : 120),
            onPrevious: onPrevious,
            onToday: onToday,
            onNext: onNext,
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WeekLayoutSwitcher(
                layout: layout,
                showLabels: showSwitcherLabels,
                onChanged: onLayoutChanged,
              ),
              const SizedBox(width: 8),
              _ToolbarSurface(
                child: WeekraIconButton(
                  key: const Key('open-settings'),
                  onPressed: onSettings,
                  tooltip: l10n.settingsTooltip,
                  icon: const Icon(Icons.tune_rounded, size: 19),
                ),
              ),
            ],
          );

          if (shouldStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: heading),
                    navigation,
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              navigation,
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({
    required this.compact,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final bool compact;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return _ToolbarSurface(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WeekraIconButton(
            key: const Key('timeline-previous-day'),
            onPressed: onPrevious,
            tooltip: l10n.previousWeekTooltip,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
          if (compact)
            WeekraIconButton(
              key: const Key('timeline-today'),
              onPressed: onToday,
              tooltip: l10n.today,
              color: accent,
              icon: const Icon(Icons.today_outlined, size: 18),
            )
          else
            _TodayButton(onPressed: onToday, label: l10n.today, color: accent),
          WeekraIconButton(
            key: const Key('timeline-next-day'),
            onPressed: onNext,
            tooltip: l10n.nextWeekTooltip,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _TodayButton extends StatefulWidget {
  const _TodayButton({
    required this.onPressed,
    required this.label,
    required this.color,
  });

  final VoidCallback onPressed;
  final String label;
  final Color color;

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: WeekraPressableScale(
        child: Semantics(
          key: const Key('timeline-today'),
          button: true,
          label: widget.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                curve: WeekraMotion.standard,
                constraints: const BoxConstraints(
                  minWidth: 58,
                  minHeight: WeekraMetrics.controlHeight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _hovered
                      ? WeekraColors.surfaceRaised
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarSurface extends StatelessWidget {
  const _ToolbarSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      GlassSurface(radius: 20, child: SizedBox(height: 42, child: child));
}

class _WeekLayoutSwitcher extends StatelessWidget {
  const _WeekLayoutSwitcher({
    required this.layout,
    required this.showLabels,
    required this.onChanged,
  });

  final _WeekLayout layout;
  final bool showLabels;
  final ValueChanged<_WeekLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    final labelWidth = math.max(
      _singleLineTextWidth(context, l10n.weekLayoutHourly, labelStyle),
      _singleLineTextWidth(context, l10n.weekLayoutGrid, labelStyle),
    );
    final width = showLabels ? math.max(204.0, labelWidth * 2 + 108) : 88.0;
    return Semantics(
      container: true,
      label: l10n.weekLayoutPickerLabel,
      child: GlassSegmentedControl(
        width: width,
        selectedIndex: layout == _WeekLayout.hourly ? 0 : 1,
        onChanged: (index) =>
            onChanged(index == 0 ? _WeekLayout.hourly : _WeekLayout.grid),
        children: [
          _WeekLayoutOption(
            key: const Key('week-layout-hourly'),
            icon: Icons.view_week_outlined,
            label: showLabels ? l10n.weekLayoutHourly : null,
            semanticLabel: l10n.weekLayoutHourly,
            selected: layout == _WeekLayout.hourly,
            onTap: () => onChanged(_WeekLayout.hourly),
          ),
          _WeekLayoutOption(
            key: const Key('week-layout-grid'),
            icon: Icons.grid_view_rounded,
            label: showLabels ? l10n.weekLayoutGrid : null,
            semanticLabel: l10n.weekLayoutGrid,
            selected: layout == _WeekLayout.grid,
            onTap: () => onChanged(_WeekLayout.grid),
          ),
        ],
      ),
    );
  }
}

class _WeekLayoutOption extends StatefulWidget {
  const _WeekLayoutOption({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_WeekLayoutOption> createState() => _WeekLayoutOptionState();
}

class _WeekLayoutOptionState extends State<_WeekLayoutOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final duration = WeekraMotion.resolve(context, WeekraMotion.control);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: WeekraPressableScale(
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.semanticLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                curve: WeekraMotion.standard,
                height: WeekraMetrics.controlHeight - 4,
                margin: const EdgeInsets.all(2),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: widget.label == null ? 9 : 10,
                ),
                decoration: BoxDecoration(
                  color: _hovered
                      ? WeekraColors.surfaceRaised.withValues(
                          alpha: widget.selected ? .28 : .82,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.selected ? 1 : 0),
                  duration: duration,
                  curve: WeekraMotion.standard,
                  builder: (context, value, child) {
                    final hoverValue = _hovered ? 1.0 : value;
                    final contentColor = Color.lerp(
                      _mutedInk,
                      _ink,
                      hoverValue,
                    )!;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon, size: 17, color: contentColor),
                        if (widget.label != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: contentColor,
                                fontSize: 12,
                                height: 1.15,
                                fontWeight: FontWeight.lerp(
                                  FontWeight.w500,
                                  FontWeight.w700,
                                  value,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The overview agenda.
///
/// It is a continuous day stream rather than a single week: the reader can keep
/// scrolling past either end, and the list grows as they approach an edge.
