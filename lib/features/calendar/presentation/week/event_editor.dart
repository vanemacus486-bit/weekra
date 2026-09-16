part of '../week_screen.dart';

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.weekStart,
    required this.suggestionEvents,
    required this.categorySettings,
    required this.onSave,
    this.existingEvent,
    this.initialStart,
    this.initialEnd,
    this.floating = false,
  }) : assert(
         (initialStart == null) == (initialEnd == null),
         'An initial time range must include both start and end.',
       );

  final DateTime weekStart;
  final List<CalendarEvent> suggestionEvents;
  final CategorySettings categorySettings;
  final _SaveEventCallback onSave;
  final CalendarEvent? existingEvent;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool floating;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _titleFocusNode = FocusNode(debugLabel: 'Event title');
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _endsNextDay = false;
  String _selectedCategoryId = EventCategories.uncategorizedId;
  String? _suggestedCategoryId;
  bool _categoryUserSelected = false;
  bool _categoryChangedByUser = false;
  bool _moreExpanded = false;
  bool _isSaving = false;
  String? _validationMessage;
  Timer? _suggestionTimer;
  int _suggestionRevision = 0;

  @override
  void initState() {
    super.initState();
    final existingEvent = widget.existingEvent;
    if (existingEvent != null) {
      _titleController.text = existingEvent.title;
      _locationController.text = existingEvent.location ?? '';
      _selectedDate = DateTime(
        existingEvent.start.year,
        existingEvent.start.month,
        existingEvent.start.day,
      );
      _startTime = TimeOfDay.fromDateTime(existingEvent.start);
      _endTime = TimeOfDay.fromDateTime(existingEvent.end);
      _endsNextDay = !_isSameDay(existingEvent.start, existingEvent.end);
      _selectedCategoryId = existingEvent.categoryId;
      _categoryUserSelected = true;
      _moreExpanded = (existingEvent.location ?? '').isNotEmpty || _endsNextDay;
      _titleController.addListener(_titleChanged);
      return;
    }
    final initialStart = widget.initialStart;
    final initialEnd = widget.initialEnd;
    if (initialStart != null && initialEnd != null) {
      _selectedDate = DateTime(
        initialStart.year,
        initialStart.month,
        initialStart.day,
      );
      _startTime = TimeOfDay.fromDateTime(initialStart);
      _endTime = TimeOfDay.fromDateTime(initialEnd);
      _endsNextDay = !_isSameDay(initialStart, initialEnd);
      _titleController.addListener(_titleChanged);
      return;
    }
    final today = DateTime.now();
    final weekEnd = widget.weekStart.add(const Duration(days: 7));
    final isInWeek =
        !today.isBefore(widget.weekStart) && today.isBefore(weekEnd);
    _selectedDate = isInWeek ? today : widget.weekStart;
    _titleController.addListener(_titleChanged);
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _titleController.removeListener(_titleChanged);
    _titleController.dispose();
    _locationController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _titleChanged() {
    if (_categoryUserSelected) {
      return;
    }
    final revision = ++_suggestionRevision;
    _suggestionTimer?.cancel();
    _suggestionTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted ||
          revision != _suggestionRevision ||
          _categoryUserSelected) {
        return;
      }
      final existingId = widget.existingEvent?.id;
      final suggestion = suggestCategoryForTitle(
        _titleController.text,
        widget.suggestionEvents
            .where((event) => event.id != existingId)
            .map((event) => (title: event.title, categoryId: event.categoryId)),
      );
      setState(() {
        _suggestedCategoryId = suggestion;
        _selectedCategoryId = suggestion ?? EventCategories.uncategorizedId;
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: widget.weekStart,
      lastDate: widget.weekStart.add(const Duration(days: 6)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = picked;
      _validationMessage = null;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _validationMessage = null;
    });
  }

  bool get _hasActiveComposition {
    final composing = _titleController.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  Future<void> _save() async {
    if (_isSaving || _hasActiveComposition) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final start = _atTime(_selectedDate, _startTime);
    final end = _atTime(
      _selectedDate,
      _endTime,
    ).add(Duration(days: _endsNextDay ? 1 : 0));

    if (title.isEmpty) {
      setState(() => _validationMessage = l10n.eventTitleRequired);
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => _validationMessage = l10n.eventEndAfterStart);
      return;
    }

    final location = _locationController.text.trim();
    final category = _resolvedCategory(
      widget.categorySettings,
      _selectedCategoryId,
    );
    final displayColor =
        category.id == EventCategories.uncategorizedId &&
            !_categoryChangedByUser
        ? widget.existingEvent?.color ?? category.color
        : category.color;
    final event = CalendarEvent(
      id:
          widget.existingEvent?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      start: start,
      end: end,
      categoryId: category.id,
      color: displayColor,
      location: location.isEmpty ? null : location,
    );
    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });
    final saved = await widget.onSave(event);
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop(event);
      return;
    }
    setState(() {
      _isSaving = false;
      _validationMessage = widget.existingEvent == null
          ? l10n.eventSaveError
          : l10n.eventChangesSaveError;
    });
    _titleFocusNode.requestFocus();
  }

  void _selectCategory(String categoryId) {
    _suggestionTimer?.cancel();
    _suggestionRevision += 1;
    setState(() {
      _selectedCategoryId = categoryId;
      _suggestedCategoryId = null;
      _categoryUserSelected = true;
      _categoryChangedByUser = true;
    });
  }

  void _cancel() {
    if (!_isSaving) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final category = _resolvedCategory(
      widget.categorySettings,
      _selectedCategoryId,
    );
    final categoryName = _categoryName(
      l10n,
      widget.categorySettings,
      category.id,
    );
    final visibleCategoryName = _suggestedCategoryId == category.id
        ? l10n.suggestedCategory(categoryName)
        : categoryName;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: FocusTraversalGroup(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!widget.floating)
                        Expanded(
                          child: Align(
                            child: Container(
                              width: 34,
                              height: 3,
                              decoration: BoxDecoration(
                                color: WeekraColors.outline,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      KeyedSubtree(
                        key: const Key('close-event-editor'),
                        child: WeekraIconButton(
                          key: const Key('cancel-event-editor'),
                          onPressed: _isSaving ? null : _cancel,
                          tooltip: l10n.closeTooltip,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    key: const Key('event-title'),
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: true,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.titleLabel,
                      hintStyle: const TextStyle(
                        color: _tertiaryInk,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 2,
                        end: 2,
                        bottom: 8,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 8),
                  _CompactDateTimeFields(
                    dateLabel: materialL10n.formatMediumDate(_selectedDate),
                    startLabel: materialL10n.formatTimeOfDay(
                      _startTime,
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    endLabel: materialL10n.formatTimeOfDay(
                      _endTime,
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    endsNextDay: _endsNextDay,
                    onDatePressed: _pickDate,
                    onStartPressed: () => _pickTime(isStart: true),
                    onEndPressed: () => _pickTime(isStart: false),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    key: const Key('event-category-menu'),
                    enabled: !_isSaving,
                    tooltip: l10n.categorySection,
                    onSelected: _selectCategory,
                    color: WeekraColors.surfaceRaised,
                    position: PopupMenuPosition.under,
                    itemBuilder: (context) => [
                      _categoryMenuItem(
                        l10n,
                        widget.categorySettings,
                        _resolvedCategory(
                          widget.categorySettings,
                          EventCategories.uncategorizedId,
                        ),
                      ),
                      for (final option in EventCategories.values)
                        _categoryMenuItem(
                          l10n,
                          widget.categorySettings,
                          _resolvedCategory(widget.categorySettings, option.id),
                        ),
                    ],
                    child: _CategoryTag(
                      color: category.color,
                      label: visibleCategoryName,
                    ),
                  ),
                  AnimatedSize(
                    duration: WeekraMotion.resolve(
                      context,
                      WeekraMotion.control,
                    ),
                    curve: WeekraMotion.standard,
                    alignment: Alignment.topCenter,
                    child: !_moreExpanded
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  key: const Key('event-location'),
                                  controller: _locationController,
                                  enabled: !_isSaving,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: l10n.locationOptionalLabel,
                                    prefixIcon: const Icon(
                                      Icons.place_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilterChip(
                                  key: const Key('event-ends-next-day'),
                                  avatar: const Icon(
                                    Icons.nights_stay_outlined,
                                    size: 16,
                                  ),
                                  label: Text(l10n.endsNextDayLabel),
                                  selected: _endsNextDay,
                                  onSelected: _isSaving
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            _endsNextDay = selected;
                                            _validationMessage = null;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ),
                  ),
                  if (_validationMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _validationMessage!,
                      softWrap: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final moreButton = TextButton.icon(
                        key: const Key('event-more'),
                        onPressed: _isSaving
                            ? null
                            : () => setState(
                                () => _moreExpanded = !_moreExpanded,
                              ),
                        icon: Icon(
                          _moreExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                        ),
                        label: Text(_moreExpanded ? l10n.less : l10n.more),
                      );
                      final saveButton = FilledButton.icon(
                        key: const Key('save-event'),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.keyboard_return_rounded,
                                size: 16,
                              ),
                        label: Text(
                          widget.existingEvent == null
                              ? l10n.saveEvent
                              : l10n.saveChanges,
                        ),
                      );
                      final stack =
                          constraints.maxWidth < 310 ||
                          MediaQuery.textScalerOf(context).scale(13) > 18;
                      if (stack) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            saveButton,
                            const SizedBox(height: 4),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: moreButton,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [moreButton, const Spacer(), saveButton],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactDateTimeFields extends StatelessWidget {
  const _CompactDateTimeFields({
    required this.dateLabel,
    required this.startLabel,
    required this.endLabel,
    required this.endsNextDay,
    required this.onDatePressed,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  final String dateLabel;
  final String startLabel;
  final String endLabel;
  final bool endsNextDay;
  final VoidCallback onDatePressed;
  final VoidCallback onStartPressed;
  final VoidCallback onEndPressed;

  @override
  Widget build(BuildContext context) {
    Widget field({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Expanded(
        child: InkWell(
          key: key,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: _mutedInk),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: _line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackDate =
              constraints.maxWidth < 430 ||
              MediaQuery.textScalerOf(context).scale(12) > 16;
          final dateField = field(
            key: const Key('event-date'),
            icon: Icons.calendar_today_outlined,
            label: dateLabel,
            onPressed: onDatePressed,
          );
          final timeFields = Row(
            children: [
              field(
                key: const Key('event-start-time'),
                icon: Icons.schedule_rounded,
                label: startLabel,
                onPressed: onStartPressed,
              ),
              const Text('–', style: TextStyle(color: _tertiaryInk)),
              field(
                key: const Key('event-end-time'),
                icon: Icons.schedule_rounded,
                label: endsNextDay ? '$endLabel +1' : endLabel,
                onPressed: onEndPressed,
              ),
            ],
          );
          if (stackDate) {
            return Column(
              children: [
                Row(children: [dateField]),
                const Divider(height: 1, color: _subtleLine),
                timeFields,
              ],
            );
          }
          return Row(
            children: [
              dateField,
              Container(width: 1, height: 24, color: _subtleLine),
              Expanded(flex: 2, child: timeFields),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 9, 8, 9),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _mutedInk,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.expand_more_rounded,
              size: 17,
              color: _tertiaryInk,
            ),
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<String> _categoryMenuItem(
  AppLocalizations l10n,
  CategorySettings categorySettings,
  EventCategory category,
) {
  return PopupMenuItem<String>(
    key: Key('event-category-${category.id}'),
    value: category.id,
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
        const SizedBox(width: 10),
        Text(_categoryName(l10n, categorySettings, category.id)),
      ],
    ),
  );
}

