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
  State<UpdateCoordinator> createState() => _UpdateCoordinatorState();
}

class _UpdateCoordinatorState extends State<UpdateCoordinator> {
  bool _started = false;

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
    try {
      final update = await widget.updateService!.checkForUpdate();
      if (update != null && mounted) {
        await _offerUpdate(update);
      }
    } on Object {
      // Update failures must never prevent the calendar from opening. The app
      // checks again on the next launch.
    }
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
                    value.$2
                        ? l10n.updateInstalling
                        : l10n.updateDownloading,
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
