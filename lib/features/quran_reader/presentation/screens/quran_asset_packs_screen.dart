import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';

class QuranAssetPacksScreen extends StatelessWidget {
  const QuranAssetPacksScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  Future<void> _downloadPack(
      BuildContext context, MushafEdition edition) async {
    final activeDownload = controller.activeOfflineDownloadEdition;
    if (activeDownload != null && activeDownload != edition) {
      final shouldDownload = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Download another edition?'),
                content: Text(
                  '${activeDownload.label} is already downloading. '
                  'Do you want to start downloading ${edition.label} too?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Download'),
                  ),
                ],
              );
            },
          ) ??
          false;
      if (!shouldDownload || !context.mounted) {
        return;
      }
    }

    try {
      await controller.downloadOfflineEditionPack(edition);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${edition.label} is ready offline.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_downloadErrorMessage(error))),
      );
    }
  }

  String _downloadErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('cancelled') ||
        message.contains('canceled') ||
        message.contains('request cancelled') ||
        message.contains('request canceled') ||
        message.contains('manually cancelled') ||
        message.contains('manually canceled') ||
        message.contains('dioexceptiontype.cancel')) {
      return 'Download cancelled.';
    }
    final looksOffline = message.contains('connection error') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('could not resolve host') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection timed out') ||
        message.contains('receivetimeoutexception') ||
        message.contains('sendtimeoutexception') ||
        message.contains('connectiontimeoutexception');

    if (looksOffline) {
      return 'Please connect to Wi-Fi and try again.';
    }
    return 'Download failed. Please try again.';
  }

  Future<void> _deletePack(BuildContext context, MushafEdition edition) async {
    try {
      await controller.removeOfflineEditionPack(edition);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${edition.label} pack deleted.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.settingsListenable,
        controller.experienceListenable,
      ]),
      builder: (context, _) {
        final settings = controller.settings;
        final experience = controller.experienceSettings;
        final themeData = settings.nightMode
            ? AppTheme.dark(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              )
            : AppTheme.light(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              );

        return Theme(
          data: themeData,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Asset Packs'),
            ),
            body: SafeArea(
              child: _AssetPackList(
                controller: controller,
                onDownload: _downloadPack,
                onDelete: _deletePack,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AssetPackList extends StatefulWidget {
  const _AssetPackList({
    required this.controller,
    required this.onDownload,
    required this.onDelete,
  });

  final QuranReaderController controller;
  final Future<void> Function(BuildContext context, MushafEdition edition)
      onDownload;
  final Future<void> Function(BuildContext context, MushafEdition edition)
      onDelete;

  @override
  State<_AssetPackList> createState() => _AssetPackListState();
}

class _AssetPackListState extends State<_AssetPackList> {
  static const Duration _minimumRefreshGap = Duration(milliseconds: 120);

  Timer? _refreshTimer;
  DateTime _lastRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant _AssetPackList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChange);
    _refreshTimer?.cancel();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChange);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _handleControllerChange() {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefreshAt);
    if (elapsed >= _minimumRefreshGap) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _refreshNow();
      return;
    }
    _refreshTimer ??= Timer(_minimumRefreshGap - elapsed, _refreshNow);
  }

  void _refreshNow() {
    if (!mounted) {
      return;
    }
    _lastRefreshAt = DateTime.now();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final packs = widget.controller.offlineEditionPacks;
    final showCancelAll = widget.controller.hasActiveOfflinePackDownloads;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: packs.length + (showCancelAll ? 1 : 0),
      cacheExtent: 360,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        if (showCancelAll && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CancelAllDownloadsTile(
              onCancelAll: widget.controller.cancelAllOfflinePackDownloads,
            ),
          );
        }
        final packIndex = index - (showCancelAll ? 1 : 0);
        final pack = packs[packIndex];
        final bottomPadding = packIndex == packs.length - 1 ? 0.0 : 12.0;
        final edition = pack.edition;
        final isDownloading = widget.controller.isOfflinePackDownloading(
          edition,
        );
        final isReady = widget.controller.isOfflinePackDownloaded(edition);
        final isBuiltIn = widget.controller.isBundledPackForEdition(edition);
        final canDownload = widget.controller.hasZipPackForEdition(edition) &&
            !isDownloading &&
            !isReady &&
            !isBuiltIn;
        final canDelete = isReady && !isBuiltIn && !isDownloading;
        final progress = widget.controller.offlinePackProgressForEdition(
          edition,
        );
        final statusLabel = isDownloading
            ? 'Downloading ${(progress * 100).round()}%'
            : isReady || isBuiltIn
                ? 'Ready'
                : 'Not downloaded';

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: RepaintBoundary(
            child: _AssetPackTile(
              edition: edition,
              statusLabel: statusLabel,
              subtitle: widget.controller.adminPackSubtitleForEdition(edition),
              progress: isDownloading ? progress : null,
              isDownloading: isDownloading,
              onDownload: canDownload
                  ? () => widget.onDownload(context, edition)
                  : null,
              onCancelDownload: isDownloading
                  ? () => widget.controller.cancelOfflineEditionPackDownload(
                        edition,
                      )
                  : null,
              onDelete:
                  canDelete ? () => widget.onDelete(context, edition) : null,
            ),
          ),
        );
      },
    );
  }
}

class _AssetPackTile extends StatelessWidget {
  const _AssetPackTile({
    required this.edition,
    required this.statusLabel,
    required this.subtitle,
    required this.isDownloading,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onDelete,
    this.progress,
  });

  final MushafEdition edition;
  final String statusLabel;
  final String subtitle;
  final bool isDownloading;
  final VoidCallback? onDownload;
  final VoidCallback? onCancelDownload;
  final VoidCallback? onDelete;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = progress;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    edition.shortLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edition.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete pack',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (progressValue != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progressValue <= 0 || progressValue >= 1
                    ? null
                    : progressValue,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDownload,
                    icon: Icon(
                      isDownloading
                          ? Icons.downloading_rounded
                          : Icons.download_rounded,
                    ),
                    label: Text(isDownloading ? 'In progress' : 'Download'),
                  ),
                ),
                if (onCancelDownload != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onCancelDownload,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelAllDownloadsTile extends StatelessWidget {
  const _CancelAllDownloadsTile({
    required this.onCancelAll,
  });

  final VoidCallback onCancelAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.downloading_rounded,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Downloads are running',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onCancelAll,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel all'),
            ),
          ],
        ),
      ),
    );
  }
}
