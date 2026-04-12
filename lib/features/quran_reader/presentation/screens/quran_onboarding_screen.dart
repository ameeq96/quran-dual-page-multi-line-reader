import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../controllers/quran_reader_controller.dart';

class QuranOnboardingScreen extends StatefulWidget {
  const QuranOnboardingScreen({
    super.key,
    required this.controller,
    required this.onComplete,
  });

  final QuranReaderController controller;
  final Future<void> Function() onComplete;

  @override
  State<QuranOnboardingScreen> createState() => _QuranOnboardingScreenState();
}

class _QuranOnboardingScreenState extends State<QuranOnboardingScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _finishing = false;

  static const List<_OnboardingItem> _items = <_OnboardingItem>[
    _OnboardingItem(
      title: 'Read your way',
      subtitle:
          'Switch between multiple Mushaf editions, portrait and landscape reading, and paper-style day or night mode.',
      icon: Icons.auto_stories_rounded,
      highlights: <String>[
        '10, 13, 14, 15, 16, and 17 line Mushaf support',
        'Portrait single-page and landscape spread reading',
        'Day mode, night mode, and reading surface controls',
      ],
    ),
    _OnboardingItem(
      title: 'Jump anywhere fast',
      subtitle:
          'Find what you need quickly from Surah index, Juz index, exact page jump, bookmarks, and page thumbnails.',
      icon: Icons.travel_explore_rounded,
      highlights: <String>[
        'Surah, Juz, Ayah, and text search',
        'Go to page and thumbnail preview navigation',
        'Resume reading and saved bookmarks',
      ],
    ),
    _OnboardingItem(
      title: 'Study and listen',
      subtitle:
          'Use audio recitation, insights, Kanzul Iman study mode, and compare editions side by side for deeper study.',
      icon: Icons.headphones_rounded,
      highlights: <String>[
        'Qari selection, play, pause, stop, and repeat',
        'Insights, notes, favorites, and daily target tracking',
        'Compare editions and Kanzul Iman study pages',
      ],
    ),
    _OnboardingItem(
      title: 'Use AI study tools',
      subtitle:
          'Open AI Studio for page explanations, study notes, semantic search, memorization review, and quick tafsir help.',
      icon: Icons.auto_awesome_rounded,
      highlights: <String>[
        'Explain the current page in simple language',
        'Generate notes, reflections, and teaching points',
        'Use AI smart search, hifz coach, and tajweed guidance',
      ],
    ),
    _OnboardingItem(
      title: 'Plan, revise, and scale',
      subtitle:
          'Use the new plans and packs hub for reading goals, hifz revision, offline edition pack strategy, accessibility, and backup-ready sync settings.',
      icon: Icons.insights_outlined,
      highlights: <String>[
        'Reading plans for steady flow, Ramadan, 30-day khatam, and custom goals',
        'Weak-page hifz tracking and quick revision queue',
        'Offline pack planning, AI depth modes, larger text, and backup export',
      ],
    ),
    _OnboardingItem(
      title: 'Built for daily use',
      subtitle:
          'Track streaks, continue from your last page, and keep everything ready from the home menu.',
      icon: Icons.verified_rounded,
      highlights: <String>[
        'Daily target and khatam progress',
        'Reader dashboard and quick access tools',
        'Optimized reader flow for fast opening and smooth navigation',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    setState(() {
      _finishing = true;
    });
    await widget.onComplete();
    if (mounted) {
      setState(() {
        _finishing = false;
      });
    }
  }

  Future<void> _next() async {
    if (_currentIndex >= _items.length - 1) {
      await _finish();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.settingsListenable,
        widget.controller.contentListenable,
      ]),
      builder: (context, _) {
        final settings = widget.controller.settings;
        final experience = widget.controller.experienceSettings;
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
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final size = MediaQuery.of(context).size;
              final compact = size.width < 420 || size.height < 760;

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        theme.colorScheme.surfaceContainerLowest
                            .withOpacity(theme.brightness == Brightness.dark ? 0.92 : 1),
                        theme.colorScheme.surface,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 14 : 18,
                        compact ? 12 : 16,
                        compact ? 14 : 18,
                        compact ? 14 : 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: compact ? 48 : 56,
                                height: compact ? 48 : 56,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    theme.brightness == Brightness.dark ? 0.18 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome to Quran Dual Page & Multi-Line Reader',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'A quick overview of what you can use in the app.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _finishing ? null : _finish,
                                child: const Text('Skip'),
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 14 : 18),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _items.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _OnboardingCard(
                                  item: item,
                                  compact: compact,
                                );
                              },
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List<Widget>.generate(
                              _items.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: index == _currentIndex ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index == _currentIndex
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 12 : 16),
                          FilledButton.icon(
                            onPressed: _finishing ? null : _next,
                            icon: Icon(
                              _currentIndex == _items.length - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            label: Text(
                              _currentIndex == _items.length - 1
                                  ? 'Start using the app'
                                  : 'Next',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.item,
    required this.compact,
  });

  final _OnboardingItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(
            theme.brightness == Brightness.dark ? 0.96 : 0.9,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(
                theme.brightness == Brightness.dark ? 0.16 : 0.08,
              ),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortCard = constraints.maxHeight < 420;
            final padding = shortCard ? (compact ? 16.0 : 18.0) : (compact ? 18.0 : 24.0);
            final titleStyle = (shortCard ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall)
                ?.copyWith(
                  fontWeight: FontWeight.w900,
                );
            final subtitleStyle = (shortCard ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                ?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: shortCard ? 1.35 : 1.45,
                );
            final content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: shortCard ? 56 : (compact ? 64 : 72),
                  height: shortCard ? 56 : (compact ? 64 : 72),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(
                      theme.brightness == Brightness.dark ? 0.2 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(shortCard ? 18 : 22),
                  ),
                  child: Icon(
                    item.icon,
                    size: shortCard ? 28 : (compact ? 30 : 34),
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: shortCard ? 12 : (compact ? 16 : 20)),
                Text(
                  item.title,
                  style: titleStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: subtitleStyle,
                ),
                SizedBox(height: shortCard ? 14 : (compact ? 18 : 22)),
                ...item.highlights.map((highlight) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: shortCard ? 10 : 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest
                            .withOpacity(
                          theme.brightness == Brightness.dark ? 0.72 : 1,
                        ),
                        borderRadius: BorderRadius.circular(shortCard ? 16 : 20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: shortCard ? 12 : 14,
                          vertical: shortCard ? 12 : 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: shortCard ? 18 : 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                highlight,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                  height: shortCard ? 1.3 : 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );

            return Padding(
              padding: EdgeInsets.all(padding),
              child: shortCard
                  ? SingleChildScrollView(child: content)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: compact ? 64 : 72,
                          height: compact ? 64 : 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(
                              theme.brightness == Brightness.dark ? 0.2 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            item.icon,
                            size: compact ? 30 : 34,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 20),
                        Text(
                          item.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 22),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: item.highlights.map((highlight) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerLowest
                                          .withOpacity(
                                        theme.brightness == Brightness.dark ? 0.72 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              highlight,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlights,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> highlights;
}
