import 'dart:async';

import 'package:flutter/material.dart';
import 'package:weekra/features/updater/domain/app_update.dart';
import 'package:weekra/features/updater/domain/update_service.dart';
import 'package:weekra/l10n/app_localizations.dart';

class UpdateCoordinator extends StatefulWidget {
  const UpdateCoordinator({
    super.key,
    required this.child,
    required this.updateService,
  });

  final Widget child;
  final UpdateService? updateService;

  @override
  State<UpdateCoordinator> createState() => UpdateCoordinatorState();
}

class UpdateCoordinatorState extends State<UpdateCoordinator>
    with WidgetsBindingObserver {
  bool _started = false;
  bool _checking = false;
  Timer? _retryTimer;
  DateTime? _lastCheck;
  final status = ValueNotifier<String?>(null);
  bool get canCheck => widget.updateService != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (canCheck) {
      _retryTimer = Timer.periodic(const Duration(hours: 6), (_) {
        unawaited(checkForUpdates());
      });
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    status.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (_lastCheck == null ||
            DateTime.now().difference(_lastCheck!) >
                const Duration(minutes: 10))) {
      unawaited(checkForUpdates());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || widget.updateService == null) {
      return;
    }
    _started = true;
    unawaited(_checkAfterStartup());
  }

  Future<void> _checkAfterStartup() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    await checkForUpdates();
  }

  Future<void> checkForUpdates({bool userInitiated = false}) async {
    if (!mounted || !canCheck || _checking) return;
    _checking = true;
    _lastCheck = DateTime.now();
    final l10n = AppLocalizations.of(context);
    if (userInitiated) _notice(l10n.updateChecking);
    try {
      final update = await widget.updateService!.checkForUpdate();
      if (!mounted) return;
      if (update != null) {
        await _offerUpdate(update);
      } else if (userInitiated) {
        _notice(l10n.updateUpToDate);
      }
    } on Object {
      if (mounted) _notice(l10n.updateCheckFailed);
    } finally {
      _checking = false;
    }
  }

  void _notice(String message) {
    status.value = message;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _offerUpdate(AppUpdate update) async {
    final l10n = AppLocalizations.of(context);
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          l10n.updateAvailableTitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        content: Text(
          l10n.updateAvailableMessage(update.version),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.updateLater,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.updateNow,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (shouldUpdate == true && mounted) {
      await _install(update);
    }
  }

  Future<void> _install(AppUpdate update) async {
    final l10n = AppLocalizations.of(context);
    final progress = ValueNotifier<(double?, bool)>((0.0, false));
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: ValueListenableBuilder<(double?, bool)>(
              valueListenable: progress,
              builder: (context, value, child) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    value.$2 ? l10n.updateInstalling : l10n.updateDownloading,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: value.$2 ? null : value.$1),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      await widget.updateService!.downloadAndInstall(
        update,
        onProgress: (value) {
          if (value != null && value >= 1) {
            progress.value = (null, true);
          } else {
            progress.value = (value, false);
          }
        },
      );
    } on Object {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.updateFailed,
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ),
      );
    } finally {
      progress.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
