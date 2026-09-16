part of '../week_screen.dart';

class _FloatingCardSurface extends StatelessWidget {
  const _FloatingCardSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
    // Dialog-sized blur should stay composited instead of rebuilding for every
    // mouse move while the user is typing or choosing a time.
    responsive: false,
    child: child,
  );
}

class _AnchoredCardLayout extends StatelessWidget {
  const _AnchoredCardLayout({
    required this.anchorRect,
    required this.maxWidth,
    required this.maxHeight,
    required this.child,
  });

  final Rect anchorRect;
  final double maxWidth;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const margin = 16.0;
          const gap = 12.0;
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          final usableHeight = math.max(
            0.0,
            constraints.maxHeight - bottomInset,
          );
          final width = math.min(maxWidth, constraints.maxWidth - margin * 2);
          final height = math.min(maxHeight, usableHeight - margin * 2);
          final canFitRight =
              constraints.maxWidth - anchorRect.right - margin >= width + gap;
          final canFitLeft = anchorRect.left - margin >= width + gap;
          final left = canFitRight
              ? anchorRect.right + gap
              : canFitLeft
              ? anchorRect.left - width - gap
              : (anchorRect.center.dx - width / 2).clamp(
                  margin,
                  constraints.maxWidth - width - margin,
                );
          final roomBelow = usableHeight - anchorRect.bottom - margin;
          final roomAbove = anchorRect.top - margin;
          final top = !canFitRight && !canFitLeft && roomBelow >= height + gap
              ? anchorRect.bottom + gap
              : !canFitRight && !canFitLeft && roomAbove >= height + gap
              ? anchorRect.top - height - gap
              : (anchorRect.center.dy - height / 2).clamp(
                  margin,
                  math.max(margin, usableHeight - height - margin),
                );
          return Stack(
            children: [
              Positioned(
                left: left.toDouble(),
                top: top.toDouble(),
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: _FloatingCardSurface(child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<_EventAction?> _showEventDetailsSheet(
  BuildContext context,
  CalendarEvent event, {
  Rect? anchorRect,
}) {
  if (_canUseAnchoredCard(context, anchorRect)) {
    return _showAnchoredCard<_EventAction>(
      context,
      anchorRect: anchorRect!,
      maxWidth: 420,
      maxHeight: 500,
      builder: (context) => _EventDetailsSheet(event: event, floating: true),
    );
  }
  return showModalBottomSheet<_EventAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WeekraColors.surface,
    showDragHandle: false,
    builder: (context) => _EventDetailsSheet(event: event),
  );
}

Future<bool> _confirmDelete(BuildContext context, CalendarEvent event) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n.deleteEventTitle,
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      content: Text(
        l10n.deleteEventMessage(event.title),
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            l10n.cancel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          key: const Key('confirm-delete-event'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.delete,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<CalendarEvent?> _showEventEditorSheet(
  BuildContext context,
  DateTime weekStart, {
  required List<CalendarEvent> suggestionEvents,
  required CategorySettings categorySettings,
  required _SaveEventCallback onSave,
  CalendarEvent? existingEvent,
  DateTime? initialStart,
  DateTime? initialEnd,
  Rect? anchorRect,
}) {
  if (_canUseAnchoredCard(context, anchorRect)) {
    return _showAnchoredCard<CalendarEvent>(
      context,
      anchorRect: anchorRect!,
      maxWidth: 400,
      maxHeight: 560,
      builder: (context) => _EventEditorSheet(
        weekStart: weekStart,
        suggestionEvents: suggestionEvents,
        categorySettings: categorySettings,
        onSave: onSave,
        existingEvent: existingEvent,
        initialStart: initialStart,
        initialEnd: initialEnd,
        floating: true,
      ),
    );
  }
  return showGlassDialog<CalendarEvent>(
    context,
    maxWidth: 400,
    maxHeight: 560,
    builder: (context) => _EventEditorSheet(
      weekStart: weekStart,
      suggestionEvents: suggestionEvents,
      categorySettings: categorySettings,
      onSave: onSave,
      existingEvent: existingEvent,
      initialStart: initialStart,
      initialEnd: initialEnd,
      floating: true,
    ),
  );
}

Future<T?> _showAnchoredCard<T>(
  BuildContext context, {
  required Rect anchorRect,
  required double maxWidth,
  required double maxHeight,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x2E000000),
    transitionDuration: WeekraMotion.resolve(context, WeekraMotion.panel),
    pageBuilder: (dialogContext, _, _) => _AnchoredCardLayout(
      anchorRect: anchorRect,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      child: builder(dialogContext),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: WeekraMotion.emphasized,
        reverseCurve: WeekraMotion.standard,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

bool _canUseAnchoredCard(BuildContext context, Rect? anchorRect) {
  return anchorRect != null &&
      MediaQuery.sizeOf(context).width >= 700 &&
      _usesDesktopPointerRules(context);
}

bool _usesDesktopPointerRules(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

Rect? _globalRectFor(BuildContext? context) {
  final renderObject = context?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

