import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';

import '../controllers/quran_reader_controller.dart';
import 'reader_app_bar.dart';

enum _DrawerPane {
  english('English'),
  urdu('Urdu');

  const _DrawerPane(this.label);

  final String label;
}

class ReaderTranslationDrawer extends StatefulWidget {
  const ReaderTranslationDrawer({
    super.key,
    required this.controller,
    required this.bottomInset,
    required this.compact,
  });

  final QuranReaderController controller;
  final double bottomInset;
  final bool compact;

  @override
  State<ReaderTranslationDrawer> createState() =>
      _ReaderTranslationDrawerState();
}

class _ReaderTranslationDrawerState extends State<ReaderTranslationDrawer> {
  bool _expanded = false;
  _DrawerPane _pane = _DrawerPane.english;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller.pageListenable,
      builder: (context, _) {
        final theme = Theme.of(context);
        final insight = widget.controller.currentPageInsight;
        final translation = _pane == _DrawerPane.english
            ? insight?.translationEn ?? ''
            : insight?.translationUr ?? '';

        return AnimatedPositionedDirectional(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          start: widget.compact ? 12 : 16,
          end: widget.compact ? 12 : 16,
          bottom: widget.bottomInset,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.xl - 4),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.7),
                  ),
                  boxShadow: AppDecor.of(context).floatShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expanded = !_expanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const ReaderAccentBadge(
                              icon: Icons.translate_rounded,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(context, 'Translation drawer'),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tr(context, insight == null
                                        ? 'No translation on this page.'
                                        : 'Page ${widget.controller.currentPageNumber}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_up_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: _expanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SegmentedButton<_DrawerPane>(
                                showSelectedIcon: false,
                                segments: _DrawerPane.values
                                    .map(
                                      (pane) => ButtonSegment<_DrawerPane>(
                                        value: pane,
                                        label: Text(tr(context, pane.label)),
                                      ),
                                    )
                                    .toList(growable: false),
                                selected: <_DrawerPane>{_pane},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _pane = selection.first;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: widget.compact ? 120 : 160,
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  translation.isEmpty ? tr(context, 'Translation is unavailable for this page.') : translation,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
