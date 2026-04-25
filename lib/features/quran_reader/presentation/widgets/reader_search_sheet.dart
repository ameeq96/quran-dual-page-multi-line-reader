import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import 'reader_skeleton.dart';
import 'reader_sheet_frame.dart';

Future<int?> showReaderSearchSheet(
  BuildContext context, {
  required List<QuranSurahNavigationEntry> surahs,
  required List<QuranJuzNavigationEntry> juzs,
  required int Function(QuranSurahNavigationEntry entry) surahPageResolver,
  required int Function(QuranJuzNavigationEntry entry) juzPageResolver,
  required Future<List<QuranSurahNavigationEntry>> Function(String query)
      surahSearch,
  required Future<List<QuranJuzNavigationEntry>> Function(String query)
      juzSearch,
  int initialTab = 0,
  bool showTabs = true,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: ReaderSheetFrame(
          child: ReaderSearchContent(
            surahs: surahs,
            juzs: juzs,
            initialTab: initialTab,
            showHandle: true,
            showTabs: showTabs,
            surahPageResolver: surahPageResolver,
            juzPageResolver: juzPageResolver,
            surahSearch: surahSearch,
            juzSearch: juzSearch,
          ),
        ),
      );
    },
  );
}

class ReaderSearchContent extends StatefulWidget {
  const ReaderSearchContent({
    super.key,
    required this.surahs,
    required this.juzs,
    required this.initialTab,
    this.showHandle = false,
    this.showTabs = true,
    this.applyKeyboardInset = true,
    required this.surahPageResolver,
    required this.juzPageResolver,
    required this.surahSearch,
    required this.juzSearch,
  });

  final List<QuranSurahNavigationEntry> surahs;
  final List<QuranJuzNavigationEntry> juzs;
  final int initialTab;
  final bool showHandle;
  final bool showTabs;
  final bool applyKeyboardInset;
  final int Function(QuranSurahNavigationEntry entry) surahPageResolver;
  final int Function(QuranJuzNavigationEntry entry) juzPageResolver;
  final Future<List<QuranSurahNavigationEntry>> Function(String query)
      surahSearch;
  final Future<List<QuranJuzNavigationEntry>> Function(String query) juzSearch;

  @override
  State<ReaderSearchContent> createState() => _ReaderSearchContentState();
}

class _ReaderSearchContentState extends State<ReaderSearchContent>
    with SingleTickerProviderStateMixin {
  static const Duration _searchDebounce = Duration(milliseconds: 140);

  late final TabController _tabController;
  final TextEditingController _surahSearchController = TextEditingController();
  final TextEditingController _juzSearchController = TextEditingController();
  Timer? _refreshTimer;
  late int _lastTabIndex;
  int _activeSearchToken = 0;
  String? _searchError;
  bool _surahLoading = false;
  bool _juzLoading = false;
  List<QuranSurahNavigationEntry> _surahResults =
      const <QuranSurahNavigationEntry>[];
  List<QuranJuzNavigationEntry> _juzResults = const <QuranJuzNavigationEntry>[];

  @override
  void initState() {
    super.initState();
    final normalizedInitialTab = widget.initialTab < 0
        ? 0
        : (widget.initialTab > 1 ? 1 : widget.initialTab);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: normalizedInitialTab,
    );
    _lastTabIndex = _tabController.index;
    _tabController.addListener(_handleTabChanged);
    _surahSearchController.addListener(_scheduleRefresh);
    _juzSearchController.addListener(_scheduleRefresh);
    _surahResults = widget.surahs;
    _juzResults = widget.juzs;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runActiveSearch();
    });
  }

  void _refreshNow() {
    _refreshTimer?.cancel();
    _runActiveSearch();
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (nextIndex == _lastTabIndex) {
      return;
    }
    _lastTabIndex = nextIndex;
    _refreshNow();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_searchDebounce, _refreshNow);
  }

  Future<void> _runActiveSearch() async {
    final searchToken = ++_activeSearchToken;
    switch (_tabController.index) {
      case 0:
        await _runSurahSearch(searchToken);
        break;
      case 1:
      default:
        await _runJuzSearch(searchToken);
        break;
    }
  }

  Future<void> _runSurahSearch(int searchToken) async {
    final query = _surahSearchController.text.trim();
    if (!mounted || searchToken != _activeSearchToken) {
      return;
    }
    setState(() {
      _surahLoading = true;
      _searchError = null;
      if (query.isEmpty) {
        _surahResults = widget.surahs;
      }
    });

    try {
      final results = await widget.surahSearch(query);
      if (!mounted || searchToken != _activeSearchToken) {
        return;
      }
      setState(() {
        _surahResults = results;
        _surahLoading = false;
      });
    } catch (_) {
      if (!mounted || searchToken != _activeSearchToken) {
        return;
      }
      setState(() {
        _surahLoading = false;
        _surahResults = const <QuranSurahNavigationEntry>[];
        _searchError = 'Unable to load surah search.';
      });
    }
  }

  Future<void> _runJuzSearch(int searchToken) async {
    final query = _juzSearchController.text.trim();
    if (!mounted || searchToken != _activeSearchToken) {
      return;
    }
    setState(() {
      _juzLoading = true;
      _searchError = null;
      if (query.isEmpty) {
        _juzResults = widget.juzs;
      }
    });

    try {
      final results = await widget.juzSearch(query);
      if (!mounted || searchToken != _activeSearchToken) {
        return;
      }
      setState(() {
        _juzResults = results;
        _juzLoading = false;
      });
    } catch (_) {
      if (!mounted || searchToken != _activeSearchToken) {
        return;
      }
      setState(() {
        _juzLoading = false;
        _juzResults = const <QuranJuzNavigationEntry>[];
        _searchError = 'Unable to load sipara search.';
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _surahSearchController.dispose();
    _juzSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTabIndex = _tabController.index;
    final filteredSurahs = activeTabIndex == 0 ? _surahResults : widget.surahs;
    final filteredJuzs = activeTabIndex == 1 ? _juzResults : widget.juzs;

    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
          final compact = constraints.maxHeight < 620;
          final ultraCompact = constraints.maxHeight < 180;
          final veryCompact = constraints.maxHeight < 120;
          final collapseTopChrome = keyboardOpen && constraints.maxHeight < 320;
          final showHandleInLayout = widget.showHandle && !collapseTopChrome;
          final showTabsInLayout = widget.showTabs && !collapseTopChrome;
          final topGap = veryCompact ? 4.0 : (compact ? 12.0 : 20.0);
          final sectionGap = veryCompact ? 6.0 : (compact ? 12.0 : 18.0);
          final fieldGap = collapseTopChrome
              ? 4.0
              : (veryCompact ? 8.0 : (compact ? 10.0 : 14.0));
          final bottomInset = widget.applyKeyboardInset
              ? MediaQuery.of(context).viewInsets.bottom
              : 0.0;

          return Padding(
            padding: EdgeInsets.only(
              left: veryCompact ? 10 : (ultraCompact ? 14 : 20),
              right: veryCompact ? 10 : (ultraCompact ? 14 : 20),
              top: collapseTopChrome
                  ? 2
                  : (veryCompact ? 6 : (ultraCompact ? 10 : 18)),
              bottom: bottomInset +
                  (collapseTopChrome
                      ? 2
                      : (veryCompact ? 6 : (ultraCompact ? 10 : 20))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: showHandleInLayout
                      ? Container(
                          width: 54,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  height: collapseTopChrome
                      ? 0
                      : (showHandleInLayout ? topGap : (ultraCompact ? 0 : 4)),
                ),
                if (showTabsInLayout) ...[
                  _SearchTabSwitcher(
                    controller: _tabController,
                    compact: compact,
                    veryCompact: veryCompact,
                  ),
                  SizedBox(height: sectionGap),
                ],
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: widget.showTabs
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    children: [
                      Column(
                        children: [
                          _SearchField(
                            controller: _surahSearchController,
                            icon: Icons.search_rounded,
                            hintText: 'Search surah name',
                            dense: collapseTopChrome,
                          ),
                          SizedBox(height: fieldGap),
                          Expanded(
                            child: _ListSurface(
                              child: _surahLoading && filteredSurahs.isEmpty
                                  ? ReaderSkeletonResultList(compact: compact)
                                  : filteredSurahs.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(
                                              _searchError ??
                                                  'No matching surahs were found.',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.all(8),
                                          itemCount: filteredSurahs.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final surah = filteredSurahs[index];
                                            return _ResultTile(
                                              leadingLabel: '${surah.id}',
                                              title: surah.nameSimple,
                                              subtitle:
                                                  '${surah.nameArabic} | Page ${widget.surahPageResolver(surah)}',
                                              trailing: surah.translatedName,
                                              compact: compact,
                                              onTap: () =>
                                                  Navigator.of(context).pop(
                                                widget.surahPageResolver(surah),
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          _SearchField(
                            controller: _juzSearchController,
                            icon: Icons.search_rounded,
                            hintText: 'Search sipara',
                            dense: collapseTopChrome,
                          ),
                          SizedBox(height: fieldGap),
                          Expanded(
                            child: _ListSurface(
                              child: _juzLoading && filteredJuzs.isEmpty
                                  ? ReaderSkeletonResultList(compact: compact)
                                  : filteredJuzs.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Text(
                                              _searchError ??
                                                  'No matching siparas were found.',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.all(8),
                                          itemCount: filteredJuzs.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (context, index) {
                                            final juz = filteredJuzs[index];
                                            return _ResultTile(
                                              leadingLabel: '${juz.number}',
                                              title: 'Sipara ${juz.number}',
                                              subtitle:
                                                  '${juz.name} | ${juz.nameArabic} | Page ${widget.juzPageResolver(juz)}',
                                              trailing: 'Juz',
                                              compact: compact,
                                              onTap: () =>
                                                  Navigator.of(context).pop(
                                                widget.juzPageResolver(juz),
                                              ),
                                            );
                                          },
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchTabSwitcher extends StatelessWidget {
  const _SearchTabSwitcher({
    required this.controller,
    required this.compact,
    required this.veryCompact,
  });

  static const _tabs = <({String label, IconData icon})>[
    (label: 'Surah', icon: Icons.menu_book_rounded),
    (label: 'Sipara', icon: Icons.layers_rounded),
  ];

  final TabController controller;
  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.44),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(veryCompact ? 6 : (compact ? 8 : 10)),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == _tabs.length - 1 ? 0 : (compact ? 8 : 10),
                    ),
                    child: _SearchTabChip(
                      label: tab.label,
                      icon: tab.icon,
                      selected: controller.index == index,
                      compact: compact,
                      veryCompact: veryCompact,
                      onTap: () => controller.animateTo(index),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _SearchTabChip extends StatelessWidget {
  const _SearchTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.compact,
    required this.veryCompact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool compact;
  final bool veryCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1);
    final minChipHeight = veryCompact ? 34.0 : (compact ? 44.0 : 48.0);
    final horizontalPadding = veryCompact ? 8.0 : (compact ? 9.0 : 12.0);
    final verticalPadding = scaleFactor > 1.05
        ? (veryCompact ? 5.0 : (compact ? 8.0 : 9.0))
        : (veryCompact ? 6.0 : (compact ? 10.0 : 11.0));

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minHeight: minChipHeight),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.26)
                : theme.dividerColor.withValues(alpha: 0.32),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!veryCompact) ...[
                Icon(
                  icon,
                  size: compact ? 16 : 18,
                  color: foreground,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: const TextScaler.linear(1),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: veryCompact ? 13 : (compact ? 14 : 15),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.icon,
    required this.hintText,
    this.dense = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: dense
            ? const []
            : [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: dense,
          prefixIcon: Icon(icon, size: dense ? 18 : 22),
          prefixIconConstraints:
              dense ? const BoxConstraints(minWidth: 40, minHeight: 40) : null,
          contentPadding: dense
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
              : null,
          hintText: hintText,
        ),
      ),
    );
  }
}

class _ListSurface extends StatelessWidget {
  const _ListSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withValues(alpha: 0.96),
            theme.colorScheme.surfaceContainer.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.46),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.leadingLabel,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.compact,
    required this.onTap,
  });

  final String leadingLabel;
  final String title;
  final String subtitle;
  final String trailing;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.34),
        ),
      ),
      child: ListTile(
        dense: compact,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        minVerticalPadding: compact ? 2 : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 0 : 2,
        ),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
          foregroundColor: theme.colorScheme.primary,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                leadingLabel,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.32,
          ),
        ),
        trailing: SizedBox(
          width: compact ? 72 : 96,
          child: Align(
            alignment: Alignment.centerRight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.34),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  trailing,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
