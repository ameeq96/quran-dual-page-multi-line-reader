import 'package:flutter/material.dart';

import '../../domain/models/reader_settings.dart';

class ReaderSettingsSheet extends StatefulWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.settings,
    required this.availableImageEditions,
    this.showHandle = true,
    required this.onSelectMushafEdition,
    required this.onToggleFullscreen,
    required this.onTogglePageNumbers,
    required this.onToggleCustomBrightness,
    required this.onBrightnessChanged,
    required this.onToggleNightMode,
    required this.onTogglePageNightMode,
    required this.onTogglePagePreset,
    required this.onSelectPagePreset,
    required this.onTogglePageOverlay,
    required this.onTogglePageReflection,
    required this.onToggleLowMemoryMode,
    required this.onToggleHifzFocusMode,
    required this.onHifzMaskHeightFactorChanged,
    required this.onToggleHifzRevealOnHold,
  });

  final ReaderSettings settings;
  final List<MushafEdition> availableImageEditions;
  final bool showHandle;
  final ValueChanged<MushafEdition> onSelectMushafEdition;
  final ValueChanged<bool> onToggleFullscreen;
  final ValueChanged<bool> onTogglePageNumbers;
  final ValueChanged<bool> onToggleCustomBrightness;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<bool> onToggleNightMode;
  final ValueChanged<bool> onTogglePageNightMode;
  final ValueChanged<bool> onTogglePagePreset;
  final ValueChanged<PagePreset> onSelectPagePreset;
  final ValueChanged<bool> onTogglePageOverlay;
  final ValueChanged<bool> onTogglePageReflection;
  final ValueChanged<bool> onToggleLowMemoryMode;
  final ValueChanged<bool> onToggleHifzFocusMode;
  final ValueChanged<double> onHifzMaskHeightFactorChanged;
  final ValueChanged<bool> onToggleHifzRevealOnHold;

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.settings;
    final availableImageEditions = widget.availableImageEditions;
    final selectedEdition =
        availableImageEditions.contains(settings.mushafEdition)
            ? settings.mushafEdition
            : (availableImageEditions.isNotEmpty
                ? availableImageEditions.first
                : settings.mushafEdition);

    return SafeArea(
      top: false,
      child: PrimaryScrollController.none(
        child: ListView(
          controller: _scrollController,
          primary: false,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Center(
              child: widget.showHandle
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
            SizedBox(height: widget.showHandle ? 20 : 4),
            const _SectionLabel(
              icon: Icons.auto_awesome_rounded,
              label: 'Reading surface',
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mushaf edition',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          availableImageEditions.length <= 1
                              ? 'Only offline-ready Quran editions are shown here.'
                              : 'Only downloaded or bundled Quran editions are shown here.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.34,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (availableImageEditions.isNotEmpty)
                          _ChoiceBlock<MushafEdition>(
                            values: availableImageEditions,
                            selected: selectedEdition,
                            labelBuilder: (edition) => edition.label,
                            colorBuilder: _mushafEditionColor,
                            onSelected: widget.onSelectMushafEdition,
                          )
                        else
                          Text(
                            'No offline-ready Mushaf edition is available right now.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.light_mode_rounded,
                    title: 'Custom brightness',
                    subtitle:
                        'Tune the page surface without changing device brightness.',
                    value: settings.customBrightnessEnabled,
                    onChanged: widget.onToggleCustomBrightness,
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: settings.customBrightnessEnabled
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      child: _SliderBlock(
                        label:
                            'Adjust page brightness ${(settings.pageBrightness * 100).round()}%',
                        value: settings.pageBrightness,
                        min: 0.7,
                        max: 1.25,
                        onChanged: widget.onBrightnessChanged,
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.dark_mode_rounded,
                    title: 'App dark mode',
                    subtitle: 'Use dark surfaces for menus and app screens.',
                    value: settings.nightMode,
                    onChanged: widget.onToggleNightMode,
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.auto_stories_outlined,
                    title: 'Quran page dark mode',
                    subtitle:
                        'Keep the Mushaf page dark or light independently.',
                    value: settings.pageNightMode,
                    onChanged: widget.onTogglePageNightMode,
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.palette_outlined,
                    title: 'Page preset',
                    subtitle: 'Apply a curated page tone to the spread.',
                    value: settings.pagePresetEnabled,
                    onChanged: widget.onTogglePagePreset,
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: settings.pagePresetEnabled
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      child: _ChoiceBlock<PagePreset>(
                        values: PagePreset.values,
                        selected: settings.pagePreset,
                        labelBuilder: (preset) => preset.label,
                        colorBuilder: _pagePresetColor,
                        onSelected: widget.onSelectPagePreset,
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.layers_rounded,
                    title: 'Page overlay',
                    subtitle: 'Add a soft tonal wash over each page.',
                    value: settings.pageOverlayEnabled,
                    onChanged: widget.onTogglePageOverlay,
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Page reflection',
                    subtitle:
                        'Keep the subtle top sheen that makes the spread feel polished.',
                    value: settings.pageReflectionEnabled,
                    onChanged: widget.onTogglePageReflection,
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.visibility_off_outlined,
                    title: 'Hifz focus mode',
                    subtitle:
                        'Show a draggable conceal plate on the Mushaf page. Tap any line to snap the plate there, or drag it line by line.',
                    value: settings.hifzFocusMode,
                    onChanged: widget.onToggleHifzFocusMode,
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState: settings.hifzFocusMode
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      child: Column(
                        children: [
                          _SliderBlock(
                            label:
                                'Conceal plate size ${(settings.hifzMaskHeightFactor * 100).round()}%',
                            value: settings.hifzMaskHeightFactor,
                            min: 0.18,
                            max: 0.7,
                            divisions: 13,
                            onChanged: widget.onHifzMaskHeightFactorChanged,
                          ),
                          const SizedBox(height: 8),
                          _InlineSwitchTile(
                            icon: Icons.pan_tool_alt_outlined,
                            title: 'Reveal on hold',
                            subtitle:
                                'Press and hold the page to temporarily reveal the concealed text.',
                            value: settings.hifzRevealOnHold,
                            onChanged: widget.onToggleHifzRevealOnHold,
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionLabel(
              icon: Icons.tune_rounded,
              label: 'Reader behavior',
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  _SwitchRow(
                    icon: Icons.fullscreen_rounded,
                    title: 'Fullscreen reading',
                    subtitle:
                        'Hide extra chrome and give the Mushaf more room.',
                    value: settings.fullscreenReading,
                    onChanged: widget.onToggleFullscreen,
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.pin_outlined,
                    title: 'Show page numbers',
                    subtitle:
                        'Keep small page markers visible on generated pages.',
                    value: settings.showPageNumbers,
                    onChanged: widget.onTogglePageNumbers,
                  ),
                  const Divider(height: 1),
                  _SwitchRow(
                    icon: Icons.memory_rounded,
                    title: 'Low memory mode',
                    subtitle:
                        'Reduce image preloading for lighter devices and long sessions.',
                    value: settings.lowMemoryMode,
                    onChanged: widget.onToggleLowMemoryMode,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.34),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.46),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'These appearance controls affect the live Mushaf instantly. Search remains the fastest way to jump by Surah or Sipara.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _pagePresetColor(PagePreset preset) {
    return switch (preset) {
      PagePreset.classic => const Color(0xFF1B6B5D),
      PagePreset.warm => const Color(0xFF9C6B2D),
      PagePreset.emerald => const Color(0xFF2B7A63),
      PagePreset.slate => const Color(0xFF51657F),
    };
  }

  Color _mushafEditionColor(MushafEdition edition) {
    return switch (edition) {
      MushafEdition.lines10 => const Color(0xFF7B4C2F),
      MushafEdition.lines13 => const Color(0xFF8A5B2B),
      MushafEdition.lines14 => const Color(0xFF6E5E9A),
      MushafEdition.lines15 => const Color(0xFF416D9C),
      MushafEdition.lines16 => const Color(0xFF1B6B5D),
      MushafEdition.lines17 => const Color(0xFF945F2A),
      MushafEdition.kanzulIman => const Color(0xFF2D7F64),
    };
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
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
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SwitchListTile.adaptive(
      secondary: Icon(
        icon,
        color: theme.colorScheme.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      value: value,
      onChanged: onChanged,
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.34,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SliderBlock extends StatelessWidget {
  const _SliderBlock({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge,
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions ?? 11,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InlineSwitchTile extends StatelessWidget {
  const _InlineSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.38),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ChoiceBlock<T> extends StatelessWidget {
  const _ChoiceBlock({
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.colorBuilder,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final Color Function(T value) colorBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((value) {
        final selectedValue = value == selected;
        return ChoiceChip(
          selected: selectedValue,
          onSelected: (_) => onSelected(value),
          avatar: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorBuilder(value),
            ),
          ),
          label: Text(labelBuilder(value)),
        );
      }).toList(),
    );
  }
}
