part of '../week_screen.dart';

class _StorageErrorBanner extends StatelessWidget {
  const _StorageErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      content: Text(message, softWrap: true, overflow: TextOverflow.visible),
      leading: const Icon(Icons.error_outline_rounded),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(
            l10n.dismiss,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _WeekLayoutStage extends StatelessWidget {
  const _WeekLayoutStage({
    required this.layout,
    required this.hourly,
    required this.overview,
  });

  final _WeekLayout layout;
  final Widget hourly;
  final Widget overview;

  @override
  Widget build(BuildContext context) {
    final duration = WeekraMotion.resolve(context, WeekraMotion.content);

    Widget layer({required _WeekLayout value, required Widget child}) {
      final active = layout == value;
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: duration,
              curve: WeekraMotion.standard,
              child: TickerMode(
                enabled: active,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        layer(value: _WeekLayout.hourly, child: hourly),
        layer(value: _WeekLayout.grid, child: overview),
      ],
    );
  }
}

