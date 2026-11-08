import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import '../../domain/models/quran_asset_pack_download.dart';
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
                title: Text(tr(context, 'Download another edition?')),
                content: Text(
                  tr(context, '${activeDownload.label} is already downloading. '
                  'Do you want to start downloading ${edition.label} too?'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr(context, 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(tr(context, 'Download')),
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
      if (!controller.isOfflinePackDownloaded(edition) ||
          controller.isOfflinePackPaused(edition) ||
          controller.isOfflinePackDownloading(edition)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '${edition.label} is ready offline.'))),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, _downloadErrorMessage(error)))),
      );
    }
  }

  String _downloadErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('paused')) return 'Download paused. Saved data is kept for resume.';
    if (message.contains('wi-fi-only')) return 'Wi-Fi-only downloads are enabled. Connect to Wi-Fi to continue.';
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
        SnackBar(content: Text(tr(context, '${edition.label} pack deleted.'))),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'Delete failed: $error'))),
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
              title: Text(tr(context, 'Asset Packs')),
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
    unawaited(widget.controller.refreshDownloadStorage().catchError((Object _) {}));
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
    unawaited(widget.controller.refreshDownloadStorage().catchError((Object _) {}));
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
      itemCount: packs.length + 1 + (showCancelAll ? 1 : 0),
      cacheExtent: 360,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DownloadStorageCard(controller: widget.controller),
          );
        }
        if (showCancelAll && index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CancelAllDownloadsTile(
              onCancelAll: widget.controller.cancelAllOfflinePackDownloads,
            ),
          );
        }
        final packIndex = index - 1 - (showCancelAll ? 1 : 0);
        final pack = packs[packIndex];
        final bottomPadding = packIndex == packs.length - 1 ? 0.0 : 12.0;
        final edition = pack.edition;
        final isDownloading = widget.controller.isOfflinePackDownloading(
          edition,
        );
        final isReady = widget.controller.isOfflinePackDownloaded(edition);
        final isPaused = widget.controller.isOfflinePackPaused(edition);
        final partial = widget.controller.partialOfflinePackForEdition(edition);
        final transfer = widget.controller.transferProgressForEdition(edition);
        final isBuiltIn = widget.controller.isBundledPackForEdition(edition);
        final canDownload =
            widget.controller.hasDownloadablePackForEdition(edition) &&
                !isDownloading &&
                (!isReady || isPaused) &&
                !isBuiltIn;
        final canDelete = isReady && !isBuiltIn && !isDownloading;
        final progress = widget.controller.offlinePackProgressForEdition(
          edition,
        );
        final statusLabel = isDownloading
            ? switch (transfer?.phase) {
                QuranPackTransferPhase.extracting => 'Verifying & extracting',
                QuranPackTransferPhase.publishing => 'Saving offline pack',
                _ => 'Downloading ${(progress * 100).round()}%',
              }
            : isPaused ? 'Paused'
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
              isPaused: isPaused,
              restartRequired: partial?.canResume == false,
              transferLabel: _transferLabel(transfer, partial),
              onDownload: isDownloading
                  ? () => widget.controller.pauseOfflineEditionPackDownload(edition)
                  : canDownload ? () => widget.onDownload(context, edition) : null,
              onCancelDownload: isDownloading
                  ? () => widget.controller.cancelOfflineEditionPackDownload(edition)
                  : isPaused ? () async {
                      try {
                        await widget.controller.discardPausedOfflineEditionPack(edition);
                      } catch (error) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(context, 'Unable to remove partial download.'))),
                        );
                      }
                    } : null,
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
    required this.isPaused,
    required this.restartRequired,
    required this.transferLabel,
    required this.onDownload,
    required this.onCancelDownload,
    required this.onDelete,
    this.progress,
  });

  final MushafEdition edition;
  final String statusLabel;
  final String subtitle;
  final bool isDownloading;
  final bool isPaused;
  final bool restartRequired;
  final String? transferLabel;
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
                    tr(context, edition.shortLabel),
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
                        tr(context, edition.label),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(context, statusLabel),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Delete pack'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr(context, subtitle).replaceFirst(edition.bestUseLabel, tr(context, edition.bestUseLabel)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (transferLabel != null) ...[
              const SizedBox(height: 8),
              Text(tr(context, transferLabel!), style: theme.textTheme.labelMedium),
            ],
            if (progressValue != null) ...[
              const SizedBox(height: 12),
              Semantics(
                container: true,
                child: LinearProgressIndicator(
                  value: progressValue <= 0 || progressValue >= 1
                      ? null
                      : progressValue,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                ),
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
                          ? Icons.pause_rounded
                          : isPaused ? Icons.play_arrow_rounded : Icons.download_rounded,
                    ),
                    label: Text(tr(context, isDownloading ? 'Pause' : isPaused ? (restartRequired ? 'Restart' : 'Resume') : 'Download')),
                  ),
                ),
                if (onCancelDownload != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onCancelDownload,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(tr(context, 'Cancel')),
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
                tr(context, 'Downloads are running'),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onCancelAll,
              icon: const Icon(Icons.close_rounded),
              label: Text(tr(context, 'Cancel all')),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPackBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String? _transferLabel(QuranPackTransferProgress? transfer, QuranPartialAssetPack? partial) {
  final received = transfer?.receivedBytes ?? partial?.receivedBytes;
  if (received == null) return null;
  final total = transfer?.totalBytes ?? partial?.totalBytes;
  return total == null || total <= 0
      ? _formatPackBytes(received)
      : '${_formatPackBytes(received)} / ${_formatPackBytes(total)}';
}

class _DownloadStorageCard extends StatelessWidget {
  const _DownloadStorageCard({required this.controller});
  final QuranReaderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = controller.packStorageInfo;
    final quota = info?.browserQuotaBytes;
    final usage = info?.browserUsageBytes;
    final free = controller.availableStorageBytes ??
        (quota != null && usage != null ? (quota - usage).clamp(0, quota) : null);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(context, 'Storage & downloads'), style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(tr(context, info == null ? tr(context, 'Checking storage…') :
            tr(context, 'Downloaded files: {size}', args: {'size': _formatPackBytes(info.totalBytes)}))),
          if (info != null && info.partialBytes > 0 && !controller.hasActiveOfflinePackDownloads)
            Text(tr(context, 'Paused data: {size}', args: {'size': _formatPackBytes(info.partialBytes)})),
          Text(tr(context, free == null ? tr(context, 'Available space could not be measured.') :
            tr(context, controller.availableStorageBytes == null ? 'Browser storage available: about {size}' : 'Device space available: {size}',
              args: {'size': _formatPackBytes(free.toInt())}))),
          if (quota != null) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(tr(context, 'Browser storage is an estimate and may be cleared by the browser.'), style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Wi-Fi-only downloads')),
            subtitle: Text(tr(context, controller.supportsWifiOnlyDownloads
                ? 'Pause edition downloads when Wi-Fi disconnects.'
                : 'Wi-Fi detection is available in the mobile app.')),
            value: controller.wifiOnlyDownloads,
            onChanged: !controller.supportsWifiOnlyDownloads ? null : (value) async {
              try {
                await controller.setWifiOnlyDownloads(value);
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr(context, 'Unable to save download setting.'))),
                );
              }
            },
          ),
        ]),
      ),
    );
  }
}
