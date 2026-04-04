import 'package:flutter/material.dart';

import '../controllers/quran_reader_controller.dart';

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

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          left: widget.compact ? 10 : 18,
          right: widget.compact ? 10 : 18,
          bottom: widget.bottomInset,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
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
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Translation drawer',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    insight == null
                                        ? 'No translation on this page.'
                                        : 'Page ${widget.controller.currentPageNumber}',
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
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: _expanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SegmentedButton<_DrawerPane>(
                                showSelectedIcon: false,
                                segments: _DrawerPane.values
                                    .map(
                                      (pane) => ButtonSegment<_DrawerPane>(
                                        value: pane,
                                        label: Text(pane.label),
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
                                  translation.isEmpty
                                      ? 'Translation is unavailable for this page.'
                                      : translation,
                                  style: theme.textTheme.bodyMedium,
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
