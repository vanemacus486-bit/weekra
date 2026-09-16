part of '../week_screen.dart';

enum _EventAction { edit, delete }

enum _EventContextAction { edit, copy, delete, category }

class _EventContextSelection {
  const _EventContextSelection(this.action, {this.categoryId});

  final _EventContextAction action;
  final String? categoryId;
}

Future<_EventContextSelection?> _showEventContextMenu(
  BuildContext context,
  CalendarEvent event, {
  required Offset position,
  required CategorySettings categorySettings,
}) {
  final l10n = AppLocalizations.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final localPosition = overlay.globalToLocal(position);
  final menuPosition = RelativeRect.fromLTRB(
    localPosition.dx,
    localPosition.dy,
    overlay.size.width - localPosition.dx,
    overlay.size.height - localPosition.dy,
  );

  PopupMenuItem<_EventContextSelection> actionItem({
    required Key key,
    required _EventContextAction action,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return PopupMenuItem<_EventContextSelection>(
      key: key,
      value: _EventContextSelection(action),
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? _mutedInk),
          const SizedBox(width: 11),
          Text(label, style: TextStyle(color: color ?? _ink, fontSize: 13)),
        ],
      ),
    );
  }

  PopupMenuItem<_EventContextSelection> categoryItem(EventCategory category) {
    final selected = event.categoryId == category.id;
    return PopupMenuItem<_EventContextSelection>(
      key: Key('event-context-category-${category.id}'),
      value: _EventContextSelection(
        _EventContextAction.category,
        categoryId: category.id,
      ),
      height: 38,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              _categoryName(l10n, categorySettings, category.id),
              style: const TextStyle(color: _ink, fontSize: 13),
            ),
          ),
          if (selected)
            Icon(
              Icons.check_rounded,
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  return showMenu<_EventContextSelection>(
    context: context,
    position: menuPosition,
    color: WeekraColors.surfaceRaised.withValues(alpha: .98),
    surfaceTintColor: Colors.transparent,
    elevation: 14,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: WeekraColors.outline),
    ),
    constraints: const BoxConstraints(minWidth: 210, maxWidth: 250),
    items: [
      actionItem(
        key: const Key('event-context-edit'),
        action: _EventContextAction.edit,
        icon: Icons.edit_outlined,
        label: l10n.edit,
      ),
      actionItem(
        key: const Key('event-context-copy'),
        action: _EventContextAction.copy,
        icon: Icons.content_copy_rounded,
        label: l10n.copy,
      ),
      actionItem(
        key: const Key('event-context-delete'),
        action: _EventContextAction.delete,
        icon: Icons.delete_outline_rounded,
        label: l10n.delete,
        color: Theme.of(context).colorScheme.error,
      ),
      const PopupMenuDivider(height: 9),
      PopupMenuItem<_EventContextSelection>(
        key: const Key('event-context-category-heading'),
        enabled: false,
        height: 30,
        child: Text(
          l10n.categorySection,
          style: const TextStyle(
            color: _tertiaryInk,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      categoryItem(
        _resolvedCategory(categorySettings, EventCategories.uncategorizedId),
      ),
      for (final category in EventCategories.values)
        categoryItem(_resolvedCategory(categorySettings, category.id)),
    ],
  );
}

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.event, this.floating = false});

  final CalendarEvent event;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!floating) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _mutedInk,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 52,
                  decoration: BoxDecoration(
                    color: event.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    event.title,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                WeekraIconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.closeTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _EventDetailRow(
              icon: Icons.calendar_today_outlined,
              text: MaterialLocalizations.of(context)
                  .formatFullDate(event.start),
            ),
            const SizedBox(height: 12),
            _EventDetailRow(
              icon: Icons.schedule_rounded,
              text:
                  '${_formatTime(context, event.startMinutes)} – '
                  '${_formatTime(context, event.endMinutes)}',
            ),
            if (event.location != null) ...[
              const SizedBox(height: 12),
              _EventDetailRow(
                icon: Icons.location_on_outlined,
                text: event.location!,
              ),
            ],
            const SizedBox(height: 26),
            _EventActionButtons(
              onEdit: () => Navigator.of(context).pop(_EventAction.edit),
              onDelete: () => Navigator.of(context).pop(_EventAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _mutedInk),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: const TextStyle(color: _ink, fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _EventActionButtons extends StatelessWidget {
  const _EventActionButtons({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget editButton() => FilledButton.icon(
      key: const Key('edit-event'),
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: Text(
        l10n.edit,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    Widget deleteButton() => OutlinedButton.icon(
      key: const Key('delete-event'),
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(
        l10n.delete,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBody = MediaQuery.textScalerOf(context).scale(16);
        final shouldStack = constraints.maxWidth < 330 || scaledBody > 21;
        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              editButton(),
              const SizedBox(height: 10),
              deleteButton(),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: editButton()),
            const SizedBox(width: 10),
            Expanded(child: deleteButton()),
          ],
        );
      },
    );
  }
}

